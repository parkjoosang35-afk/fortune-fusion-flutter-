/// [정통사주 80종 전용 신규 엔진] 세운(歲運) 엔진 — PHASE 4 §15.
///
/// 37번 지시 §15 "세운 엔진: 절기(입춘) 기준 정확 계산"에 대응한다.
///
/// [절대 원칙 — 재구현 금지] 세운 간지는 대운/출생일과 무관하게 오직
/// "입춘(立春) 절기" 하나로만 결정되는 절대 좌표다. `lunar` 패키지의
/// `LiuNian.getGanZhi()`가 이미 `_lunar.getJieQiTable()['立春']`을 이용해
/// 이를 정확히 구현하고 있으므로, 이 엔진은 그 계산을 호출하는 배선
/// 역할만 한다(연간지 계산 알고리즘 재구현 금지).
///
/// [DaYun 컨테이너 필요성] `lunar` 패키지의 `LiuNian` 생성자는
/// `LiuNian(DaYun daYun, int index)` 형태로 [DaYun] 인스턴스를 요구한다.
/// 다만 `getGanZhi()`의 실제 계산식은 입춘 기준 연간지 + 순차 오프셋으로,
/// 어떤 [DaYun] 라운드에 속하는 인덱스를 쓰든 "그 연도를 포함하는
/// 올바른 [DaYun]"만 골라 [index]를 정확히 넘기면 항상 같은(정확한)
/// 결과가 나온다 — 이는 패키지 설계상 세운이 대운 객체를 통해서만
/// 노출되기 때문이며, 세운 자체의 값이 대운에 의존한다는 뜻은 아니다.
library;

import 'package:lunar/lunar.dart' show DaYun, EightChar, LiuNian, Yun;

import '../saju_engine.dart' show getTenGod;
import 'daewoon_engine.dart' show genderToLunarCode;
import 'luck_pillar_factory.dart' show buildLuckPillar;
import 'manseryeok_policy.dart';
import 'saju_profile.dart';

class SewoonEngine {
  SewoonEngine._();

  /// [year]를 포함하는 [DaYun](대운 라운드)을 찾는다. 요청 범위가 매우
  /// 넓어(고령) 기본 라운드 수를 벗어나면 라운드를 점진적으로 늘려
  /// 재탐색한다.
  static DaYun _findDaYunForYear(Yun yun, int year) {
    var rounds = 12; // 기본: 소운기(~9년) + 11라운드(110년) ≈ 최대 119세.
    while (rounds <= 60) {
      final list = yun.getDaYunBy(rounds);
      for (final dy in list) {
        if (year >= dy.getStartYear() && year <= dy.getEndYear()) {
          return dy;
        }
      }
      rounds += 12;
    }
    // 극단적으로 범위를 벗어난 요청(사실상 발생하지 않음) — 마지막
    // 라운드를 그대로 반환해 예외 대신 근사값을 낸다.
    return yun.getDaYunBy(rounds).last;
  }

  /// [fromYear]~[toYear](양쪽 포함) 구간의 세운을 계산한다.
  static List<SewoonEntry> analyzeYears({
    required EightChar eightChar,
    required String dayStemHanja,
    required String gender,
    required int fromYear,
    required int toYear,
    DaewoonStartPrecision precision = DaewoonStartPrecision.traditionalApprox,
  }) {
    if (toYear < fromYear) {
      throw ArgumentError('toYear($toYear) < fromYear($fromYear)');
    }
    final sect = daewoonStartPrecisionToSect(precision);
    final yun = eightChar.getYun(genderToLunarCode(gender), sect);

    final entries = <SewoonEntry>[];
    for (var year = fromYear; year <= toYear; year++) {
      final dy = _findDaYunForYear(yun, year);
      final idx = year - dy.getStartYear();
      final liuNian = LiuNian(dy, idx);
      final gz = liuNian.getGanZhi();
      if (gz.length < 2) continue;
      final stemHanja = gz.substring(0, 1);
      final branchHanja = gz.substring(1, 2);
      entries.add(
        SewoonEntry(
          year: year,
          pillar: buildLuckPillar(stemHanja, branchHanja),
          tenGodStem: getTenGod(dayStemHanja, stemHanja),
          tenGodBranch: getTenGod(dayStemHanja, branchHanja),
        ),
      );
    }
    return entries;
  }
}
