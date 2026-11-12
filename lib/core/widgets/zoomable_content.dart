import 'package:flutter/material.dart';

/// [확대 기능 — 결과페이지 전체 적용] 모든 결과 화면에서 공용으로 쓰는
/// "탭하면 전체화면으로 확대 + 핀치줌" 위젯.
///
/// 사용 패턴은 두 가지다.
/// 1) 이미지 썸네일 등 [child]를 그대로 확대해도 되는 경우 → [child]만
///    넘기면 전체화면에서도 동일 위젯을 더 크게(화면 폭 기준) 그려준다.
/// 2) CustomPaint 기반 도식(사주 팔괘/기둥/오행 바 등)처럼 작은 썸네일을
///    그대로 키우면 좌표가 깨지는 경우 → [fullScreenBuilder]로 "더 큰
///    사이즈 파라미터로 다시 그린" 위젯을 별도로 전달한다.
///
/// 전체화면 뷰는 [InteractiveViewer]로 감싸 핀치줌/더블탭 확대까지
/// 지원하며, 바깥 영역을 탭하거나 우상단 닫기 버튼으로 돌아갈 수 있다.
/// 기존 위젯 트리나 상태 관리 로직은 전혀 건드리지 않고, 결과페이지의
/// 이미지/도식을 이 위젯으로 감싸기만 하면 된다.
class ZoomableContent extends StatelessWidget {
  const ZoomableContent({
    super.key,
    required this.child,
    this.heroTag,
    this.fullScreenBuilder,
    this.backgroundColor = Colors.black,
    this.borderRadius,
    this.enabled = true,
  });

  /// 화면에 보통 크기로 표시되는 위젯(썸네일/작은 카드 등).
  final Widget child;

  /// Hero 전환 태그. 지정하지 않으면 전환 애니메이션 없이 바로 전체화면으로
  /// 전환한다(동일 화면에 같은 heroTag를 가진 위젯이 여러 개 있을 때
  /// 충돌을 피하려면 null로 두고 호출부에서 고유 태그를 넘기는 쪽을
  /// 권장한다).
  final Object? heroTag;

  /// 전체화면에 표시할 "더 큰" 버전을 별도로 그리고 싶을 때 사용한다.
  /// null이면 [child]를 그대로 확대해서 보여준다.
  final WidgetBuilder? fullScreenBuilder;

  /// 전체화면 뒷배경 색.
  final Color backgroundColor;

  /// [child] 자체에 적용할 모서리 반경(탭 영역의 InkWell 리플에도 사용).
  final BorderRadius? borderRadius;

  /// false면 확대 기능을 끄고 [child]만 그대로 렌더링한다(예: 데이터가
  /// 아직 없을 때).
  final bool enabled;

  void _open(BuildContext context) {
    final tag = heroTag ?? UniqueKey();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: backgroundColor.withValues(alpha: 0.94),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _ZoomableFullScreenView(
            heroTag: tag,
            backgroundColor: backgroundColor,
            builder: fullScreenBuilder ?? (_) => child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final tag = heroTag;
    final content = Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => _open(context),
        child: child,
      ),
    );
    if (tag == null) return content;
    // 원본 child에는 Hero를 바로 씌우지 않는다(탭 영역에 InkWell 리플이
    // 필요하므로 Hero는 content 전체를 감싼다).
    return Hero(
      tag: tag,
      flightShuttleBuilder: (_, animation, __, ___, toContext) =>
          FadeTransition(opacity: animation, child: toContext.widget),
      child: content,
    );
  }
}

class _ZoomableFullScreenView extends StatefulWidget {
  const _ZoomableFullScreenView({
    required this.heroTag,
    required this.backgroundColor,
    required this.builder,
  });

  final Object heroTag;
  final Color backgroundColor;
  final WidgetBuilder builder;

  @override
  State<_ZoomableFullScreenView> createState() =>
      _ZoomableFullScreenViewState();
}

class _ZoomableFullScreenViewState extends State<_ZoomableFullScreenView> {
  // ───────────────────────────────────────────────────────────────
  // [더블탭으로 닫기]
  // 배경 탭 닫기를 없앤 뒤 "닫는 방법이 X 버튼 하나뿐"이라 불편하다는
  // 요청을 반영해, **더블탭**으로 닫을 수 있게 한다.
  //
  // ⚠️ 여기서 GestureDetector(onDoubleTap:)를 쓰면 안 된다.
  // 이 프로젝트에서 InteractiveViewer를 GestureDetector(onScale*)나
  // onDoubleTap*로 감쌌다가 **핀치가 아예 죽는 회귀를 두 번 겪었다.**
  // GestureDetector는 제스처 아레나에 참여해 더블탭 인식기가 스케일
  // 인식기보다 먼저 이기거나, 반대로 스케일 시작을 지연시킨다.
  //
  // 그래서 여기서는 **Listener**(로우레벨 포인터 콜백)만 쓴다.
  // Listener는 제스처 아레나에 참여하지 않으므로 InteractiveViewer의
  // 핀치/팬을 절대 빼앗지 않는다. 우리는 "두 번째 손가락이 닿은 시각"만
  // 스스로 재서 더블탭을 판정한다.
  //
  // 핀치(두 손가락)와 겹치지 않도록 아래 조건을 모두 만족할 때만 닫는다.
  //   1) 한 손가락으로만 두 번 (멀티터치 중이면 무시)
  //   2) 각 탭이 아주 짧게 눌렸다 떼짐 (길게 누르기/드래그 배제)
  //   3) 두 탭 사이 이동 거리가 작음 (스크롤/팬 배제)
  //   4) 두 탭 간격이 300ms 이내
  // ───────────────────────────────────────────────────────────────
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  static const double _tapSlop = 20.0;

  DateTime? _lastTapAt;
  Offset? _lastTapPos;
  DateTime? _downAt;
  Offset? _downPos;
  int _activePointers = 0;

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _onPointerDown(PointerDownEvent e) {
    _activePointers++;
    _downAt = DateTime.now();
    _downPos = e.position;
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers = (_activePointers - 1).clamp(0, 99);
    final downAt = _downAt;
    final downPos = _downPos;
    // 손가락이 여러 개 닿은 상태에서 뗀 것은 핀치의 일부다 → 판정 제외.
    if (_activePointers > 0 || downAt == null || downPos == null) {
      _lastTapAt = null;
      _lastTapPos = null;
      return;
    }
    final held = DateTime.now().difference(downAt);
    final moved = (e.position - downPos).distance;
    _downAt = null;
    _downPos = null;

    // 길게 누르기 / 드래그는 "탭"이 아니다.
    if (held > _doubleTapWindow || moved > _tapSlop) {
      _lastTapAt = null;
      _lastTapPos = null;
      return;
    }

    final now = DateTime.now();
    final prevAt = _lastTapAt;
    final prevPos = _lastTapPos;
    if (prevAt != null &&
        prevPos != null &&
        now.difference(prevAt) <= _doubleTapWindow &&
        (e.position - prevPos).distance <= _tapSlop * 2) {
      // 더블탭 성립
      _lastTapAt = null;
      _lastTapPos = null;
      _close();
      return;
    }
    _lastTapAt = now;
    _lastTapPos = e.position;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) {
          _activePointers = (_activePointers - 1).clamp(0, 99);
          _downAt = null;
          _downPos = null;
          _lastTapAt = null;
          _lastTapPos = null;
        },
        child: Stack(
          children: [
            // ─────────────────────────────────────────────────────────────
            // [수정 1 — 배경 탭 닫기 제거]
            // 원래 여기에는 `GestureDetector(behavior: opaque,
            // onTap: maybePop)`가 깔려 있었다. 핀치로 확대한 뒤 손가락을
            // 하나씩 떼는 과정에서 남은 손가락이 "탭"으로 인식되면 이 배경
            // 탭이 실행되어 전체화면이 통째로 닫혔고, 사용자 눈에는
            // **"확대가 원래대로 돌아갔다"** 로 보였다(실기기 신고 원문).
            // 확대를 유지하려면 잔여 탭으로 닫히면 안 되므로 배경 닫기를
            // 없앤다. 닫기는 우상단 X 버튼만 사용한다.
            // ─────────────────────────────────────────────────────────────
            //
            // ─────────────────────────────────────────────────────────────
            // [수정 2 — InteractiveViewer가 화면 전체를 덮게]
            // 예전에는 `Center > Hero > InteractiveViewer` 순서라서
            // InteractiveViewer의 hit-test 영역이 **콘텐츠 크기(예: 100x100)
            // 만큼**밖에 안 됐다. 사용자는 두 손가락을 콘텐츠 픽셀 위에 정확히
            // 올리지 않으므로, 한 손가락이라도 여백에 찍히면 그 포인터가
            // InteractiveViewer에 전달되지 않아 **핀치 자체가 성립하지 않았다.**
            // (위젯 테스트 실측: 콘텐츠 위에서 시작 → scale 3.8 / 여백에서
            //  시작 → scale 1.0, 확대 안 됨)
            // 그래서 InteractiveViewer를 Positioned.fill + SizedBox.expand로
            // 화면 전체에 깔고, 보이는 콘텐츠만 Center로 가운데 정렬한다
            // (레이아웃 상 보이는 모습은 이전과 동일).
            // ─────────────────────────────────────────────────────────────
            Positioned.fill(
              child: Hero(
                tag: widget.heroTag,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  // [버그 수정 — APK 실기기 5차 신고 "확대기능 조금밖에 안됨"]
                  // boundaryMargin 기본값(EdgeInsets.zero)이면 확대 후 팬(이동)이
                  // 경계에 막힌다. 넉넉하게 주어 자유롭게 이동할 수 있게 한다.
                  boundaryMargin: const EdgeInsets.all(400),
                  child: SizedBox.expand(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: widget.builder(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Text(
                    '손가락으로 확대/축소 · 두 번 탭하면 닫혀요',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 이미지 전용 간편 래퍼. [assetPath]의 작은 썸네일을 [child]로 보여주고,
/// 탭하면 같은 에셋(또는 [fullAssetPath]로 지정한 고해상도 버전)을
/// 화면 폭 기준으로 더 크게 그려 핀치줌 가능한 전체화면으로 연다.
class ZoomableAssetImage extends StatelessWidget {
  const ZoomableAssetImage({
    super.key,
    required this.assetPath,
    required this.child,
    this.fullAssetPath,
    this.heroTag,
    this.borderRadius,
    this.enabled = true,
  });

  final String assetPath;
  final String? fullAssetPath;
  final Widget child;
  final Object? heroTag;
  final BorderRadius? borderRadius;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ZoomableContent(
      heroTag: heroTag,
      borderRadius: borderRadius,
      enabled: enabled,
      fullScreenBuilder: (_) => Image.asset(
        fullAssetPath ?? assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => child,
      ),
      child: child,
    );
  }
}
