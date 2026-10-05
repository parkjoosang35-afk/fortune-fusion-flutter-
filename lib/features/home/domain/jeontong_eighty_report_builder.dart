import 'manseryeok/manseryeok_core_engine.dart';
import 'manseryeok/manseryeok_policy.dart';
import 'manseryeok/phase2_analysis_engine.dart';
import 'manseryeok/phase3_analysis_engine.dart';
import 'manseryeok/phase4_analysis_engine.dart';
import 'manseryeok/saju_profile.dart' show SajuProfile;
import 'manseryeok/saju_result_adapter.dart';
import 'saju_engine.dart';

/// [신통방통 정통사주 리뉴얼 — 69종 UI 레이어 제거]
///
/// 이 클래스는 과거 "정통사주 69종"(jeontong_eighty) UI 전용 콘텐츠
/// 생성기(`build()`, `_tryBuildRealReport()`, 결정론적 랜덤 콘텐츠 풀 등)를
/// 포함했었다. 69종 UI 레이어 전체(화면/디자인/캐시/캘큘레이터)가 완전히
/// 삭제됨에 따라 그 코드도 함께 제거되었다.
///
/// 이 파일에 남은 유일한 멤버 [buildProfileAndSajuResultViaPhase1to4]는
/// 69종과 무관하게 **귀인지도(guinji) 기능이 실사용하는 순수 계산 함수**다
/// (`guinji_provider.dart` 3곳에서 직접 호출). PHASE1(만세력 원국) →
/// PHASE2(오행/십신/지장간/십이운성/합충형파해/신살) → PHASE3(신강신약/
/// 용신희신기신구신) → PHASE4(대운/세운/월운) 순서로 검증 완료된 엔진을
/// 실행하고, [sajuResultFromProfile] 어댑터로 레거시 [SajuResult] 형태로
/// 변환한다. 이 함수는 만세력 계산을 다시 하지 않는다 — PHASE1~4가 유일한
/// 계산 기준이며, 어댑터는 이미 계산된 값을 옮기기만 한다. 계산 로직은
/// 한 글자도 바뀌지 않았다 — 69종 정리 작업은 이 함수를 호출하지 않는
/// 코드만 제거했을 뿐이다.
class JeontongReportBuilder {
  JeontongReportBuilder._();

  /// [kst]는 이미 KST(UTC+9) 벽시계 시각으로 변환된 값(호출부에서 변환
  /// 완료). [isLunar]가 true 이면 [kst]를 음력 생년월일시로 해석한다.
  static ({SajuResult saju, SajuProfile profile})
  buildProfileAndSajuResultViaPhase1to4({
    required DateTime kst,
    required String gender,
    required bool isLunar,
    required DateTime referenceDate,
    bool isLeapMonth = false,
  }) {
    final withCore = ManseryeokCoreEngine.buildProfileWithCore(
      year: kst.year,
      month: kst.month,
      day: kst.day,
      hour: kst.hour,
      minute: kst.minute,
      gender: gender,
      calendarType: isLunar ? CalendarInputType.lunar : CalendarInputType.solar,
      // 양력이면 윤달 개념 자체가 없으므로 항상 false로 강제한다.
      isLeapMonth: isLunar ? isLeapMonth : false,
    );
    final p2 = Phase2AnalysisEngine.analyze(
      baseProfile: withCore.profile,
      core: withCore.core,
    );
    final p3 = Phase3AnalysisEngine.analyze(baseProfile: p2);
    final p4 = Phase4AnalysisEngine.analyze(
      baseProfile: p3,
      core: withCore.core,
      referenceDate: referenceDate,
    );
    final saju = sajuResultFromProfile(p4, referenceDate: referenceDate);
    return (saju: saju, profile: p4);
  }
}
