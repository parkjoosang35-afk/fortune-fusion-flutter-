import 'package:flutter/material.dart';

import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_ui_kit.dart';

/// F · Friend list — `/guinji/m/:mapId/friends`
///
/// [design_handoff_guinji_web/Guinji Section.html] 1914~2031줄 마크업을
/// 재현한다. 점수 정렬된 참여자 랭킹 리스트 + 관계유형 필터 칩. 탭 시
/// [onFriendTap] 콜백으로 N(Node Sheet) 등 상세화면 연결(상위 라우팅
/// 위임).
class GuinjiFriendListScreen extends StatefulWidget {
  const GuinjiFriendListScreen({
    super.key,
    this.friends = _defaultFriends,
    this.onFriendTap,
  });

  static const routeName = '/guinji/m/friends';

  final List<GuinjiFriendEntry> friends;
  final void Function(GuinjiFriendEntry entry)? onFriendTap;

  @override
  State<GuinjiFriendListScreen> createState() =>
      _GuinjiFriendListScreenState();
}

/// 친구 랭킹 한 행의 데이터.
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

/// HTML 마크업(1951~2021줄) 그대로 이식한 목데이터 6명.
const _defaultFriends = [
  GuinjiFriendEntry(
    rank: 1,
    name: '수아',
    relationKey: 'CHEON_GWII',
    ohaengLabel: '火 오행',
    score: 92,
  ),
  GuinjiFriendEntry(
    rank: 2,
    name: '민서',
    relationKey: 'NA_SALRIDA',
    ohaengLabel: '木 오행',
    score: 88,
  ),
  GuinjiFriendEntry(
    rank: 3,
    name: '도윤',
    relationKey: 'GACHI_BICH',
    ohaengLabel: '金 오행',
    score: 84,
  ),
  GuinjiFriendEntry(
    rank: 4,
    name: '유진',
    relationKey: 'JORYEOK',
    ohaengLabel: '水 오행',
    score: 81,
  ),
  GuinjiFriendEntry(
    rank: 5,
    name: '하늘',
    relationKey: 'KKEURIDA',
    ohaengLabel: '木 오행',
    score: 76,
  ),
  GuinjiFriendEntry(
    rank: 6,
    name: '지호',
    relationKey: 'JAGEUKJE',
    ohaengLabel: '金 오행',
    score: 67,
  ),
];

/// [귀인지도 실구현] [GuinjiProvider.people]을 실제 점수 내림차순으로
/// 정렬해 순위(1..N)를 부여하고, [GuinjiPerson.ohaeng](mok/hwa/to/geum/su)를
/// 화면 표시용 한자 라벨(예: '火 오행')로 변환한 [GuinjiFriendEntry] 목록을
/// 만든다. F화면의 `_defaultFriends` 목데이터를 대체한다.
List<GuinjiFriendEntry> guinjiFriendEntriesFromPeople(
  List<GuinjiPerson> people,
) {
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
  int _filterIndex = 0;

  List<String> get _filterLabels {
    final total = widget.friends.length;
    final cheon = widget.friends
        .where((f) => f.relationKey == 'CHEON_GWII')
        .length;
    final joryeok = widget.friends
        .where((f) => f.relationKey == 'JORYEOK')
        .length;
    final kkeurida = widget.friends
        .where((f) => f.relationKey == 'KKEURIDA')
        .length;
    return ['전체 $total', '貴 $cheon', '助 $joryeok', '緣 $kkeurida'];
  }

  static const _filterRelationKeys = [null, 'CHEON_GWII', 'JORYEOK', 'KKEURIDA'];

  List<GuinjiFriendEntry> get _filtered {
    final key = _filterRelationKeys[_filterIndex];
    if (key == null) return widget.friends;
    return widget.friends.where((f) => f.relationKey == key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final labels = _filterLabels;
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.6),
        bgOpacity: 0.10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GuinjiTopBar(
              breadcrumb: 'F · FRIENDS',
              onBack: () => Navigator.of(context).maybePop(),
              trailing: GuinjiIconButton(icon: '⋯', onPressed: () {}),
            ),
            // [렌더 버그 수정 — L 화면과 동일한 패턴] 줄바꿈(`\n`)과 색상이
            // 다른 TextSpan을 한 Text.rich 트리에 섞으면 Flutter Web
            // (CanvasKit)에서 첫 줄 글리프가 깨지는 문제가 있어, 줄바꿈이
            // 들어가는 첫 줄을 별도 Text로 분리한다.
            const Text(
              '내 곁의',
              style: TextStyle(
                fontFamily: GuinjiFonts.display,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.3,
                letterSpacing: -0.4,
                color: GuinjiColors.textPrimary,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [guinjiAccentSpan('귀인 랭킹')],
                style: const TextStyle(
                  fontFamily: GuinjiFonts.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  letterSpacing: -0.4,
                  color: GuinjiColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: labels.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) => GuinjiChip(
                  label: labels[i],
                  active: _filterIndex == i,
                  onTap: () => setState(() => _filterIndex = i),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final entry = _filtered[i];
                  return _FriendRow(
                    entry: entry,
                    onTap: () => widget.onFriendTap?.call(entry),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.friend-row` — 순위 + 아바타(관계 한자) + 이름/라벨 + 점수.
class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.entry, this.onTap});

  final GuinjiFriendEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[entry.relationKey];
    final color = meta?.color ?? GuinjiColors.lavender;
    final label = meta?.label ?? entry.relationKey;
    final hanja = meta?.hanja ?? '?';

    return Material(
      color: GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  entry.rank.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.25),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Text(
                  hanja,
                  style: TextStyle(
                    fontFamily: GuinjiFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontFamily: GuinjiFonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: GuinjiColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: label,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: ' · ${entry.ohaengLabel}'),
                        ],
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: GuinjiColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.score}',
                style: TextStyle(
                  fontFamily: GuinjiFonts.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
