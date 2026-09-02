import 'package:flutter/material.dart';

import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// F · Friend list — `/guinji-map/m/friends`
///
/// [2026-09 새 디자인 리스킨] 새 디자인 zip
/// `lib/guiindo/screens/friend_list_screen.dart` + `lib/guiindo/widgets/
/// friend_row.dart` 구조를 이식했다. 탭 시 [onFriendTap] 콜백으로 N(Node
/// Sheet) 등 상세화면 연결(상위 라우팅 위임).
///
/// [필터 체계 전환] 기존 3개 특정 관계키(貴/助/緣) 필터를, 새 디자인과
/// 동일한 4대 카테고리(전체/귀인/인연/보완/조심, [guinjiCategoryOrder])
/// 필터로 전환했다.
class GuinjiFriendListScreen extends StatefulWidget {
  const GuinjiFriendListScreen({
    super.key,
    this.friends = _defaultFriends,
    this.onFriendTap,
  });

  static const routeName = '/guinji-map/m/friends';

  final List<GuinjiFriendEntry> friends;
  final void Function(GuinjiFriendEntry entry)? onFriendTap;

  @override
  State<GuinjiFriendListScreen> createState() => _GuinjiFriendListScreenState();
}

/// 친구 랭킹 한 행의 데이터. [app_router.dart]의 F라우트와
/// [guinjiFriendEntriesFromPeople]이 이 클래스를 그대로 사용하므로 필드
/// 구조를 절대 변경하지 않는다.
class GuinjiFriendEntry {
  const GuinjiFriendEntry({
    required this.rank,
    required this.name,
    required this.relationKey,
    required this.ohaengLabel,
    required this.score,
  });

  final int rank;
  final String name;
  final String relationKey;

  /// 예: '火 오행'.
  final String ohaengLabel;
  final int score;
}

const _defaultFriends = [
  GuinjiFriendEntry(rank: 1, name: '수아', relationKey: 'CHEON_GWII', ohaengLabel: '火 오행', score: 92),
  GuinjiFriendEntry(rank: 2, name: '민서', relationKey: 'NA_SALRIDA', ohaengLabel: '木 오행', score: 88),
  GuinjiFriendEntry(rank: 3, name: '도윤', relationKey: 'GACHI_BICH', ohaengLabel: '金 오행', score: 84),
  GuinjiFriendEntry(rank: 4, name: '유진', relationKey: 'JORYEOK', ohaengLabel: '水 오행', score: 81),
  GuinjiFriendEntry(rank: 5, name: '하늘', relationKey: 'KKEURIDA', ohaengLabel: '木 오행', score: 76),
  GuinjiFriendEntry(rank: 6, name: '지호', relationKey: 'JAGEUKJE', ohaengLabel: '金 오행', score: 67),
];

/// [귀인지도 실구현] [GuinjiProvider.people]을 실제 점수 내림차순으로
/// 정렬해 순위(1..N)를 부여하고, [GuinjiPerson.ohaeng](mok/hwa/to/geum/su)를
/// 화면 표시용 한자 라벨(예: '火 오행')로 변환한 [GuinjiFriendEntry] 목록을
/// 만든다. [app_router.dart]의 F라우트가 직접 호출하므로 시그니처를 절대
/// 변경하지 않는다.
List<GuinjiFriendEntry> guinjiFriendEntriesFromPeople(List<GuinjiPerson> people) {
  final sorted = [...people]..sort((a, b) => b.score.compareTo(a.score));
  return [
    for (var i = 0; i < sorted.length; i++)
      GuinjiFriendEntry(
        rank: i + 1,
        name: sorted[i].name,
        relationKey: sorted[i].relation,
        ohaengLabel: _ohaengLabelFor(sorted[i].ohaeng),
        score: sorted[i].score,
      ),
  ];
}

String _ohaengLabelFor(String ohaengKey) {
  final meta = guinjiOhaengTypes[ohaengKey];
  if (meta == null) return '오행';
  return '${meta.label} 오행';
}

class _GuinjiFriendListScreenState extends State<GuinjiFriendListScreen> {
  int _tab = 0;

  /// 탭 목록: 전체 + [guinjiCategoryOrder] 4개(귀인/인연/보완/조심).
  static final _tabs = ['전체', ...guinjiCategoryOrder.map((c) => c.title)];

  /// 탭 인덱스 → 카테고리 키(전체는 null).
  static final _catByIdx = <String?>[null, ...guinjiCategoryOrder.map((c) => c.key)];

  String? _categoryOf(String relationKey) => guinjiRelationTypes[relationKey]?.category;

  List<GuinjiFriendEntry> get _filtered {
    final cat = _catByIdx[_tab];
    if (cat == null) return widget.friends;
    return widget.friends.where((f) => _categoryOf(f.relationKey) == cat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(back: true, title: '참여자 ${widget.friends.length}명'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final active = _tab == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _tab = i),
                      child: GmChip(
                        label: _tabs[i],
                        background: active ? GmColors.ink : Colors.white,
                        foreground: active ? GmColors.ivory : GmColors.inkSoft,
                        borderColor: active ? GmColors.ink : GmColors.line,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            if (_filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    '해당 카테고리 참여자가 없어요',
                    style: TextStyle(fontSize: 12, color: GmColors.inkFaint),
                  ),
                ),
              )
            else
              ..._filtered.map(
                (entry) => _GmFriendRowTile(
                  entry: entry,
                  onTap: () => widget.onFriendTap?.call(entry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 새 디자인 `friend_row.dart`의 `FriendRow` 이식(라운드 카드형).
class _GmFriendRowTile extends StatelessWidget {
  const _GmFriendRowTile({required this.entry, this.onTap});

  final GuinjiFriendEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[entry.relationKey];
    final color = meta != null ? GmColors.categoryColor(meta.category) : GmColors.rose500;
    final label = meta?.label ?? entry.relationKey;
    final initial = entry.name.isNotEmpty ? entry.name.substring(0, 1) : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          border: Border.all(color: GmColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                entry.rank.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: GmColors.inkFaint,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: GmFonts.serif,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: GmColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GmChip(
                        label: label,
                        background: color.withValues(alpha: 0.1),
                        foreground: color,
                        borderColor: color.withValues(alpha: 0.2),
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meta?.short ?? ''} · ${entry.ohaengLabel}',
                    style: const TextStyle(fontSize: 10.5, color: GmColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${entry.score}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
                const Text(
                  'SCORE',
                  style: TextStyle(fontSize: 9, letterSpacing: 1, color: GmColors.inkFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
