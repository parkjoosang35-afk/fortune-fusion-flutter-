/// [AI 사주 호출 점진 전환] 기존 AI(LLM) 사주 해석 호출을 한 번에 끊지 않고,
/// 4개 기능 단위로 나눠 개별적으로 켜고 끌 수 있게 하는 feature flag 모음.
///
/// [배경] `SajuRepository.requestSaju()`는 admin_web의
/// `POST /api/public/fortune/saju`(실 LLM 해석)를 호출한다. 반면 정통사주 80종
/// 화면([CategoriesGridScreen] → `GenericFortuneResultScreen`)은 이미 클라이언트
/// 룰 기반([GenericFortuneReportBuilder])으로 결과를 만들고 있다. 두 경로를
/// 동시에 살려두고, 메인 AI 해석 호출 비중만 점진적으로 낮추는 것이 이번
/// 작업의 목표다.
///
/// [운영 절차 — 반드시 이 순서를 지킬 것]
/// 1) 1단계(지금): 모든 flag는 `true`(기존 동작 그대로 유지) + 카운터만 부착.
/// 2) 2단계(7일): 운영 트래픽에서 카운터만 관측(토글 없음).
/// 3) 3단계(2주): 메인 AI 호출 비중이 30% 미만으로 확인되면 그때
///    [kUseLegacyAiSajuMain]만 `false`로 내린다(히스토리/북마크/프로필은
///    그대로 유지).
/// 4) 4단계: 5% 미만까지 하락이 충분히 확인된 뒤에만
///    `SajuRepository.requestSaju()` 자체의 안전 삭제를 검토한다(이번
///    작업 범위 아님).
///
/// [금지] 이 파일의 상수를 한 번에 여러 개 false로 내리거나, 출시 빌드에서
/// 곧바로 [kUseLegacyAiSajuMain]을 false로 설정하는 것은 금지된다(운영
/// 카운터로 실제 비중을 먼저 확인한 뒤에만 내린다 — 위 2)~3)단계 참고).
class FeatureFlags {
  FeatureFlags._();

  /// 메인 AI(LLM) 사주 해석 호출([SajuRepository.requestSaju] → admin_web
  /// `/api/public/fortune/saju`).
  ///
  /// - `true`(기본값, 유지): 기존과 동일하게 실 LLM 해석을 호출한다.
  /// - `false`(3단계 이후에만 전환): 정통사주 80종과 동일한 룰 기반 결과
  ///   ([GenericFortuneReportBuilder])로 우회한다.
  static const bool kUseLegacyAiSajuMain = true;

  /// 사주 히스토리 조회([SajuRepository.getHistory]). 이번 작업에서는 항상
  /// 살려둔다(요청서 "살릴 것" 항목) — 분기 코드를 추가하지 않고 이 flag는
  /// 관측/문서화 목적으로만 존재한다.
  static const bool kUseLegacyAiSajuHistory = true;

  /// 사주 결과 북마크/즐겨찾기. 이번 작업 시점 기준 SajuRepository/
  /// SajuProvider에 별도 북마크 전용 메서드는 없음(히스토리 저장이 곧
  /// 북마크 역할을 겸함). 향후 북마크 기능이 분리되면 이 flag로 제어한다.
  static const bool kUseLegacyAiSajuBookmark = true;

  /// "내 사주함" 프로필 CRUD([SajuRepository.getProfiles]/[createProfile]/
  /// [updateProfile]/[deleteProfile]/[setPrimaryProfile]). 이번 작업에서는
  /// 항상 살려둔다(요청서 "살릴 것" 항목) — 분기 코드를 추가하지 않는다.
  static const bool kUseLegacyAiSajuProfile = true;
}
