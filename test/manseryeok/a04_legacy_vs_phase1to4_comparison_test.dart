// [j7 · A04 신규 엔진 이전] 레거시(SajuEngine.calculate) vs 신규
// (PHASE1~4 → sajuResultFromProfile 어댑터) A04(평생 직업·명예운) 결과
// 비교 테스트.
//
// A01/A02/A03과 동일한 원칙(§2/§3) — 단순 "테스트 통과 여부"가 아니라
// 다음 전부를 나란히 출력/비교한다:
//   1) 사주 8글자(년/월/일/시주)
//   2) 일간
//   3) 오행(개수)
//   4) 십신(7키)
//   5) 대운(간지/시작연령/시작연도)
//   6) 신강신약(dayMasterStrength) — A04의 work_style 필드에만 영향
//   7) 용신/희신/기신/구신 (신규 전용 — 참고용 로그)
//   8) A04 판단에 실제 쓰이는 계산값(officer/printer/output 개수,
//      dayMasterAnalysis.title)
//   9) 최종 A04 결과(structure/message/recommended_jobs/work_style/
//      growth_path)
//  10) 결과 문구 전체
//
// [A04의 계산 의존성 — A03과 다른 패턴]
// `_a04(ctx)`(jeontong_eighty_calculator.dart) → `getLifeCareer(interp)`
// (saju_life_modules.dart)를 사용한다. getLifeCareer()는:
//   - structure/message/recommended_jobs: `interp.careerFortune`
//     (=interpretCareer(), saju_interpreter.dart)에서 가져옴 — 이 함수는
//     officer(정관+편관)/printer(정인+편인)/output(식신+상관) 개수만
//     사용하고 dayMasterStrength는 전혀 참조하지 않는다(A03의
//     interpretWealth()와 달리 verdict 분기에 강/약이 안 들어감).
//   - work_style: `_workStyleByTitle(dm.title)`이 title.contains
//     ('신강'/'신약')만 체크(중화는 else로 떨어져 '균형형') — A01/A02와
//     동일한 패턴으로 dayMasterStrength에 간접 의존하지만 이 필드
//     하나에만 영향을 준다(A03처럼 verdict 전체가 재분류되지 않음).
//   - growth_path: 고정 문구, 계산 무관.
// 따라서 A04는 A01/A02와 유사한 위험도(문구 1개 필드만 영향)로 예상된다.
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
import 'package:flutter_test/flutter_test.dart';

/// 골든 테스트와 동일한 기준일(kFixedDate).
final _kFixedDate = DateTime.utc(2026, 8, 13);

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

DateTime _toKst(DateTime utc) => utc.add(const Duration(hours: 9));

String _legacyGender(String mf) => mf == 'F' ? 'female' : 'male';

class _LegacyBundle {
  _LegacyBundle(this.saju, this.interp, this.a04);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult a04;
}

class _NewBundle {
  _NewBundle(this.profile, this.saju, this.interp, this.a04);
  final SajuProfile profile;
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult a04;
}

JeontongCategoryResult _runA04(
  legacy.SajuResult saju,
  SajuFullInterpretation interp,
  DateTime referenceDate,
) {
  final rules = SajuFortuneRules.cachedOrNull!;
  final ctx = JeontongCalcContext(
    saju: saju,
    interp: interp,
    rules: rules,
    referenceDate: referenceDate,
  );
  return runJeontongCategory('A04', ctx);
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
  final a04 = _runA04(saju, interp, referenceDate);
  return _LegacyBundle(saju, interp, a04);
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
  final a04 = _runA04(saju, interp, referenceDate);
  return _NewBundle(p4, saju, interp, a04);
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

  group('[j7·A04] 레거시 vs 신규(PHASE1~4+어댑터) 전체 비교 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 8글자/일간/오행/십신/대운/신강신약/용희기구/A04 전체 비교', () {
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
        expect(newPillars, legacyPillars, reason: '${u.userId} 8글자는 100% 동일해야 함');

        // ── 2) 일간 ──
        // ignore: avoid_print
        print('[일간] legacy=${legacyB.saju.dayMaster.gan}(${legacyB.saju.dayMaster.kr})');
        // ignore: avoid_print
        print('[일간] new   =${newB.saju.dayMaster.gan}(${newB.saju.dayMaster.kr})');
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

        // ── 5) 대운(회귀 확인용, A04는 대운 자체는 사용하지 않음) ──
        final legacyReal = legacyB.saju.luckPillars.where((lp) => lp.ganZhi.isNotEmpty).toList();
        // ignore: avoid_print
        print('[대운] legacy(${legacyReal.length}개)=${legacyReal.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
        // ignore: avoid_print
        print('[대운] new(${newB.saju.luckPillars.length}개)=${newB.saju.luckPillars.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
        for (var i = 0; i < legacyReal.length; i++) {
          expect(newB.saju.luckPillars[i].ganZhi, legacyReal[i].ganZhi, reason: '${u.userId} 대운[$i] 간지 불일치');
        }

        // ── 6) 신강신약(dayMasterStrength) — A04의 work_style 필드에만 영향 ──
        final strengthSame = newB.saju.dayMasterStrength == legacyB.saju.dayMasterStrength;
        // ignore: avoid_print
        print('[신강신약] legacy=${legacyB.saju.dayMasterStrength}');
        // ignore: avoid_print
        print('[신강신약] new   =${newB.saju.dayMasterStrength}  (${strengthSame ? "동일" : "★ 다름 — A04 work_style 필드에만 영향 ★"})');
        if (newB.profile.strength != null) {
          final s = newB.profile.strength!;
          // ignore: avoid_print
          print('[신강신약·PHASE3 상세] score=${s.score.toStringAsFixed(3)} '
              'monthOrder=${s.monthOrderScore} root=${s.rootScore} '
              'support=${s.supportScore} control=${s.controlScore} drain=${s.drainScore}');
        }

        // ── 7) 용신/희신/기신/구신 (신규 전용, A04엔 미사용 — 참고 로그) ──
        if (newB.profile.yongsin != null) {
          final y = newB.profile.yongsin!;
          // ignore: avoid_print
          print('[용희기구·신규전용] method=${y.method} 용신=${y.yongsin} 희신=${y.heesin} '
              '기신=${y.gisin} 구신=${y.gusin}');
        }

        // ── 8) A04 판단에 실제 사용되는 계산값(officer/printer/output 개수) ──
        final legacyTg = legacyB.saju.tenGods.values;
        final newTg = newB.saju.tenGods.values;
        int countOf(Iterable<String> tg, List<String> keys) =>
            tg.where((v) => keys.contains(v)).length;
        final legacyOfficer = countOf(legacyTg, ['정관', '편관']);
        final newOfficer = countOf(newTg, ['정관', '편관']);
        final legacyPrinter = countOf(legacyTg, ['정인', '편인']);
        final newPrinter = countOf(newTg, ['정인', '편인']);
        final legacyOutput = countOf(legacyTg, ['식신', '상관']);
        final newOutput = countOf(newTg, ['식신', '상관']);
        // ignore: avoid_print
        print('[A04계산값] legacy officer=$legacyOfficer printer=$legacyPrinter output=$legacyOutput');
        // ignore: avoid_print
        print('[A04계산값] new    officer=$newOfficer printer=$newPrinter output=$newOutput');
        expect(newOfficer, legacyOfficer, reason: '${u.userId} 관성 개수는 십신이 일치하므로 동일해야 함');
        expect(newPrinter, legacyPrinter, reason: '${u.userId} 인성 개수는 십신이 일치하므로 동일해야 함');
        expect(newOutput, legacyOutput, reason: '${u.userId} 식상 개수는 십신이 일치하므로 동일해야 함');
        // ignore: avoid_print
        print('[A04계산값] legacy dayMasterAnalysis.title=${legacyB.interp.dayMasterAnalysis.title}');
        // ignore: avoid_print
        print('[A04계산값] new    dayMasterAnalysis.title=${newB.interp.dayMasterAnalysis.title}');

        // ── 9) A04 판단에 실제 사용되는 계산값(JeontongCategoryResult 필드) ──
        for (final key in [
          'structure',
          'message',
          'recommended_jobs',
          'work_style',
          'growth_path',
        ]) {
          final lv = legacyB.a04.data[key];
          final nv = newB.a04.data[key];
          // ignore: avoid_print
          print('[A04·$key] legacy=$lv');
          // ignore: avoid_print
          print('[A04·$key] new   =$nv');
        }

        // ── 10) 최종 A04 결과 전체 동일성 ──
        // ignore: avoid_print
        print('[A04·category] legacy=${legacyB.a04.category}  new=${newB.a04.category}');
        expect(legacyB.a04.category, '평생 직업·명예운');
        expect(newB.a04.category, '평생 직업·명예운');

        final structureSame = legacyB.a04.data['structure'] == newB.a04.data['structure'];
        final workStyleSame = legacyB.a04.data['work_style'] == newB.a04.data['work_style'];
        final a04Same = legacyB.a04.data.toString() == newB.a04.data.toString();
        // ignore: avoid_print
        print('[결론] structure동일=$structureSame work_style동일=$workStyleSame '
            'A04 전체 데이터 동일여부=$a04Same (dayMasterStrength동일=$strengthSame) → '
            '${!strengthSame && !workStyleSame ? "dayMasterStrength 차이가 work_style 문구에만 영향을 줌(A01/A02와 동일한 정상 패턴, structure/message/jobs는 무관)" : (strengthSame && a04Same ? "완전 일치" : "다른 원인으로 차이 발생 - 확인 필요")}');
        // structure/message/recommended_jobs는 dayMasterStrength와
        // 무관하므로(interpretCareer는 officer/printer/output만 사용),
        // 위에서 이미 확인한 관성/인성/식상 개수가 legacy와 100% 일치하는
        // 한 반드시 동일해야 한다 — 이건 strength 차이와 무관한 진짜 회귀
        // 검증이다.
        expect(newB.a04.data['structure'], legacyB.a04.data['structure'],
            reason: '${u.userId}: structure는 dayMasterStrength와 무관하므로 항상 동일해야 함');
        expect(newB.a04.data['message'], legacyB.a04.data['message'],
            reason: '${u.userId}: message는 dayMasterStrength와 무관하므로 항상 동일해야 함');
        expect(newB.a04.data['recommended_jobs'], legacyB.a04.data['recommended_jobs'],
            reason: '${u.userId}: recommended_jobs는 dayMasterStrength와 무관하므로 항상 동일해야 함');
        expect(newB.a04.data['growth_path'], legacyB.a04.data['growth_path'],
            reason: '${u.userId}: growth_path는 고정 문구이므로 항상 동일해야 함');

        // ── work_style만 dayMasterStrength에 간접 의존(soft assertion) ──
        expect(newB.a04.data['work_style'], isNotEmpty);
        expect(
          newB.a04.data['work_style'],
          anyOf([
            '리더·독립·창업형. 조직 내에서도 주도적 역할 유리.',
            '전문가·조력자·기획형. 안정된 조직에서 능력 발휘.',
            '균형형. 조직·독립 모두 가능.',
          ]),
        );
        // dayMasterStrength가 legacy와 동일한 seed라면 work_style도
        // 완전히 동일해야 한다(진짜 회귀 방지 — strict 비교는 이 경우에만).
        if (strengthSame) {
          expect(
            newB.a04.data,
            legacyB.a04.data,
            reason:
                '${u.userId}: dayMasterStrength가 legacy와 동일하므로 A04 결과도 '
                '완전히 동일해야 합니다.',
          );
        }
      });
    }
  });

  group('[j7·A04] runJeontongCategory("A04", ctx) 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: JeontongCalcContext + runJeontongCategory("A04") 예외 없이 동작', () {
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
        expect(() => result = runJeontongCategory('A04', ctx), returnsNormally);
        expect(result.category, '평생 직업·명예운');
        expect(result.data['structure'], newB.a04.data['structure']);
        expect(result.data['work_style'], newB.a04.data['work_style']);
      });
    }
  });
}
