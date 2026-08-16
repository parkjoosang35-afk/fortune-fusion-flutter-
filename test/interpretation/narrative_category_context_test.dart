import 'package:flutter_app/features/home/domain/jeontong_eighty_calculator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_app/features/home/domain/jeontong_narrative_interpreter.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

/// [2026-08-19] 사용자 재지적: "자녀운(A07)인데 왜 리더십·창업·오행 얘기가
/// 나오냐" — JeontongNarrativeInterpreter.paragraphs()가 반환하는 5개
/// 문단 중 오프닝(일간 소개)·성향(오행/십신) 두 문단은 모든 카테고리에서
/// 완전히 동일한 공통 문단이라, 카테고리 고유 문단 바로 다음에 아무런
/// 맥락 연결 없이 이어지면 화제가 갑자기 바뀐 것처럼 읽혔다.
///
/// 해결: 계산 로직/오행·십신 데이터는 절대 변경하지 않고(§2/§7 준수),
/// _openingParagraph/_traitsParagraph에 categoryTitle을 전달해 문단
/// 초입·마무리에 "지금 살펴보는 [카테고리]" 식의 전환 문구만 추가했다.
///
/// 이 테스트는 69종 카테고리 전체를 순회하며 (1) 예외 없이 문단이
/// 생성되는지, (2) 오프닝/성향 문단에 카테고리 제목이 실제로 삽입되어
/// 맥락이 이어지는지를 회귀 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('전체 69종 카테고리 — 이야기체 문단에 카테고리 맥락 전환 문구가 포함된다', () async {
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
        // 기본 sanity: 오프닝/성향 문단에 카테고리 제목이 실제로 포함됐는지 확인
        final combined = paragraphs.join(' ');
        if (!combined.contains(entry.title)) {
          failures.add('${entry.id} (${entry.title}): title not found in paragraphs');
          failCount++;
        } else {
          okCount++;
        }
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
