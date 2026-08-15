/// [정통사주 80종 전용] 만세력 Core Engine — 계산 정책(Policy) 명시 파일.
///
/// 이 파일은 어떤 새로운 계산도 하지 않는다. 오직 "lunar 패키지가 이미
/// 지원하는 여러 계산 방식(학파) 중 이 프로젝트가 어떤 것을 기본값으로
/// 채택하는지"를 코드 레벨에서 명확히 문서화하고, 테스트로 고정하기 위한
/// 용도다(37번 지시 §5 "계산 정책을 코드에 명확히 정의하고 테스트 가능하게
/// 한다").
///
/// [절대 원칙] 여기 정의된 정책은 기존 `saju_engine.dart`(레거시 아님 —
/// 이번 프로젝트의 jeontong 로컬 계산 엔진 그 자체)가 지금까지 사용해 온
/// 기본 동작과 **100% 동일**해야 한다. 즉, 새 Core Engine 도입으로 기존
/// 정통사주 80종의 계산 결과가 달라지면 안 된다(회귀 금지). 새 정책 옵션은
/// "명시적으로 다르게 요청했을 때만" 다른 결과를 낸다.
library;

/// 자시(子時, 23:00~00:59) 중 "야자시/조자시" 처리 정책.
///
/// 명리학계에는 두 학파가 있다.
/// - 조자시/야자시 구분파: 23:00~23:59(야자시)는 "다음 날" 일주로 계산하고,
///   00:00~00:59(조자시)는 "당일" 일주로 계산한다.
/// - 자시 통합파(인시 기준 X, 자시 전체를 당일로): 23:00~00:59 전체를
///   "당일" 일주로 계산한다(야자시도 다음날로 넘기지 않음).
///
/// `lunar` 패키지의 `EightChar.setSect(int)`가 이 두 학파를 그대로
/// 제공한다(패키지 원본 주석 인용):
/// - sect=1 → "八字流派1，晚子时（夜子/子夜）日柱算明天" (야자시 익일 처리)
/// - sect=2 → "八字流派2，晚子时（夜子/子夜）日柱算当天" (야자시 당일 처리)
///
/// [정책 결정] 이 프로젝트는 지금까지 `EightChar.setSect()`를 호출하지
/// 않고 패키지 기본값(`_sect = 2`, 즉 "야자시도 당일" 학파)을 그대로
/// 사용해 왔고, 이 상태로 박주상님(1972-02-13 02:00 남) 샘플이 원본
/// Python(`saju_calculator.py`, 역시 setSect 미호출 → sect=2)과 대조
/// 검증된 바 있다. 따라서 [lateZiSameDay]를 프로젝트 기본값으로 고정한다.
enum ZiHourPolicy {
  /// 야자시(23:00~23:59)를 다음 날 일주로 계산(sect=1).
  lateZiNextDay,

  /// 야자시(23:00~23:59)도 당일 일주로 계산(sect=2) — **프로젝트 기본값**.
  lateZiSameDay,
}

/// [ZiHourPolicy] → `EightChar.setSect()` 인자 변환.
int ziHourPolicyToSect(ZiHourPolicy policy) {
  switch (policy) {
    case ZiHourPolicy.lateZiNextDay:
      return 1;
    case ZiHourPolicy.lateZiSameDay:
      return 2;
  }
}

/// 대운 순행/역행 시작 시점의 절기 계산 정밀도 정책.
///
/// `lunar` 패키지의 `Yun.computeStart(sect)`가 두 가지 정밀도를 제공한다.
/// - sect=1: 절기까지 남은 일수를 "시진(2시간)" 단위로 반올림해 대운
///   시작 나이를 근사한다(전통적인 "3일=1년" 약식 계산).
/// - sect=2: 절기까지 남은 시간을 분 단위까지 정밀 계산한다(정밀식).
///
/// [정책 결정] 기존 `saju_engine.dart`는 `eightChar.getYun(gender)`을
/// `sect` 인자 없이 호출해 왔고, `EightChar.getYun()`의 기본값은
/// `sect=1`이다(패키지 소스 `Yun getYun(int gender, [int sect = 1])`).
/// 따라서 [traditionalApprox](시진 단위 근사, sect=1)를 프로젝트
/// 기본값으로 고정해 기존 결과와의 회귀를 방지한다. 더 정밀한 계산이
/// 필요하면 [precise](sect=2)를 명시적으로 선택할 수 있게 옵션으로만
/// 남겨둔다(기본값 변경 없음).
enum DaewoonStartPrecision {
  /// 시진(2시간) 단위 근사 — **프로젝트 기본값**(sect=1).
  traditionalApprox,

  /// 분 단위 정밀 계산(sect=2).
  precise,
}

int daewoonStartPrecisionToSect(DaewoonStartPrecision policy) {
  switch (policy) {
    case DaewoonStartPrecision.traditionalApprox:
      return 1;
    case DaewoonStartPrecision.precise:
      return 2;
  }
}

/// 입력 캘린더 종류 — 양력/음력(+윤달) 명시.
enum CalendarInputType {
  /// 양력(그레고리력) 생년월일시 입력.
  solar,

  /// 음력 생년월일시 입력(윤달 여부는 [leapMonth]로 별도 표시).
  lunar,
}

/// 출생지 시간대 정책.
///
/// [해외출생 확장 구조] 37번 지시 §5 "표준시/시간대/해외 출생 확장 구조"에
/// 대응한다. 계산 원칙은 다음과 같다.
///
/// 1. 사용자가 입력한 생년월일시는 항상 "출생지의 벽시계 시각(local wall
///    clock time)"으로 취급한다(예: 뉴욕에서 태어났다면 뉴욕 현지 시각).
/// 2. 이 벽시계 시각을 [utcOffsetMinutes](출생지 표준시의 UTC 오프셋,
///    분 단위, 예: KST=+540)를 이용해 UTC로 환산한 뒤, 다시 "한국
///    표준시(KST, UTC+9)" 벽시계 시각으로 재환산한다.
/// 3. `lunar` 패키지의 만세력 계산(60갑자/절기/월주/일주 등)은 원저자가
///    "베이징 표준시(UTC+8)" 기준 절기 계산을 내장하고 있으나, 한국의
///    전통 만세력 프로그램들은 관행적으로 "이 절기 시각표를 그대로 KST
///    (UTC+9) 벽시계 기준으로 사용"한다(원본 파이썬 `saju_calculator.py`
///    및 기존 `saju_engine.dart` 모두 이 관행을 따르고 있으며, 별도의
///    ±1시간/±30분 보정을 적용하지 않았다). 이번 Core Engine도 **기존
///    검증된 관행을 그대로 유지**한다 — 국내 출생자는 입력 시각을 그대로
///    `Lunar/Solar` 계산에 투입한다(회귀 없음).
/// 4. 해외 출생자는 위 2번 환산을 거쳐 "KST 기준 벽시계 시각"으로
///    맞춘 뒤 동일한 만세력 계산 파이프라인에 투입한다. 즉, 시간대 보정은
///    "값 변환" 단계에서만 일어나고, 절기/60갑자 계산 알고리즘 자체는
///    전혀 건드리지 않는다(계산 로직 재구현 금지 원칙 준수).
///
/// [진태양시(true solar time) 보정] 명리학 고급 논쟁 중 하나인 "경도 보정
/// (서울 기준 표준시와 실제 태양남중시각의 차이, 대략 ±30분)"은 이번
/// Phase 1에서는 **적용하지 않는다**(기존 검증된 계산과의 회귀 방지가
/// 최우선). 향후 필요 시 [SolarTimeCorrection]으로 별도 옵션화한다.
const int kstUtcOffsetMinutes = 9 * 60;

/// 진태양시(경도) 보정 정책 — 기본은 미적용(off). 향후 확장용 자리만
/// 마련해둔다(37번 지시 §5의 "해외 출생 확장 구조"에 대응하되, 회귀 방지를
/// 위해 기본 비활성).
enum SolarTimeCorrection {
  /// 보정 없음 — **프로젝트 기본값**. 입력된 벽시계 시각을 그대로 사용한다.
  none,
}
