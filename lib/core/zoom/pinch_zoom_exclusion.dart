import 'package:flutter/widgets.dart';

/// [신통방통 전역 핀치 확대 시스템] 제외 구역 레지스트리.
///
/// [GlobalPinchZoomOverlay]는 화면 전체에서 두 손가락 입력을 감시하지만,
/// 아래와 같은 특수 렌더링 환경 위에서는 "화면을 캡처해 확대"하는 방식이
/// 안전하게 동작하지 않거나(네이티브 플랫폼 뷰), 혹은 그 콘텐츠 자체가
/// 이미 독자적인 2손가락 의미(귀인지도 실제 좌표 확대/이동)를 갖고 있어
/// 전역 엔진과 의미가 충돌한다.
///
/// - WebView(webview_flutter, Hybrid Composition) 영역: `RenderRepaintBoundary
///   .toImage()`는 Flutter Skia/Impeller 캔버스만 래스터화하며, 네이티브
///   플랫폼 뷰(AndroidView)는 별도 레이어로 합성되어 캡처 이미지에 포함되지
///   않거나 빈 영역으로 찍힌다(Flutter 공식 문서에 명시된 제약). 이 영역
///   위에서 전역 확대를 켜면 "확대했더니 그 부분만 깨지거나 비어 보이는"
///   체감 버그가 생기므로 제외한다.
/// - 귀인지도 관계 그래프(interactive=true): 2손가락 핀치가 이미 "그래프
///   자체의 실좌표 확대/이동"(노드를 계속 탭 가능한 상태 유지)이라는
///   살아있는 기능이다. 전역 엔진이 그 위에 스크린샷 확대를 겹치면 같은
///   제스처가 이중으로 해석되어 둘 다 어색해진다 — 더 유용한 쪽(실좌표
///   확대, 탭 가능 유지)을 그대로 두고 전역 엔진에서는 제외한다.
///
/// 등록된 구역은 전역 오버레이의 포인터 다운 판정에서만 쓰이며, 제외 여부
/// 판정 자체는 순수 기하 비교(RenderBox 전역 좌표)만 수행한다 — 어떤
/// 네트워크 호출도, 어떤 상태 변경도 유발하지 않는다.
class PinchZoomExclusionRegistry {
  PinchZoomExclusionRegistry._();
  static final PinchZoomExclusionRegistry instance =
      PinchZoomExclusionRegistry._();

  final Set<GlobalKey> _keys = <GlobalKey>{};

  void register(GlobalKey key) => _keys.add(key);

  void unregister(GlobalKey key) => _keys.remove(key);

  /// [globalPosition]이 등록된 제외 구역 중 하나라도 포함하면 true.
  /// dispose된 RenderBox나 아직 레이아웃되지 않은 위젯은 안전하게 무시한다.
  bool isExcluded(Offset globalPosition) {
    for (final key in _keys) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      try {
        final topLeft = box.localToGlobal(Offset.zero);
        final rect = topLeft & box.size;
        if (rect.contains(globalPosition)) return true;
      } catch (_) {
        // 레이아웃 전환 중 일시적으로 좌표 변환이 실패할 수 있다 — 이 경우
        // "제외 아님"으로 안전하게 폴백한다(확대 기능 자체가 죽지 않도록).
        continue;
      }
    }
    return false;
  }
}

/// 자식 위젯 영역을 전역 핀치 확대 감시에서 제외한다.
///
/// 사용 예: WebView, 귀인지도 인터랙티브 그래프 등 "전역 스크린샷 확대"가
/// 아닌 다른 2손가락 의미를 이미 갖고 있거나, 네이티브 플랫폼 뷰라서 캡처가
/// 불가능한 콘텐츠를 감싼다.
class PinchZoomDisabled extends StatefulWidget {
  const PinchZoomDisabled({super.key, required this.child});

  final Widget child;

  @override
  State<PinchZoomDisabled> createState() => _PinchZoomDisabledState();
}

class _PinchZoomDisabledState extends State<PinchZoomDisabled> {
  final GlobalKey _boxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    PinchZoomExclusionRegistry.instance.register(_boxKey);
  }

  @override
  void dispose() {
    PinchZoomExclusionRegistry.instance.unregister(_boxKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _boxKey, child: widget.child);
  }
}
