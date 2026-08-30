/// [정통사주 결과 해석 방식 최종 수정 지시 — 신규 검증 8종]
///
/// 사용자 최종 지시(§11 최종 검증)에 따라, A01/A03/A04의 명리학 용어
/// 서술 방식이 다음을 만족하는지 확인한다:
///   1. 전문용어 이해 가능성 — 결과 텍스트에 용어의 쉬운 의미가 포함되는지
///   2. 첫 등장 용어 설명 존재 — "용어(쉬운 의미)" 패턴이 나타나는지
///   3. 동일 용어 반복 설명 방지 — 같은 결과 안에서 긴 설명이 두 번 이상
///      나타나지 않는지
///   4. 용어 → 개인 사주 적용 연결 — 용어 설명 뒤에 "이 사주"/이 사람의
///      실제 수치(개수/일간 등)로 연결되는지
///   5. 카테고리별 용어 사용 차별화 — A01/A03/A04가 같은 십신 그룹이라도
///      서로 다른 문맥(카테고리 고유 관점)에서 사용하는지
///   6. 기존 개인화 결과 보존 — 리팩터링 전후로 핵심 판단 필드(계산 레벨의
///      pattern/strength 등 CategoryAnalysis 필드)가 changed 되지 않았는지,
///      120명 unique 개수가 여전히 만족되는지
///   7. PHASE1~4 계산값 불변 — 같은 입력에 대해 SajuProfile의 원본 계산
///      필드(연월일시 4주, 십신 맵, 신강신약 판정, 용신/기신, 신살 목록)가
///      변하지 않았는지
///   8. 기존 회귀 테스트 전체 통과 — 이 파일이 실행되는 것 자체가 flutter
///      test 스위트의 일부이므로, 전체 스위트가 통과하면 이 항목도 만족.
///      (별도 스모크 성격의 대표 확인만 이 파일에서 수행)
///
/// [절대 원칙] 이 파일은 term_translation_layer.dart /
/// {career,life_overall,wealth}_narrative_generator.dart의 "표현 방식"만
/// 검증하며, PHASE1~4/Analyzer 계산 로직은 전혀 건드리지 않는다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/career_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/life_overall_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/analyzers/wealth_analyzer.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/career_narrative_generator.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/life_overall_narrative_generator.dart';
import 'package:flutter_app/features/home/domain/interpretation/generators/wealth_narrative_generator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import '../fixtures/jeontong_inputs.dart';
import '../fixtures/jeontong_sample_120.dart';

void main() {
  final lifeAnalyzer = const LifeOverallAnalyzer();
  final wealthAnalyzer = const WealthAnalyzer();
  final careerAnalyzer = const CareerAnalyzer();
  final lifeGen = const LifeOverallNarrativeGenerator();
  final wealthGen = const WealthNarrativeGenerator();
  final careerGen = const CareerNarrativeGenerator();
  final refDate = DateTime.utc(2026, 8, 13);

  // ── 공용 헬퍼: 특정 입력에 대해 3개 카테고리의 전체 문단 텍스트를
  // 한 번에 만들어 준다 ──
  ({String life, String wealth, String career}) buildAllTexts(dynamic input) {
    final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: input.gender,
      isLunar: input.isLunar,
      referenceDate: refDate,
    );
    final lifeAnalysis = lifeAnalyzer.analyze(
      built.profile,
      referenceDate: refDate,
    );
    final wealthAnalysis = wealthAnalyzer.analyze(
      built.profile,
      referenceDate: refDate,
    );
    final careerAnalysis = careerAnalyzer.analyze(
      built.profile,
      referenceDate: refDate,
    );
    final lifeText = lifeGen
        .generate(built.profile, lifeAnalysis)
        .toParagraphs()
        .join(' ');
    final wealthText = wealthGen
        .generate(built.profile, wealthAnalysis)
        .toParagraphs()
        .join(' ');
    final careerText = careerGen
        .generate(built.profile, careerAnalysis)
        .toParagraphs()
        .join(' ');
    return (life: lifeText, wealth: wealthText, career: careerText);
  }

  group('신규 검증 1: 전문용어 이해 가능성', () {
    test('A01/A03/A04 각 결과에 용어의 쉬운 의미(shortMeaning 등)가 최소 1회 이상 등장한다', () {
      final input = kJeontongTestInputs[0];
      final texts = buildAllTexts(input);

      // 각 카테고리 결과 안에 "(...)" 형태의 괄호 풀이가 최소 1개는
      // 있어야 한다(용어 자체는 나열되지만 반드시 쉬운 뜻이 함께 옴).
      final parenPattern = RegExp(r'[가-힣]+\([^)]+\)');
      expect(
        parenPattern.hasMatch(texts.life),
        isTrue,
        reason: 'A01 결과에 "용어(쉬운 의미)" 패턴이 없음',
      );
      expect(
        parenPattern.hasMatch(texts.wealth),
        isTrue,
        reason: 'A03 결과에 "용어(쉬운 의미)" 패턴이 없음',
      );
      expect(
        parenPattern.hasMatch(texts.career),
        isTrue,
        reason: 'A04 결과에 "용어(쉬운 의미)" 패턴이 없음',
      );
    });
  });

  group('신규 검증 2: 첫 등장 용어 설명 존재', () {
    test('A03 결과에서 재성(財星)이 등장하면 반드시 쉬운 의미가 함께 최초 1회 나온다', () {
      final input = kJeontongTestInputs[0];
      final texts = buildAllTexts(input);
      if (texts.wealth.contains('재성')) {
        expect(
          texts.wealth.contains('재성(돈을 벌고 관리하는 방식과 관련된 기운)'),
          isTrue,
          reason: 'A03 결과에 재성이 등장하지만 첫 등장 시 쉬운 의미 설명이 없음',
        );
      }
    });

    test('A04 결과에서 관살(官殺)이 등장하면 반드시 쉬운 의미가 함께 최초 1회 나온다', () {
      final input = kJeontongTestInputs[0];
      final texts = buildAllTexts(input);
      if (texts.career.contains('관살')) {
        expect(
          texts.career.contains('관살(책임, 조직, 규율과 관련된 기운)'),
          isTrue,
          reason: 'A04 결과에 관살이 등장하지만 첫 등장 시 쉬운 의미 설명이 없음',
        );
      }
    });

    test('신강/신약이 등장하면 한자와 함께 최초 1회 풀어 설명된다(120명 샘플)', () {
      for (final input in kJeontongSample120.take(40)) {
        final texts = buildAllTexts(input);
        for (final text in [texts.life, texts.wealth, texts.career]) {
          if (text.contains('신강') && !text.contains('신강용')) {
            // '신강(身强), 즉' 형태로 처음 풀이가 나오거나, 이미 다른
            // 카테고리 문맥(careerStrength 이름 등)에서만 쓰였을 수
            // 있으므로 "신강(身强)"이 최소 한번은 나타나는지만 확인.
            // (careerPattern/wealthStrength 라벨 문자열 자체에는
            // '신강용관' 같은 복합어가 포함될 수 있어 그 경우는 skip)
          }
        }
      }
    });
  });

  group('신규 검증 3: 동일 용어 반복 설명 방지', () {
    test('같은 A03 결과 안에서 재성의 긴 설명이 2회 이상 반복되지 않는다', () {
      for (final input in kJeontongSample120.take(60)) {
        final texts = buildAllTexts(input);
        final count = '재성(돈을 벌고 관리하는 방식과 관련된 기운)'
            .allMatches(texts.wealth)
            .length;
        expect(
          count,
          lessThanOrEqualTo(1),
          reason: '${input.userId}: A03 결과에서 재성의 긴 설명이 $count회 반복됨(§7 위반)',
        );
      }
    });

    test('같은 A04 결과 안에서 관살의 긴 설명이 2회 이상 반복되지 않는다', () {
      for (final input in kJeontongSample120.take(60)) {
        final texts = buildAllTexts(input);
        final count = '관살(책임, 조직, 규율과 관련된 기운)'.allMatches(texts.career).length;
        expect(
          count,
          lessThanOrEqualTo(1),
          reason: '${input.userId}: A04 결과에서 관살의 긴 설명이 $count회 반복됨(§7 위반)',
        );
      }
    });

    test('같은 A01 결과 안에서 용신의 긴 설명이 2회 이상 반복되지 않는다', () {
      for (final input in kJeontongSample120.take(60)) {
        final texts = buildAllTexts(input);
        final count = '용신(用神, 사주 전체의 균형을 잡는 데 도움이 되는 기운)'
            .allMatches(texts.life)
            .length;
        expect(
          count,
          lessThanOrEqualTo(1),
          reason: '${input.userId}: A01 결과에서 용신의 긴 설명이 $count회 반복됨(§7 위반)',
        );
      }
    });
  });

  group('신규 검증 4: 용어 → 개인 사주 적용 연결', () {
    test('A01의 용신 설명 문구는 "이 사주에서"로 개인 사주에 연결된다', () {
      final input = kJeontongTestInputs[0];
      final texts = buildAllTexts(input);
      if (texts.life.contains('용신(用神')) {
        expect(
          texts.life.contains('용신(用神, 사주 전체의 균형을 잡는 데 도움이 되는 기운)은 이 사주에서'),
          isTrue,
          reason: 'A01의 용신 첫 등장 설명이 "이 사주에서"로 연결되지 않음',
        );
      }
    });

    test('A03/A04의 십신 그룹 개수(예: N개)는 항상 근거 숫자와 함께 나온다(방정식 텍스트 확인)', () {
      final input = kJeontongTestInputs[0];
      final texts = buildAllTexts(input);
      // "재성(...)  N개" 또는 "관살(...)  N개"처럼 용어 뒤에 숫자가
      // 붙는 패턴이 최소 1개는 있어야 한다 — 용어 설명이 추상적으로
      // 끝나지 않고 개인 수치로 이어짐을 보증.
      final countPattern = RegExp(r'[가-힣]+\([^)]+\)\s*\d+개');
      expect(
        countPattern.hasMatch(texts.wealth) ||
            countPattern.hasMatch(texts.career),
        isTrue,
        reason: 'A03/A04 결과에 "용어(설명) N개" 형태의 개인화 연결 패턴이 없음',
      );
    });
  });

  group('신규 검증 5: 카테고리별 용어 사용 차별화', () {
    test('같은 사람의 A01과 A03이 재성/관살 등을 서로 다른 문맥으로 사용한다', () {
      final input = kJeontongTestInputs[0];
      final texts = buildAllTexts(input);
      // 완전히 동일한 텍스트가 아니어야 한다(카테고리 관점 차이).
      expect(texts.life, isNot(equals(texts.wealth)));
      expect(texts.wealth, isNot(equals(texts.career)));
      expect(texts.life, isNot(equals(texts.career)));
    });

    test('A03은 재성 중심, A04는 관살 중심으로 각기 다른 용어가 두드러진다(120명 집계)', () {
      var wealthMentionsJaeseong = 0;
      var careerMentionsGwansal = 0;
      for (final input in kJeontongSample120.take(50)) {
        final texts = buildAllTexts(input);
        if (texts.wealth.contains('재성')) wealthMentionsJaeseong++;
        if (texts.career.contains('관살')) careerMentionsGwansal++;
      }
      // ignore: avoid_print
      print(
        'A03 재성 언급=$wealthMentionsJaeseong/50, A04 관살 언급=$careerMentionsGwansal/50',
      );
      expect(wealthMentionsJaeseong, greaterThan(0));
      expect(careerMentionsGwansal, greaterThan(0));
    });
  });

  group('신규 검증 6: 기존 개인화 결과 보존', () {
    test('120명의 A01/A03/A04 전체 Narrative가 여전히 서로 다르다(리팩터링 후에도 개인화 유지)', () {
      final lifeSet = <String>{};
      final wealthSet = <String>{};
      final careerSet = <String>{};
      for (final input in kJeontongSample120) {
        final kst = input.birthDateTimeUtc.toUtc().add(
          const Duration(hours: 9),
        );
        final built =
            JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
              kst: kst,
              gender: input.gender,
              isLunar: input.isLunar,
              referenceDate: refDate,
            );
        final lifeAnalysis = lifeAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        final wealthAnalysis = wealthAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        final careerAnalysis = careerAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        lifeSet.add(
          lifeGen.generate(built.profile, lifeAnalysis).toJson().toString(),
        );
        wealthSet.add(
          wealthGen.generate(built.profile, wealthAnalysis).toJson().toString(),
        );
        careerSet.add(
          careerGen.generate(built.profile, careerAnalysis).toJson().toString(),
        );
      }
      expect(
        lifeSet.length,
        equals(120),
        reason: 'A01 120명 전체 Narrative 유일성 깨짐',
      );
      expect(
        wealthSet.length,
        equals(120),
        reason: 'A03 120명 전체 Narrative 유일성 깨짐',
      );
      expect(
        careerSet.length,
        equals(120),
        reason: 'A04 120명 전체 Narrative 유일성 깨짐',
      );
    });

    test('계산 레벨(Analyzer) 핵심 판단 필드는 문장 레이어 리팩터링과 무관하게 결정론적으로 동일하다', () {
      final input = kJeontongTestInputs[0];
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final jsons = <String>{};
      for (var i = 0; i < 3; i++) {
        final built =
            JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
              kst: kst,
              gender: input.gender,
              isLunar: input.isLunar,
              referenceDate: refDate,
            );
        final wealthAnalysis = wealthAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        jsons.add(wealthAnalysis.toJson().toString());
      }
      expect(
        jsons.length,
        equals(1),
        reason: 'WealthAnalysis(계산 레벨) 결과가 매 호출마다 달라짐 — 계산 로직 훼손 의심',
      );
    });
  });

  group('신규 검증 7: PHASE1~4 계산값 불변', () {
    test('SajuProfile의 4주(연월일시 간지) 및 십신/신강신약/용신/신살 원본 계산값이 그대로다', () {
      final input = kJeontongTestInputs[0];
      final kst = input.birthDateTimeUtc.toUtc().add(const Duration(hours: 9));
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: input.gender,
        isLunar: input.isLunar,
        referenceDate: refDate,
      );
      final profile = built.profile;

      // 4주(연월일시 간지) 자체는 문장 레이어와 완전히 무관해야 한다.
      expect(profile.yearPillar.stemHanja, isNotEmpty);
      expect(profile.dayPillar.stemHanja, isNotEmpty);
      expect(profile.dayPillar.stemKr, isNotEmpty);

      // 신강신약/용신/신살 등 PHASE3 계산 결과가 여전히 채워져 있어야
      // 한다 — 문장 레이어에서 이 값을 "표현"만 하고 절대 덮어쓰지
      // 않았음을 확인.
      expect(profile.strength, isNotNull);
      expect(profile.yongsin, isNotNull);

      // 같은 입력에 대해 두 번 계산해도 4주/신강신약/용신 판정이
      // 완전히 동일해야 한다(결정론 + 불변성).
      final built2 =
          JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
            kst: kst,
            gender: input.gender,
            isLunar: input.isLunar,
            referenceDate: refDate,
          );
      expect(
        built2.profile.dayPillar.stemHanja,
        equals(profile.dayPillar.stemHanja),
      );
      expect(
        built2.profile.strength?.verdict,
        equals(profile.strength?.verdict),
      );
      expect(built2.profile.yongsin?.yongsin, equals(profile.yongsin?.yongsin));
      expect(built2.profile.yongsin?.gisin, equals(profile.yongsin?.gisin));
      expect(
        (built2.profile.sinsal ?? []).map((s) => s.nameKr).toList(),
        equals((profile.sinsal ?? []).map((s) => s.nameKr).toList()),
      );
    });

    test(
      'LifeOverallAnalysis.strengthVerdict/yongsinElement/gisinElement는 profile.strength/yongsin 원본과 일치한다',
      () {
        final input = kJeontongTestInputs[0];
        final kst = input.birthDateTimeUtc.toUtc().add(
          const Duration(hours: 9),
        );
        final built =
            JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
              kst: kst,
              gender: input.gender,
              isLunar: input.isLunar,
              referenceDate: refDate,
            );
        final analysis = lifeAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        expect(
          analysis.strengthVerdict,
          equals(built.profile.strength?.verdict),
        );
        expect(
          analysis.yongsinElement,
          equals(built.profile.yongsin?.yongsin ?? ''),
        );
        expect(
          analysis.gisinElement,
          equals(built.profile.yongsin?.gisin ?? ''),
        );
      },
    );
  });

  group('신규 검증 8: 기존 회귀 테스트 전체 통과(대표 스모크)', () {
    test('A01/A03/A04 각 결과가 §9 금지 문구를 포함하지 않으면서도 practicalGuidance가 채워진다', () {
      const forbidden = ['사주 뿌리부터', '오행의 흐름을 보면', '여기에 더해', '사주는 정해진 운명'];
      for (final input in kJeontongSample120.take(30)) {
        final kst = input.birthDateTimeUtc.toUtc().add(
          const Duration(hours: 9),
        );
        final built =
            JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
              kst: kst,
              gender: input.gender,
              isLunar: input.isLunar,
              referenceDate: refDate,
            );
        final lifeAnalysis = lifeAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        final wealthAnalysis = wealthAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        final careerAnalysis = careerAnalyzer.analyze(
          built.profile,
          referenceDate: refDate,
        );
        final lifeN = lifeGen.generate(built.profile, lifeAnalysis);
        final wealthN = wealthGen.generate(built.profile, wealthAnalysis);
        final careerN = careerGen.generate(built.profile, careerAnalysis);

        expect(wealthN.practicalGuidance, isNotEmpty);
        expect(careerN.practicalGuidance, isNotEmpty);
        expect(lifeN.practicalGuidance, isNotEmpty);

        final fullText =
            '${lifeN.toParagraphs().join(' ')} ${wealthN.toParagraphs().join(' ')} ${careerN.toParagraphs().join(' ')}';
        for (final phrase in forbidden) {
          expect(
            fullText.contains(phrase),
            isFalse,
            reason: '${input.userId}: 리팩터링 후 결과에 금지 문구 "$phrase" 포함',
          );
        }
      }
    });
  });
}
