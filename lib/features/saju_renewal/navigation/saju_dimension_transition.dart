import 'dart:math' as math;
import 'package:flutter/material.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 00 · 앱 셸 → 진입/복귀
/// 전환.
///
/// docs/03_화면명세.md §00:
/// - **진입 전환(300ms, `ease.dimension`)**: "셸 화면 위에 01 화면이
///   원형으로 확산. `clip-path: circle(0% at 탭 지점) → circle(150% at
///   탭 지점)`. 프로토타입은 고정 (50%, 62%), **구현은 카드 중심 좌표를
///   원점으로**."
/// - **복귀 전환(300ms)**: "01 ← 탭 → 셸이 `opacity 0, brightness 0.2 →
///   opacity 1, brightness 1`. (네이티브에서는 다크 오버레이
///   페이드아웃으로 대체 가능)" — 이 대체안을 채택한다.
///
/// docs/04_모션.md M-01/M-02, ease.dimension =
/// `cubic-bezier(0.5, 0, 0.3, 1)`(docs/01 §6).
///
/// [범용 재사용 — 왜 이렇게 구조화했는가] 정통사주로 들어가는 진입점은
/// 홈탭 칩/시트카드, 운세탭 카드, 전체보기 그리드, 마이페이지, 딥링크 등
/// 최소 6곳에 흩어져 있다(이 앱은 디자인 문서가 가정한 "카드 1개짜리
/// 단일 리스트 셸"이 아니다). 이 전환은 특정 화면의 카드 디자인에
/// 전혀 의존하지 않고 "탭 지점 좌표"만 있으면 어디서든 동일하게 적용
/// 가능하므로, 각 진입점의 기존 위젯(칩/카드 스타일)은 손대지 않고
/// `Navigator.push` 호출 한 줄만 [pushSajuRenewalWithDimension]으로
/// 교체한다.
///
/// [탭 좌표가 없는 호출부] 좌표를 안전하게 얻기 어려운 자리(마이페이지
/// 리스트 타일, 딥링크 등)는 [origin]을 생략하면 프로토타입 기본값과
/// 동일한 위치(가로 중앙, 세로 62%)에서 확산한다.
const Cubic sajuEaseDimension = Cubic(0.5, 0, 0.3, 1);

/// 탭된 위젯([context]) 자신의 화면상 중심 좌표(전역 좌표계)를 구한다.
/// docs/03 §00 "구현은 카드 중심 좌표를 원점으로" 요구사항을 만족시키기
/// 위한 공용 헬퍼 — 어떤 진입점(칩/카드/리스트 타일)이든 `onTap` 콜백
/// 안에서 `sajuCardCenterOf(context)`를 호출해 좌표를 얻고
/// `pushNamed('/saju-renewal', arguments: center)`에 그대로 넘기면 된다.
/// RenderBox를 얻을 수 없는 비정상 상황(드물게 unmount 직후 등)에는
/// null을 반환해 app_router.dart의 기본값(화면 중앙 62%)으로 자연스럽게
/// 폴백한다.
Offset? sajuCardCenterOf(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.attached) return null;
  final size = renderObject.size;
  return renderObject.localToGlobal(Offset(size.width / 2, size.height / 2));
}

/// 00 → 01 진입 시 쓰는 PageRoute. 탭 지점(또는 카드 중심) [origin]을
/// 원점으로 원형 확산한다(M-01). 뒤로가기(pop)로 복귀할 때는 이 라우트
/// 자체는 즉시 사라지고, 셸 쪽 다크 오버레이 페이드아웃(M-02)은
/// [SajuDimensionReturnOverlay]가 별도로 담당한다 — 01 화면
/// (`SajuRenewalHomeScreen`)이 pop되기 직전에 그 오버레이를 띄운 뒤
/// pop하면 된다.
Route<T> sajuDimensionEnterRoute<T>(WidgetBuilder builder, {Offset? origin}) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 1),
    opaque: true,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 복귀(reverse)는 오버레이가 담당하므로 여기서는 그냥 즉시 보여준다
      // (중복 애니메이션 방지 — 두 전환이 겹치면 지저분해 보인다).
      if (animation.status == AnimationStatus.reverse) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: sajuEaseDimension,
      );
      return AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) {
          final size = MediaQuery.of(context).size;
          final center = origin ?? Offset(size.width / 2, size.height * 0.62);
          final maxRadius = _maxDistanceToCorners(center, size) * 1.5;
          return ClipPath(
            clipper: _CircleRevealClipper(
              fraction: curved.value,
              center: center,
              maxRadius: maxRadius,
            ),
            child: child,
          );
        },
      );
    },
  );
}

double _maxDistanceToCorners(Offset center, Size size) {
  final corners = [
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ];
  var maxDist = 0.0;
  for (final corner in corners) {
    final dist = (corner - center).distance;
    if (dist > maxDist) maxDist = dist;
  }
  return maxDist;
}

class _CircleRevealClipper extends CustomClipper<Path> {
  _CircleRevealClipper({
    required this.fraction,
    required this.center,
    required this.maxRadius,
  });

  final double fraction;
  final Offset center;
  final double maxRadius;

  @override
  Path getClip(Size size) {
    final radius = (maxRadius * fraction).clamp(0.0, maxRadius);
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: math.max(radius, 0)));
  }

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) {
    return oldClipper.fraction != fraction ||
        oldClipper.center != center ||
        oldClipper.maxRadius != maxRadius;
  }
}

/// docs/03 §00 복귀 전환(M-02)의 "다크 오버레이 페이드아웃" 대체 구현.
///
/// 01(SajuRenewalHomeScreen)의 뒤로가기 핸들러에서 실제 `pop()` 대신
/// 이 함수를 호출한다. 동작 순서:
/// 1. 검은 오버레이(불투명도 .8, ≈brightness .2에 대응)를 [Overlay]로
///    즉시 띄운다(01 화면이 아직 화면에 보이는 상태지만 바로 다음
///    프레임에 가려짐).
/// 2. Navigator를 pop해 셸을 드러낸다.
/// 3. 오버레이를 .8 → 0으로 300ms 페이드아웃해 "어두운 공간에서 밝은
///    일상으로 돌아오는" 느낌을 준다.
/// 4. 오버레이를 제거한다.
///
/// [Overlay를 쓰는 이유] 셸(AppShell) 쪽 코드는 전혀 수정하지 않는다.
/// Flutter의 [Overlay]는 Navigator 전체가 공유하는 단일 스택이라, pop
/// 전후로 entry를 유지한 채 그 위에 계속 그려지므로 "01 위에 덮였다가
/// pop 후 셸 위에서 걷힌다"는 동일한 시각 효과를 하나의 entry로 구현할
/// 수 있다 — 새 라우트를 추가로 push하지 않으므로 뒤로가기 스택 깊이에도
/// 영향이 없다.
Future<void> playSajuReturnOverlayThenPop(BuildContext context) async {
  final navigator = Navigator.of(context);
  final overlay = Overlay.of(context);
  final controller = AnimationController(
    vsync: navigator,
    duration: const Duration(milliseconds: 300),
    value: 1.0, // 시작값 = 완전히 어두움(.8 alpha)
  );
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final alpha = 0.8 * controller.value;
            return Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: alpha)),
            );
          },
        ),
      );
    },
  );
  overlay.insert(entry);
  // 오버레이가 실제로 한 프레임 그려진 뒤 pop해야 "덮인 채로 전환"이
  // 보인다(동기로 바로 pop하면 레이아웃 교체와 겹쳐 깜빡일 수 있음).
  await WidgetsBinding.instance.endOfFrame;
  navigator.pop();
  try {
    await controller.reverse();
  } finally {
    entry.remove();
    controller.dispose();
  }
}
