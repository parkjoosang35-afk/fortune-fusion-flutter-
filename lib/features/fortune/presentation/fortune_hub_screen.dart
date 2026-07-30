import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cosmic_card.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/presentation/pass_gate_helper.dart';

/// [Fortune Fusion 3축 정책 반영] FortuneHubScreen - 운세 탭
/// 7개 카테고리 카드(오늘의운세/사주/타로/관상/손금/궁합/AI상담)를 세로 리스트로
/// 배치한다. "오늘의 운세"는 무료 진입, 나머지 카테고리는 진입 전 공통 알림패스
/// 게이트체크(navigateWithPassGate)를 거친다 — 패스가 없으면 발급 유도
/// 바텀시트를 띄우고, 있으면 그대로 상세 화면으로 진입한다.
///
/// [주의] 게이트체크 로직은 home_screen_cosmic.dart(운세 카테고리 그리드)와
/// 완전히 동일한 공통 헬퍼(pass_gate_helper.dart)를 재사용해 중복 진입 흐름을
/// 단일화한다(6단계 요구사항).
class FortuneHubScreen extends StatefulWidget {
  const FortuneHubScreen({super.key});

  @override
  State<FortuneHubScreen> createState() => _FortuneHubScreenState();
}

class _FortuneHubScreenState extends State<FortuneHubScreen> {
  bool _checking = false;

  static const _items = [
    (
      '오늘의 운세',
      '매일 새로운 종합운을 확인해보세요',
      Icons.wb_twilight_rounded,
      AppColors.accentBlue,
      '무료',
      '/home/daily-fortune-detail',
      false, // 패스 게이트체크 불필요(무료 콘텐츠)
    ),
    (
      '사주',
      'AI가 분석하는 나의 사주 명식',
      Icons.auto_stories_rounded,
      AppColors.accentGold,
      '알림패스',
      '/ai-fortune/saju/input',
      true,
    ),
    (
      '타로',
      '78장의 카드가 전하는 오늘의 메시지',
      Icons.style_rounded,
      AppColors.accentPurple,
      '알림패스',
      '/ai-fortune/tarot/question',
      true,
    ),
    (
      '관상',
      '사진으로 보는 AI 관상 분석',
      Icons.face_retouching_natural_rounded,
      AppColors.accentPink,
      '알림패스',
      '/ai-fortune/face/capture',
      true,
    ),
    (
      '손금',
      '손바닥 속에 숨겨진 나의 운명',
      Icons.back_hand_rounded,
      AppColors.accentMint,
      '알림패스',
      '/ai-fortune/palm/capture',
      true,
    ),
    (
      '궁합',
      '두 사람의 인연과 케미를 확인해요',
      Icons.favorite_rounded,
      AppColors.accentPink,
      '알림패스',
      '/ai-fortune/compatibility/input',
      true,
    ),
    (
      'AI 상담',
      '실시간 AI 운세 상담사와 대화하기',
      Icons.chat_bubble_rounded,
      AppColors.accentBlue,
      '알림패스',
      '/ai-fortune/consultation/type',
      true,
    ),
  ];

  Future<void> _handleTap({
    required String title,
    required String route,
    required bool requiresPass,
  }) async {
    if (requiresPass) setState(() => _checking = true);
    await navigateWithPassGate(
      context,
      title: title,
      route: route,
      requiresPass: requiresPass,
    );
    if (mounted && requiresPass) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: const Text(
          '운세',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.cosmicTextPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // [6단계] 운세 탭 상단 알림패스 상태 배너 — 홈 상단 상태바와 동일한
            // 정보(활성 여부/남은시간)를 운세 탭 진입 시에도 항상 확인 가능하게 한다.
            _FortunePassStatusBanner(
              isActive: pass.isActive,
              remainingSec: pass.status.remainingSec,
              policyName: pass.status.policyName,
              isBusy: _checking,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final (title, desc, icon, color, cost, route, requiresPass) = _items[index];
                  final isFree = !requiresPass;
                  // 알림패스가 이미 활성 상태면 유료 카테고리 뱃지도 "이용가능"으로 표시해
                  // 사용자가 현재 열람 가능 여부를 직관적으로 알 수 있게 한다.
                  final badgeLabel = isFree ? '무료' : (pass.isActive ? '이용가능' : cost);
                  final badgeColor = isFree || pass.isActive ? AppColors.accentMint : AppColors.accentGold;

                  return CosmicCard(
                    showGlow: false,
                    onTap: _checking
                        ? null
                        : () => _handleTap(
                              title: title,
                              route: route,
                              requiresPass: requiresPass,
                            ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cosmicTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.cosmicTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 운세 탭 상단 알림패스 상태 배너 — 활성/비활성 상태를 항상 시각적으로 구분한다.
class _FortunePassStatusBanner extends StatelessWidget {
  const _FortunePassStatusBanner({
    required this.isActive,
    required this.remainingSec,
    required this.policyName,
    required this.isBusy,
  });

  final bool isActive;
  final int remainingSec;
  final String? policyName;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final h = remainingSec ~/ 3600;
    final m = (remainingSec % 3600) ~/ 60;
    final s = remainingSec % 60;
    final timeLabel = h > 0
        ? '$h시간 $m분 남음'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')} 남음';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.accentGold.withValues(alpha: 0.12)
            : AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isActive ? AppColors.accentGold.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.bolt_rounded : Icons.lock_clock_rounded,
            size: 16,
            color: isActive ? AppColors.accentGold : AppColors.cosmicTextTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isBusy
                  ? '알림패스 확인 중...'
                  : isActive
                      ? '알림패스 활성중 · ${policyName ?? ''} · $timeLabel'
                      : '알림패스가 없어요 · 카테고리 진입 시 발급 안내',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.accentGold : AppColors.cosmicTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
