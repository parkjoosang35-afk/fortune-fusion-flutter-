import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/pass/application/pass_provider.dart';
import 'package:flutter_app/features/pass/data/pass_repository.dart';
import 'package:flutter_app/features/pass/domain/pass_model.dart';
import 'package:flutter_app/features/result_access/application/result_access_provider.dart';
import 'package:flutter_app/features/result_access/data/result_access_repository.dart';
import 'package:flutter_app/features/result_access/presentation/result_access_gate_sheet.dart';
import 'package:flutter_app/features/wallet/application/wallet_provider.dart';
import 'package:flutter_app/features/wallet/data/wallet_repository.dart';

// [반응형 화면 규격 통일 — 신규 확인 버그] 기존 매트릭스는 textScale 1.3까지만
// 검증했으나, _GateOptionButton(복주머니 옵션)의 subLabel('보유 N개')이
// Flexible 없이 고정 폭으로 Row에 추가되어 있어, label이 줄어들어도
// 320x568 기준 textScale 2.5에서 Row 폭을 초과해 가로 오버플로가 발생함을
// 확인했다(실측 28px, debugDumpRenderTree로 RenderFlex#5b2b8 확인).
// → result_access_gate_sheet.dart의 subLabel Text를 Flexible+ellipsis로
// 감싸 수정. 아래 매트릭스를 2.0/2.5까지 확장해 회귀 검증한다.
//
// [2026-11-11 반응형 전수 점검 — 테스트 시나리오 보수]
// 2026-11-12(커밋 cb03057f) "Freepass-first 강제 퍼널"이
// `showResultAccessGateSheet` 공개 진입점에 추가되면서, 이 테스트가
// 검증하려던 조건(`freePassAvailable:false && todayClaimed:false`, 즉
// "쿠팡 클레임 버튼이 노출되는 상태")은 그 퍼널 로직과 완전히 동일한
// 조건이 되어버렸다 — 이제 그 조건에서는 결제 게이트(이 테스트의 검증
// 대상인 `ResultAccessGateSheet`, 3택 옵션 버튼들)를 공개 진입점으로는
// 아예 열 수 없고, 쿠팡 프리패스 발급 시트(coupang_pass_sheet.dart,
// 별도 테스트 파일로 이미 검증됨)만 뜬다. 즉 기능이 의도적으로 바뀌어
// 이 테스트의 원래 시나리오를 우회해버린 것이지, 레이아웃 버그가 아니다.
//
// 이 파일의 실제 목적(`_GateOptionButton`의 subLabel 가로 오버플로
// 회귀 검증, 그리고 "쿠팡 클레임 노출" 상태에서 옵션이 4개로 늘어났을
// 때의 레이아웃)은 여전히 유효하므로, 공개 진입점의 퍼널을 거치지 않고
// `ResultAccessGateSheet` 위젯 자체를 직접 바텀시트로 띄워 검증한다
// (이 위젯은 같은 파일에서 public으로 export됨 — 캡슐화를 깨지 않는다).
// 퍼널 로직 자체(쿠팡 시트 우선 노출)는 result_access funnel 전용
// 테스트에서 별도로 검증해야 할 영역이라 이 파일의 책임 밖이다.
class _FakePassRepository extends PassRepository {
  @override
  Future<ApiResult<List<PassPolicyModel>>> getPolicies() async {
    return ApiResult.ok([
      const PassPolicyModel(
        id: 11,
        name: '쿠팡 프리패스',
        passType: PassType.ad,
        durationMin: 0,
        grantCount: 2,
        adType: 'image',
        bannerImageUrl: null,
        adGuideTitle: '"재물운 상세 풀이"는 프리패스로 열람할 수 있어요',
        adGuideText: '쿠팡 파트너스 광고를 확인하면 결과보기 2회가\n지급되어 무료로 이용할 수 있어요.',
      ),
    ]);
  }

  @override
  Future<ApiResult<PassStatusModel>> getStatus() async {
    return ApiResult.ok(PassStatusModel.inactive());
  }
}

class _FakePassProvider extends PassProvider {
  _FakePassProvider() : super(_FakePassRepository());
}

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider() : super(WalletRepository());
  @override
  Future<void> load() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  http.Response quoteResponse({
    required bool freePassAvailable,
    required bool pouchSufficient,
    required bool todayClaimed,
  }) {
    final body = {
      'success': true,
      'data': {
        'freePassRemaining': freePassAvailable ? 2 : 0,
        'freePassHasLegacyUnlimited': false,
        'freePassAvailable': freePassAvailable,
        'pouchBalance': pouchSufficient ? 500 : 10,
        'pouchPrice': 100,
        'pouchAvailable': true,
        'adAvailable': true,
        'coupangClaimedTodayKey': null,
        'todayClaimed': todayClaimed,
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<void> runInZone(
    WidgetTester tester,
    http.Client client,
    Future<void> Function() body,
  ) {
    return http.runWithClient(body, () => client);
  }

  // [2026-11-11] coupang_pass_sheet_overflow_test.dart와 동일한 Fake
  // Provider 패턴 — 쿠팡 프리패스 발급 시트(_handleCoupangClaim 경로)가
  // 요구하는 PassProvider/WalletProvider를 네트워크 호출 없이 충족한다.

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '정통사주·타로·80종 공용 결과보기 게이트 시트(쿠팡 클레임 노출)가 '
      '${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final client = MockClient((request) async {
          return quoteResponse(
            freePassAvailable: false,
            pouchSufficient: true,
            todayClaimed: false,
          );
        });

        await runInZone(tester, client, () async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider<ResultAccessProvider>(
                    create: (_) => ResultAccessProvider(ResultAccessRepository()),
                  ),
                  // [2026-11-11] ResultAccessGateSheet 내부(_beginAndClose)가
                  // 결제 완료 시 PassProvider.load()를 호출하므로 테스트
                  // 트리에도 제공해 둔다(이 테스트는 버튼을 탭하지 않으므로
                  // 실제로 호출되지는 않지만, 위젯 빌드 시점에 Provider가
                  // 없으면 이후 리팩터링에서 조용히 깨질 수 있어 방지).
                  ChangeNotifierProvider<PassProvider>(
                    create: (_) => _FakePassProvider(),
                  ),
                  ChangeNotifierProvider<WalletProvider>(
                    create: (_) => _FakeWalletProvider(),
                  ),
                ],
                child: MaterialApp(
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        // [2026-11-11] Freepass-first 강제 퍼널을 우회하고
                        // 이 테스트의 실제 검증 대상인 ResultAccessGateSheet
                        // 위젯 자체를 직접 바텀시트로 띄운다(공개 진입점
                        // showResultAccessGateSheet는 이 조건에서 쿠팡 시트로
                        // 가로채 버려 더 이상 이 시트에 도달할 수 없다).
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ResultAccessGateSheet(
                            contentType: 'saju_renewal',
                            categoryKey: 'wealth',
                            contentTitle: '재물운 상세 풀이',
                            returnRoute: '/saju-renewal/home',
                            userInputForRestore: const {},
                          ),
                        ),
                        child: const Text('열기'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('열기'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          final ex = tester.takeException();
          if (ex != null) debugDumpRenderTree();
          expect(ex, isNull);
          // 쿠팡 클레임 버튼 문구까지 실제로 그려지는지 확인(가장 아래 요소).
          expect(find.text('오늘의 프리패스 2회 받기 (쿠팡 방문)'), findsOneWidget);
        });
      },
    );
  }
}
