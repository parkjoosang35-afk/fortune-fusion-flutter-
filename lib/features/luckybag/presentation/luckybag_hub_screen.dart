import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_section_title.dart';
import '../../../core/widgets/premium_graphics.dart';
import '../../attendance/application/attendance_provider.dart';
import '../../attendance/presentation/attendance_calendar_screen.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../wallet/presentation/wallet_content.dart';
import '../../fortune_ad/application/fortune_ad_provider.dart';

/// [복주머니 화면 재구성 - 2차] 사용자 요청("하단바 복주머니를 누르면 나오는
/// 화면의 내용을 다 삭제하고 지갑 화면 내용만 남긴다" + "미션/복주머니열기/
/// 개봉이력은 삭제하고 출석체크만 남기는데, 누르면 30일 출석 달력이 뜨게")에
/// 따라 전면 재작성한 하단바 "복주머니" 탭.
///
/// 구성: `WalletContent`(잔액 + 관리자가 등록한 만큼 늘어나는 무료 충전 카드들 +
/// 접이식 적립/사용 내역, `WalletScreen`과 완전히 동일한 콘텐츠) + "출석체크"
/// 바로가기 카드 1개(탭하면 `AttendanceCalendarScreen`으로 이동).
///
/// 삭제된 기능(미션/복주머니열기/복주머니개봉이력/소원방 바로가기)은 이 화면의
/// 유일한 진입점이었으므로 화면에서 제거되며, 해당 라우트/화면 파일 자체는
/// 프로젝트 관례에 따라 보존한다(필요 시 다른 화면에서 재사용 가능).
class LuckyBagScreen extends StatefulWidget {
  const LuckyBagScreen({super.key});

  @override
  State<LuckyBagScreen> createState() => _LuckyBagScreenState();
}

class _LuckyBagScreenState extends State<LuckyBagScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      context.read<FortuneAdProvider>().load();
      context.read<AttendanceProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceMd,
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceXxl,
          ),
          children: [
            Text('복주머니', style: UnifiedText.titleLarge()),
            const SizedBox(height: 4),
            Text('모으고, 나누고, 다시 행운으로 돌아와요', style: UnifiedText.body()),
            const SizedBox(height: UnifiedTokens.spaceLg),

            const FadeSlideIn(child: WalletContent()),
            const SizedBox(height: UnifiedTokens.spaceXxl),

            const PremiumSectionTitle(title: '출석체크'),
            const SizedBox(height: UnifiedTokens.spaceMd),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: _AttendanceShortcutCard(
                checkedToday: attendance.checkedToday,
                streak: attendance.streak,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AttendanceCalendarScreen(),
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

/// "출석체크" 바로가기 카드 — 탭하면 30일 출석 달력 화면으로 이동한다.
class _AttendanceShortcutCard extends StatelessWidget {
  const _AttendanceShortcutCard({
    required this.checkedToday,
    required this.streak,
    required this.onTap,
  });

  final bool checkedToday;
  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: UnifiedTokens.iconCircleLg,
            height: UnifiedTokens.iconCircleLg,
            decoration: BoxDecoration(
              color: UnifiedColors.bg,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: UnifiedTokens.iconLg,
              color: UnifiedColors.textPrimary,
            ),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('출석체크', style: UnifiedText.bodyStrong()),
                const SizedBox(height: 2),
                Text(
                  checkedToday
                      ? '오늘 출석 완료 · 연속 $streak일'
                      : '연속 $streak일째 · 이번 달 출석 달력 보기',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UnifiedText.caption(),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: UnifiedTokens.iconSm,
            color: UnifiedColors.textCaption,
          ),
        ],
      ),
    );
  }
}
