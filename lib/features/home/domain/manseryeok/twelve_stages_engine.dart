/// [정통사주 80종 전용 신규 엔진] 십이운성(十二運星) 엔진 — PHASE 2 §10.
///
/// 37번 지시 §10 "장생/목욕/관대/건록/제왕/쇠/병/사/묘/절/태/양 12개를
/// 일간 기준으로 각 지지에 계산"에 대응한다.
///
/// [계산 로직 재사용] `lunar` 패키지의 `EightChar`가 이미 십이운성
/// (長生·沐浴·冠带·临官·帝旺·衰·病·死·墓·绝·胎·养, `CHANG_SHENG` 상수 +
/// `getDiShi()`)을 정확히 구현하고 있다(§10 조사 결과, `EightChar.dart`
/// 25~119라인). 이 파일은 그 결과를 한글 라벨로 변환해 [TwelveStagesProfile]
/// 형태로 정리하는 역할만 한다 — 계산 알고리즘 재구현 없음.
library;

import 'package:lunar/lunar.dart';

import 'saju_profile.dart';

/// `EightChar.CHANG_SHENG`(중국어 한자)과 정통사주 한글 명칭 매핑.
const Map<String, String> _changShengToKr = {
  '长生': '장생',
  '沐浴': '목욕',
  '冠带': '관대',
  '临官': '건록',
  '帝旺': '제왕',
  '衰': '쇠',
  '病': '병',
  '死': '사',
  '墓': '묘',
  '绝': '절',
  '胎': '태',
  '养': '양',
};

class TwelveStagesEngine {
  TwelveStagesEngine._();

  /// [eightChar]는 [ManseryeokCoreEngine.calculatePillars]가 반환한
  /// [ManseryeokCoreResult.eightChar]를 그대로 전달받는다(일간 기준
  /// 계산이므로 setSect() 등 자시 정책이 이미 반영된 인스턴스를 그대로
  /// 사용해야 회귀가 없다).
  static TwelveStagesProfile analyze(EightChar eightChar) {
    String label(String hanja) => _changShengToKr[hanja] ?? hanja;

    return TwelveStagesProfile(
      year: label(eightChar.getYearDiShi()),
      month: label(eightChar.getMonthDiShi()),
      day: label(eightChar.getDayDiShi()),
      hour: label(eightChar.getTimeDiShi()),
    );
  }
}
