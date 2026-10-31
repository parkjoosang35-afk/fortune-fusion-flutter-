// [신통방통 반응형 화면 규격 통일 지시서] 복주머니 광고 시청 팝업
// (FortuneAdWatchDialog) 오버플로 회귀 테스트.
//
// [확인된 실제 버그 2건 - debugDumpRenderTree로 근본원인 확정]
//
// 배경: 이 다이얼로그는 Dialog 본문 전체가 `SizedBox(height: 420)`로
// 고정되어 있었다 — 지금까지 이 지시서에서 고친 버그들은 대부분
// "가로(Row) 오버플로"였지만, 이 다이얼로그는 구조상 "세로(Column)
// 오버플로" 위험이 있는 첫 사례였다.
//
// 버그 1) watching 단계(_WatchingView): 광고 제목(ad.title)에 maxLines
// 제한이 없어, 아주 긴 제목(관리자가 임의로 입력 가능) + textScale
// 1.5배 이상 조합에서 하단 고정 텍스트 블록(Padding+Column, Expanded가
// 아님)이 여러 줄로 늘어나 Stack의 고정 420px 영역을 넘어 세로
// RenderFlex 오버플로가 발생했다(320x568@2.0에서 실측 35px,
// debugDumpRenderTree로 `Column ← Stack ← _WatchingView ← SizedBox`
// 체인에서 OVERFLOWING 확인). 수정: 제목/안내문구 Text에
// `maxLines: 2, overflow: TextOverflow.ellipsis` 추가 — 길이가 넘치면
// 말줄임표로 축약되고, 기존처럼 짧은 제목은 한 줄로 그대로 보인다.
//
// 버그 2) error 단계(_ErrorView): 긴 에러 메시지(네트워크 오류 등 서버가
// 내려줄 수 있는 문자열 길이가 가변적) + textScale 1.5배 이상 조합에서
// `Center > Padding > Column(mainAxisSize: min)`이 420px보다 커져
// 세로 오버플로가 발생했다(320x568@1.5/2.0/2.5에서 실측 76px/316px/
// 666px). 수정: watching 단계를 제외한 나머지 단계(starting/verifying/
// granted/error)는 `SizedBox(height:420)` 대신
// `ConstrainedBox(maxHeight:420) + SingleChildScrollView`로 감싸,
// 내용이 420px보다 커지면 스크롤되게 했다 — 420px보다 작을 때는 기존과
// 시각적으로 완전히 동일하다. watching 단계는 Expanded 기반 레이아웃이라
// 고정 420px가 필요하므로 그대로 유지했다.
//
// [테스트 인프라 참고] watching 단계 테스트는 `_tick()`이 매초 재귀적으로
// `Future.delayed`를 예약하므로, 테스트가 끝나기 전에 그 카운트다운
// 체인을 끝까지 흘려보내지 않으면 flutter_test의
// "Timer is still pending" 어서션에 걸린다 — 프로덕션 버그가 아니라
// 테스트 자체의 문제라, 아래에서 `watchSeconds`만큼 pump해 카운트다운을
// 완전히 소진시킨 뒤 테스트를 종료한다.
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/features/fortune_ad/application/fortune_ad_provider.dart';
import 'package:flutter_app/features/fortune_ad/data/fortune_ad_repository.dart';
import 'package:flutter_app/features/fortune_ad/domain/fortune_ad_model.dart';
import 'package:flutter_app/features/fortune_ad/presentation/fortune_ad_watch_dialog.dart';

const _longTitle =
    '신통방통 복주머니 무료 충전 이벤트 광고 — 끝까지 시청하면 큰 혜택이 쏟아지는 특별한 프로모션 영상입니다 (매우 긴 제목 테스트)';

const _longErrorMessage =
    '지금은 네트워크 상태가 불안정하거나 서버 쪽 일시적인 오류로 인해 보상 지급 요청을 처리할 수 없습니다. '
    '잠시 후 Wi-Fi 또는 데이터 연결 상태를 확인하신 뒤 다시 시도해주세요. 문제가 계속되면 고객센터로 문의해주세요.';

/// 시청 시작(start)은 성공시켜 watching 단계로 진입시키되, 실제 비디오/
/// 이미지 URL은 비워 `_fallbackIcon()` 경로로만 렌더링되게 한다(네트워크
/// 이미지 로딩에 테스트가 좌우되지 않도록).
class _FakeFortuneAdRepository extends FortuneAdRepository {
  @override
  Future<ApiResult<FortuneAdWatchSession>> start(int adId) async {
    return ApiResult.ok(
      const FortuneAdWatchSession(
        sessionId: 'session_test_1',
        watchLogId: 1,
        adId: 1,
        watchSeconds: 15,
        rewardAmount: 3,
      ),
    );
  }

  @override
  Future<ApiResult<FortuneAdRewardResult>> complete({
    required int adId,
    required String sessionId,
    int? watchSeconds,
  }) async {
    return ApiResult.ok(
      const FortuneAdRewardResult(rewardAmount: 3, balance: 10),
    );
  }
}

/// 시청 시작 자체가 (긴 에러 메시지로) 실패해 바로 error 단계로 진입시킨다.
class _FailingFortuneAdRepository extends FortuneAdRepository {
  @override
  Future<ApiResult<FortuneAdWatchSession>> start(int adId) async {
    return ApiResult.fail(_longErrorMessage);
  }
}

FortuneAdModel _buildAd({required String title}) => FortuneAdModel(
  id: 1,
  title: title,
  description: null,
  adType: 'image', // imageUrl 없음 -> _fallbackIcon() 경로
  imageUrl: null,
  videoUrl: null,
  externalUrl: null,
  adSourceHtml: null,
  rewardAmount: 3,
  watchSeconds: 15,
  perUserDailyLimit: 3,
  dailyLimitReward: null,
  todayWatchedCount: 0,
  todayRemainingCount: 3,
  watchable: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cases = <(Size, double)>[
    (Size(390, 844), 1.0),
    (Size(360, 640), 1.3),
    (Size(320, 568), 1.5),
    (Size(320, 568), 2.0),
    (Size(320, 568), 2.5),
  ];

  for (final (size, scale) in cases) {
    final label = '${size.width.toInt()}x${size.height.toInt()}@$scale';

    testWidgets('FortuneAdWatchDialog watching 단계 $label overflow 없어야 함', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = FortuneAdProvider(_FakeFortuneAdRepository());
      final ad = _buildAd(title: _longTitle);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<FortuneAdProvider>.value(
            value: provider,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => FortuneAdWatchDialog.show(context, ad: ad),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      // starting -> start() 완료 -> watching 단계 진입까지 몇 프레임 진행.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final ex = tester.takeException();
      if (ex != null) {
        debugDumpRenderTree();
      }
      expect(
        ex,
        isNull,
        reason: 'FortuneAdWatchDialog watching $label overflow 없어야 함',
      );
      // watching 단계의 광고 제목이 실제로 렌더링됐는지 확인(단계 진입 검증).
      expect(find.text(_longTitle), findsOneWidget);

      // [테스트 인프라] `_tick()`의 재귀 Future.delayed 카운트다운
      // (watchSeconds초)을 끝까지 흘려보내 watching -> verifying -> granted
      // 로 자연히 전환시킨다 — 그래야 테스트 종료 시점에 남은 타이머가
      // 없어 flutter_test의 "Timer is still pending" 어서션에 걸리지
      // 않는다(프로덕션 코드가 아니라 테스트 자체의 타이머 처리 문제).
      for (var i = 0; i < ad.watchSeconds + 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
    });

    testWidgets('FortuneAdWatchDialog error 단계 $label overflow 없어야 함', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = FortuneAdProvider(_FailingFortuneAdRepository());
      final ad = _buildAd(title: '짧은 제목');

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          child: ChangeNotifierProvider<FortuneAdProvider>.value(
            value: provider,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => FortuneAdWatchDialog.show(context, ad: ad),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final ex = tester.takeException();
      if (ex != null) {
        debugDumpRenderTree();
      }
      expect(
        ex,
        isNull,
        reason: 'FortuneAdWatchDialog error $label overflow 없어야 함',
      );
      expect(find.text(_longErrorMessage), findsOneWidget);
    });
  }
}
