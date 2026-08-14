import 'package:flutter/material.dart';

import '../../home/domain/jeontong_eighty_matrix.dart';
import '../domain/history_readonly_adapter.dart';

/// [정통사주 히스토리 섹션 뷰] 사용자 히스토리 Read-Only 화면의 "정통사주" 탭
/// 본문 — [JeontongHistoryStore]에 누적된 결과 이력을 8개 섹션(A~H)
/// ExpansionTile 그룹으로 펼침/접침 표시하고, 카드 탭 시 80종 결과 화면으로
/// 재진입시킨다.
///
/// [STEP 0 raw 확인 결과 - 계약 교정]
/// · [HistoryReadOnlyEntry]에는 categoryId 전용 필드가 없다. 실제로는
///   [JeontongHistoryStore.record]가 `id: '$categoryId-$userId-$epoch'`
///   형식으로 id를 구성하므로, 이 뷰는 `entry.id.split('-').first`로
///   categoryId(및 섹션 문자 = 그 첫 글자)를 역산한다.
/// · [CRITICAL] `lib/core/router/app_router.dart`의
///   `case JeontongEightyMatrix.resultRoute:`는
///   `JeontongEightyResultScreen(categoryId: settings.arguments as String?)`
///   로 **String만** 캐스팅한다. Map 인자를 넘기면 즉시 런타임
///   TypeError가 발생하므로, 이 뷰의 카드 탭 시에는 반드시 categoryId
///   String **단독**을 arguments로 전달한다(기존 [JeontongEightyScreen]/
///   [JeontongEightyGridScreen]과 동일한 네비게이션 계약 재사용).
/// · [userId] 필드는 호출부(history_readonly_screen.dart)와의 시그니처
///   계약상 보관하지만, 결과 라우트는 자체 initState에서
///   AuthTokenStore로 사용자ID를 다시 구하므로 이 뷰의 네비게이션에는
///   사용하지 않는다(전달 불필요 — 이중 관리 방지).
///
/// dart:io/HTTP/Socket/File/Random/DateTime.now() 호출 0건 — 오직
/// `entry.createdAt`(이미 계산된 값)만 표시한다(read-only 원칙).
class HistoryJeontongSectionedView extends StatelessWidget {
  const HistoryJeontongSectionedView({
    super.key,
    required this.entries,
    required this.userId,
  });

  final List<HistoryReadOnlyEntry> entries;

  /// 호출부 시그니처 계약 보존용 — 이 뷰의 네비게이션 로직에는 사용되지
  /// 않는다(위 클래스 문서 참고).
  final String userId;

  static const _sectionLetters = <String>[
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
  ];

  /// entry.id(`'$categoryId-$userId-$epoch'`)에서 categoryId만 역산.
  /// categoryId 자체에는 하이픈이 없으므로(예: 'A01') 안전하다.
  String _categoryIdOf(HistoryReadOnlyEntry entry) =>
      entry.id.split('-').first;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('결과가 아직 없습니다'));
    }

    // 섹션(A~H)별 그룹핑. 알 수 없는 첫 글자는 안전하게 무시한다(assert 없음).
    final Map<String, List<HistoryReadOnlyEntry>> bySection = {
      for (final l in _sectionLetters) l: <HistoryReadOnlyEntry>[],
    };
    for (final entry in entries) {
      final categoryId = _categoryIdOf(entry);
      if (categoryId.isEmpty) continue;
      final letter = categoryId[0].toUpperCase();
      final bucket = bySection[letter];
      if (bucket == null) continue; // A~H 외 글자 → 폴백 무시
      bucket.add(entry);
    }
    // 섹션 내부는 categoryId 오름차순 정렬(결정론적 표시 순서).
    for (final bucket in bySection.values) {
      bucket.sort((a, b) => _categoryIdOf(a).compareTo(_categoryIdOf(b)));
    }

    final sectionsWithData = _sectionLetters
        .where((l) => bySection[l]!.isNotEmpty)
        .toList(growable: false);

    if (sectionsWithData.isEmpty) {
      return const Center(child: Text('결과가 아직 없습니다'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sectionsWithData.length,
      itemBuilder: (context, index) {
        final letter = sectionsWithData[index];
        final sectionEntries = bySection[letter]!;
        return _JeontongSectionTile(
          sectionLetter: letter,
          entries: sectionEntries,
          categoryIdOf: _categoryIdOf,
          initiallyExpanded: letter == 'A',
        );
      },
    );
  }
}

class _JeontongSectionTile extends StatelessWidget {
  const _JeontongSectionTile({
    required this.sectionLetter,
    required this.entries,
    required this.categoryIdOf,
    required this.initiallyExpanded,
  });

  final String sectionLetter;
  final List<HistoryReadOnlyEntry> entries;
  final String Function(HistoryReadOnlyEntry) categoryIdOf;
  final bool initiallyExpanded;

  void _openResult(BuildContext context, HistoryReadOnlyEntry entry) {
    // [CRITICAL 계약 준수] arguments는 categoryId String 단독만 전달한다.
    Navigator.of(context).pushNamed(
      JeontongEightyMatrix.resultRoute,
      arguments: categoryIdOf(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text('$sectionLetter · ${entries.length}건'),
        subtitle: Text(entries.first.subtitle),
        children: [
          for (final entry in entries)
            ListTile(
              title: Text(entry.title),
              subtitle: Text(
                '$sectionLetter · ${entry.createdAt.toIso8601String()} UTC',
              ),
              onTap: () => _openResult(context, entry),
            ),
        ],
      ),
    );
  }
}
