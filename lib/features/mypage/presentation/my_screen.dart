import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/assets/open_pass_state.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/app_shortcut_row.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/grade_model.dart';
import '../../pass/application/pass_provider.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../wish_wall_board/presentation/wish_wall_board_screen.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../pass/presentation/pass_time_format.dart';

/// [9단계 - 마이 탭 정리] MyScreen - 마이 탭
/// 프로필+등급뱃지 + [열림패스/복주머니/구독 요약(3축 정책 한눈에 보기)]
/// + 아카이브(사주/타로/관상/손금/궁합 히스토리) + 커뮤니티(내 글·소원) + 설정
///
/// [서브 디자인 통일 확산 프롬프트] §5 마이 탭 확산 규칙 적용. 기존 다크
/// "우주(Cosmic)" 톤(CosmicCard/AppColors.bgPrimary 등)을 홈 화면과 동일한
/// 화이트+라벤더 팔레트로 전면 전환한다. 화면 구조/섹션 순서는 그대로 유지.
///
/// [주의] AuthProvider/GradeModel/UserModel/PassProvider/WalletProvider/
/// SubscriptionProvider는 기존 것을 그대로 재사용하며, 아카이브·설정 메뉴는
/// 모두 기존 app_router.dart에 등록된 라우트로 이동한다.
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // [무료 광고형 구조 재정비 §2/§7] 마이 탭 진입 시 프리패스/복주머니만
    // 최신화한다. 구독(SubscriptionProvider)은 화면에서 off 처리했으므로
    // 더 이상 여기서 로드하지 않는다(레거시 코드/라우트는 보존).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassProvider>().load();
      context.read<WalletProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final pass = context.watch<PassProvider>();
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('마이', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(UnifiedTokens.screenPadding),
          children: [
            // §1 프로필 카드
            PremiumCard(
              backgroundColor: UnifiedColors.cardSection,
              borderColor: Colors.transparent,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
              padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
              child: Row(
                children: [
                  Container(
                    width: UnifiedTokens.iconCircleLg + 24,
                    height: UnifiedTokens.iconCircleLg + 24,
                    decoration: const BoxDecoration(
                      color: UnifiedColors.cardAllMenu,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: UnifiedColors.textPrimary,
                      size: UnifiedTokens.iconXl,
                    ),
                  ),
                  const SizedBox(width: UnifiedTokens.spaceLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.nickname ?? '게스트',
                                style: UnifiedText.title(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (auth.currentGrade != null) ...[
                              const SizedBox(width: UnifiedTokens.spaceSm),
                              _GradeBadge(grade: auth.currentGrade!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '로그인이 필요합니다',
                          style: UnifiedText.caption(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: UnifiedColors.textCaption,
                      size: UnifiedTokens.iconLg,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/signup/profile-check'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [9단계] §1.5 열림패스/복주머니/구독 요약 - 3축 정책을 한 화면에서
            // 확인할 수 있도록 마이 탭에 요약 카드 3개를 배치한다.
            // [무료 광고형 구조 재정비 §2/§7] 사용자에게는 "프리패스 + 복주머니"
            // 2축만 보이게 정리한다. 구독 요약 카드는 삭제하지 않고 렌더링만
            // 끈다(off — §13 레거시 단계적 처리 원칙: 삭제보다 숨김을 우선).
            const _SectionTitle(title: '내 혜택 요약'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _PassSummaryCard(
              pass: pass,
              isLoading: pass.isLoading,
              onAcquireTap: () =>
                  showPassRequiredSheet(context, categoryTitle: '마이페이지'),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _WalletSummaryCard(
              balance: wallet.balance,
              isLoading: wallet.isLoading,
              onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // §2 아카이브 섹션
            const _SectionTitle(title: '나의 운세 아카이브'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: UnifiedTokens.spaceMd,
              crossAxisSpacing: UnifiedTokens.spaceMd,
              childAspectRatio: 2.2,
              children: [
                _ArchiveCard(
                  icon: Icons.auto_stories_outlined,
                  label: '사주 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/saju/history'),
                ),
                _ArchiveCard(
                  icon: Icons.style_outlined,
                  label: '타로 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/tarot/history'),
                ),
                _ArchiveCard(
                  icon: Icons.face_outlined,
                  label: '관상 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/face/history'),
                ),
                _ArchiveCard(
                  icon: Icons.back_hand_outlined,
                  label: '손금 히스토리',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed('/ai-fortune/palm/history'),
                ),
                // [오늘의 운세 표준 플로우 §6] 저장한 운세 카드 기록 진입점
                _ArchiveCard(
                  icon: Icons.bookmark_outline_rounded,
                  label: '내 운세 기록',
                  onTap: () =>
                      Navigator.of(context).pushNamed('/my/fortune-records'),
                ),
              ],
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // [커뮤니티 완전 삭제 + 소원벽 신설] 구 커뮤니티 허브(자유게시판 등)는
            // 완전히 삭제되었고, 소원방 생태계의 "소원벽"이 그 자리를 대신한다.
            const _SectionTitle(title: '나의 소원'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            _MenuTile(
              icon: Icons.local_fire_department_outlined,
              title: '소원벽 보러가기',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WishWallBoardScreen()),
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceMd),
            // [신통방통 소원방 재개발] 별도 격리 디자인 시스템(Midnight
            // Temple/Moonlit Crystal)을 쓰는 소원방 진입점. 라우트만 연결하고
            // 이 화면 자체의 톤(라벤더 UnifiedColors)은 그대로 유지한다.
            _MenuTile(
              icon: Icons.auto_awesome_outlined,
              title: '신통방통 소원방',
              onTap: () => Navigator.of(context).pushNamed('/wish-room'),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            // §3 설정 섹션
            const _SectionTitle(title: '설정'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            PremiumCard(
              backgroundColor: UnifiedColors.bg,
              borderColor: UnifiedColors.border,
              showShadow: false,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // [무료 광고형 구조 재정비 §7/§13] "프리미엄 구독" 메뉴는
                  // off 처리(라우트/화면 파일은 보존, 진입점만 제거).
                  _MenuRow(
                    icon: Icons.notifications_none_rounded,
                    title: '알림',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/notifications'),
                  ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    title: '설정',
                    onTap: () =>
                        Navigator.of(context).pushNamed('/my/settings'),
                  ),
                  _MenuRow(
                    icon: Icons.info_outline_rounded,
                    title: '앱 정보',
                    onTap: () {},
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: UnifiedTokens.spaceXxl),
            OutlinedButton(
              onPressed: () async {
                // [로그아웃 시 프리패스 서버측 강제 만료] 반드시 인증 토큰이
                // 살아있는 동안(= AuthProvider.logout()으로 토큰을 지우기 전에)
                // PassProvider.resetOnLogout()을 먼저 호출해야 한다. 이 메서드는
                // 서버 UserPass를 revoked 처리한 뒤 화면 상태도 초기화한다.
                // 순서를 바꾸면 userId를 얻을 수 없어 서버측 만료가 누락되고,
                // 재로그인 시 프리패스 잔여시간이 그대로 복원되는 문제가 재발한다.
                await context.read<PassProvider>().resetOnLogout();
                if (context.mounted) {
                  await context.read<AuthProvider>().logout();
                }
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: UnifiedColors.textSecondary,
                side: const BorderSide(color: UnifiedColors.border),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
              child: Text('로그아웃', style: UnifiedText.bodyStrong()),
            ),
            // [열림패스/복주머니/복주머니 통합정책 §5/§7] "열림패스 테스트 모드
            // 구현: 강제 ON/OFF, 만료 상태 테스트, 남은 시간 표시 테스트"에
            // 대응하는 QA 전용 패널. 실 사용자에게는 노출되지 않도록
            // kDebugMode로 가드한다(릴리즈 빌드에서는 완전히 제거됨).
            if (kDebugMode) ...[
              const SizedBox(height: UnifiedTokens.spaceXxl),
              const _SectionTitle(title: '개발자 테스트'),
              const SizedBox(height: UnifiedTokens.spaceMd),
              const _OpenPassTestPanel(),
            ],
          ],
        ),
      ),
    );
  }
}

/// [9단계] §1.5 열림패스 요약 카드 - 활성 여부와 남은 시간을 한눈에 보여준다.
/// [서브 디자인 통일 확산 프롬프트] §5 "열림패스 요약은 잔여 시간만 담백하게".
class _PassSummaryCard extends StatelessWidget {
  const _PassSummaryCard({
    required this.pass,
    required this.isLoading,
    required this.onAcquireTap,
  });

  final PassProvider pass;
  final bool isLoading;
  final VoidCallback onAcquireTap;

  // [프리패스 단순화 - 쿠팡파트너스 전용] §6 — HH:MM:SS 형식으로 통일.
  String _formatRemaining(int sec) => formatPassHms(Duration(seconds: sec));

  String _formatExpiry(DateTime dt) {
    return '${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // [재잠금 정확도] pass.status(서버 스냅샷) 대신 OpenPassState.fromModel의
    // 실시간 계산값을 사용해 만료 시점 이후 즉시 잠금 상태로 반영된다.
    final liveState = OpenPassState.fromModel(pass.status);
    final status = pass.status;
    final isActive = liveState.isActive;
    final remainingSec = liveState.remaining.inSeconds;
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShortcutRow(
            emoji: '🔔',
            accentColor: UnifiedColors.textPrimary,
            icon: Icons.lock_clock_outlined,
            iconColor: UnifiedColors.textPrimary,
            circleColor: UnifiedColors.bg,
            circleSize: UnifiedTokens.iconCircleLg,
            spacing: UnifiedTokens.spaceMd,
            titleStyle: UnifiedText.bodyStrong(),
            subtitleStyle: UnifiedText.caption(),
            arrowColor: UnifiedColors.textCaption,
            arrowSize: UnifiedTokens.iconMd,
            title: '프리패스',
            subtitle: isLoading
                ? '불러오는 중...'
                : isActive
                ? '남은 시간 ${_formatRemaining(remainingSec)}'
                : '보유한 프리패스가 없어요',
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          // [무료 광고형 구조 재정비 §2] 프리패스는 "광고 1회 = 1시간"
          // 단일 획득 경로만 노출한다(복주머니로 구매 버튼은 off).
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAcquireTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: UnifiedColors.textPrimary,
                side: const BorderSide(color: UnifiedColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    UnifiedTokens.radiusPill,
                  ),
                ),
              ),
              child: const Text('광고 보고 1시간 열기'),
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            isActive && status.expiresAt != null
                ? '만료 예정: ${_formatExpiry(status.expiresAt!)}'
                : '광고 1회 시청으로 1시간 동안 모든 운세를 볼 수 있어요.',
            style: UnifiedText.caption(),
          ),
        ],
      ),
    );
  }
}

/// [9단계] §1.5 복주머니 요약 카드 - 현재 잔액을 한눈에 보여준다.
/// [서브 디자인 통일 확산 프롬프트] §5 "복주머니 요약은 잔액 + 짧은 안내".
class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({
    required this.balance,
    required this.isLoading,
    required this.onTap,
  });

  final int balance;
  final bool isLoading;
  final VoidCallback onTap;

  String _formatBalance(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShortcutRow(
            emoji: '🍀',
            accentColor: UnifiedColors.textPrimary,
            icon: Icons.eco_outlined,
            iconColor: UnifiedColors.textPrimary,
            circleColor: UnifiedColors.bg,
            circleSize: UnifiedTokens.iconCircleLg,
            spacing: UnifiedTokens.spaceMd,
            titleStyle: UnifiedText.bodyStrong(),
            subtitleStyle: UnifiedText.caption(),
            arrowColor: UnifiedColors.textCaption,
            arrowSize: UnifiedTokens.iconMd,
            title: '복주머니',
            subtitle: isLoading
                ? '불러오는 중...'
                : '${_formatBalance(balance)}개 보유 중',
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          // [무료 광고형 구조 재정비 §4] "충전"(유료 결제) 버튼은 off — 복주머니는
          // 광고/활동으로만 적립되는 무료 재화이므로 결제 진입점을 남기지 않는다.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: UnifiedColors.textPrimary,
                side: const BorderSide(color: UnifiedColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    UnifiedTokens.radiusPill,
                  ),
                ),
              ),
              child: const Text('내역 보기'),
            ),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            '광고 보기, 출석, 커뮤니티 활동으로 모을 수 있어요.',
            style: UnifiedText.caption(),
          ),
        ],
      ),
    );
  }
}

// [무료 광고형 구조 재정비 §2/§7/§13 - 자율 정리 갱신] "구독 요약 카드"는
// 마이페이지 화면 진입점에서 제거했다(off). 기반 기능 자체(SubscriptionProvider,
// 구독 라우트 /my/subscription 등)는 실사용자 결제 데이터(user_subscriptions)와
// 연결되어 있어 삭제하지 않고 그대로 보존한다 — 필요 시 다시 진입점만 연결하면
// 복원 가능하다(유지→수정→통합→off→삭제 원칙, 삭제 아님).
// [자율 정리] "복주머니로 프리패스 구매" 바텀시트 + 기반 기능
// (PassProvider.purchaseWithLuckPouch())은 애초에 UI 호출부가 전혀 없던
// 순수 죽은 코드였으므로(사용자 데이터 영향 없음) Provider/Repository/Model
// 자체를 완전히 제거했다 — 위 구독과 달리 "off 보존"이 아니라 "삭제" 대상이었다.

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: UnifiedText.titleLarge());
  }
}

/// Phase2-1: 04A §A-5 `user_grades` 등급 배지
class _GradeBadge extends StatelessWidget {
  final GradeModel grade;

  const _GradeBadge({required this.grade});

  @override
  Widget build(BuildContext context) {
    // [서브 디자인 통일 확산 프롬프트] §9 컬러 남용 금지 - 등급 색상 구분 대신
    // 블랙 텍스트 + 라벤더 배경 단일 톤으로 통일하고, 강조는 굵기로만 표현한다.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: UnifiedColors.cardAllMenu,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      ),
      child: Text(grade.name, style: UnifiedText.chipLabel()),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.symmetric(
        horizontal: UnifiedTokens.spaceMd,
        vertical: UnifiedTokens.spaceSm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleMd,
            height: UnifiedTokens.iconCircleMd,
            decoration: const BoxDecoration(
              color: UnifiedColors.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Text(
              label,
              style: UnifiedText.bodyStrong(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: UnifiedColors.textPrimary,
            size: UnifiedTokens.iconLg,
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
          Icon(
            Icons.chevron_right_rounded,
            color: UnifiedColors.textCaption,
            size: UnifiedTokens.iconMd,
          ),
        ],
      ),
    );
  }
}

/// [서브 디자인 통일 확산 프롬프트] §5 "리스트 아이템 높이 균일 48~56, 좌측
/// 아이콘 20(iconSize.lg), 우측 화살표 16(iconSize.md) 색상 #9A9AA2,
/// 라벨 BodyStrong14 SemiBold, 하단 구분선 #ECECEF" - 설정 리스트 전용 행.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: UnifiedTokens.spaceLg),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: UnifiedColors.border, width: 1),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: UnifiedColors.textPrimary,
              size: UnifiedTokens.iconLg,
            ),
            const SizedBox(width: UnifiedTokens.spaceMd),
            Expanded(child: Text(title, style: UnifiedText.bodyStrong())),
            Icon(
              Icons.chevron_right_rounded,
              color: UnifiedColors.textCaption,
              size: UnifiedTokens.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}

/// [열림패스/복주머니/복주머니 통합정책 §5/§7] 열림패스 테스트 모드 패널.
/// 실 서버 호출 없이 PassProvider.debugForceState()로 강제 ON/OFF/만료
/// 상태를 만들고, 1초마다 남은 시간을 갱신해 카운트다운을 눈으로 QA할 수
/// 있게 한다. kDebugMode 빌드에서만 마이페이지에 노출된다.
class _OpenPassTestPanel extends StatefulWidget {
  const _OpenPassTestPanel();

  @override
  State<_OpenPassTestPanel> createState() => _OpenPassTestPanelState();
}

class _OpenPassTestPanelState extends State<_OpenPassTestPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 남은 시간 라벨이 실시간으로 줄어드는 것을 QA 화면에서 바로 확인할 수
    // 있도록 1초마다 rebuild한다(PassProvider 자체 상태는 그대로).
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _statusLabel(OpenPassStatus status) => switch (status) {
    OpenPassStatus.inactive => '비활성(inactive)',
    OpenPassStatus.active => '활성(active)',
    OpenPassStatus.expired => '만료(expired)',
  };

  @override
  Widget build(BuildContext context) {
    final pass = context.watch<PassProvider>();
    final state = pass.openPassState;

    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: UnifiedTokens.iconMd,
                color: UnifiedColors.textSecondary,
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Text('프리패스 테스트 모드', style: UnifiedText.title()),
              if (pass.isDebugOverrideActive) ...[
                const SizedBox(width: UnifiedTokens.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UnifiedTokens.spaceSm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: UnifiedColors.neon,
                    borderRadius: BorderRadius.circular(
                      UnifiedTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    'TEST',
                    style: UnifiedText.caption(
                      color: UnifiedColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          Text(
            '상태: ${_statusLabel(state.status)}'
            '${state.remainingLabel != null ? ' · ${state.remainingLabel}' : ''}',
            style: UnifiedText.body(),
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Wrap(
            spacing: UnifiedTokens.spaceSm,
            runSpacing: UnifiedTokens.spaceSm,
            children: [
              _TestButton(
                label: '강제 ON(60분)',
                onTap: () => pass.debugForceState(
                  OpenPassStatus.active,
                  remaining: const Duration(minutes: 60),
                ),
              ),
              _TestButton(
                label: '강제 ON(2분)',
                onTap: () => pass.debugForceState(
                  OpenPassStatus.active,
                  remaining: const Duration(minutes: 2),
                ),
              ),
              _TestButton(
                label: '강제 OFF',
                onTap: () => pass.debugForceState(OpenPassStatus.inactive),
              ),
              _TestButton(
                label: '강제 만료',
                onTap: () => pass.debugForceState(OpenPassStatus.expired),
              ),
              _TestButton(
                label: '테스트 해제(실서버)',
                onTap: () {
                  pass.clearDebugOverride();
                  pass.load();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: UnifiedColors.textPrimary,
        side: const BorderSide(color: UnifiedColors.border),
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedTokens.spaceMd,
          vertical: UnifiedTokens.spaceSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
      ),
      child: Text(label, style: UnifiedText.caption()),
    );
  }
}
