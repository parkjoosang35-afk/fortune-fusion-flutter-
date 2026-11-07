import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mypage/presentation/theme/mypage_minimal_theme.dart';
import '../../mypage/presentation/theme/mypage_toast.dart';
import '../../wallet/application/wallet_provider.dart';
import '../application/attendance_provider.dart';
import '../domain/attendance_calendar_model.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S09] 신규 "출석체크" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S09 출석체크" 스펙에 따른
/// 전면 신규 화면이다. 기존 `AttendanceCalendarScreen`(다크 `UnifiedColors`
/// 톤, 1~30일차 선형 보상 30칸 가로스크롤)은 README §S09 레이아웃(달력
/// 셀 디자인, 연속 보너스 트랙의 원형 노드+연결선 등)과 크게 달라 같은
/// 파일을 리스킨하는 대신 새 파일로 작성했다 — 기존 파일은 프로젝트
/// 관례에 따라 삭제하지 않는다. `/reward/attendance` 라우트만 이 화면을
/// 가리키도록 app_router.dart를 교체한다(§S03/S05와 동일한 패턴).
///
/// 데이터 소스(변경 없음, 기존 Provider/Repository 재사용):
/// - [AttendanceProvider]: 달력 로드([loadCalendar]), 체크인([checkIn]).
///   서버가 지갑 적립까지 트랜잭션으로 처리하므로, 체크인 성공 시
///   [WalletProvider.load]로 잔액만 재조회한다(기존 화면과 동일한 원칙 —
///   WalletProvider.earn()을 별도 호출하면 중복 적립되므로 호출 금지).
/// - [AttendanceCalendarModel.milestones]: 관리자가 등록한 연속출석
///   보상표(현재 1~30일차 "N×10개" 선형 보상)를 그대로 사용한다. README는
///   5단계 예시값(3/7/14/21/30일 +10/+30/+50/+70/+100)을 들었지만, 각주에
///   "보상 값은 기획 확정이 필요합니다"라고 명시돼 있어 실제 값은 서버가
///   확정한 것을 그대로 신뢰한다("로직은 그대로" 원칙 — 보상 테이블을
///   하드코딩하지 않는다).
class AttendanceMinimalScreen extends StatefulWidget {
  const AttendanceMinimalScreen({super.key});

  @override
  State<AttendanceMinimalScreen> createState() =>
      _AttendanceMinimalScreenState();
}

class _AttendanceMinimalScreenState extends State<AttendanceMinimalScreen> {
  late int _displayYear;
  late int _displayMonth;

  /// README "찍는 순간 도장 애니메이션"을 1회성으로 재생하기 위한 트리거.
  /// 체크인 성공 직후에만 true가 되고, 애니메이션이 끝나면 다시 false로
  /// 되돌려 버튼이 평소 상태로 복귀한다.
  bool _justStamped = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayYear = now.year;
    _displayMonth = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendanceProvider>().loadCalendar(
        year: _displayYear,
        month: _displayMonth,
      );
    });
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return now.year == _displayYear && now.month == _displayMonth;
  }

  void _changeMonth(int delta) {
    var y = _displayYear;
    var m = _displayMonth + delta;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    setState(() {
      _displayYear = y;
      _displayMonth = m;
    });
    context.read<AttendanceProvider>().loadCalendar(year: y, month: m);
  }

  Future<void> _handleCheckIn() async {
    final attendance = context.read<AttendanceProvider>();
    if (attendance.checkedToday) return;

    final earned = await attendance.checkIn();
    if (!mounted) return;
    if (earned > 0) {
      await context.read<WalletProvider>().load();
      if (!mounted) return;
      // 체크인한 달이 현재 보고 있는 달과 다를 수 있으므로(월 이동 중
      // 체크인은 사실상 없지만 방어적으로) 보고 있는 달 기준으로 다시
      // 불러와 달력에 오늘 도장을 반영한다.
      await attendance.loadCalendar(
        year: _displayYear,
        month: _displayMonth,
      );
      if (!mounted) return;
      setState(() => _justStamped = true);
      showMyPageToast(context, '오늘 출석을 마쳤어요 · 복주머니 +$earned개');
    } else {
      showMyPageToast(
        context,
        attendance.lastError ?? '잠시 연결이 고르지 않아요 · 다시 시도해 주세요',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final calendar = attendance.calendar;

    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: MyPageColors.red,
          onRefresh: () => attendance.loadCalendar(
            year: _displayYear,
            month: _displayMonth,
          ),
          child: CustomScrollView(
            slivers: [
              // README "서브화면 공통 셸" 상단바.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 40,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: MyPageColors.ink,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          '출석체크',
                          textAlign: TextAlign.center,
                          style: MyPageTextStyles.header,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  MyPageSpacing.subX,
                  6,
                  MyPageSpacing.subX,
                  120,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _HeroTitle(checkedToday: calendar?.checkedToday ?? false),
                    const SizedBox(height: 6),
                    const Text(
                      '하루에 한 번, 복주머니 10개가 담겨요',
                      style: MyPageTextStyles.body,
                    ),
                    const SizedBox(height: 24),
                    _MonthHeader(
                      year: _displayYear,
                      month: _displayMonth,
                      onPrev: () => _changeMonth(-1),
                      onNext: () => _changeMonth(1),
                    ),
                    const SizedBox(height: 12),
                    if (calendar == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: attendance.isCalendarLoading
                              ? const CircularProgressIndicator(
                                  color: MyPageColors.red,
                                )
                              : Text(
                                  attendance.calendarError ??
                                      '잠시 연결이 고르지 않아요 · 다시 시도해 주세요',
                                  style: MyPageTextStyles.caption,
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      )
                    else ...[
                      _CalendarGrid(
                        year: _displayYear,
                        month: _displayMonth,
                        isCurrentMonth: _isCurrentMonth,
                        attendedDays: calendar.attendedDays,
                      ),
                      const SizedBox(height: 28),
                      if (calendar.milestones.isNotEmpty) ...[
                        const Text(
                          '연속 보너스 트랙',
                          style: MyPageTextStyles.cardTitle,
                        ),
                        const SizedBox(height: 14),
                        _BonusTrack(
                          streak: calendar.streak,
                          milestones: calendar.milestones,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ],
                    _CheckInCta(
                      checkedToday: calendar?.checkedToday ?? false,
                      justStamped: _justStamped,
                      onStampFinished: () =>
                          setState(() => _justStamped = false),
                      onTap: _handleCheckIn,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// README §S09 타이틀: 출석 전 "오늘의 도장을 / 찍어 주세요", 출석 후
/// "오늘도 도장을 / 찍었어요".
class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.checkedToday});
  final bool checkedToday;

  @override
  Widget build(BuildContext context) {
    return Text(
      checkedToday ? '오늘도 도장을\n찍었어요' : '오늘의 도장을\n찍어 주세요',
      style: MyPageTextStyles.display,
    );
  }
}

/// README "월 헤더: ‹ "2026 · 11" › (mono)".
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.year,
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final int year;
  final int month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: MyPageColors.ink3,
          ),
        ),
        Text(
          '$year · ${month.toString().padLeft(2, '0')}',
          style: const TextStyle(
            fontFamily: MyPageFonts.mono,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            letterSpacing: 1.5,
            color: MyPageColors.ink,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: MyPageColors.ink3,
          ),
        ),
      ],
    );
  }
}

/// README "달력 7열" — 요일 행(日만 빨강) + 셀(출석=빨강 도장 회전, 오늘=
/// 점선 빨강 원, 미래=opacity .6).
class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.isCurrentMonth,
    required this.attendedDays,
  });

  final int year;
  final int month;
  final bool isCurrentMonth;
  final Set<int> attendedDays;

  static const _weekdayLabels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = firstDay.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now().day;

    return Column(
      children: [
        Row(
          children: [
            for (int i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _weekdayLabels[i],
                    style: TextStyle(
                      fontFamily: MyPageFonts.ui,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: i == 0 ? MyPageColors.red : MyPageColors.ink3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (int r = 0; r < rows; r++)
          SizedBox(
            height: 40,
            child: Row(
              children: List.generate(7, (c) {
                final cellIndex = r * 7 + c;
                final day = cellIndex - leadingBlanks + 1;
                if (day < 1 || day > daysInMonth) {
                  return const Expanded(child: SizedBox.shrink());
                }
                final isToday = isCurrentMonth && today == day;
                final isFuture =
                    isCurrentMonth && day > today && !attendedDays.contains(day);
                final isAttended = attendedDays.contains(day);
                return Expanded(
                  child: _DayCell(
                    day: day,
                    isToday: isToday,
                    isAttended: isAttended,
                    isFuture: isFuture,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isAttended,
    required this.isFuture,
  });

  final int day;
  final bool isToday;
  final bool isAttended;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    Widget cell;
    if (isAttended) {
      // README: "출석한 날: 34×34 radius 7, --mp-red, 印 900, rotate(-8°)".
      cell = Transform.rotate(
        angle: -8 * 3.1415926535 / 180,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: MyPageColors.red,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: const Text(
            '印',
            style: TextStyle(
              fontFamily: MyPageFonts.hanja,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Color(0xFFFBF1DE),
            ),
          ),
        ),
      );
    } else if (isToday) {
      // README: "오늘(미출석): 36 원, 1.5px dashed 빨강".
      cell = CustomPaint(
        painter: _DashedCirclePainter(color: MyPageColors.red),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              '$day',
              style: const TextStyle(
                fontFamily: MyPageFonts.ui,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: MyPageColors.red,
              ),
            ),
          ),
        ),
      );
    } else {
      cell = Opacity(
        opacity: isFuture ? 0.6 : 1.0,
        child: Center(
          child: Text(
            '$day',
            style: const TextStyle(
              fontFamily: MyPageFonts.ui,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: MyPageColors.ink2,
            ),
          ),
        ),
      );
    }
    return Center(child: cell);
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    const dashWidth = 3.5;
    const dashGap = 3.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// README "연속 보너스 트랙" — 32px 원 노드 + 연결선(진행도만큼 채워짐).
/// 관리자가 등록한 [milestones]을 그대로 가로 스크롤로 보여준다(5단계
/// 고정이 아니라 실제 서버 보상표 길이를 그대로 따른다).
class _BonusTrack extends StatefulWidget {
  const _BonusTrack({required this.streak, required this.milestones});

  final int streak;
  final List<AttendanceMilestone> milestones;

  @override
  State<_BonusTrack> createState() => _BonusTrackState();
}

class _BonusTrackState extends State<_BonusTrack> {
  final _scrollController = ScrollController();
  static const double _nodeSize = 32;
  static const double _lineWidth = 28;
  static const double _itemExtent = _nodeSize + _lineWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final nextIndex = widget.milestones.indexWhere(
      (m) => m.streakDay > widget.streak,
    );
    final targetIndex = nextIndex == -1
        ? widget.milestones.length - 1
        : nextIndex;
    final targetOffset = (targetIndex * _itemExtent) - (_itemExtent * 1.5);
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
    final milestones = widget.milestones;
    return SizedBox(
      height: 70,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final m = milestones[index];
          final reached = widget.streak >= m.streakDay;
          final isLast = index == milestones.length - 1;
          final nextReached = !isLast && widget.streak >= milestones[index + 1].streakDay;
          return Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _nodeSize,
                    height: _nodeSize,
                    decoration: BoxDecoration(
                      color: reached ? MyPageColors.red : MyPageColors.paper2,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: reached
                        ? const Text(
                            '印',
                            style: TextStyle(
                              fontFamily: MyPageFonts.hanja,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFFFBF1DE),
                            ),
                          )
                        : Text(
                            '${m.streakDay}',
                            style: const TextStyle(
                              fontFamily: MyPageFonts.ui,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: MyPageColors.ink3,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+${m.rewardPoint}',
                    style: const TextStyle(
                      fontFamily: MyPageFonts.ui,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      color: MyPageColors.ink3,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                SizedBox(
                  width: _lineWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Container(
                      height: 2,
                      color: nextReached
                          ? MyPageColors.red
                          : MyPageColors.hair,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// README "CTA" — 출석 전: "출석 도장 찍기 · +10" / 출석 후: 비활성
/// "오늘 출석 완료". 체크인 성공 직후 도장 애니메이션(scale 1.8→1,
/// rotate -20°→-8°, opacity 0→1, 600ms)을 1회 재생한다.
class _CheckInCta extends StatefulWidget {
  const _CheckInCta({
    required this.checkedToday,
    required this.justStamped,
    required this.onStampFinished,
    required this.onTap,
  });

  final bool checkedToday;
  final bool justStamped;
  final VoidCallback onStampFinished;
  final VoidCallback onTap;

  @override
  State<_CheckInCta> createState() => _CheckInCtaState();
}

class _CheckInCtaState extends State<_CheckInCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stampController;

  @override
  void initState() {
    super.initState();
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(covariant _CheckInCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.justStamped && !oldWidget.justStamped) {
      _stampController.forward(from: 0).whenComplete(widget.onStampFinished);
    }
  }

  @override
  void dispose() {
    _stampController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checkedToday = widget.checkedToday;
    return SizedBox(
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _stampController,
        builder: (context, child) {
          // cubic-bezier(.3,1.6,.5,1) 근사: 오버슈트가 있는 ease-out 커브.
          final t = Curves.easeOutBack.transform(_stampController.value);
          final scale = widget.justStamped ? (1.8 - 0.8 * t) : 1.0;
          final angle = widget.justStamped
              ? (-20 + 12 * t) * 3.1415926535 / 180
              : 0.0;
          final opacity = widget.justStamped
              ? (0.0 + t).clamp(0.0, 1.0)
              : 1.0;
          return Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: angle,
              child: Opacity(opacity: opacity, child: child),
            ),
          );
        },
        child: GestureDetector(
          onTap: checkedToday ? null : widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: checkedToday
                  ? const Color(0x1F281909)
                  : MyPageColors.red,
              borderRadius: BorderRadius.circular(MyPageRadius.cta),
              boxShadow: checkedToday ? null : MyPageShadows.cta,
            ),
            child: Text(
              checkedToday ? '오늘 출석 완료' : '출석 도장 찍기 · +10',
              style: TextStyle(
                fontFamily: MyPageFonts.ui,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: checkedToday
                    ? MyPageColors.ink3
                    : const Color(0xFFFBF1DE),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
