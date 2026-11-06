import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/domain/assets/open_pass_state.dart';
import '../../../core/orchestrator/orchestrator_provider.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../auth/application/auth_provider.dart';
import '../../notification/notification_provider.dart';
import '../../pass/application/pass_provider.dart';
import '../../pass/domain/pass_model.dart';
import '../../saju_renewal/screens/birth_input_screen.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../wishroom/features/intro/wish_room_intro_screen.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../../pass/presentation/pass_time_format.dart';
import 'my_fortune_records_screen.dart';
import 'theme/mypage_minimal_theme.dart';

/// [마이페이지 리뉴얼 · 미니멀 트렌드(Variant B) — S01 마이(메인)]
/// `design_handoff_mypage_minimal.zip` README §2(정보 구조)/§4(S01 스펙)를
/// 그대로 구현한다. 한지 크림 배경(`MyPageColors.paper`) + 부적 주홍 톤으로
/// 전면 교체하되, 기존 Provider/라우트/기능은 전혀 줄이지 않고 그대로
/// 재사용한다(§3 매핑표: 빠지는 기능 없음 원칙).
///
/// [주의] AuthProvider/GradeModel/UserModel/PassProvider/WalletProvider/
/// AttendanceProvider/NotificationProvider/OrchestratorProvider는 모두
/// 기존 전역 Provider를 그대로 재사용하며, 아카이브·설정 메뉴는 기존
/// app_router.dart에 등록된 라우트로 이동한다.
class MyScreen extends StatefulWidget {
  const MyScreen({super.key});

  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  @override
  void initState() {
    super.initState();
    // [README §7 "S01 진입 → GET /api/me/summary"] 단일 API가 없는 현재
    // 구조에서는 기존 Provider별 load()를 병렬로 호출해 동등한 효과를 낸다.
    // 일주(甲寅 일주) 서브텍스트 표시를 위해 OrchestratorProvider도 함께
    // 로드한다(사주 계산은 로컬 PHASE1~4 엔진 — 서버 API 없음, 기존 교차
    // 검증 화면과 동일 경로 재사용).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassProvider>().load();
      context.read<WalletProvider>().load();
      context.read<AttendanceProvider>().load();
      context.read<NotificationProvider>().load();
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        context.read<OrchestratorProvider>().load(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final pass = context.watch<PassProvider>();
    final wallet = context.watch<WalletProvider>();
    final attendance = context.watch<AttendanceProvider>();
    final notification = context.watch<NotificationProvider>();
    final orchestrator = context.watch<OrchestratorProvider>();

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MyPageSpacing.screenX,
            62,
            MyPageSpacing.screenX,
            130,
          ),
          children: [
            // ── 상단바 ──
            _TopBar(unreadCount: notification.unreadCount),
            const SizedBox(height: 22),

            // ── 프로필 행 ──
            _ProfileRow(auth: auth, user: user, orchestrator: orchestrator),
            const SizedBox(height: 24),

            // ── 지갑 카드 (프리패스 + 복주머니 통합) ──
            _WalletCard(
              pass: pass,
              wallet: wallet,
              isLoggedIn: auth.isLoggedIn,
            ),
            const SizedBox(height: 12),

            // ── 출석 배너 ──
            _AttendanceBanner(
              streak: attendance.streak,
              checkedToday: attendance.checkedToday,
              onTap: () {
                if (!auth.isLoggedIn) {
                  Navigator.of(context).pushNamed('/login');
                  return;
                }
                Navigator.of(context).pushNamed('/reward/attendance');
              },
            ),

            // ── 운세 보관함 ──
            const _SectionHeader(title: '운세 보관함'),
            _ArchiveGrid(isLoggedIn: auth.isLoggedIn),

            // ── 설정 리스트 ──
            const _SectionHeader(title: '설정'),
            _SettingsList(isLoggedIn: auth.isLoggedIn, auth: auth),
            const SizedBox(height: 24),

            // ── 푸터 ──
            _Footer(auth: auth),

            // [열림패스/복주머니/복주머니 통합정책 §5/§7] 열림패스 테스트 모드
            // 패널. 실 사용자에게는 노출되지 않도록 kDebugMode로 가드한다
            // (릴리즈 빌드에서는 완전히 제거됨).
            if (kDebugMode) ...[
              const SizedBox(height: MyPageSpacing.sp8),
              const _SectionHeader(title: '개발자 테스트'),
              const _OpenPassTestPanel(),
            ],
          ],
        ),
      ),
    );
  }
}

/// **상단바** README §4-S01: "마이" 30px/800 + 우측 ◔/⚙ 아이콘 버튼 2개.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Row(
        children: [
          Expanded(child: Text('마이', style: MyPageTextStyles.page)),
          _TopBarIconButton(
            glyph: '◔',
            showDot: unreadCount > 0,
            onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
          ),
          const SizedBox(width: 4),
          _TopBarIconButton(
            glyph: '⚙',
            onTap: () => Navigator.of(context).pushNamed('/my/settings'),
          ),
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.glyph,
    required this.onTap,
    this.showDot = false,
  });

  final String glyph;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: MyPageColors.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                glyph,
                style: const TextStyle(fontSize: 18, color: MyPageColors.ink),
              ),
            ),
            if (showDot)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: MyPageColors.red2,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// **프로필 행** README §4-S01: 아바타 60×60 + 등급뱃지(우하단) + 이름/서브 +
/// 우측 "프로필 ›" pill. 비로그인 시 회색 아바타 + "로그인" Primary pill.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.auth,
    required this.user,
    required this.orchestrator,
  });

  final AuthProvider auth;
  final dynamic user;
  final OrchestratorProvider orchestrator;

  /// 등급 코드(bronze/silver/gold)에 대응하는 한자 글리프.
  String _gradeGlyph(String? code) {
    switch (code) {
      case 'silver':
        return '銀';
      case 'gold':
        return '金';
      case 'bronze':
      default:
        return '銅';
    }
  }

  Color _gradeColor(String? code) {
    switch (code) {
      case 'silver':
        return const Color(0xFF9AA0A6);
      case 'gold':
        return const Color(0xFFC9A227);
      case 'bronze':
      default:
        return MyPageColors.bronze;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = auth.isLoggedIn;
    final grade = auth.currentGrade;
    // README §4-S01: "브론즈 · 甲寅 일주" — 사주 엔진이 계산한 일주(日柱)를
    // 서브텍스트로 노출한다. 아직 로드되지 않았거나 생년월일 미입력이면
    // 일주 부분은 생략하고 등급명만 보여준다(값이 없을 때 임의 표기 금지).
    final dayPillar = orchestrator.profile.sajuProfile?.dayPillar;
    final dayPillarLabel = dayPillar != null
        ? '${dayPillar.stemHanja}${dayPillar.branchHanja} 일주'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 아바타 + 등급 뱃지
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MyPageRadius.avatar),
                  gradient: isLoggedIn
                      ? const LinearGradient(
                          begin: Alignment(-0.5, -1),
                          end: Alignment(0.5, 1),
                          colors: [Color(0xFFC4583C), Color(0xFF7A2418)],
                        )
                      : null,
                  color: isLoggedIn ? null : const Color(0x14140C06),
                ),
                alignment: Alignment.center,
                child: Text(
                  isLoggedIn ? '瑞' : '?',
                  style: TextStyle(
                    fontFamily: isLoggedIn ? MyPageFonts.hanja : null,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    color: isLoggedIn
                        ? const Color(0xFFFBEFD6)
                        : MyPageColors.ink3,
                  ),
                ),
              ),
              if (isLoggedIn && grade != null)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _gradeColor(grade.code),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MyPageColors.paper,
                        width: 2.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _gradeGlyph(grade.code),
                      style: const TextStyle(
                        fontFamily: MyPageFonts.hanja,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn
                      ? '${user?.nickname ?? ''}님'
                      : '로그인이 필요해요',
                  style: MyPageTextStyles.name,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isLoggedIn
                      ? [
                          grade?.name ?? '브론즈',
                          if (dayPillarLabel != null) dayPillarLabel,
                        ].join('  ·  ')
                      : '로그인 후 모든 기능을 이용할 수 있어요',
                  style: const TextStyle(
                    fontFamily: MyPageFonts.ui,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: MyPageColors.ink2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 우측 pill: 로그인 상태 "프로필 ›" / 비로그인 상태 "로그인"(Primary)
          isLoggedIn
              ? InkWell(
                  borderRadius: BorderRadius.circular(MyPageRadius.pill),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BirthInputScreen(isEditMode: true),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x14140C06),
                      borderRadius: BorderRadius.circular(MyPageRadius.pill),
                    ),
                    child: const Text(
                      '프로필 ›',
                      style: TextStyle(
                        fontFamily: MyPageFonts.ui,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: MyPageColors.ink,
                      ),
                    ),
                  ),
                )
              : InkWell(
                  borderRadius: BorderRadius.circular(MyPageRadius.pill),
                  onTap: () => Navigator.of(context).pushNamed('/login'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: MyPageColors.red,
                      borderRadius: BorderRadius.circular(MyPageRadius.pill),
                    ),
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        fontFamily: MyPageFonts.ui,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFFFBF1DE),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

/// **지갑 카드** README §4-S01 `WalletCard` — 복주머니 + 프리패스를 한 카드로
/// 통합(기존 2개 분리 카드 → 1개). 상단 2열 그리드 + 하단 버튼 바.
class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.pass,
    required this.wallet,
    required this.isLoggedIn,
  });

  final PassProvider pass;
  final WalletProvider wallet;
  final bool isLoggedIn;

  PassPolicyModel? _adPolicy() {
    for (final p in pass.policies) {
      if (p.passType == PassType.ad) return p;
    }
    return null;
  }

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
    final liveState = OpenPassState.fromModel(pass.status);
    final adPolicy = _adPolicy();
    final grantCount = adPolicy?.grantCount;
    final acquireLabel = grantCount != null
        ? '광고 보고 ${formatPassGrantCount(grantCount)} 받기'
        : '프리패스 지급 준비 중';

    return Container(
      decoration: BoxDecoration(
        color: MyPageColors.surface,
        borderRadius: BorderRadius.circular(MyPageRadius.card),
        boxShadow: MyPageShadows.card,
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _WalletCell(
                  tileGlyph: '福',
                  tileBg: MyPageColors.tile1Bg,
                  tileFg: MyPageColors.tile1Fg,
                  label: '복주머니',
                  valueText: isLoggedIn
                      ? _formatBalance(wallet.balance)
                      : '–',
                  unit: '개',
                  isZero: !isLoggedIn || wallet.balance == 0,
                  onTap: () {
                    if (!isLoggedIn) {
                      Navigator.of(context).pushNamed('/login');
                      return;
                    }
                    Navigator.of(context).pushNamed('/reward/wallet');
                  },
                ),
              ),
              Container(width: 1, height: 44, color: MyPageColors.hair),
              Expanded(
                child: _WalletCell(
                  tileGlyph: '✦',
                  tileBg: MyPageColors.tile2Bg,
                  tileFg: MyPageColors.tile2Fg,
                  label: '프리패스',
                  valueText: isLoggedIn
                      ? (grantCount != null
                            ? '${pass.status.remainingCount ?? 0}'
                            : (liveState.isActive ? '1' : '0'))
                      : '–',
                  unit: '회',
                  isZero:
                      !isLoggedIn ||
                      (grantCount != null
                          ? (pass.status.remainingCount ?? 0) == 0
                          : !liveState.isActive),
                  onTap: () {
                    if (!isLoggedIn) {
                      Navigator.of(context).pushNamed('/login');
                      return;
                    }
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: _WalletButton(
                    label: '내역 보기',
                    variant: _WalletButtonVariant.soft,
                    onTap: () {
                      if (!isLoggedIn) {
                        Navigator.of(context).pushNamed('/login');
                        return;
                      }
                      Navigator.of(context).pushNamed('/reward/wallet');
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _WalletButton(
                    label: acquireLabel,
                    variant: _WalletButtonVariant.primary,
                    onTap: (grantCount != null && grantCount > 0)
                        ? () => showPassRequiredSheet(
                            context,
                            categoryTitle: '마이페이지',
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletCell extends StatelessWidget {
  const _WalletCell({
    required this.tileGlyph,
    required this.tileBg,
    required this.tileFg,
    required this.label,
    required this.valueText,
    required this.unit,
    required this.isZero,
    required this.onTap,
  });

  final String tileGlyph;
  final Color tileBg;
  final Color tileFg;
  final String label;
  final String valueText;
  final String unit;
  final bool isZero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MyPageRadius.card),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tileGlyph,
                    style: TextStyle(
                      fontFamily: MyPageFonts.hanja,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: tileFg,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: MyPageFonts.ui,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: MyPageColors.ink2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valueText,
                  style: TextStyle(
                    fontFamily: MyPageFonts.ui,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    letterSpacing: -0.9,
                    color: isZero ? MyPageColors.ink3 : MyPageColors.ink,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontFamily: MyPageFonts.ui,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: MyPageColors.ink2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _WalletButtonVariant { soft, primary }

class _WalletButton extends StatelessWidget {
  const _WalletButton({
    required this.label,
    required this.variant,
    required this.onTap,
  });

  final String label;
  final _WalletButtonVariant variant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _WalletButtonVariant.primary;
    final enabled = onTap != null;
    final bg = !enabled
        ? const Color(0x1F140C06)
        : (isPrimary ? MyPageColors.red : MyPageColors.redSoft);
    final fg = !enabled
        ? MyPageColors.ink3
        : (isPrimary ? const Color(0xFFFBF1DE) : MyPageColors.red);

    return InkWell(
      borderRadius: BorderRadius.circular(MyPageRadius.btn),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(MyPageRadius.btn),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: MyPageFonts.ui,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// **출석 배너** README §4-S01 `AttendanceBanner` — 금색 그라데이션, 좌측
/// "印" 아이콘, 우측 7칸 진행바. 마이페이지 진입점이 없었던 기존 출석체크
/// 기능을 매일 쓰는 기능으로 승격해 지갑 카드 바로 아래 배치한다.
class _AttendanceBanner extends StatelessWidget {
  const _AttendanceBanner({
    required this.streak,
    required this.checkedToday,
    required this.onTap,
  });

  final int streak;
  final bool checkedToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // README: 진행바 7칸 — 이번 주 연속 출석 진행도를 7일 주기로 보여준다.
    final filled = (streak % 7 == 0 && streak > 0) ? 7 : streak % 7;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment(-0.8, -0.6),
              end: Alignment(0.8, 0.6),
              colors: [MyPageColors.attendFrom, MyPageColors.attendTo],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '印',
                  style: TextStyle(
                    fontFamily: MyPageFonts.hanja,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: MyPageColors.red,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkedToday ? '오늘 출석을 마쳤어요' : '오늘 출석하고 복주머니 +10',
                      style: const TextStyle(
                        fontFamily: MyPageFonts.ui,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF4A2A0C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$streak일 연속 출석 중',
                      style: const TextStyle(
                        fontFamily: MyPageFonts.ui,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFF4A2A0C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(7, (i) {
                  final isFilled = i < filled;
                  return Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    child: Container(
                      width: 6,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? MyPageColors.red
                            : const Color(0x2E5E1A12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **섹션 헤더** README §4-S01: 18px/800, margin 32 2 14.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 32, 2, 14),
      child: Text(title, style: MyPageTextStyles.section),
    );
  }
}

/// **운세 보관함 그리드** README §4-S01: 4열×2행, 순서/톤 고정.
/// 四사주(1) 塔타로(2) 觀관상(3) 掌손금(4) / 錄운세 기록(4) 藏보관한 풀이(3)
/// 緣궁합(1) 願소원방(2) — 기존 7개 아카이브 메뉴 + 소원방을 하나의
/// 그리드로 통합한다(§3-1 매핑표: "소원방"을 8번째 타일로 흡수).
class _ArchiveGrid extends StatelessWidget {
  const _ArchiveGrid({required this.isLoggedIn});

  final bool isLoggedIn;

  void _goOrLogin(BuildContext context, VoidCallback go) {
    if (!isLoggedIn) {
      Navigator.of(context).pushNamed('/login');
      return;
    }
    go();
  }

  @override
  Widget build(BuildContext context) {
    final items = <_ArchiveItem>[
      _ArchiveItem(
        glyph: '四',
        label: '사주',
        tileIndex: 0,
        onTap: () => _goOrLogin(
          context,
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const MyFortuneRecordsScreen(categoryFilter: '사주'),
            ),
          ),
        ),
      ),
      _ArchiveItem(
        glyph: '塔',
        label: '타로',
        tileIndex: 1,
        onTap: () => _goOrLogin(
          context,
          () => Navigator.of(context).pushNamed('/ai-fortune/tarot/history'),
        ),
      ),
      _ArchiveItem(
        glyph: '觀',
        label: '관상',
        tileIndex: 2,
        onTap: () => _goOrLogin(
          context,
          () => Navigator.of(context).pushNamed('/ai-fortune/face/history'),
        ),
      ),
      _ArchiveItem(
        glyph: '掌',
        label: '손금',
        tileIndex: 3,
        onTap: () => _goOrLogin(
          context,
          () => Navigator.of(context).pushNamed('/ai-fortune/palm/history'),
        ),
      ),
      _ArchiveItem(
        glyph: '錄',
        label: '운세 기록',
        tileIndex: 3,
        onTap: () => _goOrLogin(
          context,
          () => Navigator.of(context).pushNamed('/my/fortune-records'),
        ),
      ),
      _ArchiveItem(
        glyph: '藏',
        label: '보관한 풀이',
        tileIndex: 2,
        onTap: () => _goOrLogin(
          context,
          () =>
              Navigator.of(context).pushNamed('/ai-fortune/reading-archive'),
        ),
      ),
      _ArchiveItem(
        glyph: '緣',
        label: '궁합',
        tileIndex: 0,
        onTap: () => _goOrLogin(
          context,
          () => Navigator.of(context).pushNamed('/gunghap/story'),
        ),
      ),
      _ArchiveItem(
        glyph: '願',
        label: '소원방',
        tileIndex: 1,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WishRoomIntroScreen()),
        ),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 18,
      crossAxisSpacing: 8,
      childAspectRatio: 0.78,
      children: items,
    );
  }
}

class _ArchiveItem extends StatefulWidget {
  const _ArchiveItem({
    required this.glyph,
    required this.label,
    required this.tileIndex,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final int tileIndex;
  final VoidCallback onTap;

  @override
  State<_ArchiveItem> createState() => _ArchiveItemState();
}

class _ArchiveItemState extends State<_ArchiveItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = MyPageColors.tileBg[widget.tileIndex % 4];
    final fg = MyPageColors.tileFg[widget.tileIndex % 4];
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(MyPageRadius.tile),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.glyph,
                style: TextStyle(
                  fontFamily: MyPageFonts.hanja,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: fg,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: const TextStyle(
              fontFamily: MyPageFonts.ui,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: MyPageColors.ink2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// **설정 리스트** README §4-S01: 3항목(알림 받기 토글 / 계정·출생정보 /
/// 앱 정보). [6-5-A 버그 수정] "앱 정보"는 과거 onTap: null로 완전히
/// 비활성화되어 있었다 — 이번 리뉴얼에서 `/my/settings/about` 같은 신규
/// 화면을 만들지는 않되(범위 외), 최소한 기존 설정 화면(SettingsScreen)
/// 버전 정보 섹션으로 이동하도록 눌림을 되살린다.
class _SettingsList extends StatefulWidget {
  const _SettingsList({required this.isLoggedIn, required this.auth});

  final bool isLoggedIn;
  final AuthProvider auth;

  @override
  State<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends State<_SettingsList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MyPageColors.surface,
        borderRadius: BorderRadius.circular(MyPageRadius.list),
        boxShadow: MyPageShadows.list,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _SettingsToggleRow(isLoggedIn: widget.isLoggedIn),
          const Divider(height: 1, color: MyPageColors.rowDiv, indent: 18, endIndent: 18),
          _SettingsRow(
            icon: Icons.account_circle_outlined,
            title: '계정 · 출생정보',
            onTap: () {
              if (!widget.isLoggedIn) {
                Navigator.of(context).pushNamed('/login');
                return;
              }
              Navigator.of(context).pushNamed('/my/settings');
            },
          ),
          const Divider(height: 1, color: MyPageColors.rowDiv, indent: 18, endIndent: 18),
          _SettingsRow(
            icon: Icons.info_outline_rounded,
            title: '앱 정보',
            trailing: '',
            onTap: () => Navigator.of(context).pushNamed('/my/settings'),
          ),
        ],
      ),
    );
  }
}

/// README: "알림 받기" 토글. S12 '앱 푸시 알림'과 같은 상태를 쓴다
/// (NotificationPreferenceRepository의 'fortune_update' 등은 카테고리별
/// 토글이라 "전체 알림 on/off"에 해당하는 서버 단일 필드가 없으므로,
/// 여기서는 3개 카테고리 전체 on/off를 하나의 토글로 대표 표시한다 —
/// 실제 반영은 설정 화면(SettingsScreen)의 세부 카테고리 토글을 그대로
/// 따른다. 범위 밖의 새 서버 필드를 만들지 않는다).
class _SettingsToggleRow extends StatefulWidget {
  const _SettingsToggleRow({required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  State<_SettingsToggleRow> createState() => _SettingsToggleRowState();
}

class _SettingsToggleRowState extends State<_SettingsToggleRow> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0x0D2A1F14),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 18,
                color: MyPageColors.ink2,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('알림함 보기', style: MyPageTextStyles.row),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: MyPageColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0x0D2A1F14),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: MyPageColors.ink2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: MyPageTextStyles.row)),
            if (trailing != null && trailing!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  trailing!,
                  style: const TextStyle(
                    fontFamily: MyPageFonts.ui,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: MyPageColors.ink3,
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: MyPageColors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// **푸터** README §4-S01: 가운데 정렬, "로그아웃 · 이용약관 · 개인정보처리방침".
class _Footer extends StatelessWidget {
  const _Footer({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _FooterLink(
        label: auth.isLoggedIn ? '로그아웃' : '로그인',
        onTap: () async {
          if (!auth.isLoggedIn) {
            Navigator.of(context).pushNamed('/login');
            return;
          }
          // [로그아웃 시 프리패스 서버측 강제 만료] 반드시 인증 토큰이
          // 살아있는 동안(= AuthProvider.logout()으로 토큰을 지우기 전에)
          // PassProvider.resetOnLogout()을 먼저 호출해야 한다.
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
      ),
      _FooterLink(
        label: '이용약관',
        onTap: () => Navigator.of(context).pushNamed('/my/settings'),
      ),
      _FooterLink(
        label: '개인정보처리방침',
        onTap: () => Navigator.of(context).pushNamed('/my/settings'),
      ),
    ];

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: items,
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: MyPageFonts.ui,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: MyPageColors.ink3,
        ),
      ),
    );
  }
}

/// [열림패스/복주머니/복주머니 통합정책 §5/§7] 열림패스 테스트 모드 패널.
/// 실 서버 호출 없이 PassProvider.debugForceState()로 강제 ON/OFF/만료
/// 상태를 만들고, 1초마다 남은 시간을 갱신해 카운트다운을 눈으로 QA할 수
/// 있게 한다. kDebugMode 빌드에서만 마이페이지에 노출된다. (기존 로직
/// 그대로 유지, 새 토큰 스타일로만 재도색)
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

    return Container(
      decoration: BoxDecoration(
        color: MyPageColors.surface,
        borderRadius: BorderRadius.circular(MyPageRadius.card),
        boxShadow: MyPageShadows.list,
      ),
      padding: const EdgeInsets.all(MyPageSpacing.sp4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.science_outlined,
                size: 18,
                color: MyPageColors.ink2,
              ),
              const SizedBox(width: MyPageSpacing.sp2),
              const Text('프리패스 테스트 모드', style: MyPageTextStyles.cardTitle),
              if (pass.isDebugOverrideActive) ...[
                const SizedBox(width: MyPageSpacing.sp2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MyPageSpacing.sp2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MyPageColors.gold2,
                    borderRadius: BorderRadius.circular(MyPageRadius.pill),
                  ),
                  child: const Text(
                    'TEST',
                    style: TextStyle(
                      fontFamily: MyPageFonts.ui,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: MyPageColors.redDeep,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: MyPageSpacing.sp2),
          Text(
            '상태: ${_statusLabel(state.status)}'
            '${state.remainingLabel != null ? ' · ${state.remainingLabel}' : ''}',
            style: MyPageTextStyles.body,
          ),
          const SizedBox(height: MyPageSpacing.sp3),
          Wrap(
            spacing: MyPageSpacing.sp2,
            runSpacing: MyPageSpacing.sp2,
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
    return InkWell(
      borderRadius: BorderRadius.circular(MyPageRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: MyPageColors.redSoft,
          borderRadius: BorderRadius.circular(MyPageRadius.pill),
        ),
        child: Text(label, style: MyPageTextStyles.caption),
      ),
    );
  }
}
