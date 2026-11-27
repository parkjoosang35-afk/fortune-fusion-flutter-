/// admin_web `GET /api/public/attendance/calendar` 응답 대응 모델.
///
/// [배경] 기존 `/api/public/attendance/status`는 streak/checkedToday만 반환해
/// "이번 달 출석 달력" UI를 만들 수 없었다. 이 모델은 신규 calendar API가
/// 함께 내려주는 "이번 달 출석한 날짜 목록"과 "연속출석 마일스톤 보상표"를
/// 담아 출석 달력 화면(AttendanceCalendarScreen)에서 그대로 사용한다.
class AttendanceCalendarModel {
  final int year;
  final int month;
  final int streak;
  final bool checkedToday;
  final List<AttendanceDay> attendedDates;
  final List<AttendanceMilestone> milestones;

  const AttendanceCalendarModel({
    required this.year,
    required this.month,
    required this.streak,
    required this.checkedToday,
    required this.attendedDates,
    required this.milestones,
  });

  factory AttendanceCalendarModel.fromJson(Map<String, dynamic> json) {
    return AttendanceCalendarModel(
      year: json['year'] as int,
      month: json['month'] as int,
      streak: json['streak'] as int? ?? 0,
      checkedToday: json['checkedToday'] as bool? ?? false,
      attendedDates: ((json['attendedDates'] as List?) ?? [])
          .map((e) => AttendanceDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      milestones: ((json['milestones'] as List?) ?? [])
          .map((e) => AttendanceMilestone.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 이번 달 출석한 "일(day)" 숫자 집합 — 달력 셀 렌더링 시 `attendedDays.contains(day)`로
  /// 빠르게 조회하기 위한 편의 getter.
  Set<int> get attendedDays =>
      attendedDates.map((e) => e.date.day).toSet();
}

class AttendanceDay {
  final DateTime date;
  final int rewardPoint;
  final int streakCount;

  const AttendanceDay({
    required this.date,
    required this.rewardPoint,
    required this.streakCount,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) {
    final raw = json['date'] as String; // "yyyy-MM-dd" (KST 기준)
    final parts = raw.split('-');
    return AttendanceDay(
      date: DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      ),
      rewardPoint: json['rewardPoint'] as int? ?? 0,
      streakCount: json['streakCount'] as int? ?? 0,
    );
  }
}

/// 연속출석 마일스톤 보상 규칙(관리자 등록, `AttendanceRewardRule` 대응) - 예: 7일차 +50개.
class AttendanceMilestone {
  final int streakDay;
  final int rewardPoint;

  const AttendanceMilestone({
    required this.streakDay,
    required this.rewardPoint,
  });

  factory AttendanceMilestone.fromJson(Map<String, dynamic> json) {
    return AttendanceMilestone(
      streakDay: json['streakDay'] as int,
      rewardPoint: json['rewardPoint'] as int,
    );
  }
}
