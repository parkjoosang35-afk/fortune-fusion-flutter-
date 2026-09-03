import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// [PC 웹 미리보기 개선] 데스크톱 브라우저에서 앱을 열었을 때, 화면 전체를
/// 꽉 채우는 대신 실제 스마트폰 목업(테두리 · 노치 · 홈 인디케이터) 안에
/// 들어있는 것처럼 보여준다.
///
/// [배경] 이 앱은 모바일 전용으로 디자인되어 있어(세로형 레이아웃), PC
/// 브라우저 창을 그대로 채우면 글자/버튼이 지나치게 커 보이고 레이아웃이
/// 어색해진다. sintong.kr/app/ 처럼 PC에서도 접속 가능한 웹 배포를 하게
/// 되면서, 실제로 이 문제가 사용자에게 체감되었다. 1차로 폭만 430px로
/// 제한했었는데, 이번에는 실제 "폰 안에 들어있는" 느낌을 주기 위해 목업
/// 프레임(베젤 · 노치 · 홈 인디케이터 · 그림자)을 추가했다.
///
/// [적용 범위] 웹 플랫폼(kIsWeb)에서만 동작하고, 안드로이드 APK/실제 모바일
/// 브라우저 폭에서는 화면 폭이 이미 [maxWidth] 이하이므로 시각적으로 아무
/// 변화가 없다(기존 프로덕션 동작과 동일). 즉 이 위젯은 "PC에서 볼 때만"
/// 실질적으로 효과가 있다.
class WebMobileFrame extends StatelessWidget {
  const WebMobileFrame({super.key, required this.child});

  final Widget child;

  /// 화면(스크린) 영역 폭. 기존과 동일하게 유지해 앱 내부 레이아웃에는
  /// 영향이 없다.
  static const double maxWidth = 430;

  // 폰 목업 치수 -----------------------------------------------------
  static const double _bezelSide = 12; // 좌우 베젤 두께
  static const double _notchAreaHeight = 34; // 상단 노치 공간
  static const double _homeAreaHeight = 26; // 하단 홈 인디케이터 공간
  static const double _outerRadius = 44; // 폰 바디 바깥 모서리 반경
  static const double _minVerticalMargin = 16; // 위/아래 최소 여백
  static const double _maxVerticalMargin = 40; // 위/아래 최대 여백(공간 넉넉할 때)

  /// [버그 수정 - PC에서 폰이 지나치게 가늘고 길게 보임] 기존 코드는
  /// frameHeight를 "화면 전체 높이"까지 늘어날 수 있게 허용했다. 폭은
  /// 430(+베젤)으로 고정인데 세로만 브라우저 창 높이만큼 늘어나면서,
  /// 실제 스마트폰 비율(대략 9:19.5~9:20)을 크게 벗어나 매우 가늘고
  /// 긴 모양이 되는 문제가 있었다. 실제 폰 화면 비율에 맞춰 프레임
  /// 전체 높이(바디 기준, 노치/홈 인디케이터 포함)의 상한을 둔다.
  /// maxWidth(430) 기준 최대 비율 약 1:2.2 → 430 * 2.2 ≈ 946.
  static const double _maxAspectRatio = 2.2; // height / width(바디 기준)

  static const Color _bodyColor = Color(0xFF0B0B12);
  static const Color _bodyEdgeColor = Color(0xFF3A3A46);
  static const Color _notchColor = Color(0xFF15141F);
  static const Color _homeIndicatorColor = Color(0xFF55536A);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 이미 모바일 폭(모바일 브라우저로 접속)이면 목업 없이 그대로 통과.
        if (constraints.maxWidth <= maxWidth) return child;

        final totalHeight = constraints.maxHeight;

        // 화면 높이가 넉넉할수록 위아래 여백을 더 크게 줘서 "책상 위에
        // 놓인 폰"처럼 보이게 하고, 창이 낮으면 여백을 줄여 잘리지 않게 한다.
        final margin = totalHeight > 760
            ? _maxVerticalMargin
            : totalHeight > 560
            ? _minVerticalMargin
            : 0.0;

        // 실제 폰 비율을 넘지 않도록 상한을 걸어준다(바디 폭 = maxWidth
        // 기준, 베젤은 좌우로만 붙으므로 비율 계산에서는 제외).
        final maxHeightByAspect = maxWidth * _maxAspectRatio;
        final availableHeight = totalHeight - margin * 2;
        final cappedHeight = availableHeight > maxHeightByAspect
            ? maxHeightByAspect
            : availableHeight;
        final frameHeight = cappedHeight < 320.0 ? 320.0 : cappedHeight;
        final contentHeight =
            frameHeight - _notchAreaHeight - _homeAreaHeight;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C1B2E), Color(0xFF2A2846)],
            ),
          ),
          child: Center(
            child: SizedBox(
              width: maxWidth + _bezelSide * 2,
              height: frameHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 폰 바디(테두리 + 그림자)
                  Container(
                    decoration: BoxDecoration(
                      color: _bodyColor,
                      borderRadius: BorderRadius.circular(_outerRadius),
                      border: Border.all(color: _bodyEdgeColor, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 48,
                          spreadRadius: 2,
                          offset: const Offset(0, 24),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_outerRadius - 2),
                      child: Column(
                        children: [
                          // 상단 노치 영역
                          SizedBox(
                            height: _notchAreaHeight,
                            child: Center(
                              child: Container(
                                width: 110,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _notchColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          // 실제 앱이 그려지는 화면 영역
                          //
                          // [배너 세로 비율 버그 수정] 이 아래의 `child`는 실제로는
                          // 이 SizedBox(430 x contentHeight) 안에 그려지지만,
                          // `MediaQuery.of(context).size`는 여전히 "PC 브라우저
                          // 전체 창 크기"(예: 1920x1080)를 반환한다. 앱 내부의
                          // 일부 위젯(예: 홈 배너 캐러셀)이 높이를
                          // `MediaQuery.size.width * 비율`로 계산하기 때문에,
                          // PC에서는 실제 그려지는 폭(430)이 아니라 창 전체 폭
                          // (1920)을 기준으로 높이가 계산되어 배너가 세로로 길게
                          // 늘어나는 문제가 있었다. 이 프레임 내부에서는
                          // MediaQuery를 실제 화면 크기(maxWidth x
                          // contentHeight)로 다시 감싸 하위 위젯들이 실제
                          // "폰 화면" 크기를 기준으로 레이아웃을 계산하게 한다.
                          SizedBox(
                            width: maxWidth,
                            height: contentHeight,
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                size: Size(maxWidth, contentHeight),
                              ),
                              child: Material(child: child),
                            ),
                          ),
                          // 하단 홈 인디케이터 영역
                          SizedBox(
                            height: _homeAreaHeight,
                            child: Center(
                              child: Container(
                                width: 120,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: _homeIndicatorColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 우측 전원 버튼(장식)
                  Positioned(
                    top: frameHeight * 0.22,
                    right: -2,
                    child: Container(
                      width: 3,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _bodyEdgeColor,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // 좌측 볼륨 버튼(장식)
                  Positioned(
                    top: frameHeight * 0.18,
                    left: -2,
                    child: Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _bodyEdgeColor,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: frameHeight * 0.28,
                    left: -2,
                    child: Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _bodyEdgeColor,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
