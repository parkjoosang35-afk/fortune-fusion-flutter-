import 'package:flutter/foundation.dart';

import '../../features/auth/domain/user_model.dart';
import '../../features/compatibility/data/compatibility_repository.dart';
import '../../features/compatibility/domain/compatibility_model.dart';
import '../../features/fortune/face/data/face_repository.dart';
import '../../features/fortune/face/domain/face_model.dart';
import '../../features/fortune/palm/data/palm_repository.dart';
import '../../features/fortune/palm/domain/palm_model.dart';
import '../../features/fortune/tarot/data/tarot_repository.dart';
import '../../features/fortune/tarot/domain/tarot_model.dart';
import '../../features/home/domain/jeontong_eighty_report_builder.dart';
import '../../features/home/domain/manseryeok/saju_profile.dart';
import '../../features/home/domain/saju_engine.dart' show SajuResult;
import '../../features/home/domain/user_profile_to_jeontong_adapter.dart';

/// [엔진 통합 지시문 STEP 3 §3] 오케스트레이터가 "구체 Repository 클래스"에
/// 직접 묶이지 않도록 분리하는 게이트웨이 인터페이스.
///
/// [설계 원칙]
/// - 이 인터페이스는 **기존 엔진을 재구현하지 않는다** — 모든 구현체는
///   이미 존재하는 TarotRepository/FaceRepository/PalmRepository/
///   CompatibilityRepository.getHistory()를 호출하거나, 이미 검증된 로컬
///   PHASE1~4 만세력 엔진([JeontongReportBuilder])을 호출할 뿐이다.
/// - "이력 API를 먼저 확인한다"(지시문 원칙) — [DefaultDoorEngineGateway]는
///   각 문의 `getHistory()`를 호출해 최신 1건을 가져온다. 새 분석을
///   트리거(예: FaceRepository.analyze())하지 않는다 — 오케스트레이터는
///   조회 전용이며, 신규 분석 실행은 각 기능 화면의 기존 플로우 책임이다.
/// - 테스트는 이 인터페이스의 Fake 구현체를 주입해 네트워크 없이 검증한다
///   (§7 테스트 요구사항 "Fake 게이트웨이로 각 조합 시뮬레이션").
abstract class DoorEngineGateway {
  /// 로그인 사용자의 생년월일시 기반 사주 원국을 계산해 반환한다. 로그인
  /// 사용자가 없거나 생년월일 정보가 없으면(프로필 미완성) null.
  /// (로컬 PHASE1~4 엔진 호출 — 서버 API 없음, §3 설계결정).
  ///
  /// [중복계산 개선 — 2026-엔진연결 STEP 1 §1 옵션 A] 이 메서드는
  /// [getSajuProfileAndResult]의 `.profile`만 꺼내 반환하는 하위호환용
  /// 래퍼로 유지된다(혹시 모를 외부 참조 대비, 삭제하지 않음). 신규
  /// 소비처는 [getSajuProfileAndResult]를 사용해 PHASE1~4 중복 실행을
  /// 피해야 한다.
  Future<SajuProfile?> getSajuProfile(UserModel? user);

  /// [getSajuProfile]과 동일한 입력으로 계산된 레거시 [SajuResult] 형태
  /// (사주 화면 일부가 참조하는 `fiveElementsCount` 등 호환용).
  ///
  /// [중복계산 개선 — 2026-엔진연결 STEP 1 §1 옵션 A] 이 메서드 역시
  /// [getSajuProfileAndResult]의 `.result`만 꺼내 반환하는 하위호환용
  /// 래퍼로 유지된다(삭제하지 않음). 신규 소비처는
  /// [getSajuProfileAndResult]를 사용해야 한다.
  Future<SajuResult?> getSajuResult(UserModel? user);

  /// [중복계산 개선 — 2026-엔진연결 STEP 1 §1 옵션 A 핵심 신규 메서드]
  /// [getSajuProfile]+[getSajuResult]를 각각 독립 호출하면 동일한 입력으로
  /// `JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4()`(PHASE1~4
  /// 전체)가 **2회** 실행되는 문제가 있었다. 이 메서드는 그 함수를 **1회만**
  /// 호출해 반환된 튜플(`{saju, profile}`)을 그대로 노출한다 — 계산 로직은
  /// 한 글자도 바뀌지 않았고, 단지 호출 횟수만 1회로 줄어든다.
  ///
  /// [FortuneOrchestrator.buildProfile]이 사주 데이터를 조회할 때는 반드시
  /// 이 메서드를 사용해야 한다(기존 두 메서드를 각각 호출하지 않는다).
  Future<({SajuProfile? profile, SajuResult? result})> getSajuProfileAndResult(
    UserModel? user,
  );

  /// 타로 이력 중 가장 최근 1건(없으면 null).
  Future<TarotResultModel?> getLatestTarot();

  /// 관상 이력 중 가장 최근 1건(없으면 null).
  Future<FaceResultModel?> getLatestFace();

  /// 손금 이력 중 가장 최근 1건(없으면 null).
  Future<PalmResultModel?> getLatestPalm();

  /// 궁합 이력 중 가장 최근 1건(없으면 null).
  Future<CompatibilityResultModel?> getLatestCompatibility();
}

/// [DoorEngineGateway]의 실사용 구현체 — 실제 Repository/로컬 엔진을
/// 호출한다. 생성자 주입으로 각 Repository 인스턴스를 받는다(app.dart의
/// Provider가 이미 들고 있는 동일 인스턴스를 그대로 넘겨 재사용 —
/// 새 인스턴스를 만들지 않음, 상태/캐시 이중화 방지).
class DefaultDoorEngineGateway implements DoorEngineGateway {
  DefaultDoorEngineGateway({
    required TarotRepository tarotRepository,
    required FaceRepository faceRepository,
    required PalmRepository palmRepository,
    required CompatibilityRepository compatibilityRepository,
  }) : _tarotRepository = tarotRepository,
       _faceRepository = faceRepository,
       _palmRepository = palmRepository,
       _compatibilityRepository = compatibilityRepository;

  final TarotRepository _tarotRepository;
  final FaceRepository _faceRepository;
  final PalmRepository _palmRepository;
  final CompatibilityRepository _compatibilityRepository;

  @override
  Future<SajuProfile?> getSajuProfile(UserModel? user) async {
    final built = await getSajuProfileAndResult(user);
    return built.profile;
  }

  @override
  Future<SajuResult?> getSajuResult(UserModel? user) async {
    final built = await getSajuProfileAndResult(user);
    return built.result;
  }

  @override
  Future<({SajuProfile? profile, SajuResult? result})>
  getSajuProfileAndResult(UserModel? user) async {
    if (user == null) return (profile: null, result: null);
    final jeontongInput = userModelToJeontongInput(user);
    if (jeontongInput == null) return (profile: null, result: null);
    try {
      final kst = jeontongInput.birthDateTimeUtc.add(const Duration(hours: 9));
      final sajuGender = jeontongInput.gender == 'F' ? 'female' : 'male';
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: sajuGender,
        isLunar: jeontongInput.isLunar,
        isLeapMonth: jeontongInput.effectiveIsLeapMonth,
        referenceDate: DateTime.now(),
      );
      return (profile: built.profile, result: built.saju);
    } catch (e) {
      debugPrint(
        '[DefaultDoorEngineGateway] [getSajuProfileAndResult] 예외 -> $e',
      );
      return (profile: null, result: null);
    }
  }

  @override
  Future<TarotResultModel?> getLatestTarot() async {
    final result = await _tarotRepository.getHistory();
    if (!result.success || result.data == null || result.data!.isEmpty) {
      return null;
    }
    return result.data!.first;
  }

  @override
  Future<FaceResultModel?> getLatestFace() async {
    final result = await _faceRepository.getHistory();
    if (!result.success || result.data == null || result.data!.isEmpty) {
      return null;
    }
    return result.data!.first;
  }

  @override
  Future<PalmResultModel?> getLatestPalm() async {
    final result = await _palmRepository.getHistory();
    if (!result.success || result.data == null || result.data!.isEmpty) {
      return null;
    }
    return result.data!.first;
  }

  @override
  Future<CompatibilityResultModel?> getLatestCompatibility() async {
    final result = await _compatibilityRepository.getHistory();
    if (!result.success || result.data == null || result.data!.isEmpty) {
      return null;
    }
    return result.data!.first;
  }
}
