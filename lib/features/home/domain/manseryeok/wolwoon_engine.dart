/// [정통사주 80종 전용 신규 엔진] 월운(月運) 엔진 — PHASE 4 §16.
///
/// 37번 지시 §16 "월운 엔진: 절기기준 정확 계산, 이 월주가 시작되는
/// 절기 이름 저장"에 대응한다.
///
/// [절대 원칙 — 재구현 금지] 월운 간지(오호둔법 — 세운 연간으로부터
/// 갑기년→丙寅부터, 을경년→戊寅부터 등)는 `lunar` 패키지의
/// `LiuYue.getGanZhi()`가 이미 완전히 구현하고 있다. 이 엔진은 그 계산을
/// 호출하고, "절기 이름"만 별도로 부여하는 배선(wiring) 역할을 한다.
///
/// [절기 이름 매핑의 근거 — 재구현 아님, 패키지 알고리즘 역산 확인]
/// `LiuYue.getGanZhi()`의 지지 계산식은
/// `ZHI[(index + LunarUtil.BASE_MONTH_ZHI_INDEX) % 12 + 1]`
/// (`BASE_MONTH_ZHI_INDEX == 2`)이며, 이는 항상 index=0일 때 寅(인)월에서
/// 시작해 卯辰巳午未申酉戌亥子丑 순으로 고정 순환한다(연간지와 무관하게
/// 지지 순환 자체는 절대 고정 — 패키지 소스로 검증됨, 아래 [_liuYueOrder]
/// 참고). 전통 명리학에서 각 지지월은 반드시 특정 절기에서 시작하는
/// 것으로 정의되어 있다(寅월=입춘, 卯월=경칩, 辰월=청명, 巳월=입하,
/// 午월=망종, 未월=소서, 申월=입추, 酉월=백로, 戌월=한로, 亥월=입동,
/// 子월=대설, 丑월=소한 — 이는 임의 정의가 아니라 명리학 교과서의
/// 보편 고정 정의다). 따라서 [index] → 절기 이름은 패키지의 지지 순환
/// 순서와 1:1 고정 매핑되며, 별도의 절기 재계산이 필요하지 않다.
library;

import 'package:lunar/lunar.dart' show DaYun, EightChar, LiuNian, LiuYue, Yun;

import '../saju_engine.dart' show getTenGod;
import 'daewoon_engine.dart' show genderToLunarCode;
import 'luck_pillar_factory.dart' show buildLuckPillar;
import 'manseryeok_policy.dart';
import 'saju_profile.dart';

/// [LiuYue.getGanZhi()]의 지지 순환 순서(index 0~11)에 대응하는 "이 월주가
/// 시작되는 절기" 이름 — 寅월=입춘 ... 丑월=소한 고정 정의.
const List<String> _liuYueJieQiOrder = [
  '입춘', // 寅월(index0)
  '경칩', // 卯월(index1)
  '청명', // 辰월(index2)
  '입하', // 巳월(index3)
  '망종', // 午월(index4)
  '소서', // 未월(index5)
  '입추', // 申월(index6)
  '백로', // 酉월(index7)
  '한로', // 戌월(index8)
  '입동', // 亥월(index9)
  '대설', // 子월(index10)
  '소한', // 丑월(index11)
];

class WolwoonEngine {
  WolwoonEngine._();

  static DaYun _findDaYunForYear(Yun yun, int year) {
    var rounds = 12;
    while (rounds <= 60) {
      final list = yun.getDaYunBy(rounds);
      for (final dy in list) {
        if (year >= dy.getStartYear() && year <= dy.getEndYear()) {
          return dy;
        }
      }
      rounds += 12;
    }
    return yun.getDaYunBy(rounds).last;
  }

  /// 주어진 [year](세운 연도) 1건에 대한 12개월 월운 전체를 계산한다.
  /// [month] 필드는 전통 월건 순서(1=寅월/입춘 ~ 12=丑월/소한)를 의미하며,
  /// 이는 `LiuNian.getLiuYue()`가 실제로 반환하는 12건과 1:1 대응한다
  /// (그레고리력 달력 월과는 다름 — 예: 1=寅월은 그레고리력상 대략
  /// 2월~3월 초에 걸친다. 재구현이 아니라 패키지가 이미 이 순서로
  /// 계산해 제공하는 12건을 그대로 사용하는 것이다).
  static List<WolwoonEntry> analyzeYear({
    required EightChar eightChar,
    required String dayStemHanja,
    required String gender,
    required int year,
    DaewoonStartPrecision precision = DaewoonStartPrecision.traditionalApprox,
  }) {
    final sect = daewoonStartPrecisionToSect(precision);
    final yun = eightChar.getYun(genderToLunarCode(gender), sect);
    final dy = _findDaYunForYear(yun, year);
    final idx = year - dy.getStartYear();
    final liuNian = LiuNian(dy, idx);
    final liuYueList = liuNian.getLiuYue();

    final entries = <WolwoonEntry>[];
    for (final LiuYue ly in liuYueList) {
      final gz = ly.getGanZhi();
      if (gz.length < 2) continue;
      final stemHanja = gz.substring(0, 1);
      final branchHanja = gz.substring(1, 2);
      entries.add(
        WolwoonEntry(
          year: year,
          month: ly.getIndex() + 1,
          pillar: buildLuckPillar(stemHanja, branchHanja),
          tenGodStem: getTenGod(dayStemHanja, stemHanja),
          tenGodBranch: getTenGod(dayStemHanja, branchHanja),
          jieQiName: _liuYueJieQiOrder[ly.getIndex()],
        ),
      );
    }
    return entries;
  }
}
