// [j7 · F01 신규 엔진 이전] 레거시(SajuEngine.calculate) vs 신규
// (PHASE1~4 → sajuResultFromProfile 어댑터) F01(재물 축적 방법) 결과 비교 테스트.
//
// A01/A02와 동일한 원칙(§2/§3) — 단순 "테스트 통과 여부"가 아니라
// 다음 전부를 나란히 출력/비교한다:
//   1) 사주 8글자(년/월/일/시주)
//   2) 일간
//   3) 오행(개수)
//   4) 십신(7키)
//   5) 대운(간지/시작연령/시작연도)
//   6) 신강신약(dayMasterStrength) — F01의 verdict 분기에 직접 사용됨
//   7) 용신/희신/기신/구신 (신규 전용 — 참고용 로그)
//   8) F01 판단에 실제 쓰이는 계산값(wealthCount, dayMasterStrength)
//   9) 최종 F01 결과(verdict/structure/message/asset_style/peak_period)
//  10) 결과 문구 전체
//
// [F01의 계산 의존성 — A01/A02보다 위험도 높음]
// `_f01(ctx)`(jeontong_eighty_calculator.dart) → `getLifeWealth(interp)`
// (saju_life_modules.dart) → `interp.wealthFortune`
// (=`interpretWealth(saju)`, saju_interpreter.dart)를 사용한다.
// `interpretWealth()`는 `saju.dayMasterStrength`를 **verdict 분기
// 조건 자체**로 직접 사용한다(재다신약/재왕신강/무재격/신강용재/
// 재약신약 5분기 — wealthCount와 strength.contains('弱'/'强') 조합).
// A01/A02는 dayMasterStrength가 달라져도 verdict 자체(=headline의
// 신강/중화/신약 라벨)만 바뀌고 핵심 문구 구조는 유지되었지만, F01은
// dayMasterStrength가 달라지면 **verdict 문자열 자체(예: '재왕신강'
// ↔ '재약신약')와 asset_style/message가 통째로 바뀔 수 있다** — 더
// 신중한 검증이 필요하다.
//
// 단, PHASE3(억부법)와 legacy(단순 오행비율)의 판정 차이는 '强'/'弱'
// 경계(예: 身强↔中和, 身弱↔中和)에서만 발생하며, `strength.contains
// ('强')`/`strength.contains('弱')` 판정은 '中和'일 때 둘 다 false가
// 되므로, legacy가 强/弱이고 신규가 中和로 바뀌는 케이스에서는
// verdict가 realloc될 수 있다(예: '재왕신강'→'무재격'이 아니라
// wealthCount 분기가 유지된 채 else 분기인 '재약신약'으로 떨어짐).
// 이는 PHASE3가 기준 엔진이라는 원칙(§3)에 따른 정상 결과이며,
// verdict 차이가 있더라도 무조건 실패시키지 않고 구조적 안전성 +
// 상세 로그로 원인을 투명하게 남긴다.
//
// [category 필드 주의] `jeontong_eighty_calculator.dart`의
// `_categoryIndex`에서 `'F01': (ctx) => _a03(ctx)`로 정의되어 있어,
// `_a03()`이 반환하는 `category` 필드는 A03과 동일한 '평생 재물운'
// 고정값이다(F01의 매트릭스 title '재물 축적 방법'과 다름). 실제 화면
// (`report_builder.dart`)은 `entry.title`(매트릭스 title)을 사용하므로
// UX엔 영향 없다 — 이 테스트는 실제 엔진 반환값('평생 재물운')을
// 기대값으로 사용한다.
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
  _LegacyBundle(this.saju, this.interp, this.f01);
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult f01;
}

class _NewBundle {
  _NewBundle(this.profile, this.saju, this.interp, this.f01);
  final SajuProfile profile;
  final legacy.SajuResult saju;
  final SajuFullInterpretation interp;
  final JeontongCategoryResult f01;
}

JeontongCategoryResult _runF01(
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
  return runJeontongCategory('F01', ctx);
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
  final f01 = _runF01(saju, interp, referenceDate);
  return _LegacyBundle(saju, interp, f01);
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
  final f01 = _runF01(saju, interp, referenceDate);
  return _NewBundle(p4, saju, interp, f01);
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

  group('[j7·F01] 레거시 vs 신규(PHASE1~4+어댑터) 전체 비교 — seed 유저 3명', () {
    for (final u in _seedUsers) {
      test('${u.userId}: 8글자/일간/오행/십신/대운/신강신약/용희기구/F01 전체 비교', () {
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

        // ── 5) 대운(회귀 확인용, F01은 대운 자체는 사용하지 않음) ──
        final legacyReal = legacyB.saju.luckPillars.where((lp) => lp.ganZhi.isNotEmpty).toList();
        // ignore: avoid_print
        print('[대운] legacy(${legacyReal.length}개)=${legacyReal.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
        // ignore: avoid_print
        print('[대운] new(${newB.saju.luckPillars.length}개)=${newB.saju.luckPillars.map((e) => '${e.ganZhiKr}(${e.startAge}세~)').join(', ')}');
        for (var i = 0; i < legacyReal.length; i++) {
          expect(newB.saju.luckPillars[i].ganZhi, legacyReal[i].ganZhi, reason: '${u.userId} 대운[$i] 간지 불일치');
        }

        // ── 6) 신강신약(dayMasterStrength) — F01 verdict 분기의 핵심 입력값 ──
        final strengthSame = newB.saju.dayMasterStrength == legacyB.saju.dayMasterStrength;
        // ignore: avoid_print
        print('[신강신약] legacy=${legacyB.saju.dayMasterStrength}');
        // ignore: avoid_print
        print('[신강신약] new   =${newB.saju.dayMasterStrength}  (${strengthSame ? "동일" : "★ 다름 — F01 verdict 자체가 바뀔 수 있음 ★"})');
        if (newB.profile.strength != null) {
          final s = newB.profile.strength!;
          // ignore: avoid_print
          print('[신강신약·PHASE3 상세] score=${s.score.toStringAsFixed(3)} '
              'monthOrder=${s.monthOrderScore} root=${s.rootScore} '
              'support=${s.supportScore} control=${s.controlScore} drain=${s.drainScore}');
        }

        // ── 7) 용신/희신/기신/구신 (신규 전용, F01엔 미사용 — 참고 로그) ──
        if (newB.profile.yongsin != null) {
          final y = newB.profile.yongsin!;
          // ignore: avoid_print
          print('[용희기구·신규전용] method=${y.method} 용신=${y.yongsin} 희신=${y.heesin} '
              '기신=${y.gisin} 구신=${y.gusin}');
        }

        // ── 8) F01 판단에 실제 사용되는 계산값(wealthCount, dominant 십신) ──
        final legacyWealthCount = legacyB.interp.wealthFortune.wealthGodCount;
        final newWealthCount = newB.interp.wealthFortune.wealthGodCount;
        // ignore: avoid_print
        print('[F01계산값] legacy wealthGodCount=$legacyWealthCount (재성 개수, verdict 1차 분기)');
        // ignore: avoid_print
        print('[F01계산값] new    wealthGodCount=$newWealthCount');
        expect(newWealthCount, legacyWealthCount, reason: '${u.userId} 재성(정재+편재) 개수는 십신이 일치하므로 동일해야 함');
        // ignore: avoid_print
        print('[F01계산값] legacy verdict=${legacyB.interp.wealthFortune.verdict}');
        // ignore: avoid_print
        print('[F01계산값] new    verdict=${newB.interp.wealthFortune.verdict}');

        // ── 9) F01 판단에 실제 사용되는 계산값(JeontongCategoryResult 필드) ──
        for (final key in [
          'verdict',
          'structure',
          'message',
          'asset_style',
          'peak_period',
        ]) {
          final lv = legacyB.f01.data[key];
          final nv = newB.f01.data[key];
          // ignore: avoid_print
          print('[F01·$key] legacy=$lv');
          // ignore: avoid_print
          print('[F01·$key] new   =$nv');
        }

        // ── 10) 최종 F01 결과 전체 동일성 ──
        // ignore: avoid_print
        print('[F01·category] legacy=${legacyB.f01.category}  new=${newB.f01.category}');
        expect(legacyB.f01.category, '평생 재물운');
        expect(newB.f01.category, '평생 재물운');

        final verdictSame = legacyB.f01.data['verdict'] == newB.f01.data['verdict'];
        final f01Same = legacyB.f01.data.toString() == newB.f01.data.toString();
        // ignore: avoid_print
        print('[결론] verdict동일=$verdictSame F01 전체 데이터 동일여부=$f01Same '
            '(dayMasterStrength동일=$strengthSame) → '
            '${!strengthSame && !verdictSame ? "dayMasterStrength 차이가 F01 verdict 자체를 바꿈(재물운 유형 재분류 — PHASE3 기준 정상 결과)" : (strengthSame && f01Same ? "완전 일치" : (verdictSame && !f01Same ? "verdict는 동일하나 세부 문구 차이 있음 - 확인 필요" : "다른 원인으로 차이 발생 - 확인 필요"))}');

        // ── 구조적 안전성만 강제(문구 1:1 동일성은 요구하지 않음 — §2/§3
        // 원칙). F01은 dayMasterStrength를 verdict 분기 조건 자체로 사용
        // 하므로, dayMasterStrength가 다른 경우(seed-user-C 패턴) verdict
        // 문자열 자체가 달라지는 것도 정상적인 엔진 개선일 수 있다.
        expect(newB.f01.data['verdict'], isNotEmpty);
        expect(newB.f01.data['message'], isNotEmpty);
        expect(newB.f01.data['structure'], isNotEmpty);
        expect(newB.f01.data['asset_style'], isNotEmpty);
        expect(newB.f01.data['peak_period'], isNotEmpty);
        // verdict는 항상 5가지 정의된 값 중 하나여야 한다(getLifeWealth 공식).
        expect(
          newB.f01.data['verdict'],
          anyOf(['재다신약', '재왕신강', '무재격', '신강용재', '재약신약']),
        );
        // asset_style은 verdict에 대응하는 값이어야 한다(정의되지 않은
        // verdict가 나오면 '균형 잡힌 자산 배분' 폴백이 사용되므로, 5가지
        // 정의된 verdict라면 폴백이 아닌 전용 문구가 나와야 한다).
        const assetStyleByVerdict = {
          '재다신약': '부동산·현금 등 안정형 위주. 주식·코인 등 변동성 금물.',
          '재왕신강': '사업·투자 확대 가능. 리스크 감수형 유리.',
          '무재격': '지식재산·자격증·저작권 형태 재물.',
          '신강용재': '정재+편재 균형 운용. 월급+투자 조합.',
          '재약신약': '저축·현금성 자산 중심, 소액 분산투자.',
        };
        expect(
          newB.f01.data['asset_style'],
          assetStyleByVerdict[newB.f01.data['verdict']],
          reason: '${u.userId}: asset_style은 verdict에 정확히 대응해야 함(폴백 사용 금지)',
        );

        // dayMasterStrength가 legacy와 동일한 seed라면 F01 결과도
        // 완전히 동일해야 한다(진짜 회귀 방지 — strict 비교는 이 경우에만).
        if (strengthSame) {
          expect(
            newB.f01.data,
            legacyB.f01.data,
            reason:
                '${u.userId}: dayMasterStrength가 legacy와 동일하므로 F01 결과도 '
                '완전히 동일해야 합니다.',
          );
        }
      });
    }
  });

  group('[j7·F01] runJeontongCategory("F01", ctx) 경로 자체도 정상 동작 확인', () {
    for (final u in _seedUsers) {
      test('${u.userId}: JeontongCalcContext + runJeontongCategory("F01") 예외 없이 동작', () {
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
        expect(() => result = runJeontongCategory('F01', ctx), returnsNormally);
        expect(result.category, '평생 재물운');
        expect(result.data['verdict'], newB.f01.data['verdict']);
        expect(result.data['message'], newB.f01.data['message']);
      });
    }
  });
}
