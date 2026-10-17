// [중복계산 개선 — 2026-엔진연결 승인지시 §1 옵션 A] FortuneOrchestrator가
// 사주 데이터를 조회할 때 PHASE1~4(만세력 전체 계산)가 2회 중복 실행되던
// 문제를 해소하기 위해 [DoorEngineGateway]에 신규 메서드
// `getSajuProfileAndResult()`를 추가했다(1회 호출로 `{profile, result}`
// 튜플을 동시에 반환). 이 테스트는 다음을 검증한다:
//
//   1) [동일성 검증] 기존 방식(getSajuProfile()+getSajuResult() 각각 호출)과
//      신규 방식(getSajuProfileAndResult() 1회 호출)의 결과가 "완전히
//      동일"해야 한다 — 계산 로직이 바뀐 게 아니라 호출 경로만 바뀐 것이기
//      때문이다. 비교는 toJson()류 메서드가 없으므로 필드 단위 수동
//      비교(deep comparison)로 수행한다.
//   2) [null 입력 처리 일관성] user가 null이거나 생년월일 정보가 없을 때
//      두 방식 모두 동일하게 null을 반환해야 한다.
//   3) [호출 횟수 계측] FortuneOrchestrator.buildProfile()이 실제로
//      getSajuProfileAndResult()를 1회만 호출하고, 레거시
//      getSajuProfile()/getSajuResult()는 전혀 호출하지 않는지 Fake
//      게이트웨이로 계측한다 — "중복이 실제로 사라졌는지"를 코드 리뷰가
//      아니라 테스트로 증명한다.
//   4) [결정론성 재확인] 같은 입력을 여러 번 호출해도 항상 같은 결과가
//      나오는지(PHASE1~4 엔진 자체의 성질이 이번 리팩터링으로 깨지지
//      않았는지) 재확인한다.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/orchestrator/door_engine_gateway.dart';
import 'package:flutter_app/core/orchestrator/fortune_orchestrator.dart';
import 'package:flutter_app/features/auth/domain/user_model.dart';
import 'package:flutter_app/features/compatibility/data/compatibility_repository.dart';
import 'package:flutter_app/features/compatibility/domain/compatibility_model.dart';
import 'package:flutter_app/features/fortune/face/data/face_repository.dart';
import 'package:flutter_app/features/fortune/face/domain/face_model.dart';
import 'package:flutter_app/features/fortune/palm/data/palm_repository.dart';
import 'package:flutter_app/features/fortune/palm/domain/palm_model.dart';
import 'package:flutter_app/features/fortune/tarot/data/tarot_repository.dart';
import 'package:flutter_app/features/fortune/tarot/domain/tarot_model.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';
import 'package:flutter_app/features/home/domain/saju_engine.dart';

/// 사주 계산이 가능한 로그인 사용자(1990-03-15 08:30 남, 양력) —
/// 기존 `cross_check_cta_navigation_test.dart`의 `_sajuCapableUserJson()`과
/// 동일한 생년월일을 재사용해(§7 테스트 요구사항과 일치) 기존 자산과의
/// 비교 가능성을 유지한다.
UserModel _sajuCapableUser() => const UserModel(
  id: 'user_dedup_test_1',
  nickname: '중복계산검증유저',
  birthDate: '1990-03-15',
  birthTime: '08:30',
  isLunar: false,
  isLeapMonth: false,
  birthTimeUnknown: false,
  gender: 'M',
);

/// 두 번째 테스트 케이스(여성, 음력 아님, 다른 생년월일시) — 단일
/// 케이스만으로는 "우연히 일치"할 가능성을 배제하기 위해 추가.
UserModel _sajuCapableUserB() => const UserModel(
  id: 'user_dedup_test_2',
  nickname: '중복계산검증유저B',
  birthDate: '1995-11-02',
  birthTime: '22:10',
  isLunar: false,
  isLeapMonth: false,
  birthTimeUnknown: false,
  gender: 'F',
);

/// 생년월일 정보가 없는 사용자(프로필 미완성) — null 처리 일관성 검증용.
UserModel _incompleteUser() =>
    const UserModel(id: 'user_incomplete', nickname: '미완성유저');

void main() {
  group('[중복계산 개선 §1] DefaultDoorEngineGateway 동일성 검증', () {
    test(
      '동일 입력(personA)에 대해 '
      'getSajuProfile()+getSajuResult() 개별 호출 결과와 '
      'getSajuProfileAndResult() 1회 호출 결과가 완전히 동일하다',
      () async {
        final gatewayLegacy = DefaultDoorEngineGateway(
          tarotRepository: TarotRepository(),
          faceRepository: FaceRepository(),
          palmRepository: PalmRepository(),
          compatibilityRepository: CompatibilityRepository(),
        );
        final gatewayNew = DefaultDoorEngineGateway(
          tarotRepository: TarotRepository(),
          faceRepository: FaceRepository(),
          palmRepository: PalmRepository(),
          compatibilityRepository: CompatibilityRepository(),
        );

        final user = _sajuCapableUser();

        // 기존 방식: 두 메서드를 각각 독립 호출(리팩터링 전 buildProfile()과
        // 동일한 호출 패턴을 재현).
        final legacyProfile = await gatewayLegacy.getSajuProfile(user);
        final legacyResult = await gatewayLegacy.getSajuResult(user);

        // 신규 방식: 1회 호출로 튜플을 동시에 획득.
        final combined = await gatewayNew.getSajuProfileAndResult(user);

        expect(legacyProfile, isNotNull);
        expect(combined.profile, isNotNull);
        expect(legacyResult, isNotNull);
        expect(combined.result, isNotNull);

        _expectSameSajuProfile(legacyProfile!, combined.profile!);
        _expectSameSajuResult(legacyResult!, combined.result!);
      },
    );

    test(
      '두 번째 생년월일시(personB, 여성)에서도 동일성이 유지된다 '
      '(단일 케이스 우연 일치 가능성 배제)',
      () async {
        final gatewayLegacy = DefaultDoorEngineGateway(
          tarotRepository: TarotRepository(),
          faceRepository: FaceRepository(),
          palmRepository: PalmRepository(),
          compatibilityRepository: CompatibilityRepository(),
        );
        final gatewayNew = DefaultDoorEngineGateway(
          tarotRepository: TarotRepository(),
          faceRepository: FaceRepository(),
          palmRepository: PalmRepository(),
          compatibilityRepository: CompatibilityRepository(),
        );

        final user = _sajuCapableUserB();

        final legacyProfile = await gatewayLegacy.getSajuProfile(user);
        final legacyResult = await gatewayLegacy.getSajuResult(user);
        final combined = await gatewayNew.getSajuProfileAndResult(user);

        expect(legacyProfile, isNotNull);
        expect(combined.profile, isNotNull);
        expect(legacyResult, isNotNull);
        expect(combined.result, isNotNull);

        _expectSameSajuProfile(legacyProfile!, combined.profile!);
        _expectSameSajuResult(legacyResult!, combined.result!);
      },
    );

    test('user가 null이면 세 메서드 모두 동일하게 null을 반환한다', () async {
      final gateway = DefaultDoorEngineGateway(
        tarotRepository: TarotRepository(),
        faceRepository: FaceRepository(),
        palmRepository: PalmRepository(),
        compatibilityRepository: CompatibilityRepository(),
      );

      expect(await gateway.getSajuProfile(null), isNull);
      expect(await gateway.getSajuResult(null), isNull);
      final combined = await gateway.getSajuProfileAndResult(null);
      expect(combined.profile, isNull);
      expect(combined.result, isNull);
    });

    test('생년월일 정보가 없는 사용자(프로필 미완성)는 세 메서드 모두 null을 반환한다', () async {
      final gateway = DefaultDoorEngineGateway(
        tarotRepository: TarotRepository(),
        faceRepository: FaceRepository(),
        palmRepository: PalmRepository(),
        compatibilityRepository: CompatibilityRepository(),
      );
      final user = _incompleteUser();

      expect(await gateway.getSajuProfile(user), isNull);
      expect(await gateway.getSajuResult(user), isNull);
      final combined = await gateway.getSajuProfileAndResult(user);
      expect(combined.profile, isNull);
      expect(combined.result, isNull);
    });

    test(
      '[결정론성 재확인] 같은 입력으로 getSajuProfileAndResult()를 '
      '두 번 호출해도 완전히 동일한 결과가 나온다',
      () async {
        final gateway = DefaultDoorEngineGateway(
          tarotRepository: TarotRepository(),
          faceRepository: FaceRepository(),
          palmRepository: PalmRepository(),
          compatibilityRepository: CompatibilityRepository(),
        );
        final user = _sajuCapableUser();

        final first = await gateway.getSajuProfileAndResult(user);
        final second = await gateway.getSajuProfileAndResult(user);

        _expectSameSajuProfile(first.profile!, second.profile!);
        _expectSameSajuResult(first.result!, second.result!);
      },
    );
  });

  group('[중복계산 개선 §1] FortuneOrchestrator 호출 횟수 계측(Fake 게이트웨이)', () {
    test(
      'buildProfile()은 getSajuProfileAndResult()를 정확히 1회만 호출하고, '
      '레거시 getSajuProfile()/getSajuResult()는 전혀 호출하지 않는다',
      () async {
        final fakeGateway = _CallCountingGateway();
        final orchestrator = FortuneOrchestrator(gateway: fakeGateway);

        final profile = await orchestrator.buildProfile(_sajuCapableUser());

        expect(
          fakeGateway.getSajuProfileAndResultCallCount,
          1,
          reason:
              'buildProfile()은 PHASE1~4 중복 실행을 피하기 위해 '
              'getSajuProfileAndResult()를 정확히 1회만 호출해야 한다.',
        );
        expect(
          fakeGateway.getSajuProfileCallCount,
          0,
          reason: '레거시 getSajuProfile()은 buildProfile() 내부에서 '
              '더 이상 직접 호출되면 안 된다(하위호환용으로만 남겨둔 메서드).',
        );
        expect(
          fakeGateway.getSajuResultCallCount,
          0,
          reason: '레거시 getSajuResult()은 buildProfile() 내부에서 '
              '더 이상 직접 호출되면 안 된다(하위호환용으로만 남겨둔 메서드).',
        );

        // 사주 데이터가 Fake가 제공한 값 그대로 UnifiedFortuneProfile에
        // 반영되는지도 함께 확인(배선이 올바른지).
        expect(profile.sajuProfile, fakeGateway.fixedProfile);
        expect(profile.sajuResult, fakeGateway.fixedResult);
      },
    );

    test('buildProfile()은 여전히 타로/관상/손금/궁합 4개 getHistory 조회를 각각 1회씩 수행한다', () async {
      final fakeGateway = _CallCountingGateway();
      final orchestrator = FortuneOrchestrator(gateway: fakeGateway);

      await orchestrator.buildProfile(_sajuCapableUser());

      expect(fakeGateway.getLatestTarotCallCount, 1);
      expect(fakeGateway.getLatestFaceCallCount, 1);
      expect(fakeGateway.getLatestPalmCallCount, 1);
      expect(fakeGateway.getLatestCompatibilityCallCount, 1);
    });
  });
}

/// [SajuProfile 필드 단위 동일성 검증] SajuProfile에는 `==`/`toJson()`이
/// 구현되어 있지 않으므로(상속된 `Object.==`는 참조 동일성만 비교),
/// 교차검증 규칙(cross_check_rules.dart)이 실제로 읽는 필드와 화면
/// 렌더링에 쓰이는 핵심 필드를 전부 수동으로 비교한다.
void _expectSameSajuProfile(SajuProfile a, SajuProfile b) {
  // 8글자(사주 원국) 동일성.
  expect(a.yearPillar.hanja, b.yearPillar.hanja);
  expect(a.monthPillar.hanja, b.monthPillar.hanja);
  expect(a.dayPillar.hanja, b.dayPillar.hanja);
  expect(a.hourPillar.hanja, b.hourPillar.hanja);
  expect(a.yearPillar.kr, b.yearPillar.kr);
  expect(a.monthPillar.kr, b.monthPillar.kr);
  expect(a.dayPillar.kr, b.dayPillar.kr);
  expect(a.hourPillar.kr, b.hourPillar.kr);

  expect(a.solarDate, b.solarDate);
  expect(a.lunarDate, b.lunarDate);
  expect(a.lunarLeapMonth, b.lunarLeapMonth);

  // Phase 2: 오행/지장간/십신/십이운성/합충형파해/신살.
  expect(a.fiveElements?.totalCount, b.fiveElements?.totalCount);
  expect(a.fiveElements?.stemCount, b.fiveElements?.stemCount);
  expect(a.fiveElements?.branchCount, b.fiveElements?.branchCount);
  expect(a.fiveElements?.dominant, b.fiveElements?.dominant);
  expect(a.fiveElements?.deficient, b.fiveElements?.deficient);
  expect(a.tenGods, b.tenGods);
  expect(a.twelveStages?.toMap(), b.twelveStages?.toMap());
  expect(a.relationships?.length, b.relationships?.length);
  for (var i = 0; i < (a.relationships?.length ?? 0); i++) {
    expect(a.relationships![i].type, b.relationships![i].type);
    expect(a.relationships![i].characters, b.relationships![i].characters);
  }
  expect(a.sinsal?.map((s) => s.id).toList(), b.sinsal?.map((s) => s.id).toList());

  // Phase 3: 신강신약/용희기구.
  expect(a.strength?.verdict, b.strength?.verdict);
  expect(a.strength?.score, b.strength?.score);
  expect(a.yongsin?.yongsin, b.yongsin?.yongsin);
  expect(a.yongsin?.heesin, b.yongsin?.heesin);
  expect(a.yongsin?.gisin, b.yongsin?.gisin);
  expect(a.yongsin?.gusin, b.yongsin?.gusin);
  expect(a.yongsin?.method, b.yongsin?.method);

  // Phase 4: 대운/세운/월운.
  expect(a.daewoon?.length, b.daewoon?.length);
  for (var i = 0; i < (a.daewoon?.length ?? 0); i++) {
    expect(a.daewoon![i].pillar.hanja, b.daewoon![i].pillar.hanja);
    expect(a.daewoon![i].startAge, b.daewoon![i].startAge);
  }
  expect(a.sewoon?.length, b.sewoon?.length);
  for (var i = 0; i < (a.sewoon?.length ?? 0); i++) {
    expect(a.sewoon![i].pillar.hanja, b.sewoon![i].pillar.hanja);
    expect(a.sewoon![i].year, b.sewoon![i].year);
  }
  expect(a.wolwoon?.length, b.wolwoon?.length);
}

/// [SajuResult 필드 단위 동일성 검증] 레거시 호환 필드까지 전부 비교한다.
void _expectSameSajuResult(SajuResult a, SajuResult b) {
  expect(a.gender, b.gender);
  expect(a.birthSolar, b.birthSolar);
  expect(a.birthLunar, b.birthLunar);
  expect(a.dayMaster.gan, b.dayMaster.gan);
  expect(a.dayMaster.element, b.dayMaster.element);
  expect(a.dayMasterStrength, b.dayMasterStrength);
  expect(a.fiveElementsCount, b.fiveElementsCount);
  expect(a.tenGods, b.tenGods);
  expect(a.sinsal, b.sinsal);
  expect(a.gongmang, b.gongmang);
  expect(a.currentAge, b.currentAge);
  expect(a.luckPillars.length, b.luckPillars.length);
  for (var i = 0; i < a.luckPillars.length; i++) {
    expect(a.luckPillars[i].ganZhi, b.luckPillars[i].ganZhi);
    expect(a.luckPillars[i].startAge, b.luckPillars[i].startAge);
  }
  expect(a.currentLuck?.ganZhi, b.currentLuck?.ganZhi);
  for (final key in a.pillars.keys) {
    expect(a.pillars[key]?.gan, b.pillars[key]?.gan);
    expect(a.pillars[key]?.zhi, b.pillars[key]?.zhi);
  }
}

/// [호출 횟수 계측 전용 Fake] 실제 PHASE1~4 계산은 수행하지 않고, 각
/// 메서드가 몇 번 호출됐는지만 센다 — "중복 계산이 실제로 제거됐는지"를
/// FortuneOrchestrator.buildProfile() 레벨에서 증명하기 위함.
class _CallCountingGateway implements DoorEngineGateway {
  int getSajuProfileCallCount = 0;
  int getSajuResultCallCount = 0;
  int getSajuProfileAndResultCallCount = 0;
  int getLatestTarotCallCount = 0;
  int getLatestFaceCallCount = 0;
  int getLatestPalmCallCount = 0;
  int getLatestCompatibilityCallCount = 0;

  final SajuProfile fixedProfile = _dummySajuProfile();
  final SajuResult fixedResult = _dummySajuResult();

  @override
  Future<SajuProfile?> getSajuProfile(UserModel? user) async {
    getSajuProfileCallCount++;
    return fixedProfile;
  }

  @override
  Future<SajuResult?> getSajuResult(UserModel? user) async {
    getSajuResultCallCount++;
    return fixedResult;
  }

  @override
  Future<({SajuProfile? profile, SajuResult? result})> getSajuProfileAndResult(
    UserModel? user,
  ) async {
    getSajuProfileAndResultCallCount++;
    return (profile: fixedProfile, result: fixedResult);
  }

  @override
  Future<TarotResultModel?> getLatestTarot() async {
    getLatestTarotCallCount++;
    return null;
  }

  @override
  Future<FaceResultModel?> getLatestFace() async {
    getLatestFaceCallCount++;
    return null;
  }

  @override
  Future<PalmResultModel?> getLatestPalm() async {
    getLatestPalmCallCount++;
    return null;
  }

  @override
  Future<CompatibilityResultModel?> getLatestCompatibility() async {
    getLatestCompatibilityCallCount++;
    return null;
  }
}

Pillar _dummyPillar() => const Pillar(
  stemHanja: '甲',
  branchHanja: '子',
  stemKr: '갑',
  branchKr: '자',
  stemElement: '목',
  stemYinYang: '양',
  branchElement: '목',
  branchYinYang: '양',
  jiaZiIndex: 0,
);

SajuProfile _dummySajuProfile() => SajuProfile(
  engineVersion: 'dedup-test-v1',
  birthInfo: const BirthInfo(
    calendarType: CalendarInputType.solar,
    year: 1990,
    month: 3,
    day: 15,
    hour: 8,
    minute: 30,
    isLeapMonth: false,
    gender: 'male',
  ),
  solarDate: '1990-03-15 08:30',
  lunarDate: '1990-02-19',
  lunarLeapMonth: false,
  utcOffsetMinutes: 540,
  ziHourPolicy: ZiHourPolicy.lateZiSameDay,
  daewoonStartPrecision: DaewoonStartPrecision.traditionalApprox,
  yearPillar: _dummyPillar(),
  monthPillar: _dummyPillar(),
  dayPillar: _dummyPillar(),
  hourPillar: _dummyPillar(),
);

SajuResult _dummySajuResult() => SajuResult(
  gender: 'male',
  birthSolar: '1990-03-15 08:30',
  birthLunar: '1990-02-19',
  pillars: const {
    'year': SajuPillar(gan: '갑', zhi: '자', kr: '갑자', element: '목-목'),
    'month': SajuPillar(gan: '갑', zhi: '자', kr: '갑자', element: '목-목'),
    'day': SajuPillar(gan: '갑', zhi: '자', kr: '갑자', element: '목-목'),
    'hour': SajuPillar(gan: '갑', zhi: '자', kr: '갑자', element: '목-목'),
  },
  dayMaster: const SajuDayMaster(
    gan: '갑',
    kr: '갑목',
    element: '목',
    yinYang: '양',
    image: '큰 나무',
  ),
  dayMasterStrength: '신강',
  fiveElementsCount: const {'목': 4, '화': 0, '토': 0, '금': 0, '수': 0},
  tenGods: const {},
  sinsal: const [],
  gongmang: '',
  luckPillars: const [],
  currentAge: 34,
  currentLuck: null,
);
