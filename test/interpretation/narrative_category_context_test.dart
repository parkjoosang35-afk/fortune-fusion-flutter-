import 'package:flutter_app/features/home/domain/jeontong_eighty_calculator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_app/features/home/domain/jeontong_narrative_interpreter.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

/// [2026-08-19] 사용자 재지적: "자녀운(A07)인데 왜 리더십·창업·오행 얘기가
/// 나오냐" — 당시엔 JeontongNarrativeInterpreter.paragraphs()가 반환하는
/// 5개 문단 중 오프닝(일간 소개)·성향(오행/십신) 두 문단이 모든 카테고리에서
/// 완전히 동일한 공통 문단이라, 카테고리 고유 문단 바로 다음에 아무런
/// 맥락 연결 없이 이어지면 화제가 갑자기 바뀐 것처럼 읽혔다. 그때는
/// categoryTitle을 전환 문구에 엮어 넣는 방식으로 대응했다.
///
/// [2026-08-21 재지적 — 사용자 스크린샷: "b그룹부터 전체 다 나오는 얘기
/// 같은데 이렇게 하면 소비자가 뭐라고 하겠어" · 확정 지시 "핵심해석 밑으로
/// 잘 다듬어서"] categoryTitle을 엮어도 오프닝/성향/신살/마무리 4개 문단의
/// "내용"(일간 설명, 오행 쏠림, 신살, 나침반 비유) 자체는 여전히 모든
/// 카테고리에서 거의 동일해 "다 같은 말"로 읽히는 근본 문제가 해결되지
/// 않았다. 최종 해결책은 그 4개 공통 문단을 완전히 제거하고, 카테고리마다
/// 실제로 달라지는 [_categoryParagraph]("핵심해석") 문단 하나만 남기는
/// 것이었다(+ 각 카테고리 계산이 실제로 산출한 advice/message가 있을 때만
/// 짧은 행동지침 문단을 추가로 붙인다).
///
/// 이 테스트는 69종 카테고리 전체를 순회하며 (1) 예외 없이 문단이
/// 생성되는지, (2) 문단이 1~2개로 유지되는지(공통 문단 재추가 회귀 감시),
/// (3) §9 금지 문구(모든 카테고리에서 반복되던 고정 문구)가 다시
/// 등장하지 않는지를 회귀 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('전체 69종 카테고리 — 핵심해석 중심 1~2문단, 공통 반복 문구 없음', () async {
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();

    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: DateTime(1990, 5, 12, 10, 30),
      gender: 'male',
      isLunar: false,
      referenceDate: DateTime.utc(2026, 8, 13),
    );
    final interp = SajuInterpreter.fullInterpretation(built.saju);
    final rules = SajuFortuneRules.cachedOrNull!;
    final ctx = JeontongCalcContext(
      saju: built.saju,
      interp: interp,
      rules: rules,
      referenceDate: DateTime.utc(2026, 8, 13),
      profile: built.profile,
    );

    // [2026-08-21] B~H그룹 반복 문구 문제의 원인이었던 §9 금지 문구.
    // paragraphs()가 이 문구를 다시 만들어내면 공통 문단이 부활한
    // 회귀이므로 즉시 실패해야 한다.
    const forbiddenGenericPhrases = [
      '사주 뿌리부터',
      '오행의 흐름을 살펴보면',
      '여기에 더해',
      '사주는 정해진 운명',
    ];

    var okCount = 0;
    var failCount = 0;
    final failures = <String>[];

    for (final entry in JeontongEightyMatrix.all) {
      try {
        final data = runJeontongCategory(entry.id, ctx).data;
        final paragraphs = JeontongNarrativeInterpreter.paragraphs(
          interp,
          entry,
          name: '박주상',
          data: data,
        );

        if (paragraphs.isEmpty) {
          failures.add('${entry.id} (${entry.title}): 문단이 비어 있음');
          failCount++;
          continue;
        }
        if (paragraphs.length > 2) {
          failures.add(
            '${entry.id} (${entry.title}): 문단이 ${paragraphs.length}개로 '
            '2개 초과 — 공통 문단이 다시 붙었을 가능성',
          );
          failCount++;
          continue;
        }

        final combined = paragraphs.join(' ');
        final hitPhrase = forbiddenGenericPhrases
            .where((p) => combined.contains(p))
            .toList();
        if (hitPhrase.isNotEmpty) {
          failures.add(
            '${entry.id} (${entry.title}): 금지 문구 재등장 — ${hitPhrase.join(', ')}',
          );
          failCount++;
          continue;
        }

        okCount++;
      } catch (e) {
        failures.add('${entry.id} (${entry.title}): EXCEPTION $e');
        failCount++;
      }
    }

    expect(
      failCount,
      0,
      reason:
          '총 ${JeontongEightyMatrix.all.length}개 중 $failCount개 실패, '
          '$okCount개 통과\n${failures.join('\n')}',
    );
  });
}
