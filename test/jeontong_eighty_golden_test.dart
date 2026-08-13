// 정통사주 80종 결정론 골든 스냅샷 테스트.
//
// [STEP 0 raw 로 확정한 실제 이름/시그니처 — 미션 템플릿의 가상 이름과 다름]
//   · 카탈로그: JeontongEightyMatrix.all (List<JeontongCategoryEntry>) —
//     `JeontongCategory` enum 은 존재하지 않음.
//   · 빌더: JeontongReportBuilder.build(JeontongCategoryEntry entry, {DateTime? date, ...})
//     — `JeontongEightyReportBuilder` 클래스는 존재하지 않고, 첫 인자도
//     categoryCode(String)가 아니라 entry(JeontongCategoryEntry)임.
//   · 결과 모델: FortuneReport/FortuneHero/FortuneSection 계열은 toJson()이
//     없으므로, 이 파일 내부에서 공개 필드를 직접 걷는 수동 직렬화 함수를
//     사용한다.
//   · [2026-08-13 개인화 배선] build() 가 userId/birthDateTimeUtc/gender/
//     isLunar 4축을 named+default null 로 받도록 확장되어, 이 4축을 모두
//     전달하면 결과의 keywords/list/lucky 슬롯 순서와 aspect index가
//     사용자별로 결정론적으로 달라진다(문구 콘텐츠는 불변).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/features/fortune/shared/domain/fortune_report_model.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_matrix.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/jeontong_inputs.dart';

/// 골든 재현성을 위해 반드시 고정 날짜를 사용한다.
/// JeontongReportBuilder.build() 는 date 를 넘기지 않으면 DateTime.now() 를
/// 시드에 사용하므로, 그 경우 날짜가 바뀔 때마다 골든이 깨진다.
final DateTime kFixedDate = DateTime.utc(2026, 8, 13);

void main() {
  const goldenPath = 'test/goldens/jeontong_eighty.json';

  test('jeontong 80 x 3 seeds is deterministic (golden)', () async {
    final all = <String, Map<String, dynamic>>{};

    for (final input in kJeontongTestInputs) {
      final perUser = <String, dynamic>{};
      for (final entry in JeontongEightyMatrix.all) {
        // [2026-08-13 개인화 배선] build() 가 4축(userId/birthDateTimeUtc/
        // gender/isLunar)을 받아 결정론적으로 반영하도록 확장되었으므로,
        // fixture 의 각 seed 유저 값을 실제로 전달해 개인화 계약을 검증한다.
        final report = JeontongReportBuilder.build(
          entry,
          date: kFixedDate,
          userId: input.userId,
          birthDateTimeUtc: input.birthDateTimeUtc,
          gender: input.gender,
          isLunar: input.isLunar,
        );
        perUser[entry.id] = _reportToJson(report);
      }
      all[input.userId] = perUser;
    }

    final actual = _sortedJson(all);

    final file = File(goldenPath);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      file.writeAsStringSync(actual);
      // 캡처 회차: 통과시켜 다음 실행에서 회귀 감시 시작.
      return;
    }

    final expected = file.readAsStringSync();
    expect(
      actual,
      expected,
      reason: '정통사주 결정론 스냅샷 불일치 — 시드/문자열/룰 변경이 있는지 확인.',
    );
  });
}

Map<String, dynamic> _heroToJson(FortuneHero hero) => {
  'score': hero.score,
  'headline': hero.headline,
  'name': hero.name,
  'date': hero.date.toIso8601String(),
  'statusLabel': hero.statusLabel,
  'keywords': hero.keywords,
  'subDescription': hero.subDescription,
};

Map<String, dynamic> _sectionToJson(FortuneSection section) {
  final base = <String, dynamic>{
    'type': section.type.toString(),
    'title': section.title,
    'requiresPass': section.requiresPass,
  };
  if (section is OverviewSection) {
    base['body'] = section.body;
  } else if (section is TimelineSection) {
    base['slots'] = section.slots
        .map((slot) => {'label': slot.label, 'body': slot.body})
        .toList();
  } else if (section is AspectSection) {
    base['index'] = section.index;
    base['body'] = section.body;
  } else if (section is ListSection) {
    base['items'] = section.items;
    base['isAvoid'] = section.isAvoid;
  } else if (section is LuckySection) {
    base['items'] = section.items
        .map(
          (item) => {
            'label': item.label,
            'value': item.value,
            'requiresPass': item.requiresPass,
          },
        )
        .toList();
  }
  return base;
}

Map<String, dynamic> _reportToJson(FortuneReport report) => {
  'hero': _heroToJson(report.hero),
  'sections': report.sections.map(_sectionToJson).toList(),
};

String _sortedJson(dynamic v) {
  const enc = JsonEncoder.withIndent('  ');
  final normalized = _sortKeys(v);
  return enc.convert(normalized);
}

dynamic _sortKeys(dynamic v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sortKeys(v[k])};
  }
  if (v is List) return v.map(_sortKeys).toList();
  return v;
}
