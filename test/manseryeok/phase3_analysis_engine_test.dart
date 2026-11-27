// [정통사주 80종 전용 신규 엔진] PHASE 3 검증 테스트.
//
// 37번 지시 §12(신강신약 정밀 분석)/§13(용신희신기신구신, 억부/조후 분리)
// 및 "각 단계가 실제 검증된 후 다음 단계로 넘어간다" 원칙에 대응한다.
//
// 검증 전략:
// 1) 구조적 정합성(structural invariant) 검증 — 희신은 항상 용신을
//    생(生)하고, 기신은 항상 용신을 극(剋)하며, 구신은 항상 기신을
//    생한다는 고정 오행 관계표 상의 불변식이 모든 결과에서 성립하는지
//    확인한다(이는 특정 사주의 "정답"을 가정하지 않는, 로직 자체의
//    내부 일관성 검증이다).
// 2) 방향성(directional) 검증 — 비겁/인성만 극단적으로 많은 사주는
//    반드시 '신강'으로, 관살/식상/재성만 극단적으로 많은 사주는 반드시
//    '신약'으로 판정되는지 수동 구성한 극단 사례로 검증한다.
// 3) 조후법 개별 검증 — 월지 亥子丑(겨울)→화, 巳午未(여름)→수,
//    寅卯辰/申酉戌(봄/가을)→조후 불요를 고정 사례로 검증한다.
// 4) 억부+조후 종합 로직 검증 — (a) 조후 불요 시 억부법 그대로 채택,
//    (b) 억부·조후 용신이 일치할 때 그대로 채택, (c) 불일치할 때 "조후
//    우선 원칙"에 따라 조후법 결과를 채택하는 3가지 분기를 모두 검증한다.
// 5) 십신 범주 매핑([tenGodCategoryOf])과 오행 관계 판정
//    ([relationCategoryOf])을 10개 십신 / 25개(5×5) 오행 조합 전수로
//    검증한다.
// 6) 파이프라인 통합 검증 — 실제 생년월일 샘플로 PHASE1→PHASE2→PHASE3
//    전체를 실행해 예외 없이 유효한 [StrengthProfile]/[YongsinProfile]이
//    생성되는지 확인하고, PHASE 2 없이 PHASE 3만 단독 호출하면
//    [StateError]가 발생하는지(선행조건 강제) 확인한다.
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_core_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/manseryeok_policy.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase2_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/phase3_analysis_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/saju_profile.dart';
import 'package:flutter_app/features/home/domain/manseryeok/strength_engine.dart';
import 'package:flutter_app/features/home/domain/manseryeok/yongsin_engine.dart';
import 'package:flutter_app/features/home/domain/saju_engine.dart'
    show sheng, ke;
import 'package:flutter_test/flutter_test.dart';

/// 최소 필드만 채운 테스트 전용 [Pillar] 생성기 — strength/yongsin
/// 엔진은 stemHanja/branchHanja만 실제로 사용하므로 나머지 필드는
/// 임의 유효값으로 채운다.
Pillar fakePillar(String stemHanja, String branchHanja) {
  const ganInfo = {
    '甲': ('목', '양'),
    '乙': ('목', '음'),
    '丙': ('화', '양'),
    '丁': ('화', '음'),
    '戊': ('토', '양'),
    '己': ('토', '음'),
    '庚': ('금', '양'),
    '辛': ('금', '음'),
    '壬': ('수', '양'),
    '癸': ('수', '음'),
  };
  const zhiInfo = {
    '子': ('수', '양'),
    '丑': ('토', '음'),
    '寅': ('목', '양'),
    '卯': ('목', '음'),
    '辰': ('토', '양'),
    '巳': ('화', '음'),
    '午': ('화', '양'),
    '未': ('토', '음'),
    '申': ('금', '양'),
    '酉': ('금', '음'),
    '戌': ('토', '양'),
    '亥': ('수', '음'),
  };
  final (se, sy) = ganInfo[stemHanja]!;
  final (be, by) = zhiInfo[branchHanja]!;
  return Pillar(
    stemHanja: stemHanja,
    branchHanja: branchHanja,
    stemKr: stemHanja,
    branchKr: branchHanja,
    stemElement: se,
    stemYinYang: sy,
    branchElement: be,
    branchYinYang: by,
    jiaZiIndex: 0,
  );
}

FiveElementsProfile fakeFiveElements(Map<String, int> totalCount) {
  final full = {'목': 0, '화': 0, '토': 0, '금': 0, '수': 0, ...totalCount};
  return FiveElementsProfile(
    stemCount: full,
    branchCount: full,
    hiddenStemCount: full.map((k, v) => MapEntry(k, v.toDouble())),
    totalCount: full,
    dominant: const [],
    deficient: const [],
    isImbalanced: false,
  );
}

/// 지장간 최소 1개(정기)만 있는 [HiddenStemEntry] 생성기.
HiddenStemEntry fakeHiddenStemEntry(
  String branch,
  String stemHanja,
  String tenGod,
) {
  return HiddenStemEntry(
    branch: branch,
    stems: [
      HiddenStemDetail(
        stemHanja: stemHanja,
        stemKr: stemHanja,
        role: '정기',
        tenGod: tenGod,
      ),
    ],
  );
}

void main() {
  group('PHASE 3 구조적 정합성 — 희신/기신/구신 오행 관계 불변식', () {
    void expectYongsinRelationsConsistent(YongsinProfile p) {
      if (p.yongsin.isEmpty) return; // 조후 불요('') 케이스는 관계 검증 제외.
      expect(
        sheng[p.heesin],
        p.yongsin,
        reason: '희신(${p.heesin})은 반드시 용신(${p.yongsin})을 생해야 한다',
      );
      expect(
        ke[p.gisin],
        p.yongsin,
        reason: '기신(${p.gisin})은 반드시 용신(${p.yongsin})을 극해야 한다',
      );
      expect(
        sheng[p.gusin],
        p.gisin,
        reason: '구신(${p.gusin})은 반드시 기신(${p.gisin})을 생해야 한다',
      );
    }

    test('억부법(신강) 결과의 희신/기신/구신 관계가 일관된다', () {
      final strength = StrengthProfile(
        verdict: '신강',
        score: 0.8,
        monthOrderScore: 1.0,
        rootScore: 2,
        supportScore: 3,
        controlScore: 0,
        drainScore: 0,
        detail: const [],
      );
      final fiveElements = fakeFiveElements({'화': 1});
      final p = YongsinEngine.byEokbu(
        dayPillar: fakePillar('甲', '子'),
        strength: strength,
        fiveElements: fiveElements,
      );
      expectYongsinRelationsConsistent(p);
    });

    test('억부법(신약) 결과의 희신/기신/구신 관계가 일관된다', () {
      final strength = StrengthProfile(
        verdict: '신약',
        score: 0.2,
        monthOrderScore: -1.0,
        rootScore: 0,
        supportScore: 0,
        controlScore: 3,
        drainScore: 2,
        detail: const [],
      );
      final fiveElements = fakeFiveElements({'수': 1});
      final p = YongsinEngine.byEokbu(
        dayPillar: fakePillar('甲', '午'),
        strength: strength,
        fiveElements: fiveElements,
      );
      expectYongsinRelationsConsistent(p);
    });

    test('조후법(겨울/여름) 결과의 희신/기신/구신 관계가 일관된다', () {
      expectYongsinRelationsConsistent(
        YongsinEngine.byJohu(monthPillar: fakePillar('甲', '子')),
      );
      expectYongsinRelationsConsistent(
        YongsinEngine.byJohu(monthPillar: fakePillar('甲', '午')),
      );
    });
  });

  group('PHASE 3 신강/신약 — 방향성(극단 사례) 검증', () {
    test('비겁+인성만 극단적으로 많으면 반드시 신강으로 판정된다', () {
      final tenGods = {
        'year_gan': '비견',
        'month_gan': '비견',
        'hour_gan': '정인',
        'year_zhi': '비견',
        'month_zhi': '정인',
        'day_zhi': '비견',
        'hour_zhi': '비견',
      };
      final hiddenStems = {
        'year': fakeHiddenStemEntry('卯', '甲', '비견'),
        'month': fakeHiddenStemEntry('卯', '甲', '비견'),
        'day': fakeHiddenStemEntry('卯', '甲', '비견'),
        'hour': fakeHiddenStemEntry('卯', '甲', '비견'),
      };
      final result = StrengthEngine.analyze(
        dayPillar: fakePillar('甲', '子'),
        monthPillar: fakePillar('甲', '卯'), // 월지 卯 → 목왕(비겁과 같은 오행)
        tenGods: tenGods,
        hiddenStems: hiddenStems,
      );
      expect(result.verdict, '신강');
      expect(result.score, greaterThanOrEqualTo(0.6));
    });

    test('관살+식상+재성만 극단적으로 많으면 반드시 신약으로 판정된다', () {
      final tenGods = {
        'year_gan': '정관',
        'month_gan': '편관',
        'hour_gan': '상관',
        'year_zhi': '정재',
        'month_zhi': '편관',
        'day_zhi': '식신',
        'hour_zhi': '편재',
      };
      final hiddenStems = {
        'year': fakeHiddenStemEntry('酉', '辛', '정관'),
        'month': fakeHiddenStemEntry('申', '庚', '편관'),
        'day': fakeHiddenStemEntry('午', '丁', '상관'),
        'hour': fakeHiddenStemEntry('午', '丁', '상관'),
      };
      final result = StrengthEngine.analyze(
        dayPillar: fakePillar('甲', '子'),
        monthPillar: fakePillar('甲', '申'), // 월지 申 → 금왕(관살과 같은 오행)
        tenGods: tenGods,
        hiddenStems: hiddenStems,
      );
      expect(result.verdict, '신약');
      expect(result.score, lessThanOrEqualTo(0.4));
    });
  });

  group('PHASE 3 조후법(調候法) — 월지별 고정 사례 검증', () {
    test('월지가 亥/子/丑(한겨울)이면 화(火)가 조후 용신이다', () {
      for (final zhi in ['亥', '子', '丑']) {
        final p = YongsinEngine.byJohu(monthPillar: fakePillar('甲', zhi));
        expect(p.yongsin, '화', reason: '월지=$zhi');
        expect(p.method, '조후');
      }
    });

    test('월지가 巳/午/未(한여름)이면 수(水)가 조후 용신이다', () {
      for (final zhi in ['巳', '午', '未']) {
        final p = YongsinEngine.byJohu(monthPillar: fakePillar('甲', zhi));
        expect(p.yongsin, '수', reason: '월지=$zhi');
      }
    });

    test('월지가 봄(寅卯辰)/가을(申酉戌)이면 조후 불요(빈 문자열)이다', () {
      for (final zhi in ['寅', '卯', '辰', '申', '酉', '戌']) {
        final p = YongsinEngine.byJohu(monthPillar: fakePillar('甲', zhi));
        expect(p.yongsin, isEmpty, reason: '월지=$zhi');
      }
    });
  });

  group('PHASE 3 억부+조후 종합(combine) — 3가지 분기 전부 검증', () {
    test('조후 불요 계절이면 억부법 결과를 그대로 채택한다', () {
      final strength = StrengthProfile(
        verdict: '신약',
        score: 0.2,
        monthOrderScore: -1.0,
        rootScore: 0,
        supportScore: 0,
        controlScore: 3,
        drainScore: 2,
        detail: const [],
      );
      final fiveElements = fakeFiveElements({'수': 1}); // 인성=수 존재
      final combined = YongsinEngine.combine(
        dayPillar: fakePillar('甲', '子'),
        monthPillar: fakePillar('甲', '卯'), // 봄 → 조후 불요
        strength: strength,
        fiveElements: fiveElements,
      );
      final eokbuOnly = YongsinEngine.byEokbu(
        dayPillar: fakePillar('甲', '子'),
        strength: strength,
        fiveElements: fiveElements,
      );
      expect(combined.yongsin, eokbuOnly.yongsin);
      expect(combined.reasoning, contains('조후 불요'));
    });

    test('억부법과 조후법의 용신이 일치하면 그대로 채택하고 명시한다', () {
      // 신강 + 화(火) 존재 → 억부 priority(식상=화) 우선 채택 → 화.
      // 월지 子(겨울) → 조후도 화. 두 방법이 일치하는 시나리오.
      final strength = StrengthProfile(
        verdict: '신강',
        score: 0.8,
        monthOrderScore: 1.0,
        rootScore: 2,
        supportScore: 3,
        controlScore: 0,
        drainScore: 0,
        detail: const [],
      );
      final fiveElements = fakeFiveElements({'화': 1});
      final combined = YongsinEngine.combine(
        dayPillar: fakePillar('甲', '子'),
        monthPillar: fakePillar('甲', '子'),
        strength: strength,
        fiveElements: fiveElements,
      );
      expect(combined.yongsin, '화');
      expect(combined.reasoning, contains('일치'));
    });

    test('억부법과 조후법의 용신이 불일치하면 조후법을 우선 채택한다', () {
      // 신강 + 토(재성)만 존재(화 없음) → 억부는 재성=토를 채택.
      // 월지 子(겨울) → 조후는 화를 요구. 불일치 → 조후(화) 채택.
      final strength = StrengthProfile(
        verdict: '신강',
        score: 0.8,
        monthOrderScore: 1.0,
        rootScore: 2,
        supportScore: 3,
        controlScore: 0,
        drainScore: 0,
        detail: const [],
      );
      final fiveElements = fakeFiveElements({'토': 1});
      final eokbuOnly = YongsinEngine.byEokbu(
        dayPillar: fakePillar('甲', '子'),
        strength: strength,
        fiveElements: fiveElements,
      );
      expect(eokbuOnly.yongsin, '토'); // 사전 확인 — 억부 단독 결과는 토.

      final combined = YongsinEngine.combine(
        dayPillar: fakePillar('甲', '子'),
        monthPillar: fakePillar('甲', '子'),
        strength: strength,
        fiveElements: fiveElements,
      );
      expect(combined.yongsin, '화'); // 조후 우선 원칙 적용.
      expect(combined.reasoning, contains('조후 우선 원칙'));
    });
  });

  group('PHASE 3 십신 범주/오행 관계 매핑 — 전수 검증', () {
    test('tenGodCategoryOf: 10개 십신이 5대 범주로 정확히 매핑된다', () {
      const expected = {
        '비견': '비겁',
        '겁재': '비겁',
        '식신': '식상',
        '상관': '식상',
        '편재': '재성',
        '정재': '재성',
        '편관': '관살',
        '정관': '관살',
        '편인': '인성',
        '정인': '인성',
      };
      for (final e in expected.entries) {
        expect(tenGodCategoryOf(e.key), e.value, reason: e.key);
      }
    });

    test('relationCategoryOf: 5×5(25개) 오행 조합이 모두 정확히 판정된다', () {
      const elements = ['목', '화', '토', '금', '수'];
      for (final day in elements) {
        for (final target in elements) {
          final cat = relationCategoryOf(day, target);
          if (target == day) {
            expect(cat, '비겁', reason: '$day vs $target');
          } else if (sheng[day] == target) {
            expect(cat, '식상', reason: '$day vs $target');
          } else if (ke[day] == target) {
            expect(cat, '재성', reason: '$day vs $target');
          } else if (ke[target] == day) {
            expect(cat, '관살', reason: '$day vs $target');
          } else if (sheng[target] == day) {
            expect(cat, '인성', reason: '$day vs $target');
          } else {
            fail('알 수 없는 조합: $day vs $target');
          }
        }
      }
    });
  });

  group('PHASE 3 파이프라인 통합 검증', () {
    SajuProfile buildPhase12(int year, int month, int day, int hour) {
      final withCore = ManseryeokCoreEngine.buildProfileWithCore(
        year: year,
        month: month,
        day: day,
        hour: hour,
        gender: 'male',
        calendarType: CalendarInputType.solar,
      );
      return Phase2AnalysisEngine.analyze(
        baseProfile: withCore.profile,
        core: withCore.core,
      );
    }

    test('실제 생년월일 샘플로 PHASE1→2→3 전체 파이프라인이 예외 없이 '
        '유효한 결과를 생성한다', () {
      final samples = [
        (1990, 5, 15, 10),
        (1972, 2, 13, 2),
        (1995, 11, 3, 23),
        (2000, 1, 1, 0),
      ];
      for (final s in samples) {
        final phase2Profile = buildPhase12(s.$1, s.$2, s.$3, s.$4);
        final phase3Profile = Phase3AnalysisEngine.analyze(
          baseProfile: phase2Profile,
        );

        final strength = phase3Profile.strength!;
        final yongsin = phase3Profile.yongsin!;

        expect(['신강', '중화', '신약'], contains(strength.verdict));
        expect(strength.score, inInclusiveRange(0.0, 1.0));
        expect(yongsin.method, '억부+조후');
        expect(['목', '화', '토', '금', '수', ''], contains(yongsin.yongsin));
        if (yongsin.yongsin.isNotEmpty) {
          expect(sheng[yongsin.heesin], yongsin.yongsin);
          expect(ke[yongsin.gisin], yongsin.yongsin);
          expect(sheng[yongsin.gusin], yongsin.gisin);
        }
        expect(yongsin.reasoning, isNotEmpty);
        expect(strength.detail, isNotEmpty);
      }
    });

    test('PHASE 2 결과 없이 PHASE 3만 단독 호출하면 StateError가 발생한다'
        ' (선행조건 강제)', () {
      final phase1Only = ManseryeokCoreEngine.buildProfile(
        year: 1990,
        month: 5,
        day: 15,
        hour: 10,
        gender: 'male',
        calendarType: CalendarInputType.solar,
      );
      expect(
        () => Phase3AnalysisEngine.analyze(baseProfile: phase1Only),
        throwsA(isA<StateError>()),
      );
    });
  });
}
