// [j7 · C05 신규 엔진 이전] 레거시(SajuEngine.calculate) vs 신규
// (PHASE1~4 → sajuResultFromProfile 어댑터) C05(올해 건강운) 결과 비교 테스트.
//
// A01/B01과 동일한 원칙(§2/§3) — 단순 "테스트 통과 여부"가 아니라 다음
// 전부를 나란히 출력/비교한다:
//   1) 사주 8글자(년/월/일/시주)
//   2) 일간
//   3) 오행(개수)
//   4) 십신(7키)
//   5) 대운(간지/시작연령/시작연도)
//   6) 신강신약(dayMasterStrength) — C05 자체는 사용하지 않지만 회귀 확인용
//   7) 용신/희신/기신/구신 (신규 전용 — 참고용 로그)
//   8) C05 판단에 실제 쓰이는 계산값(getYearFortune 결과 전체 필드 —
//      yearGanZhi/yearTheme/ganGod/zhiGod/title/overall/wealth/career/
//      love/health/advice)
//   9) 최종 C05 결과(JeontongCategoryResult 전체 필드)
//  10) 결과 문구 전체
//
// [C05의 계산 의존성 — B01과 동일 패턴] C05(`_yearFortuneToResult()` →
// `getYearFortune(ctx.saju, ctx.rules, year: ctx.year)`)은 세운(올해) 간지를
// `Solar.fromYmd(year, 6, 15)`로 원국과 무관하게 직접 구한 뒤, 그 세운
// 간지와 `saju.dayMaster.gan`(일간)의 십신 관계만으로 rules JSON을
// 룩업한다. dayMasterStrength(신강신약)에는 **의존하지 않는다**. 따라서
// 일간이 legacy/신규 완전 일치하는 한(모든 seed 유저에서 이미 확인됨),
// C05 결과는 seed-user-A/B/C 전원 완전 일치해야 한다.
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

/// 골든 테스트와 동일한 기준일(kFixedDate) — C05의 `ctx.year`는 이
/// 기준일의 연도(2026)를 그대로 사용한다.
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
  _LegacyBundle(this.saju, this.interp, this.c05);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult c05;
}

class _NewBundle {
  _NewBundle(this.profile, this.saju, this.interp, this.c05);
  final SajuProfile profile;
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult c05;
}

JeontongCategoryResult _runC05(
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
  return runJeontongCategory('C05', ctx);
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
  final c05 = _runC05(saju, interp, referenceDate);
  return _LegacyBundle(saju, interp, c05);
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
  final c05 = _runC05(saju, interp, referenceDate);
  return _NewBundle(p4, saju, interp, c05);
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

  group('[j7·C05] 레거시 vs 신규(PHASE1~4+어댑터) 전체 비교 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 8글자/일간/오행/십신/대운/신강신약/용희기구/C05 전체 비교', () {
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
        expect(
          newPillars,
          legacyPillars,
          reason: '${u.userId} 8글자는 100% 동일해야 함',
        );

        // ── 2) 일간 (C05의 핵심 입력값) ──
        // ignore: avoid_print
        print(
          '[일간] legacy=${legacyB.saju.dayMaster.gan}(${legacyB.saju.dayMaster.kr})',
        );
        // ignore: avoid_print
        print(
          '[일간] new   =${newB.saju.dayMaster.gan}(${newB.saju.dayMaster.kr})',
        );
        expect(
          newB.saju.dayMaster.gan,
          legacyB.saju.dayMaster.gan,
          reason: '${u.userId} 일간 불일치',
        );

        // ── 3) 오행 ──
        // ignore: avoid_print
        print('[오행] legacy=${legacyB.saju.fiveElementsCount}');
        // ignore: avoid_print
        print('[오행] new   =${newB.saju.fiveElementsCount}');
        expect(
          newB.saju.fiveElementsCount,
          legacyB.saju.fiveElementsCount,
          reason: '${u.userId} 오행 총량 불일치',
        );

        // ── 4) 십신(7키) ──
        // ignore: avoid_print
        print('[십신] legacy=${legacyB.saju.tenGods}');
        // ignore: avoid_print
        print('[십신] new   =${newB.saju.tenGods}');
        expect(
          newB.saju.tenGods,
          legacyB.saju.tenGods,
          reason: '${u.userId} 십신 불일치',
        );

        // ── 5) 대운(회귀 확인용, C05은 대운 자체는 사용하지 않음) ──
        final legacyReal = legacyB.saju.luckPillars
            .where((lp) => lp.ganZhi.isNotEmpty)
            .toList();
        // ignore: avoid_print
        print(
          '[대운] legacy(${legacyReal.length}개)=${legacyReal.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}',
        );
        // ignore: avoid_print
        print(
          '[대운] new(${newB.saju.luckPillars.length}개)=${newB.saju.luckPillars.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}',
        );
        for (var i = 0; i < legacyReal.length; i++) {
          expect(
            newB.saju.luckPillars[i].ganZhi,
            legacyReal[i].ganZhi,
            reason: '${u.userId} 대운[$i] 간지 불일치',
          );
        }

        // ── 6) 신강신약(dayMasterStrength) — C05엔 미사용, 회귀 확인용 ──
        final strengthSame =
            newB.saju.dayMasterStrength == legacyB.saju.dayMasterStrength;
        // ignore: avoid_print
        print('[신강신약] legacy=${legacyB.saju.dayMasterStrength}');
        // ignore: avoid_print
        print(
          '[신강신약] new   =${newB.saju.dayMasterStrength}  (${strengthSame ? "동일" : "★ 다름(A01/B01과 동일한 seed-user-C 패턴 - C05엔 영향 없음) ★"})',
        );
        if (newB.profile.strength != null) {
          final s = newB.profile.strength!;
          // ignore: avoid_print
          print(
            '[신강신약·PHASE3 상세] score=${s.score.toStringAsFixed(3)} '
            'monthOrder=${s.monthOrderScore} root=${s.rootScore} '
            'support=${s.supportScore} control=${s.controlScore} drain=${s.drainScore}',
          );
        }

        // ── 7) 용신/희신/기신/구신 (신규 전용, C05엔 미사용 — 참고 로그) ──
        if (newB.profile.yongsin != null) {
          final y = newB.profile.yongsin!;
          // ignore: avoid_print
          print(
            '[용희기구·신규전용] method=${y.method} 용신=${y.yongsin} 희신=${y.heesin} '
            '기신=${y.gisin} 구신=${y.gusin}',
          );
        }

        // ── 8) C05 판단에 실제 사용되는 계산값(JeontongCategoryResult 필드) ──
        for (final key in [
          'year_gan_zhi',
          'year_theme',
          'gan_god',
          'zhi_god',
          'title',
          'overall',
          'wealth',
          'career',
          'love',
          'health',
          'advice',
        ]) {
          final lv = legacyB.c05.data[key];
          final nv = newB.c05.data[key];
          // ignore: avoid_print
          print('[C05·$key] legacy=$lv');
          // ignore: avoid_print
          print('[C05·$key] new   =$nv');
        }

        // ── 9)/10) 최종 C05 결과 전체 동일성 ──
        // ignore: avoid_print
        print(
          '[C05·category] legacy=${legacyB.c05.category}  new=${newB.c05.category}',
        );

        final c05Same = legacyB.c05.data.toString() == newB.c05.data.toString();
        // ignore: avoid_print
        print(
          '[결론] C05 전체 데이터 동일여부=$c05Same '
          '(dayMasterStrength동일=$strengthSame — C05은 신강신약을 사용하지 않으므로 '
          'strength 차이와 무관하게 C05 결과는 일간 계산이 일치하는 한 항상 동일해야 함)',
        );

        // ── C05은 dayMasterStrength에 의존하지 않으므로, 일간이 이미
        // 완전 일치함을 확인했다면(위 2번) legacy/신규 C05 결과는 100%
        // 동일해야 한다 — 이것이 C05의 정상 기대값이다.
        expect(
          newB.c05.data,
          legacyB.c05.data,
          reason:
              '${u.userId}: C05은 dayMasterStrength를 사용하지 않는 카테고리이므로 '
              '일간(위에서 이미 일치 확인됨)이 같다면 legacy/신규 결과가 완전히 '
              '동일해야 합니다. 다르다면 십신 매핑(getTenGod) 또는 rules 참조 '
              '로직에 회귀가 있다는 뜻입니다.',
        );
      });
    }
  });

  group('[j7·C05] runJeontongCategory("C05", ctx) 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test(
        '${u.userId}: JeontongCalcContext + runJeontongCategory("C05") 예외 없이 동작',
        () {
          final newB = _runNew(u, _kFixedDate);
          final rules = SajuFortuneRules.cachedOrNull;
          expect(
            rules,
            isNotNull,
            reason: 'SajuFortuneRules.preload()가 setUpAll에서 완료되어야 함',
          );

          final ctx = JeontongCalcContext(
            saju: newB.saju,
            interp: newB.interp,
            rules: rules!,
            referenceDate: _kFixedDate,
          );

          late final JeontongCategoryResult result;
          expect(
            () => result = runJeontongCategory('C05', ctx),
            returnsNormally,
          );
          expect(result.category, '올해 건강운');
          expect(result.data['title'], newB.c05.data['title']);
          expect(result.data['overall'], newB.c05.data['overall']);
        },
      );
    }
  });
}
