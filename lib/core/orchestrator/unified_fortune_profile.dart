import '../../features/compatibility/domain/compatibility_model.dart';
import '../../features/fortune/face/domain/face_model.dart';
import '../../features/fortune/palm/domain/palm_model.dart';
import '../../features/fortune/tarot/domain/tarot_model.dart';
import '../../features/home/domain/manseryeok/saju_profile.dart';
import '../../features/home/domain/saju_engine.dart' show SajuResult;

/// [엔진 통합 지시문 STEP 3] 6개 운세 "문(door)" 중 이번 범위(사주/타로/
/// 관상/손금/궁합 5종, 귀인지도·소원방은 범위 밖)의 **최신 결과를 한 곳에
/// 모아두는 불변 값 객체**.
///
/// [설계 원칙 — 기존 Repository/엔진을 재구현하지 않는다]
/// 이 클래스는 새로운 계산을 전혀 하지 않는다 — 각 Repository의
/// `getHistory()`(타로/관상/손금/궁합)가 반환한 기존 결과 모델, 그리고
/// 로컬 PHASE1~4 만세력 엔진(`JeontongReportBuilder`)이 이미 계산해 둔
/// [SajuProfile]/[SajuResult]를 그대로 참조로 들고 있을 뿐이다.
/// [FortuneOrchestrator]가 이 객체를 채우고, [CrossCheckRule]의 점수
/// 추출기들이 이 객체를 읽어 교차검증 점수를 계산한다.
///
/// 5개 필드 모두 nullable이다 — 사용자가 해당 문을 아직 이용하지 않았으면
/// null이며, 이는 "실패"가 아니라 "아직 데이터 없음"을 뜻한다(Mock으로
/// 채우지 않는다는 원칙). [CrossCheckRule]의 각 점수 추출기는 필요한
/// 필드가 null이면 그 규칙 자체를 "미판정"으로 건너뛴다.
class UnifiedFortuneProfile {
  const UnifiedFortuneProfile({
    this.sajuProfile,
    this.sajuResult,
    this.tarotResult,
    this.faceResult,
    this.palmResult,
    this.compatibilityResult,
  });

  /// 로컬 PHASE1~4 만세력 엔진이 계산한 사주 원국+오행+신강신약+합충형파해
  /// 등 전체 상세 데이터. `lib/features/home/domain/manseryeok/` 소속.
  final SajuProfile? sajuProfile;

  /// [sajuProfile]을 레거시 [SajuResult] 형태로 옮긴 것(화면 호환용,
  /// 재계산 아님). 오케스트레이터는 주로 [sajuProfile]을 사용하지만,
  /// 일부 추출기가 레거시 필드(`fiveElementsCount` 등)를 참조할 때 쓴다.
  final SajuResult? sajuResult;

  /// 타로 Repository의 `getHistory()` 최신 1건(서버 영속 이력 우선, 실패
  /// 시 세션 로컬 이력으로 자동 폴백 — Repository 내부 정책 그대로 신뢰).
  final TarotResultModel? tarotResult;

  /// 관상 Repository의 `getHistory()` 최신 1건.
  final FaceResultModel? faceResult;

  /// 손금 Repository의 `getHistory()` 최신 1건.
  final PalmResultModel? palmResult;

  /// 궁합 Repository의 `getHistory()` 최신 1건.
  final CompatibilityResultModel? compatibilityResult;

  bool get hasSaju => sajuProfile != null;
  bool get hasTarot => tarotResult != null;
  bool get hasFace => faceResult != null;
  bool get hasPalm => palmResult != null;
  bool get hasCompatibility => compatibilityResult != null;

  /// 5개 문 중 몇 개가 채워져 있는지(진행도 표시 등에 사용 가능).
  int get filledDoorCount =>
      (hasSaju ? 1 : 0) +
      (hasTarot ? 1 : 0) +
      (hasFace ? 1 : 0) +
      (hasPalm ? 1 : 0) +
      (hasCompatibility ? 1 : 0);

  UnifiedFortuneProfile copyWith({
    SajuProfile? sajuProfile,
    SajuResult? sajuResult,
    TarotResultModel? tarotResult,
    FaceResultModel? faceResult,
    PalmResultModel? palmResult,
    CompatibilityResultModel? compatibilityResult,
  }) {
    return UnifiedFortuneProfile(
      sajuProfile: sajuProfile ?? this.sajuProfile,
      sajuResult: sajuResult ?? this.sajuResult,
      tarotResult: tarotResult ?? this.tarotResult,
      faceResult: faceResult ?? this.faceResult,
      palmResult: palmResult ?? this.palmResult,
      compatibilityResult: compatibilityResult ?? this.compatibilityResult,
    );
  }
}
