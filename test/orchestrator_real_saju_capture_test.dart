// [엔진 통합 지시문 STEP 3 — "실제 사주 엔진이 진짜 작동하는지" 검증]
//
// 이 테스트는 사용자의 핵심 질문("사주엔진이 실질적으로 움직이는지 조합을
// 해서 해석을 하는건지 엔진이 정말 역할을 하는지")에 직접 답하기 위해
// 작성되었다. Mock SajuProfile을 쓰지 않고, 실제 서비스가 호출하는 바로
// 그 함수(`JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4`,
// `guinji_provider.dart`가 실사용하는 함수와 동일)를 **실제 생년월일시
// 입력으로 호출**해 PHASE1(만세력 원국 계산)→PHASE2(오행/지장간/합충형파해)
// →PHASE3(신강신약/용신)→PHASE4(대운/세운)를 전부 실행시킨다. 이 출력이
// "고정된 Mock 값"이 아니라 "입력에 따라 실제로 달라지는 진짜 계산
// 결과"임을 서로 다른 두 생년월일로 증명한 뒤, 그 실제 계산 결과를
// [CrossCheckEngine](교차검증 판정 엔진, 역시 LLM 미개입 결정론적 코드)에
// 그대로 투입해 **진짜 판정 JSON 1건**을 생성하고 콘솔에 출력한다.
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:flutter_app/core/orchestrator/cross_check_engine.dart';
import 'package:flutter_app/core/orchestrator/cross_check_rules.dart';
import 'package:flutter_app/core/orchestrator/unified_fortune_profile.dart';
import 'package:flutter_app/features/fortune/face/domain/face_model.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';

void main() {
  group('실제 사주 엔진 동작 검증(STEP 3 — 사용자 핵심 질문 대응)', () {
    test(
      '서로 다른 두 생년월일시를 PHASE1~4 엔진에 실제로 투입하면 '
      '서로 다른 원국(팔자)/오행 카운트가 나온다 — '
      '즉, 이 엔진은 고정된 Mock이 아니라 입력에 따라 실제로 계산한다',
      () {
        final personA = JeontongReportBuilder
            .buildProfileAndSajuResultViaPhase1to4(
              kst: DateTime(1990, 3, 15, 8, 30),
              gender: 'male',
              isLunar: false,
              referenceDate: DateTime(2024, 1, 1),
            );
        final personB = JeontongReportBuilder
            .buildProfileAndSajuResultViaPhase1to4(
              kst: DateTime(1995, 11, 2, 22, 10),
              gender: 'female',
              isLunar: false,
              referenceDate: DateTime(2024, 1, 1),
            );

        // 1) 두 사람의 팔자(8글자)는 서로 달라야 한다(같은 알고리즘이
        //    같은 입력에는 같은 값을, 다른 입력에는 다른 값을 낸다는
        //    증거 — "진짜 계산 엔진"의 정의 그 자체).
        expect(
          personA.profile.dayPillar.kr,
          isNot(equals(personB.profile.dayPillar.kr)),
          reason: '서로 다른 생년월일시인데 일주(日柱)가 같다면 엔진이 입력을 '
              '무시하고 고정값을 반환하는 Mock일 가능성이 있다.',
        );

        // 2) 같은 사람(personA)을 두 번 계산하면 완전히 동일한 결과가
        //    나와야 한다(결정론성 — "같은 입력엔 항상 같은 출력").
        final personAAgain = JeontongReportBuilder
            .buildProfileAndSajuResultViaPhase1to4(
              kst: DateTime(1990, 3, 15, 8, 30),
              gender: 'male',
              isLunar: false,
              referenceDate: DateTime(2024, 1, 1),
            );
        expect(personAAgain.profile.dayPillar.kr, personA.profile.dayPillar.kr);
        expect(
          personAAgain.profile.yearPillar.kr,
          personA.profile.yearPillar.kr,
        );
        expect(
          personAAgain.profile.fiveElements!.totalCount,
          personA.profile.fiveElements!.totalCount,
        );

        // 3) Phase2~4가 실제로 값을 채웠는지(null로 비어있지 않은지)
        //    확인 — "엔진이 역할을 하는지"의 직접 증거.
        expect(personA.profile.fiveElements, isNotNull);
        expect(personA.profile.tenGods, isNotNull);
        expect(personA.profile.relationships, isNotNull);
        expect(personA.profile.strength, isNotNull);
        expect(personA.profile.yongsin, isNotNull);
        expect(personA.profile.sewoon, isNotNull);
        expect(personA.profile.sewoon, isNotEmpty);

        // 실제 계산 결과를 테스트 리포트에 남겨 눈으로 확인 가능하게 한다.
        // ignore: avoid_print
        print(
          '[실제 엔진 출력 — personA(1990-03-15 08:30 남, 양력)] '
          '팔자=${personA.profile.yearPillar.kr}년 '
          '${personA.profile.monthPillar.kr}월 '
          '${personA.profile.dayPillar.kr}일 '
          '${personA.profile.hourPillar.kr}시, '
          '오행=${personA.profile.fiveElements!.totalCount}, '
          '신강신약=${personA.profile.strength!.verdict}'
          '(점수${personA.profile.strength!.score.toStringAsFixed(3)}), '
          '용신=${personA.profile.yongsin!.yongsin}'
          '(${personA.profile.yongsin!.method}), '
          '관계=${personA.profile.relationships!.map((r) => r.type).toList()}',
        );
        // ignore: avoid_print
        print(
          '[실제 엔진 출력 — personB(1995-11-02 22:10 여, 양력)] '
          '팔자=${personB.profile.yearPillar.kr}년 '
          '${personB.profile.monthPillar.kr}월 '
          '${personB.profile.dayPillar.kr}일 '
          '${personB.profile.hourPillar.kr}시, '
          '오행=${personB.profile.fiveElements!.totalCount}',
        );
      },
    );

    test(
      '실제 사주 엔진 계산 결과 + 실사용 수준 관상 텍스트를 '
      'CrossCheckEngine에 투입하면 진짜 판정 JSON 1건이 생성된다 '
      '(캡처된 JSON을 콘솔에 출력)',
      () {
        // 실제 PHASE1~4 엔진 호출 — Mock SajuProfile이 아니다.
        final real = JeontongReportBuilder
            .buildProfileAndSajuResultViaPhase1to4(
              kst: DateTime(1988, 6, 21, 14, 5),
              gender: 'male',
              isLunar: false,
              referenceDate: DateTime(2024, 6, 1),
            );

        // 관상 결과는 AI(LLM) 출력이 저장되는 형태라서 여기서는 실사용과
        // 동일한 "자연어 요약" 형태의 대표 샘플을 투입한다 — 교차검증
        // 대상은 "사주 엔진이 실제로 계산한 값"이며, 이 테스트가 증명하려는
        // 핵심은 그 오행 계산 결과가 실제로 판정에 반영된다는 점이다.
        final face = FaceResultModel(
          id: 'capture_face_1',
          features: const {
            '이마': '넓고 둥근 이마로 적극적이고 활동적인 기운이 느껴집니다',
            '눈': '또렷한 눈매로 추진력과 열정이 강한 인상입니다',
          },
          topicResults: const {
            '직업': '진취적이고 도전적인 성향이 직업운에 긍정적으로 작용합니다',
          },
          summary: '전반적으로 적극적이고 열정적이며 추진력이 강한 인상입니다',
          createdAt: DateTime(2024, 6, 1),
        );

        final profile = UnifiedFortuneProfile(
          sajuProfile: real.profile,
          sajuResult: real.saju,
          faceResult: face,
        );

        final result =
            CrossCheckEngine.evaluateRule(const SajuFaceDriveRule(), profile)
                as CrossCheckResult;

        final json = result.toJson();
        const encoder = JsonEncoder.withIndent('  ');

        // ignore: avoid_print
        print('=== [STEP 3 — 실제 교차검증 판정 JSON 캡처] ===');
        // ignore: avoid_print
        print(encoder.convert(json));
        // ignore: avoid_print
        print('================================================');

        // 구조 검증(스키마 그대로인지).
        expect(
          json.keys.toSet(),
          {
            'ruleId',
            'pair',
            'axis',
            'verdict',
            'scoreA',
            'scoreB',
            'delta',
            'evidence',
            'sources',
          },
        );
        expect(json['ruleId'], 'saju_face_drive_v1');
        expect(json['pair'], '사주↔관상');
        expect(json['axis'], '추진력');
        // scoreA는 실제 사주 엔진이 계산한 오행 카운트에서 나온 값이며,
        // 고정 Mock이 아니라 1988-06-21 14:05 입력의 실제 목화 비중이다.
        expect(json['scoreA'], isA<double>());
        expect(
          json['scoreA'],
          real.profile.fiveElements!.totalCount.values.fold<int>(
                0,
                (a, b) => a + b,
              ) ==
              0
              ? throw StateError('오행 총합이 0이면 안 됨')
              : (((real.profile.fiveElements!.totalCount['목'] ?? 0) +
                              (real.profile.fiveElements!.totalCount['화'] ??
                                  0)) /
                          real.profile.fiveElements!.totalCount.values
                              .fold<int>(0, (a, b) => a + b) *
                          2 -
                      1)
                  .clamp(-1.0, 1.0),
        );
      },
    );
  });
}
