import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/consultation_provider.dart';
import 'consultation_ad_gate.dart';
import 'widgets/consultation_type_style.dart';

/// [무료 광고형 구조 재정비 §3단계] 복주머니는 소원게시판/소원성에서만 쓰는
/// 유일한 재화로 고정한다. AI 상담은 "운세 열람"과 같은 성격의 콘텐츠라 더
/// 이상 복주머니를 차감하지 않고 완전 무료로 이용할 수 있다(과거 -10개
/// 차감 정책은 폐기).

/// 03단계 §3.3 / 07단계 - ConsultationTypeScreen (선택형 패턴)
/// 상담 유형(사주상담/타로상담/일반상담) 선택 → 채팅 화면으로 이동
///
/// 07단계(추가) §3.4 - HelloBot류 앱을 참고한 아름다운 카드형 온보딩으로 개편.
/// 각 카드는 유형별 그라디언트 아이콘 + Staggered FadeInUp 등장 애니메이션을 가진다.
///
/// ▸ 진입 모드 2가지:
///   - 최초 진입(consultation/type, arguments 없음): 카드 선택 → startSession → 채팅 화면으로 push
///   - 유형 변경 모드(ConsultationChatScreen에서 arguments: true로 진입):
///     카드 선택 → provider.changeType() 호출 → 현재 화면을 pop하여 채팅 화면으로 복귀
class ConsultationTypeScreen extends StatefulWidget {
  const ConsultationTypeScreen({super.key});

  @override
  State<ConsultationTypeScreen> createState() => _ConsultationTypeScreenState();
}

class _ConsultationTypeScreenState extends State<ConsultationTypeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // 07단계(추가) §3.4 - 카드 3개가 순차적으로 나타나는 Staggered Animation
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  bool get _isChangeMode {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args == true;
  }

  Future<void> _select(String type) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);

    final provider = context.read<ConsultationProvider>();
    final navigator = Navigator.of(context);
    final changeMode = _isChangeMode;

    // [AI 상담 채팅 실연동] 오늘 첫 세션인데 광고 시청 완료 기록이 없으면
    // 서버가 거부(needsAdReward)한다 — runConsultationAdGateAndStart가
    // 광고 시청 게이트를 띄우고 시청 완료 시 세션 생성을 재시도한다.
    final started = await runConsultationAdGateAndStart(
      context,
      provider,
      type,
      changeMode: changeMode,
    );

    if (!mounted) {
      return;
    }
    if (!started) {
      setState(() => _isNavigating = false);
      return;
    }

    if (changeMode) {
      // 07단계(추가) §3.4 - 유형 변경 모드: 새 웰컴 메시지로 재시작 후 채팅 화면으로 복귀
      // (이미 이용 중인 세션의 유형만 바꾸는 것이므로 복주머니 재차감 없음)
      navigator.pop();
    } else {
      // [무료 광고형 구조 재정비 §3단계] AI 상담은 완전 무료 — 복주머니
      // 차감 없이 바로 세션을 시작한다.
      navigator.pushNamed('/ai-fortune/consultation/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI 상담'),
        leading: _isChangeMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isChangeMode ? '어떤 상담으로 바꿔볼까요?' : '어떤 상담을 받아보고 싶으신가요?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI 상담사와 실시간으로 대화하며 궁금한 점을 물어보세요',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView.builder(
                  itemCount: ConsultationTypeStyle.all.length,
                  itemBuilder: (context, index) {
                    final style = ConsultationTypeStyle.all[index];
                    // 07단계(추가) §3.4 - 카드마다 0.12초씩 지연되는 Staggered FadeInUp
                    final start = index * 0.15;
                    final end = (start + 0.6).clamp(0.0, 1.0);
                    final animation = CurvedAnimation(
                      parent: _staggerController,
                      curve: Interval(start, end, curve: Curves.easeOutCubic),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _AnimatedTypeCard(
                        animation: animation,
                        style: style,
                        onTap: () => _select(style.type),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 07단계(추가) §3.4 - Staggered FadeInUp + 탭 시 살짝 눌리는 스케일 피드백을 가진
/// 상담 유형 선택 카드. 유형별 그라디언트 원형 아이콘으로 시각적 구분을 강화한다.
class _AnimatedTypeCard extends StatefulWidget {
  final Animation<double> animation;
  final ConsultationTypeStyle style;
  final VoidCallback onTap;

  const _AnimatedTypeCard({
    required this.animation,
    required this.style,
    required this.onTap,
  });

  @override
  State<_AnimatedTypeCard> createState() => _AnimatedTypeCardState();
}

class _AnimatedTypeCardState extends State<_AnimatedTypeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final value = widget.animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 24),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: [
                BoxShadow(
                  color: widget.style.primaryColor.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: widget.style.gradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.style.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.style.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.style.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: widget.style.primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
