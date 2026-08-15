/// [정통사주 80종 전용 신규 엔진] 대운(大運) 엔진 — PHASE 4 §14.
///
/// 37번 지시 §14 "대운 엔진: 패키지 네이티브 API 활용, 순행/역행/절기기준
/// 정확 계산"에 대응한다.
///
/// [절대 원칙 — 재구현 금지] 대운 순행/역행 판정(양남음녀 순행, 음남양녀
/// 역행)과 절기 기준 대운 시작 시점 계산은 `lunar` 패키지의
/// `EightChar.getYun(gender, sect)` → `Yun.computeStart(sect)`가 이미
/// 완전히 구현하고 있다. 이 엔진은 그 계산을 호출하고 결과를
/// [DaewoonEntry] 형태로 정규화하는 배선(wiring) 역할만 한다.
///
/// [기존 회귀 방지] 기존 `saju_engine.dart`의 `SajuEngine.calculate()`는
/// `eightChar.getYun(gender == 'male' ? 1 : 0)`을 `sect` 인자 없이
/// 호출한다 — `EightChar.getYun()`의 기본값은 `sect=1`이다. 이 엔진은
/// [manseryeok_policy.dart]의 `DaewoonStartPrecision.traditionalApprox`
/// (sect=1)를 프로젝트 기본값으로 사용해 기존 결과와 100% 동일한 대운
/// 간지/시작연령이 나오도록 한다(§17 "80종은 SajuProfile 재사용" 및
/// PHASE 1~3의 회귀 방지 원칙을 그대로 계승).
library;

import 'package:lunar/lunar.dart' show EightChar;

import '../saju_engine.dart' show getTenGod;
import 'luck_pillar_factory.dart' show buildLuckPillar;
import 'manseryeok_policy.dart';
import 'saju_profile.dart';

/// [gender]('male'|'female')를 `lunar` 패키지의 성별 코드(1=男, 0=女)로
/// 변환한다. 기존 `saju_engine.dart`의 `gender == 'male' ? 1 : 0`과 동일.
int genderToLunarCode(String gender) => gender == 'male' ? 1 : 0;

class DaewoonEngine {
  DaewoonEngine._();

  /// [eightChar]는 PHASE 1에서 계산된 것과 동일한 인스턴스(또는 동일
  /// 입력으로 재계산된 것)여야 하며, 이미 [ManseryeokCoreEngine]에서
  /// `setSect()`(자시 정책)가 적용된 상태여야 한다. 대운 시작 시점
  /// 정밀도는 [precision]으로 별도 제어한다(자시 정책과는 독립적인
  /// 정책이기 때문).
  ///
  /// [count]는 계산할 대운 개수(기본 9개 — 기존 `saju_engine.dart`와
  /// 동일 범위, §17 회귀 방지).
  static List<DaewoonEntry> analyze({
    required EightChar eightChar,
    required String dayStemHanja,
    required String gender,
    DaewoonStartPrecision precision = DaewoonStartPrecision.traditionalApprox,
    int count = 9,
  }) {
    final sect = daewoonStartPrecisionToSect(precision);
    final yun = eightChar.getYun(genderToLunarCode(gender), sect);
    final daYunList = yun.getDaYunBy(count + 1); // index 0은 소운기 — 아래서 제외.

    final entries = <DaewoonEntry>[];
    for (final dy in daYunList) {
      if (dy.getIndex() < 1) {
        // index 0(소운기, 출생~첫 대운 시작 전)은 "대운"이 아니므로
        // DaewoonEntry 목록에는 포함하지 않는다(37번 지시 §14는 "대운"
        // 만을 지칭하며, 기존 saju_engine.dart의 luckPillars도 index<1을
        // 별도 처리하지 않고 getGanZhi()가 빈 문자열을 반환하는 채로
        // 목록에 넣지만, 신규 엔진에서는 명확히 걸러내 빈 간지 항목이
        // 80종 콘텐츠에 노출되는 것을 방지한다).
        continue;
      }
      final gz = dy.getGanZhi();
      if (gz.length < 2) continue;
      final stemHanja = gz.substring(0, 1);
      final branchHanja = gz.substring(1, 2);
      entries.add(
        DaewoonEntry(
          index: dy.getIndex(),
          startAge: dy.getStartAge(),
          startYear: dy.getStartYear(),
          pillar: buildLuckPillar(stemHanja, branchHanja),
          tenGodStem: getTenGod(dayStemHanja, stemHanja),
          tenGodBranch: getTenGod(dayStemHanja, branchHanja),
        ),
      );
      if (entries.length >= count) break;
    }
    return entries;
  }
}
