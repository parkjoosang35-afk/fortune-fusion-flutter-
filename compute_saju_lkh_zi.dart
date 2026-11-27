import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';

void main() {
  // 비교용: "자시"(23:00~00:59) 대표 시각 00:30으로 시주만 비교.
  final core = ManseryeokCoreEngine.calculatePillars(
    year: 1970, month: 11, day: 26, hour: 0, minute: 30,
    calendarType: CalendarInputType.lunar, isLeapMonth: false,
  );
  print('자시(00:30) 시주: ${core.hourPillar.kr}(${core.hourPillar.hanja})');
  print('자시(00:30) 일주: ${core.dayPillar.kr}(${core.dayPillar.hanja})');

  final core2 = ManseryeokCoreEngine.calculatePillars(
    year: 1970, month: 11, day: 26, hour: 1, minute: 0,
    calendarType: CalendarInputType.lunar, isLeapMonth: false,
  );
  print('축시(01:00, 입력값 그대로) 시주: ${core2.hourPillar.kr}(${core2.hourPillar.hanja})');
  print('축시(01:00, 입력값 그대로) 일주: ${core2.dayPillar.kr}(${core2.dayPillar.hanja})');
}
