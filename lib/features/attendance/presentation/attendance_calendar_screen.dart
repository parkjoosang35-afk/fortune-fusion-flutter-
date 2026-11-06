import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/premium_card.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/attendance_provider.dart';
import '../domain/attendance_calendar_model.dart';

/// [복주머니 화면 재구성] 미션/복주머니열기/개봉이력 3가지 기능을 삭제하고
/// "출석체크"만 남기면서, 사용자 요청("30일동안 출석 달력창이 떠서 출석을
/// 하면 복주머니를 줬으면 좋겠어")에 따라 신설한 이번 달 출석 달력 화면.
///
/// 구성: 이번 달 달력 그리드(출석한 날 🧧 표시, 오늘 강조) + 연속출석일수 +
/// 마일스톤 보상 트랙(관리자가 등록한 1/3/7/14/21/30일차 보상표) + 하단
/// "출석하기" 버튼(이미 출석했으면 비활성화 "오늘 출석 완료").
class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadCalendar();
    });
  }

  Future<void> _handleCheckIn() async {
    final attendance = context.read<AttendanceProvider>();
    if (attendance.checkedToday) {
      AppToast.show(context, '오늘 출석을 이미 완료했어요. (연속 ${attendance.streak}일째)');
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: '오늘 출석하기',
      message: '출석체크를 하고 복주머니를 받으시겠습니까?',
      confirmLabel: '출석하기',
    );
    if (!confirmed || !mounted) return;

    final earned = await attendance.checkIn();
    if (!mounted) return;
    if (earned > 0) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      await attendance.loadCalendar();
      if (!mounted) return;
      AppToast.show(context, '출석 완료! 복주머니 $earned개 지급되었습니다.');
    } else {
      AppToast.show(
        context,
        attendance.lastError ?? '출석 처리에 실패했습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final calendar = attendance.calendar;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(title: const Text('출석체크')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => attendance.loadCalendar(),
          child: attendance.isCalendarLoading && calendar == null
              ? const Center(child: CircularProgressIndicator())
              : calendar == null
                  ? _ErrorState(
                      message: attendance.calendarError ?? '출석 달력을 불러오지 못했어요.',
                      onRetry: () => attendance.loadCalendar(),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        UnifiedTokens.screenPadding,
                        UnifiedTokens.spaceMd,
                        UnifiedTokens.screenPadding,
                        UnifiedTokens.spaceXxl,
                      ),
                      children: [
                        _StreakHeader(
                          streak: calendar.streak,
                          checkedToday: calendar.checkedToday,
                        ),
                        const SizedBox(height: UnifiedTokens.spaceXl),
                        _CalendarGrid(calendar: calendar),
                        const SizedBox(height: UnifiedTokens.spaceXl),
                        _MilestoneTrack(calendar: calendar),
                        const SizedBox(height: UnifiedTokens.spaceXxl),
                        _CheckInButton(
                          checkedToday: calendar.checkedToday,
                          onTap: _handleCheckIn,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UnifiedTokens.spaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: UnifiedText.body(), textAlign: TextAlign.center),
            const SizedBox(height: UnifiedTokens.spaceLg),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: UnifiedColors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
                ),
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 연속출석일수 요약 헤더 카드.
///
/// [2026 출석 연속보너스 재설계] 1~30일차가 "N일차=N×10개" 선형 보상표로
/// 채워지면서, 오늘 출석 시 정확히 몇 개를 받는지(또는 이미 받았는지)를
/// 바로 보여주는 것이 사용자에게 더 명확하다고 판단해 추가한 영역.
/// (서버가 실제로 계산한 금액은 체크인 시점의 /checkin 응답으로만 확정되며,
/// 여기서는 어디까지나 "다음 출석 시 예상 지급량"을 미리 보여주는 용도다.)
class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.streak, required this.checkedToday});
  final int streak;
  final bool checkedToday;

  /// calendar.streak는 "가장 최근 출석의 연속일수"다(오늘 체크인했으면
  /// 오늘 포함, 아니면 어제까지 기준). 따라서 다음 체크인(오늘 미출석 시
  /// 오늘, 이미 출석했다면 내일)의 일차는 항상 streak+1이다.
  /// 1~30일차는 N×10, 31일차 이후는 서버가 30일차 보상(300개)을 계속
  /// 유지 지급하므로 동일 공식을 클라이언트 미리보기에도 반영한다.
  int get _nextDayNumber => streak + 1;
  int get _expectedReward {
    final day = _nextDayNumber.clamp(1, 30);
    return day * 10;
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardMain,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: UnifiedColors.bg,
              shape: BoxShape.circle,
            ),
            child: const Text('🧧', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: UnifiedTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('연속 출석', style: UnifiedText.caption()),
                const SizedBox(height: 2),
                Text('$streak일째', style: UnifiedText.titleLarge()),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: UnifiedColors.black,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  checkedToday ? '내일 받을 보상' : '오늘 받을 보상',
                  style: UnifiedText.caption(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  '+$_expectedReward개',
                  style: UnifiedText.bodyStrong(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 이번 달 출석 달력 그리드 — 일요일 시작 7열, 출석한 날엔 🧧 배지, 오늘은 테두리 강조.
class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.calendar});
  final AttendanceCalendarModel calendar;

  @override
  Widget build(BuildContext context) {
    final year = calendar.year;
    final month = calendar.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // DateTime.weekday: 월=1..일=7 → 일요일 시작 그리드를 위해 0(일)~6(토)로 변환.
    final leadingBlanks = firstDay.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final now = DateTime.now();
    final isCurrentMonth = now.year == year && now.month == month;
    final attendedDays = calendar.attendedDays;

    const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$year년 $month월', style: UnifiedText.title()),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Row(
            children: weekdayLabels
                .map(
                  (w) => Expanded(
                    child: Center(
                      child: Text(w, style: UnifiedText.caption()),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: UnifiedTokens.spaceSm),
          for (int r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceSm),
              child: Row(
                children: List.generate(7, (c) {
                  final cellIndex = r * 7 + c;
                  final day = cellIndex - leadingBlanks + 1;
                  if (day < 1 || day > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 40));
                  }
                  final isToday = isCurrentMonth && now.day == day;
                  final isAttended = attendedDays.contains(day);
                  return Expanded(
                    child: _DayCell(
                      day: day,
                      isToday: isToday,
                      isAttended: isAttended,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isAttended,
  });
  final int day;
  final bool isToday;
  final bool isAttended;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isAttended ? UnifiedColors.cardMain : Colors.transparent,
          shape: BoxShape.circle,
          border: isToday
              ? Border.all(color: UnifiedColors.black, width: 1.5)
              : null,
        ),
        child: isAttended
            ? const Text('🧧', style: TextStyle(fontSize: 16))
            : Text(
                '$day',
                style: UnifiedText.bodySmall(
                  color: isToday
                      ? UnifiedColors.textPrimary
                      : UnifiedColors.textSecondary,
                ),
              ),
      ),
    );
  }
}

/// 연속출석 마일스톤 보상 트랙.
///
/// [2026 출석 연속보너스 재설계] 기존엔 관리자가 등록한 6개 포인트
/// (1/3/7/14/21/30일차)만 듬성듬성 보여줬지만, 이제 1~30일차 전부가
/// "N일차=N×10개" 선형 보상표로 채워져 있으므로 30칸을 전부 가로
/// 스크롤로 보여준다. 항목이 많아진 만큼 화면을 열자마자 "오늘/다음
/// 목표" 근처로 자동 스크롤해 사용자가 직접 30칸을 끝까지 넘기지
/// 않아도 되게 한다(사용자가 요청한 "더 좋은 출석 아이템" 개선 아이디어).
class _MilestoneTrack extends StatefulWidget {
  const _MilestoneTrack({required this.calendar});
  final AttendanceCalendarModel calendar;

  @override
  State<_MilestoneTrack> createState() => _MilestoneTrackState();
}

class _MilestoneTrackState extends State<_MilestoneTrack> {
  final _scrollController = ScrollController();
  static const double _itemWidth = 84;
  static const double _itemGap = UnifiedTokens.spaceMd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final milestones = widget.calendar.milestones;
    if (milestones.isEmpty) return;
    // 다음 목표(아직 안 받은 가장 가까운 일차)를 화면 가운데쯤 오도록 스크롤.
    final nextIndex = milestones.indexWhere(
      (m) => m.streakDay > widget.calendar.streak,
    );
    final targetIndex = nextIndex == -1 ? milestones.length - 1 : nextIndex;
    final targetOffset =
        (targetIndex * (_itemWidth + _itemGap)) - (_itemWidth * 1.5);
    _scrollController.jumpTo(
      targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendar = widget.calendar;
    if (calendar.milestones.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('연속출석 보상', style: UnifiedText.title()),
              Text(
                '1일 10개 → 30일 300개',
                style: UnifiedText.caption(color: UnifiedColors.textCaption),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          SizedBox(
            height: 76,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: calendar.milestones.length,
              separatorBuilder: (_, __) => const SizedBox(width: _itemGap),
              itemBuilder: (context, index) {
                final m = calendar.milestones[index];
                final reached = calendar.streak >= m.streakDay;
                final isNextTarget =
                    !reached &&
                    (index == 0 ||
                        calendar.streak >= calendar.milestones[index - 1].streakDay);
                return Container(
                  width: _itemWidth,
                  padding: const EdgeInsets.symmetric(
                    vertical: UnifiedTokens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: reached ? UnifiedColors.black : UnifiedColors.bg,
                    borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
                    border: isNextTarget
                        ? Border.all(color: UnifiedColors.black, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${m.streakDay}일차',
                        style: UnifiedText.chipLabel(
                          color: reached ? Colors.white : UnifiedColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${m.rewardPoint}개',
                        style: UnifiedText.caption(
                          color: reached
                              ? Colors.white70
                              : UnifiedColors.textCaption,
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
    );
  }
}

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.checkedToday, required this.onTap});
  final bool checkedToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: checkedToday ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              checkedToday ? UnifiedColors.chipInactiveBg : UnifiedColors.black,
          foregroundColor:
              checkedToday ? UnifiedColors.textCaption : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
          ),
          elevation: 0,
        ),
        child: Text(
          checkedToday ? '오늘 출석 완료' : '출석하기',
          style: UnifiedText.bodyStrong(
            color: checkedToday ? UnifiedColors.textCaption : Colors.white,
          ),
        ),
      ),
    );
  }
}
