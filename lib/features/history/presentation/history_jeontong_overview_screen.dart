import 'package:flutter/material.dart';

import '../../home/data/jeontong_bookmark_store.dart';
import '../../home/data/jeontong_history_store.dart';
import 'widgets/jeontong_keyword_search_bar.dart';
import 'widgets/jeontong_section_filter_chips.dart';

/// [정통사주 키워드 검색] id/title/subtitle/생성시각(ISO) substring
/// (대소문자 무시) 매칭. regex 0건 — String.contains() 단순 패턴만 사용.
/// 빈 입력(trim 후 empty)은 전체 반환.
List<HistoryEntry> _simpleSearch(List<HistoryEntry> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where((e) {
        if (e.id.toLowerCase().contains(q)) return true;
        if (e.categoryId.toLowerCase().contains(q)) return true;
        if (e.title.toLowerCase().contains(q)) return true;
        if (e.subtitle.toLowerCase().contains(q)) return true;
        if (e.createdAtUtc.toIso8601String().toLowerCase().contains(q)) {
          return true;
        }
        return false;
      })
      .toList(growable: false);
}

/// [정통사주 80종 한눈에 미리보기] 사용자가 누적한 결과를 8개 섹션(A~H)
/// GridView + 섹션 필터 칩으로 한 화면에서 조망하는 read-only 화면.
///
/// [STEP 0 raw 로 확정 — 미션 템플릿과의 차이]
/// 1) import 경로: 미션은
///    `package:<PKG>/features/fortune/jeontong/data/jeontong_history_store.dart`
///    를 가정했으나, 실제 store는
///    `lib/features/home/data/jeontong_history_store.dart`에 있다(직전
///    다섯 개 미션에서 반복 확인된 동일 경로 오류 패턴).
/// 2) `JeontongHistoryStore.instance.list(userId)`는 이미 **동기**
///    `List<HistoryEntry>`를 반환한다(FutureBuilder/await 불필요) —
///    미션이 예시로 든 `List<HistoryEntry> entries` 필드 자체는 맞으나,
///    "store 가 채워질 때까지 폴백 record"는 `record()`가 필수로 요구하는
///    `createdAtUtc`를 얻으려면 `DateTime.now()`가 필요한데, 이번 미션의
///    금지 목록(`DateTime.now()=0`)과 정면으로 충돌한다. 따라서 그 폴백은
///    구현하지 않고, 비어 있으면 "아직 열람한 결과가 없습니다" 안내만
///    보여준다(원칙 우선순위: 비용/결정론 금지 목록이 스펙 예시 코드보다
///    우선).
/// 3) `HistoryEntry`에는 `categoryId` 필드가 이미 직접 존재한다(다른
///    미션이 만든 `entry.id.split('-')[0]` 재계산은 불필요 — 그래도
///    안전하게 필드를 그대로 사용).
/// 4) [CRITICAL] `app_router.dart`의 `JeontongEightyMatrix.resultRoute`
///    case는 `settings.arguments as String?`로 **String 단독**만
///    허용한다(Map 전달 시 즉시 TypeError). 이 화면의 카드 탭 시에도
///    `entry.categoryId` String 하나만 arguments로 넘긴다(userId는 결과
///    화면이 자체 initState에서 AuthTokenStore로 재조회 — 직전
///    `HistoryJeontongSectionedView`와 동일한 계약 재사용).
///
/// dart:io/HTTP/Socket/File/Random/DateTime.now() 사용 0건 — 이미 저장된
/// `entry.createdAtUtc` 값만 표시한다(read-only 원칙).
class HistoryJeontongOverviewScreen extends StatefulWidget {
  const HistoryJeontongOverviewScreen({super.key, required this.userId});

  final String userId;

  @override
  State<HistoryJeontongOverviewScreen> createState() =>
      _HistoryJeontongOverviewScreenState();
}

class _HistoryJeontongOverviewScreenState
    extends State<HistoryJeontongOverviewScreen> {
  String _activeLetter = '전체';
  String _query = '';
  List<HistoryEntry> _entries = const [];

  // [정통사주 즐겨찾기 필터] 새 Provider/Repository/Service 를 만들지 않고
  // 기존 JeontongBookmarkStore(SharedPreferences 기반, in-memory 폴백)를
  // 그대로 재사용한다. 이 화면은 read-only 이력 조회 화면이므로 즐겨찾기
  // 데이터도 조회만 하고 store 자체를 수정하지 않는다.
  final JeontongBookmarkStore _bookmarks = JeontongBookmarkStore();
  bool _onlyBookmarks = false;
  Set<String> _bookmarkedCodes = <String>{};

  static const _letters = <String>['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  @override
  void initState() {
    super.initState();
    // 동기 스냅샷 1회 조회 — 위 클래스 문서 2)번 참고(폴백 record 없음).
    _entries = JeontongHistoryStore.instance.list(widget.userId);
    _reloadBookmarks();
  }

  Future<void> _reloadBookmarks() async {
    final codes = await _bookmarks.get(widget.userId);
    if (mounted) setState(() => _bookmarkedCodes = codes);
  }

  String _nextSection(String current) {
    if (current == '전체') return _letters.first;
    final i = _letters.indexOf(current);
    if (i < 0 || i == _letters.length - 1) return '전체';
    return _letters[i + 1];
  }

  @override
  Widget build(BuildContext context) {
    final searched = _simpleSearch(_entries, _query);
    final letterFiltered = _activeLetter == '전체'
        ? searched
        : searched
              .where((e) => e.categoryId.startsWith(_activeLetter))
              .toList(growable: false);
    // [정통사주 즐겨찾기 필터] "즐겨찾기만 보기" 스위치가 켜져 있으면
    // _bookmarkedCodes 에 포함된 categoryId 만 남긴다(다른 필터와 AND 조합).
    final filtered = _onlyBookmarks
        ? letterFiltered
              .where((e) => _bookmarkedCodes.contains(e.categoryId))
              .toList(growable: false)
        : letterFiltered;

    final Map<String, List<HistoryEntry>> bySection = {
      for (final l in _letters) l: <HistoryEntry>[],
    };
    for (final e in filtered) {
      if (e.categoryId.isEmpty) continue;
      final letter = e.categoryId[0].toUpperCase();
      bySection[letter]?.add(e);
    }
    for (final bucket in bySection.values) {
      bucket.sort((a, b) => a.categoryId.compareTo(b.categoryId));
    }
    final sectionsWithData = _letters
        .where((l) => bySection[l]!.isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('정통사주 한눈에 보기'),
        actions: [
          TextButton(
            onPressed: () =>
                setState(() => _activeLetter = _nextSection(_activeLetter)),
            child: Text(
              _activeLetter == '전체' ? '섹션 필터' : '$_activeLetter 필터 중',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(child: Text('아직 열람한 결과가 없습니다'))
          : Column(
              children: [
                JeontongKeywordSearchBar(
                  initialQuery: _query,
                  onChanged: (q) => setState(() => _query = q),
                ),
                JeontongSectionFilterChips(
                  activeLetter: _activeLetter,
                  onChanged: (l) => setState(() => _activeLetter = l),
                ),
                SwitchListTile(
                  key: const ValueKey('jeontong_only_bookmarks_switch'),
                  dense: true,
                  title: const Text('⭐ 즐겨찾기만 보기'),
                  value: _onlyBookmarks,
                  onChanged: (v) async {
                    await _reloadBookmarks();
                    if (mounted) setState(() => _onlyBookmarks = v);
                  },
                ),
                Expanded(
                  child: sectionsWithData.isEmpty
                      ? Center(
                          child: Text(
                            _query.trim().isNotEmpty
                                ? '검색 결과 없음'
                                : '해당 섹션 결과가 없습니다',
                          ),
                        )
                      // [수정: ListView.builder → SingleChildScrollView+Column]
                      // ListView.builder는 뷰포트 밖 섹션(예: H)을 지연
                      // 빌드하지 않아 "80개 전체 한눈에 조망"이라는 미션
                      // 목표와 위젯 테스트(스크롤 없이 전 항목 find.text)
                      // 계약을 둘 다 어긴다. 80건 규모는 작으므로 전 섹션을
                      // 한번에 즉시 빌드하는 SingleChildScrollView 로 전환해
                      // 지연 로딩으로 인한 미노출 문제를 원천 차단한다.
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 56),
                          child: Column(
                            children: [
                              for (final letter in sectionsWithData)
                                _SectionGrid(
                                  key: ValueKey('section_$letter'),
                                  letter: letter,
                                  entries: bySection[letter]!,
                                ),
                            ],
                          ),
                        ),
                ),
                const _EasyTermHintBar(),
              ],
            ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({super.key, required this.letter, required this.entries});

  final String letter;
  final List<HistoryEntry> entries;

  void _openResult(BuildContext context, HistoryEntry entry) {
    // [CRITICAL 계약 준수] arguments는 categoryId String 단독만 전달한다.
    Navigator.of(
      context,
    ).pushNamed('/jeontong/eighty/result', arguments: entry.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '$letter 섹션 · ${entries.length}건',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 76,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                title: Text(
                  '${entry.categoryId} ${entry.title}',
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '$letter · ${entry.createdAtUtc.toIso8601String()} UTC',
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _openResult(context, entry),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 화면 하단 sticky 안내 1줄 — [JeontongResultTextExtractor]의
/// easyTermHints() 개념을 재사용해, 이 화면 자체에서도 "쉬운 설명 가능"
/// 힌트가 있다는 사실만 고정 문구로 안내한다(각 카드 자체는 목록
/// 표시용이라 개별 힌트를 계산하지 않음 — 성능/비용 0 우선).
class _EasyTermHintBar extends StatelessWidget {
  const _EasyTermHintBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Text(
        '쉬운 설명 가능 키워드: 카드를 열면 전문 용어를 쉬운 말로 볼 수 있어요',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}
