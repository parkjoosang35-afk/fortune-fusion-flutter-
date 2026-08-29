import 'package:flutter/material.dart';

import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';

/// [STEP05-B STEP9 — 상세화면 재사용] 이 파일의 함수/위젯은 전부
/// `wish_room_home_screen.dart`(STEP03~05에서 이미 실제 캡처로 검증된
/// 로직/애니메이션)에서 그대로 옮겨온 것이다. 새 로직·새 애니메이션을
/// 발명하지 않고, 홈 화면에서만 쓰이던 것을 상세 화면에서도 재사용할 수
/// 있도록 공용(public) 위치로 옮겼을 뿐이다. 홈 화면(`wish_room_home_screen.dart`)
/// 자체는 이미 STEP8까지 검증이 끝났으므로 건드리지 않는다(회귀 위험 최소화
/// — 그 파일의 private 버전은 그대로 남겨두고 중복 정의 상태를 유지한다).
///
/// [절대 원칙] wishState/sealedAt/unlockAt 등 서버 원본 필드는 여기서
/// 절대 변경하지 않고 읽기만 하며, 오직 "표시용 변환"만 수행한다.

/// 소원 상태별 감성 문구 매핑. DB의 wishState 원시값(sealed/fulfilled/
/// archived)은 그대로 유지하며, 이 함수는 표시용 변환만 한다. "곧 열려요"는
/// wishState와 별개의 파생 조건(unlockAt까지 7일 이내)이며, 서버가 재계산하는
/// 게 아니라 클라이언트가 "표시용으로만" 판단한다.
String wishStateEmotionalLabel(WishPost wish) {
  switch (wish.wishState) {
    case 'fulfilled':
      return '🌸 소원이 이루어졌어요';
    case 'archived':
      return '📦 소원함에 간직하고 있어요';
    case 'sealed':
    default:
      final unlock = wish.unlockAt;
      if (unlock != null) {
        final remaining = unlock.difference(DateTime.now()).inDays;
        if (remaining <= 7 && remaining >= 0) {
          return '✨ 소원이 이루어질 시간이 가까워요';
        }
      }
      return '🌱 소원이 자라고 있어요';
  }
}

/// 표시용 진행률(0.0~1.0) 계산 — 서버 sealedAt/unlockAt을 그대로 신뢰하며
/// 재계산하지 않는다. 둘 중 하나라도 null이면(예: 구버전 소원) null을
/// 반환해 호출부가 "진행률 알 수 없음" 상태를 표시하게 한다.
({int elapsedDays, int totalDays, int remainingDays, double ratio})?
wishProgressOf(WishPost wish) {
  final sealed = wish.sealedAt;
  final unlock = wish.unlockAt;
  if (sealed == null || unlock == null) return null;
  final total = unlock.difference(sealed).inDays;
  if (total <= 0) return null;
  var elapsed = DateTime.now().difference(sealed).inDays;
  if (elapsed < 0) elapsed = 0;
  if (elapsed > total) elapsed = total;
  final remaining = total - elapsed;
  final ratio = (elapsed / total).clamp(0.0, 1.0);
  return (
    elapsedDays: elapsed,
    totalDays: total,
    remainingDays: remaining,
    ratio: ratio,
  );
}

/// 소원 진행률을 5단계 성장 트랙으로 표현(🌱→🌿→🌳→✨→🌸). 순수 시간
/// 경과에 대한 감성적 표현이며 성취 "확률"을 의미하지 않는다.
/// [wish_room_home_screen.dart]의 `_GrowthStageTrack`을 public으로 승격한
/// 동일 구현.
class GrowthStageTrack extends StatelessWidget {
  const GrowthStageTrack({super.key, required this.ratio});
  final double ratio;

  static const _stages = ['🌱', '🌿', '🌳', '✨', '🌸'];

  int _currentStageIndex() {
    final idx = (ratio * (_stages.length - 1)).round();
    return idx.clamp(0, _stages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStageIndex();
    return Row(
      children: List.generate(_stages.length, (i) {
        final isCurrent = i == current;
        final isPassed = i < current;
        final opacity = isCurrent ? 1.0 : (isPassed ? 0.7 : 0.28);
        return Expanded(
          child: Column(
            children: [
              AnimatedScale(
                scale: isCurrent ? 1.25 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: opacity,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: isCurrent
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: WishRoomColors.glow.withValues(
                                  alpha: 0.5,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          )
                        : null,
                    child: Text(
                      _stages[i],
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ),
              if (i < _stages.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Container(
                    height: 1.5,
                    color: isPassed
                        ? WishRoomColors.glow.withValues(alpha: 0.4)
                        : WishRoomColors.surfaceCardBorder,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// 인장(印) 은은한 breathing glow 래퍼 — `_AltarStrip`(wish_room_home_screen.dart)
/// 내부의 breathing 구현을 그대로 옮겨 재사용한다(2.6s, alpha 0.5~1.0).
/// 새 애니메이션이 아니라 기존 검증된 효과를 다른 화면에서도 쓸 수 있게
/// 감싸기만 한 것.
class SealBreathingGlow extends StatefulWidget {
  const SealBreathingGlow({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  State<SealBreathingGlow> createState() => _SealBreathingGlowState();
}

class _SealBreathingGlowState extends State<SealBreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, child) {
        final glow = 0.5 + 0.5 * _breathe.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35 * glow),
                blurRadius: 14 * glow,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// [STEP05-B STEP9-8 — 상세화면 "오늘의 소원 활동"] 홈 화면
/// `_TodayWishActions`/`_TodayActionButton`(private)과 동일한 모양의
/// public 버튼 3개 Row. 새 보상정책/화폐를 만들지 않고, 호출부(상세화면)가
/// 넘겨주는 콜백(기존 `_doSupport`/`_openSendPouch`/`policy.earnDailyCandleBonus`)
/// 에만 연결한다. [supportEnabled]가 false면 응원 버튼을 비활성 스타일로
/// 표시한다(이미 응원했거나 처리 중일 때).
class TodayWishActionsRow extends StatelessWidget {
  const TodayWishActionsRow({
    super.key,
    required this.onCandle,
    required this.onSupport,
    required this.onPouch,
    this.supportLabel = '응원하기',
    this.supportEnabled = true,
  });

  final VoidCallback onCandle;
  final VoidCallback? onSupport;
  final VoidCallback onPouch;
  final String supportLabel;
  final bool supportEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TodayActionTile(icon: '🕯', label: '촛불 켜기', onTap: onCandle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TodayActionTile(
            icon: '💛',
            label: supportLabel,
            onTap: supportEnabled ? onSupport : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TodayActionTile(icon: '🎁', label: '복주머니', onTap: onPouch),
        ),
      ],
    );
  }
}

class _TodayActionTile extends StatelessWidget {
  const _TodayActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: WishRoomColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: WishRoomColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: disabled ? 0.4 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: WishRoomColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 부적(符) 은은한 pulsing glow 래퍼 — `_TalismanAmbientBadge`
/// (wish_room_home_screen.dart) 구현을 그대로 옮겨 재사용한다(2.2s).
class TalismanPulseGlow extends StatefulWidget {
  const TalismanPulseGlow({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  State<TalismanPulseGlow> createState() => _TalismanPulseGlowState();
}

class _TalismanPulseGlowState extends State<TalismanPulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 0.4 + 0.6 * _pulse.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4 * glow),
                blurRadius: 10 * glow,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
