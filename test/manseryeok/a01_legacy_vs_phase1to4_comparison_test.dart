// [j7 · A01 신규 엔진 이전] 레거시(SajuEngine.calculate) vs 신규
// (PHASE1~4 → sajuResultFromProfile 어댑터) A01(평생 총운) 결과 비교 테스트.
//
// 사용자 지시(§2) 대응 — 단순 "테스트 통과 여부"가 아니라 다음 전부를
// 나란히 출력/비교한다:
//   1) 사주 8글자(년/월/일/시주)
//   2) 일간
//   3) 오행(개수)
//   4) 십신(7키)
//   5) 대운(간지/시작연령/시작연도)
//   6) 신강신약(dayMasterStrength)
//   7) 용신/희신/기신/구신 (신규 전용 — 레거시엔 없음, PHASE3 결과만 출력)
//   8) A01 판단에 실제 쓰이는 계산값(dayMasterAnalysis.title/dominant 십신 등)
//   9) 최종 A01 결과(headline/coreNature/personality/strengths/weaknesses/
//      fiveElements/lifeTheme/summary)
//  10) 결과 문구 전체
//
// [골든 데이터와 동일 입력] test/fixtures/jeontong_inputs.dart 의 3개 seed
// 유저(A/B/C)를 그대로 사용해, 골든 JSON의 현재 A01 값과 1:1 대조 가능하게
// 한다. 이 테스트는 "실패 여부"보다 "차이를 눈으로 확인하기 위한 보고서
// 생성"이 목적이므로, dayMasterStrength/headline 등이 달라져도 즉시 fail로
// 처리하지 않고 print로 상세 로그를 남긴 뒤, 구조적으로 필요한 것만
// expect 한다(예외 없이 실행되는지, 필드가 비어있지 않은지).
import 'package:flutter_app/features/home/domain/jeontong_eighty_calculator.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase2_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase3_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase4_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_result_adapter.dart';
import 'package:flutter_app/features/home/domain/saju_engine.dart' as legacy;
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/domain/saju_life_modules.dart';
import 'package:flutter_test/flutter_test.dart';

/// 골든 테스트와 동일한 기준일(kFixedDate).
final _kFixedDate = DateTime.utc(2026, 8, 13);

/// test/fixtures/jeontong_inputs.dart 의 3개 seed 유저를 이 테스트 파일
/// 안에서 그대로 재현한다(픽스처 파일을 import 하면 test/ 하위 다른 test
/// 파일과 결합도가 생기므로, 값만 복사해 독립적으로 유지 — 값 자체는
/// jeontong_inputs.dart와 100% 동일해야 한다).
class _SeedUser {
  const _SeedUser({
    required this.userId,
    required this.birthDateTimeUtc,
    required this.isLunar,
    required this.gender,
  });
  final String userId;
  final DateTime birthDateTimeUtc;
  final bool isLunar;
  final String gender; // 'M' | 'F'
}

final _seedUsers = <_SeedUser>[
  _SeedUser(
    userId: 'seed-user-A',
    birthDateTimeUtc: DateTime.utc(1972, 2, 12, 17, 0, 0),
    isLunar: false,
    gender: 'M',
  ),
  _SeedUser(
    userId: 'seed-user-B',
    birthDateTimeUtc: DateTime.utc(1990, 6, 15, 3, 0, 0),
    isLunar: false,
    gender: 'F',
  ),
  _SeedUser(
    userId: 'seed-user-C',
    birthDateTimeUtc: DateTime.utc(2005, 11, 30, 21, 0, 0),
    isLunar: false,
    gender: 'F',
  ),
];

/// report_builder.dart의 `_tryBuildRealReport()`와 동일한 규약 —
/// birthDateTimeUtc(UTC 저장값) + 9시간 = KST 벽시계 시각.
DateTime _toKst(DateTime utc) => utc.add(const Duration(hours: 9));

String _legacyGender(String mf) => mf == 'F' ? 'female' : 'male';

/// 레거시 경로 전체 실행 결과 묶음.
class _LegacyBundle {
  _LegacyBundle(this.saju, this.interp, this.a01);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final LifeTotalResult a01;
}

/// 신규(PHASE1~4 + 어댑터) 경로 전체 실행 결과 묶음.
class _NewBundle {
  _NewBundle(this.profile, this.saju, this.interp, this.a01);
  final SajuProfile profile;
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final LifeTotalResult a01;
}

_LegacyBundle _runLegacy(_SeedUser u, DateTime referenceDate) {
  final kst = _toKst(u.birthDateTimeUtc);
  final saju = legacy.SajuEngine.calculate(
    year: kst.year,
    month: kst.month,
    day: kst.day,
    hour: kst.hour,
    minute: kst.minute,
    gender: _legacyGender(u.gender),
    isLunar: u.isLunar,
    referenceDate: referenceDate,
  );
  final interp = SajuInterpreter.fullInterpretation(saju);
  final a01 = getLifeTotal(interp);
  return _LegacyBundle(saju, interp, a01);
}

_NewBundle _runNew(_SeedUser u, DateTime referenceDate) {
  final kst = _toKst(u.birthDateTimeUtc);
  final withCore = ManseryeokCoreEngine.buildProfileWithCore(
    year: kst.year,
    month: kst.month,
    day: kst.day,
    hour: kst.hour,
    minute: kst.minute,
    gender: _legacyGender(u.gender),
    calendarType: u.isLunar ? CalendarInputType.lunar : CalendarInputType.solar,
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
  final interp = SajuInterpreter.fullInterpretation(saju);
  final a01 = getLifeTotal(interp);
  return _NewBundle(p4, saju, interp, a01);
}

String _pillarsStr(Map<String, legacy.SajuPillar> pillars) =>
    '${pillars['year']!.kr}년 ${pillars['month']!.kr}월 '
    '${pillars['day']!.kr}일 ${pillars['hour']!.kr}시';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
  });

  group('[j7·A01] 레거시 vs 신규(PHASE1~4+어댑터) 전체 비교 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 8글자/일간/오행/십신/대운/신강신약/용희기구/A01 전체 비교', () {
        final legacyB = _runLegacy(u, _kFixedDate);
        final newB = _runNew(u, _kFixedDate);

        // ignore: avoid_print
        print('\n========== ${u.userId} ==========');

        // ── 1) 사주 8글자 ──
        final legacyPillars = _pillarsStr(legacyB.saju.pillars);
        final newPillars = _pillarsStr(newB.saju.pillars);
        // ignore: avoid_print
        print('[8글자] legacy=$legacyPillars');
        // ignore: avoid_print
        print('[8글자] new   =$newPillars');
        expect(newPillars, legacyPillars, reason: '${u.userId} 8글자는 100% 동일해야 함(만세력 계산 자체는 동일 기준)');

        // ── 2) 일간 ──
        // ignore: avoid_print
        print('[일간] legacy=${legacyB.saju.dayMaster.gan}(${legacyB.saju.dayMaster.kr}, ${legacyB.saju.dayMaster.element}/${legacyB.saju.dayMaster.yinYang})');
        // ignore: avoid_print
        print('[일간] new   =${newB.saju.dayMaster.gan}(${newB.saju.dayMaster.kr}, ${newB.saju.dayMaster.element}/${newB.saju.dayMaster.yinYang})');
        expect(newB.saju.dayMaster.gan, legacyB.saju.dayMaster.gan, reason: '${u.userId} 일간 불일치');

        // ── 3) 오행 ──
        // ignore: avoid_print
        print('[오행] legacy=${legacyB.saju.fiveElementsCount}');
        // ignore: avoid_print
        print('[오행] new   =${newB.saju.fiveElementsCount}');
        expect(newB.saju.fiveElementsCount, legacyB.saju.fiveElementsCount, reason: '${u.userId} 오행 총량 불일치');

        // ── 4) 십신(7키) ──
        // ignore: avoid_print
        print('[십신] legacy=${legacyB.saju.tenGods}');
        // ignore: avoid_print
        print('[십신] new   =${newB.saju.tenGods}');
        expect(newB.saju.tenGods, legacyB.saju.tenGods, reason: '${u.userId} 십신 불일치');

        // ── 5) 대운 ──
        final legacyReal = legacyB.saju.luckPillars.where((lp) => lp.ganZhi.isNotEmpty).toList();
        // ignore: avoid_print
        print('[대운] legacy(${legacyReal.length}개)=${legacyReal.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
        // ignore: avoid_print
        print('[대운] new(${newB.saju.luckPillars.length}개)=${newB.saju.luckPillars.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
        for (var i = 0; i < legacyReal.length; i++) {
          expect(newB.saju.luckPillars[i].ganZhi, legacyReal[i].ganZhi, reason: '${u.userId} 대운[$i] 간지 불일치');
        }

        // ── 6) 신강신약(dayMasterStrength) — 핵심 비교 포인트 ──
        final strengthSame = newB.saju.dayMasterStrength == legacyB.saju.dayMasterStrength;
        // ignore: avoid_print
        print('[신강신약] legacy=${legacyB.saju.dayMasterStrength}');
        // ignore: avoid_print
        print('[신강신약] new   =${newB.saju.dayMasterStrength}  (${strengthSame ? "동일" : "★ 다름 ★"})');
        if (newB.profile.strength != null) {
          final s = newB.profile.strength!;
          // ignore: avoid_print
          print('[신강신약·PHASE3 상세] score=${s.score.toStringAsFixed(3)} '
              'monthOrder=${s.monthOrderScore} root=${s.rootScore} '
              'support=${s.supportScore} control=${s.controlScore} drain=${s.drainScore}');
        }

        // ── 7) 용신/희신/기신/구신 (신규 전용) ──
        if (newB.profile.yongsin != null) {
          final y = newB.profile.yongsin!;
          // ignore: avoid_print
          print('[용희기구·신규전용] method=${y.method} 용신=${y.yongsin} 희신=${y.heesin} '
              '기신=${y.gisin} 구신=${y.gusin}');
          // ignore: avoid_print
          print('[용희기구·근거] ${y.reasoning}');
        }

        // ── 8) A01 판단에 실제 사용되는 계산값 ──
        // ignore: avoid_print
        print('[A01계산값] legacy dayMasterAnalysis.title=${legacyB.interp.dayMasterAnalysis.title}');
        // ignore: avoid_print
        print('[A01계산값] new    dayMasterAnalysis.title=${newB.interp.dayMasterAnalysis.title}');
        // ignore: avoid_print
        print('[A01계산값] legacy dominant십신=${legacyB.interp.tenGodsAnalysis.dominantName}'
            '(${legacyB.interp.tenGodsAnalysis.dominantCount}개)');
        // ignore: avoid_print
        print('[A01계산값] new    dominant십신=${newB.interp.tenGodsAnalysis.dominantName}'
            '(${newB.interp.tenGodsAnalysis.dominantCount}개)');
        final dominantSame =
            newB.interp.tenGodsAnalysis.dominantName == legacyB.interp.tenGodsAnalysis.dominantName;
        // 십신 7키가 100% 동일함을 이미 확인했으므로(위 4번), dominant 십신도
        // 같아야 정상이다 — 만약 다르면 tenGodsAnalysis 집계 로직 자체의
        // 문제이지 PHASE1~4 계산값의 문제가 아니므로 반드시 표시한다.
        // ignore: avoid_print
        print('[A01계산값] dominant십신 동일여부=$dominantSame');

        // ── 9) 최종 A01 결과 ──
        // ignore: avoid_print
        print('[A01·headline] legacy=${legacyB.a01.headline}');
        // ignore: avoid_print
        print('[A01·headline] new   =${newB.a01.headline}');
        // ignore: avoid_print
        print('[A01·coreNature] legacy=${legacyB.a01.coreNature}');
        // ignore: avoid_print
        print('[A01·coreNature] new   =${newB.a01.coreNature}');
        // ignore: avoid_print
        print('[A01·lifeTheme] legacy=${legacyB.a01.lifeTheme}');
        // ignore: avoid_print
        print('[A01·lifeTheme] new   =${newB.a01.lifeTheme}');
        // ignore: avoid_print
        print('[A01·strengths] legacy=${legacyB.a01.strengths}');
        // ignore: avoid_print
        print('[A01·strengths] new   =${newB.a01.strengths}');
        // ignore: avoid_print
        print('[A01·weaknesses] legacy=${legacyB.a01.weaknesses}');
        // ignore: avoid_print
        print('[A01·weaknesses] new   =${newB.a01.weaknesses}');

        // ── 10) 결과 문구(summary) 전체 ──
        // ignore: avoid_print
        print('[A01·summary] legacy=${legacyB.a01.summary}');
        // ignore: avoid_print
        print('[A01·summary] new   =${newB.a01.summary}');

        final headlineSame = newB.a01.headline == legacyB.a01.headline;
        final summarySame = newB.a01.summary == legacyB.a01.summary;
        // ignore: avoid_print
        print('[결론] headline동일=$headlineSame summary동일=$summarySame '
            '(dayMasterStrength동일=$strengthSame) → '
            '${!strengthSame && (!headlineSame || !summarySame) ? "dayMasterStrength 차이가 A01 문구에 실제 영향을 줌" : (strengthSame && headlineSame && summarySame ? "완전 일치" : "다른 원인으로 차이 발생 - 확인 필요")}');

        // ── 구조적 안전성만 강제(문구 1:1 동일성은 요구하지 않음 — §3 원칙) ──
        expect(newB.a01.headline, isNotEmpty);
        expect(newB.a01.summary, isNotEmpty);
        expect(newB.a01.coreNature, isNotEmpty);
        expect(newB.a01.strengths, isNotEmpty);
        expect(newB.a01.weaknesses, isNotEmpty);
        // headline엔 항상 dominant 십신 이름이 포함되어야 한다(getLifeTotal 공식).
        expect(
          newB.a01.headline,
          contains(newB.interp.tenGodsAnalysis.dominantName),
        );
      });
    }
  });

  group('[j7·A01] runJeontongCategory("A01", ctx) 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: JeontongCalcContext + runJeontongCategory("A01") 예외 없이 동작', () {
        final newB = _runNew(u, _kFixedDate);
        final rules = SajuFortuneRules.cachedOrNull;
        expect(rules, isNotNull, reason: 'SajuFortuneRules.preload()가 setUpAll에서 완료되어야 함');

        final ctx = JeontongCalcContext(
          saju: newB.saju,
          interp: newB.interp,
          rules: rules!,
          referenceDate: _kFixedDate,
        );

        late final JeontongCategoryResult result;
        expect(() => result = runJeontongCategory('A01', ctx), returnsNormally);
        expect(result.category, '평생 총운');
        expect(result.data['headline'], newB.a01.headline);
        expect(result.data['summary'], newB.a01.summary);
      });
    }
  });
}
