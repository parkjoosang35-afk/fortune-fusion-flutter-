// [신통방통 반응형 화면 규격 통일 지시서] 복주머니 광고 시청 팝업
// (FortuneAdWatchDialog) 오버플로 회귀 테스트.
//
// [2026-11-11 반응형 전수 점검 — 2차 수정]
//
// 이 파일은 애초(2026-10-31) `SizedBox(height: 420)` 고정 레이아웃 시절에
// 작성됐다가, 2026-11-06 S04 Minimal Design B 리스킨
// (`fortune_ad_watch_dialog.dart` 커밋 8c95fdde)으로 watching 단계의 UI가
// "광고 제목(ad.title) 노출" → "고정 문구(`광고 보고\n복주머니 받기`) 노출"로
// 바뀌면서 테스트와 실제 구현이 어긋나 있었다(`find.text(_longTitle)`이
// 영원히 실패). 그 사실을 이번 점검에서 발견해 바로잡았다 — 리스킨 당시
// 의도된 디자인 변경(관리자 입력 제목 대신 고정 카피를 쓰는 것)이므로 이
// 테스트를 현재 구현에 맞게 갱신한다(기능 자체를 되돌리지 않음).
//
// [확인된 실제 버그 — debugDumpRenderTree로 근본원인 확정, 이번에 수정]
// watching 단계(_WatchingView, non-admob)에서 광고 영역을 그리는
// `MyPageDashedBorderBox`는 자체적으로 `SizedBox(height: 150)` 고정
// 높이를 이미 갖고 있는데도, 바깥 Column에서 다시 이를 `Expanded`로
// 감싸고 있었다. textScale이 2.0~2.5배로 커져 제목/안내문구 텍스트가
// 길어지면, Expanded가 요구하는 "남는 공간"이 음수가 되면서 광고 영역이
// 강제로 0px까지 찌그러지고 Column 전체가 세로로 31px(@2.0)/124px(@2.5)
// 오버플로됐다. 수정: 1) Dialog 본문을 watching 단계도 포함해 전부
// `ConstrainedBox(maxHeight:420) + SingleChildScrollView`로 통일(420px
// 이내면 기존과 완전히 동일, 넘치면 예외 대신 스크롤), 2) 그에 따라
// 더 이상 유효하지 않은 `Expanded`(광고 영역을 감싸던 것, watching 단계
// 바깥 Column의 `_WatchingView`를 감싸던 것)를 제거하고 README 스펙대로
// 150px 고정 높이만 사용.
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
      // [2026-11-11] S04 리스킨 이후 non-admob watching 화면은 ad.title을
      // 더 이상 렌더링하지 않는다(고정 카피 "광고 보고/복주머니 받기"로
      // 대체됨) — 그래도 "관리자가 긴 제목을 넣어도 다른 부작용이 없는지"는
      // 의미가 있으므로 ad 모델에는 여전히 _longTitle을 넣어 둔다(현재는
      // 화면에 쓰이지 않지만 회귀 발생 시 조기 발견 목적).
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
      // watching 단계가 실제로 렌더링됐는지 확인(단계 진입 검증) —
      // S04 리스킨 이후 고정 카피 헤드라인으로 검증한다.
      expect(find.text('광고 보고\n복주머니 받기'), findsOneWidget);

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
