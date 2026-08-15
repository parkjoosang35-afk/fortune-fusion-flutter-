// [미션 3 · 21종 플레이스홀더 UX 안전장치] 회귀 검증 테스트.
// (2026-08-15 갱신: B02~B10이 PHASE1~4 기반 실계산으로 전환되어 44→35)
// (2026-08-15 갱신: C06~C10이 세운 간지 기반 실계산으로 전환되어 35→30)
// (2026-08-15 갱신: D04/D10이 실계산으로 전환되어 30→28)
// (2026-08-15 갱신: F03~F08/F10이 실계산으로 전환되어 28→21, F09만 잔류)
// (2026-08-15 갱신: G03/G05/G06/G08/G10이 실계산으로 전환되어 21→16,
//  G07/G09만 잔류)
// (2026-08-15 갱신: F09가 A07 자녀성 배정 + B05 대운 타임라인 패턴으로
//  실계산 전환되어 16→15)
// (2026-08-15 갱신: E08/E09/E10(띠 궁합/오행 궁합/겉속궁합)이 자기참조형
//  계산으로 실계산 전환되어 15→12 — 상대방 사주 없이 본인 사주만으로
//  계산 가능하다고 재검토 판정됨. E01~E07은 여전히 상대 사주 필요로
//  플레이스홀더 유지)
// (2026-08-15 갱신: G07(정신 건강 취약도)이 PHASE2의 원진·귀문 관계 +
//  화·수 과다 오행 심리 성향 조합으로 실계산 전환되어 12→11 — G09만 잔류)
//
// `kJeontongPlaceholderCategoryIds`(jeontong_eighty_calculator.dart)는
// `_categoryIndex` 매핑을 사람이 직접 대조해서 만든 정적 Set이므로, 향후
// `_categoryIndex`가 수정(플레이스홀더 → 실계산 전환 등)될 때 이 목록이
// 함께 갱신되지 않으면 결과 화면의 톤다운 배지가 잘못된 카테고리에 뜨거나
// (또는 떠야 할 곳에 안 뜨는) 조용한 버그가 생긴다.
//
// 이 테스트는 실제 `runJeontongCategory()`를 80종 전부 실행해, 그 결과가
// "플레이스홀더 형태"(`{"message": ...}` 또는 `{"note": "상대 사주 필요"}`
// 단일 키)인지를 직접 판정하고, 그 판정 결과가 `kJeontongPlaceholderCategoryIds`
// 목록과 정확히 일치하는지 대조한다 — 목록이 실제 동작과 어긋나는 순간
// 이 테스트가 실패한다.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/features/home/domain/jeontong_eighty_calculator.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/saju_engine.dart';
import 'package:flutter_app/features/home/domain/saju_fortune_rules.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';

bool _isPlaceholderResult(JeontongCategoryResult result) {
  final keys = result.data.keys.toSet();
  return keys.length == 1 && (keys.single == 'message' || keys.single == 'note');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SajuRules.resetForTest();
    SajuFortuneRules.resetForTest();
    await SajuRules.preload();
    await SajuFortuneRules.preload();
  });

  test('kJeontongPlaceholderCategoryIds는 정확히 11개', () {
    expect(kJeontongPlaceholderCategoryIds.length, 11);
  });

  test('kJeontongPlaceholderCategoryIds는 JeontongEightyMatrix의 유효한 id만 포함', () {
    final validIds = JeontongEightyMatrix.all.map((e) => e.id).toSet();
    for (final id in kJeontongPlaceholderCategoryIds) {
      expect(validIds.contains(id), isTrue, reason: '$id 는 존재하지 않는 카테고리 id');
    }
  });

  test('80종 전체: 플레이스홀더 판정 결과가 kJeontongPlaceholderCategoryIds와 정확히 일치', () {
    final saju = SajuEngine.calculate(
      year: 1972,
      month: 2,
      day: 13,
      hour: 2,
      minute: 0,
      gender: 'male',
      isLunar: false,
      referenceDate: DateTime.utc(2026, 8, 13),
    );
    final interp = SajuInterpreter.fullInterpretation(saju);
    final ctx = JeontongCalcContext(
      saju: saju,
      interp: interp,
      rules: SajuFortuneRules.cachedOrNull!,
      referenceDate: DateTime.utc(2026, 8, 13),
    );

    final actualPlaceholders = <String>{};
    for (final entry in JeontongEightyMatrix.all) {
      final result = runJeontongCategory(entry.id, ctx);
      if (_isPlaceholderResult(result)) {
        actualPlaceholders.add(entry.id);
      }
    }

    expect(
      actualPlaceholders,
      kJeontongPlaceholderCategoryIds,
      reason: '실제 계산 결과의 플레이스홀더 집합과 kJeontongPlaceholderCategoryIds 목록이 어긋남 — '
          '_categoryIndex가 수정됐다면 이 목록도 함께 갱신해야 함.',
    );
  });
}
