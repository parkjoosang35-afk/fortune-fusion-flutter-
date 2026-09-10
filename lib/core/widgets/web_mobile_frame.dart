import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../util/is_mobile_browser.dart';

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
/// [버그 수정 이력]
/// 1차: 세로만 브라우저 창 높이만큼 늘어나 지나치게 가늘고 긴 모양이 됨
///      → 높이에 실제 폰 비율 상한을 둠.
/// 2차(본 수정): 1차 수정 후, 폭은 항상 430px로 고정된 채였기 때문에
///      화면이 넓은 PC(특히 울트라와이드 모니터)에서는 폰 목업이 상대적으로
///      매우 작아 보이는 문제가 남아있었다("PC에서 이렇게 작은 걸 어떻게
///      쓰냐"는 사용자 피드백). 원인은 "세로만 가변, 가로는 고정"이라는
///      비대칭 구조 자체였다.
///
/// [해결 방식] 폰을 "고정 디자인 크기"(가로세로 비율이 정해진 하나의
/// 기준 목업)로 정의해두고, 실제 사용 가능한 공간(가로/세로 모두)에 맞춰
/// 이 기준 목업 전체를 통째로 확대/축소(Transform.scale)한다. 즉 가로와
/// 세로가 항상 같은 배율로 함께 커지거나 작아지므로, 화면이 넓고 높이도
/// 넉넉한 PC에서는 폰이 실제로 더 크게 보이고, 창이 작으면 비율을 유지한
/// 채 작아진다 — 어떤 경우에도 실제 스마트폰과 같은 비율을 유지한다.
///
/// [적용 범위] 웹 플랫폼(kIsWeb)에서만 동작하고, 안드로이드 APK에서는
/// 이 위젯이 즉시 child를 그대로 반환한다(기존 프로덕션 동작과 동일).
///
/// [3차 긴급 수정 - 실제 모바일에서 목업이 잘못 나타난 사고] 기존에는
/// "화면 폭이 430px를 넘으면 PC"로만 판단했는데, 실제 사용자가 카카오톡
/// 공유 링크를 눌러 휴대폰(삼성 등 안드로이드 기기 다수 포함) 브라우저로
/// 열었을 때도 CSS 논리적 뷰포트 폭이 430px를 초과하는 경우가 있어 PC로
/// 오판되었다. 그 결과 실제 서비스 링크를 받은 사용자에게 앱이 아주 작은
/// 장식용 폰 그림 안에 쪼그라들어 표시되는 심각한 문제가 발생했다.
/// 이제는 폭 조건에 더해 User-Agent로 실제 모바일/태블릿 기기인지를
/// 먼저 확인하고, 실제 모바일 기기라면 폭 값과 무관하게 무조건 목업 없이
/// child를 그대로 보여준다 — "실제 모바일 사용자에게는 항상 정상 화면"이
/// 최우선이며, 폰 목업은 오직 데스크톱 브라우저에서만 나타나야 한다.
class WebMobileFrame extends StatelessWidget {
  const WebMobileFrame({super.key, required this.child});

  final Widget child;

  /// 앱 내부 레이아웃이 기준으로 삼는 화면(스크린) 콘텐츠 폭. 이 값은
  /// 실제로 화면에 그려지는 최종 픽셀 크기가 아니라, 앱 내부 위젯들이
  /// `MediaQuery.size`를 통해 참조하는 "논리적 캔버스 폭"이다. 이 값을
  /// 바꾸면 앱 내부 레이아웃 자체가 달라지므로(폰 화면 디자인 기준)
  /// 함부로 바꾸지 않는다.
  static const double maxWidth = 430;

  // 폰 목업 치수(디자인 기준값 — 실제 표시 크기는 아래 build()에서
  // 가용 공간에 맞춰 이 값 전체를 통째로 확대/축소한다) ------------------
  static const double _bezelSide = 12; // 좌우 베젤 두께
  static const double _notchAreaHeight = 34; // 상단 노치 공간
  static const double _homeAreaHeight = 26; // 하단 홈 인디케이터 공간
  static const double _outerRadius = 44; // 폰 바디 바깥 모서리 반경

  /// 앱 콘텐츠(노치/홈 인디케이터 제외) 영역의 디자인 기준 높이. 실제
  /// 폰의 화면 비율(대략 19.5:9 ~ 20:9)에 맞춰 고정값으로 정해둔다 —
  /// 브라우저 창 높이에 따라 매번 다시 계산하지 않으므로, 어떤 창
  /// 크기에서도 앱 내부 레이아웃이 항상 동일하게 유지된다(레이아웃
  /// 안정성 확보). 실제 화면에 보이는 크기는 아래 스케일 계산으로
  /// 결정된다.
  static const double _designScreenHeight = 900;

  static const double _designFrameWidth = maxWidth + _bezelSide * 2; // 454
  static const double _designFrameHeight =
      _designScreenHeight + _notchAreaHeight + _homeAreaHeight; // 960

  // 스케일(확대/축소) 허용 범위 ------------------------------------------
  // 창이 아주 작으면 과도하게 찌그러지지 않도록, 아주 크면 화면 대비
  // 비정상적으로 커 보이지 않도록 상하한을 둔다.
  static const double _minScale = 0.6;
  static const double _maxScale = 1.5;
  static const double _horizontalPadding = 24; // 좌우 최소 여백
  static const double _verticalPadding = 24; // 위아래 최소 여백

  static const Color _bodyColor = Color(0xFF0B0B12);
  static const Color _bodyEdgeColor = Color(0xFF3A3A46);
  static const Color _notchColor = Color(0xFF15141F);
  static const Color _homeIndicatorColor = Color(0xFF55536A);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    // [3차 긴급 수정] User-Agent로 실제 모바일/태블릿 기기임이 확인되면,
    // 화면 폭과 무관하게 절대 목업을 씌우지 않는다. 이 판별을 폭 검사보다
    // 먼저 수행해 실제 모바일 사용자에게 절대 영향이 가지 않도록 한다.
    if (isMobileBrowser()) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 이미 모바일 폭(모바일 브라우저로 접속)이면 목업 없이 그대로 통과.
        if (constraints.maxWidth <= maxWidth) return child;

        final availableWidth = constraints.maxWidth - _horizontalPadding * 2;
        final availableHeight =
            constraints.maxHeight - _verticalPadding * 2;

        // 가로/세로 각각 "이 공간에 맞추려면 몇 배로 키우거나 줄여야
        // 하는지"를 계산한 뒤, 둘 중 더 작은(더 제약이 큰) 배율을
        // 채택한다 — 그래야 어느 방향으로도 넘치지 않으면서 항상 실제
        // 폰과 동일한 비율을 유지할 수 있다.
        final scaleByWidth = availableWidth / _designFrameWidth;
        final scaleByHeight = availableHeight / _designFrameHeight;
        final rawScale = scaleByWidth < scaleByHeight
            ? scaleByWidth
            : scaleByHeight;
        final scale = rawScale.clamp(_minScale, _maxScale);

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1C1B2E), Color(0xFF2A2846)],
            ),
          ),
          child: Center(
            // 실제로 화면에 할당되는 최종 크기 = 디자인 기준 크기 × 배율.
            // Transform.scale 자체는 그려지는 모양만 바꾸고 레이아웃이
            // 차지하는 공간은 바꾸지 않으므로, 바깥 SizedBox를 배율이
            // 반영된 최종 크기로 명시해줘야 Center가 정확히 중앙에
            // 배치하고 다른 위젯과 공간을 올바르게 나눠 쓴다.
            child: SizedBox(
              width: _designFrameWidth * scale,
              height: _designFrameHeight * scale,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _designFrameWidth,
                  height: _designFrameHeight,
                  child: _PhoneBody(child: child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 폰 바디(베젤 · 노치 · 실제 앱 화면 · 홈 인디케이터 · 측면 버튼)를
/// 그리는 위젯. 항상 [WebMobileFrame._designFrameWidth] x
/// [WebMobileFrame._designFrameHeight] 크기의 고정 캔버스 위에서
/// 그려지고, 최종 화면 표시 크기는 부모의 Transform.scale이 결정한다.
class _PhoneBody extends StatelessWidget {
  const _PhoneBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const frameWidth = WebMobileFrame._designFrameWidth;
    const frameHeight = WebMobileFrame._designFrameHeight;
    const contentHeight = WebMobileFrame._designScreenHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 폰 바디(테두리 + 그림자)
        Container(
          width: frameWidth,
          height: frameHeight,
          decoration: BoxDecoration(
            color: WebMobileFrame._bodyColor,
            borderRadius: BorderRadius.circular(WebMobileFrame._outerRadius),
            border: Border.all(
              color: WebMobileFrame._bodyEdgeColor,
              width: 1.4,
            ),
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
            borderRadius: BorderRadius.circular(
              WebMobileFrame._outerRadius - 2,
            ),
            child: Column(
              children: [
                // 상단 노치 영역
                SizedBox(
                  height: WebMobileFrame._notchAreaHeight,
                  child: Center(
                    child: Container(
                      width: 110,
                      height: 22,
                      decoration: BoxDecoration(
                        color: WebMobileFrame._notchColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                // 실제 앱이 그려지는 화면 영역
                //
                // [배너 세로 비율 버그 수정] 이 아래의 `child`는 실제로는
                // 이 SizedBox(WebMobileFrame.maxWidth x contentHeight)
                // 안에 그려지지만, `MediaQuery.of(context).size`는 여전히
                // "PC 브라우저 전체 창 크기"를 반환한다. 앱 내부의 일부
                // 위젯(예: 홈 배너 캐러셀)이 높이를
                // `MediaQuery.size.width * 비율`로 계산하기 때문에, PC에서는
                // 실제 그려지는 폭이 아니라 창 전체 폭을 기준으로 높이가
                // 계산되어 배너가 세로로 길게 늘어나는 문제가 있었다. 이
                // 프레임 내부에서는 MediaQuery를 디자인 기준 화면 크기로
                // 다시 감싸 하위 위젯들이 항상 "폰 화면" 크기를 기준으로
                // 레이아웃을 계산하게 한다. 이 값은 고정값이므로(브라우저
                // 창 크기에 따라 변하지 않음) 어떤 화면에서도 앱 내부
                // 레이아웃이 항상 동일하게 유지된다.
                SizedBox(
                  width: WebMobileFrame.maxWidth,
                  height: contentHeight,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: const Size(
                        WebMobileFrame.maxWidth,
                        contentHeight,
                      ),
                    ),
                    child: Material(child: child),
                  ),
                ),
                // 하단 홈 인디케이터 영역
                SizedBox(
                  height: WebMobileFrame._homeAreaHeight,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: WebMobileFrame._homeIndicatorColor,
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
              color: WebMobileFrame._bodyEdgeColor,
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
              color: WebMobileFrame._bodyEdgeColor,
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
              color: WebMobileFrame._bodyEdgeColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
