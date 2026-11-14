// [신통방통 반응형 화면 규격 통일 지시서] 공유결과 수신 화면
// (SharedResultScreen) 가로 오버플로 회귀 테스트.
//
// `/r/{shareId}` 딥링크로 도착하는 이 화면은 서버 응답(JSON payload)을
// 그대로 렌더링하므로, 실제 서비스에서 올 수 있는 "길이가 긴" 값
// (제목/설명/인물 이름/태그/조언 등)을 담은 가짜 HTTP 응답으로 테스트해야
// 진짜 회귀를 잡을 수 있다. `package:http/testing.dart`의 MockClient +
// `http.runWithClient`로 실제 네트워크 호출 없이 ShareApiService의 응답을
// 완전히 대체한다(코드 수정 없이 외부에서 주입 가능 — Repository/Provider를
// 건드리지 않는 범용 패턴).
//
// 대상 분기 2가지:
// 1) 일반 타입(`_buildResult`) — wish/tarot/saju/face/palm 공통 경로.
//    카드명/질문/설명/하이라이트 텍스트가 길 때 Row/Container 오버플로
//    여부 확인. → 5개 조건 전부 안전(기존에 이미 Expanded/Container로
//    보호되어 있음, 실제 버그 없음).
// 2) 귀인지도(relationship, `_buildRelationshipResult`) — GmColors 다크
//    테마 전용 경로. 긴 이름/관계 라벨/오행 설명 등으로 확인.
//    → [실제 버그 발견 & 수정 완료] "98 / 100" 점수 Row가 fontSize: 44
//    고정값 + Flexible/FittedBox 보호 없이 배치되어, 320x568@2.0 이상에서
//    RenderFlex 오버플로(최대 150px) 발생. `FittedBox(fit: scaleDown)`로
//    감싸 공간 부족 시에만 비율 유지한 채 축소하도록 수정했다(일반 크기
//    에서는 기존과 완전히 동일하게 렌더링).
//
// [2026-11-11 반응형 전수 점검 — 테스트 인프라 보수]
// "결과페이지 글씨 확대" 기능(커밋 7ba4753b 등)이 추가되면서
// `SharedResultScreen`이 내부적으로 `ResultTextScaleOverlay`를 쓰게
// 됐는데, 그 위젯은 `context.watch<TextScaleProvider>()`로 전역
// Provider를 읽는다. 실제 앱에서는 app.dart의 최상위 `MultiProvider`가
// 항상 이 Provider를 제공하지만, 이 테스트는 `MaterialApp`만 단독으로
// pump해서 Provider 트리가 없어 `ProviderNotFoundException`이 났다 —
// 이건 화면의 반응형/오버플로 버그가 아니라 "글씨 확대 기능 추가 당시
// 이 테스트 파일이 함께 갱신되지 않은" 테스트 인프라 누락이다. 실제
// 앱 동작에는 영향이 없으므로(Provider는 항상 존재) `ChangeNotifierProvider
// <TextScaleProvider>`로 감싸 실제 앱과 동일한 조건을 맞춰준다.
import 'dart:convert';

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/theme/text_scale_provider.dart';
import 'package:flutter_app/features/share/presentation/shared_result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cases = <(Size, double)>[
    (Size(390, 844), 1.0),
    (Size(360, 640), 1.3),
    (Size(320, 568), 1.5),
    (Size(320, 568), 2.0),
    (Size(320, 568), 2.5),
  ];

  /// 일반(wish/tarot/saju 등) 공유 결과 — 긴 텍스트 payload.
  Map<String, dynamic> buildGenericResponse() => {
        'success': true,
        'data': {
          'shareId': 'share_test_001',
          // [resultType] saju로 설정 — '정통사주' 라벨 분기 확인.
          'resultType': 'saju',
          'title': '2026년 신통방통 정통사주 종합 풀이: 재물운과 인간관계가 동시에 크게 상승하는 아주 길고 상세한 제목입니다',
          'description':
              '올해는 당신에게 있어 재물운과 인간관계 양쪽 모두에서 뚜렷한 상승세가 나타나는 해로, 특히 상반기보다는 하반기에 더 큰 변화와 기회가 찾아올 것으로 보이며 평소에 꾸준히 준비해온 일들이 결실을 맺는 시기가 될 것입니다.',
          'payload': {
            'question': '올해 하반기 이직과 재물운은 어떻게 될까요? 지금 다니는 회사에 남아야 할지 새로운 곳으로 옮겨야 할지 고민이 많습니다',
            'cardName': '매우 길고 상세한 카드 이름이 들어가는 경우를 테스트하기 위한 임의의 긴 문자열입니다',
            'summary': '결과 요약 섹션에 들어가는 아주 긴 텍스트로 여러 줄에 걸쳐 표시될 수 있으며 좁은 화면에서는 줄바꿈이 자연스럽게 일어나야 하고 가로로 넘치면 안 됩니다.',
            'advice': {
              'label': '아주 길게 작성된 조언 라벨 텍스트입니다 테스트용',
              'text': '꾸준히 노력하되 서두르지 않는 것이 중요합니다. 특히 금전 관련 결정은 신중하게 내리시고 주변 사람들과 충분히 상의한 뒤에 진행하시길 권합니다.',
            },
            'highlights': [
              '이 달의 운세는 전반적으로 안정적이며 특히 대인관계에서 좋은 소식이 들려올 가능성이 높습니다',
              '재물운은 중반 이후 상승하는 흐름을 보이니 성급한 지출보다는 계획적인 소비가 유리합니다',
            ],
            'luckyColor': '아주 길게 설명되는 행운의 색깔 이름 테스트 문자열',
            'luckyNumber': '7',
          },
          'imageUrl': null,
          'originalImageUrl': null,
          'ownerNickname': '아주긴닉네임을가진사용자테스트케이스입니다',
          'viewCount': 42,
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
      };

  /// 귀인지도(relationship) 공유 결과 — 긴 이름/오행 설명 payload.
  Map<String, dynamic> buildRelationshipResponse() => {
        'success': true,
        'data': {
          'shareId': 'share_test_002',
          'resultType': 'relationship',
          'title': '귀인지도 결과: 아주 길고 상세한 관계 분석 제목이 들어가는 테스트 케이스입니다',
          'description': '관계 분석 설명',
          'payload': {
            'relationType': 'CHEON_GWII',
            'personName': '김아주긴이름테스트용사용자입니다',
            'personBirth': '1990년 1월 1일 (아주 길게 표시되는 생년월일 텍스트)',
            'score': 98,
            'ohaeng': 'WOOD',
            'note': '오행 보충 설명이 매우 길게 작성되어 여러 줄에 걸쳐 표시될 수 있는 테스트용 문자열입니다',
          },
          'imageUrl': null,
          'originalImageUrl': null,
          'ownerNickname': '귀인지도공유자아주긴닉네임테스트',
          'viewCount': 7,
          'createdAt': '2026-01-01T00:00:00.000Z',
        },
      };

  Future<Object?> pumpShared(
    WidgetTester tester,
    Map<String, dynamic> response,
    Size size,
    double scale,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<TextScaleProvider>(
            create: (_) => TextScaleProvider(),
            child: const MaterialApp(
              home: SharedResultScreen(shareId: 'share_test_001'),
            ),
          ),
        ),
      );
      // initState의 addPostFrameCallback -> _load()의 await http 호출이
      // 완료될 때까지 충분히 펌프한다.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }, () => client);
    final ex = tester.takeException();
    if (ex != null) {
      debugDumpRenderTree();
    }
    return ex;
  }

  for (final (size, scale) in cases) {
    final label = '${size.width.toInt()}x${size.height.toInt()}@$scale';

    testWidgets('공유결과 일반 타입(saju) $label overflow 없어야 함', (tester) async {
      final ex = await pumpShared(tester, buildGenericResponse(), size, scale);

      expect(
        ex,
        isNull,
        reason: '공유결과(saju) $label overflow 없어야 함: $ex',
      );
      // 실제로 결과 화면이 그려졌는지(에러로 빠지지 않았는지) 확인.
      expect(find.text('정통사주'), findsOneWidget);
    });

    testWidgets('공유결과 귀인지도(relationship) $label overflow 없어야 함', (
      tester,
    ) async {
      final ex =
          await pumpShared(tester, buildRelationshipResponse(), size, scale);

      expect(
        ex,
        isNull,
        reason: '공유결과(relationship) $label overflow 없어야 함: $ex',
      );
      expect(find.text('98'), findsOneWidget);
    });
  }
}
