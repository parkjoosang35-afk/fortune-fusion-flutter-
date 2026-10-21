import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'sintong_sound_service.dart';

/// [신통방통 사운드 배치 개발 기획서 §5.1/§9.2] 8개 메뉴 화면 각각에
/// "이 화면은 어떤 BGM·앰비언스 라우트인지"를 선언하기만 하면 되도록 만든
/// 얇은 래퍼. `StatefulWidget`의 initState에 직접 호출을 추가하는 대신
/// 이 위젯으로 감싸면, StatelessWidget 화면(예: TarotHomeScreen)에도
/// 동일한 한 줄로 적용할 수 있다.
///
/// [재진입 시 재시작 금지와의 관계] `SintongSoundService.playRoute()`
/// 자체가 동일 라우트 재호출을 무시하므로(§6.3), 이 위젯이 build될
/// 때마다(예: 탭 전환으로 다시 보이게 될 때) 호출해도 안전하다 —
/// didChangeDependencies가 아니라 initState에서 1회만 호출해 중복 호출
/// 자체를 최소화한다.
///
/// 사용 예:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return SoundRouteTrigger(
///     routeKey: 'tarot',
///     child: Scaffold(...),
///   );
/// }
/// ```
class SoundRouteTrigger extends StatefulWidget {
  const SoundRouteTrigger({
    super.key,
    required this.routeKey,
    required this.child,
  });

  /// `assets/config/sound_routes.json`의 routes 키
  /// (main/saju/guide/tarot/wish/face/palm/shrine) 중 하나.
  final String routeKey;
  final Widget child;

  @override
  State<SoundRouteTrigger> createState() => _SoundRouteTriggerState();
}

class _SoundRouteTriggerState extends State<SoundRouteTrigger> {
  @override
  void initState() {
    super.initState();
    // addPostFrameCallback: build 중 Provider 트리 접근은 안전하지만,
    // 화면 전환 애니메이션과 사운드 트리거 타이밍을 맞추기 위해
    // 프레임 완료 직후로 늦춘다(기획서 §6.4 타임라인 "0.05s 화면 전환
    // 애니메이션 시작"과 거의 동시에 BGM 전환이 시작되는 것이 자연스럽다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<SintongSoundService>().playRoute(widget.routeKey);
      } catch (_) {
        // [저사양 degrade] Provider 미등록 등 어떤 이유로든 실패해도
        // 화면 자체의 렌더링에는 영향을 주지 않는다.
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
