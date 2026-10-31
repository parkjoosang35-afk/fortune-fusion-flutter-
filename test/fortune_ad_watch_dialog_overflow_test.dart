// [신통방통 반응형 화면 규격 통일 지시서] 복주머니 광고 시청 팝업
// (FortuneAdWatchDialog) 오버플로 회귀 테스트.
//
// 배경: 이 다이얼로그는 다른 화면들과 달리 Dialog 본문 전체가
// `SizedBox(height: 420)`로 고정되어 있고 내부에 SingleChildScrollView가
// 없다 — 지금까지 이 지시서에서 고친 버그들은 모두 "가로(Row) 오버플로"
// 였지만, 이 다이얼로그는 구조상 "세로(Column) 오버플로" 위험이 있는
// 첫 사례라 별도로 점검했다.
//
// 실측 결과: watching 단계(_WatchingView)의 광고 제목(ad.title, 1줄
// 가정하고 만든 레이아웃)이 아주 긴 문자열 + textScale 2.5배로 3줄 이상
// 길어지는 worst-case와, error 단계(_ErrorView)의 긴 에러 메시지
// worst-case를 모두 5개 기기폭×텍스트스케일 조합에서 실측했으나,
// RenderFlex 오버플로는 재현되지 않았다 — `_WatchingView`는 Expanded(광고
// 콘텐츠 영역)가 남는 공간을 모두 흡수하고 하단 텍스트 블록만 고정 크기로
// 차지하는 구조라 420px 안에서도 자연스럽게 수축되고, `_ErrorView`/
// `_GrantedView`는 `Center` + `mainAxisSize: min`이라 Dialog의
// `insetPadding`/바깥 여백 덕에 420px보다 작은 실제 기기 높이에서도 아직은
// 여유가 있었다. 따라서 프로덕션 코드는 수정하지 않고, 이 구조적 위험을
// 영구적으로 감시하는 회귀 테스트만 추가한다(문구가 더 길어지거나 420px
// 가정이 깨지는 변경이 생기면 이 테스트가 즉시 잡아낸다).
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
