import 'package:flutter/material.dart';

import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_map_relation_detail_screen.dart';
import 'guinji_result_card_screen.dart';

/// 랭킹 — `/guinji-map/m/ranking` (`/guinji-map/*` 신규 디자인 톤).
///
/// [귀인지도 기능 정리 — 2] 신규 디자인(`/guinji-map/*`) 8화면 흐름에는
/// 랭킹 화면 진입점이 아예 없었다(기존 `GuinjiRankingScreen`은 구계열
/// `/guinji`에만 연결돼 있고, 그마저 고정 목데이터 `guinjiSamplePeople`을
/// 기본값으로 씀). 이 화면은 M(내 지도)/F(참여자 목록) 화면에서 전달받은
/// **실제 참여자 데이터**(`GuinjiProvider.people`)로 동작하며, 아이보리·
/// 로즈골드 팔레트(`GmColors`)로 새로 구현했다.
class GuinjiMapRankingScreen extends StatelessWidget {
  const GuinjiMapRankingScreen({
    super.key,
    required this.people,
    this.ownerName = '나',
  });

  static const routeName = '/guinji-map/m/ranking';

  final List<GuinjiPerson> people;

  /// [귀인지도 기능 정리 — 3, 이상한 부분] 결과 카드 공유 시 실제 지도
  /// 소유자 이름을 전달한다(하드코딩 "지민" 제거).
  final String ownerName;

  @override
  Widget build(BuildContext context) {
    final sorted = [...people]..sort((a, b) => b.score.compareTo(a.score));
    final first = sorted.isNotEmpty ? sorted[0] : null;
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;

    return Scaffold(
      backgroundColor: GmColors.bg,
      appBar: const GmTopBar(back: true, title: '케미 랭킹'),
      // [핸드오프 `RankScreen` `list.length < 3` 분기 이식] 참여자가
      // 3명 미만이면 포디움/전체순위 대신 "지인 3명이 모이면 케미 랭킹이
      // 열려요" 안내 + 초대 CTA를 보여준다.
      body: sorted.length < 3
          ? _EmptyRanking(count: sorted.length)
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            '나에게 1등 귀인은',
                            style: TextStyle(
                              fontFamily: GmText.display,
                              fontSize: 15,
                              color: GmColors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            first?.name ?? '-',
                            style: const TextStyle(
                              fontFamily: GmText.display,
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              color: GmColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PodiumSlot(person: second, place: 2),
                        const SizedBox(width: 14),
                        _PodiumSlot(person: first, place: 1),
                        const SizedBox(width: 14),
                        _PodiumSlot(person: third, place: 3),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final p = sorted[index];
                          return _RankRow(
                            rank: index + 1,
                            person: p,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    GuinjiMapRelationDetailScreen(person: p),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    GmRoseButton(
                      label: '결과 카드로 공유하기',
                      icon: Icons.ios_share,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GuinjiResultCardScreen(
                            people: people,
                            ownerName: ownerName,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// [핸드오프 `RankScreen` "list.length < 3" 분기 1:1 이식] 왕관(♛,
/// 반투명) + "지인 3명이 모이면 케미 랭킹이 열려요" + 현재 인원/남은
/// 인원 안내 + "지인 초대하기" CTA.
class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final remain = 3 - count;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '♛',
              style: TextStyle(
                fontFamily: GmText.display,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: GmColors.gold.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '지인 3명이 모이면\n케미 랭킹이 열려요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GmText.display,
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: GmColors.fg,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              remain > 0
                  ? '지금 $count명 · $remain명만 더 초대해 보세요'
                  : '지금 $count명이 함께하고 있어요',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.6, color: GmColors.muted),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: gmPrimary(),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/guinji-map/m/share'),
                child: const Text('지인 초대하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.person, required this.place});

  final GuinjiPerson? person;
  final int place;

  @override
  Widget build(BuildContext context) {
    if (person == null) {
      return const SizedBox(width: 76);
    }
    final meta = guinjiRelationMetaOf(person!.relation);
    final color = meta.color;
    final isFirst = place == 1;
    final initial = person!.name.isNotEmpty ? person!.name.substring(0, 1) : '?';

    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isFirst ? 56 : 42,
            height: isFirst ? 56 : 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.85)]),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 1),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: GmText.display,
                fontSize: isFirst ? 22 : 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            person!.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GmColors.fg),
          ),
          Text(
            '${person!.score}pt',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isFirst ? GmColors.gold : GmColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isFirst ? GmColors.gold : GmColors.card,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'N°$place',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: isFirst ? Colors.white : GmColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.person, required this.onTap});

  final int rank;
  final GuinjiPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationMetaOf(person.relation);
    final color = meta.color;
    final label = meta.label;
    final top3 = rank <= 3;
    final initial = person.name.isNotEmpty ? person.name.substring(0, 1) : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: GmColors.card.withValues(alpha: 0.85),
          border: Border.all(color: GmColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                rank.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: top3 ? GmColors.gold : GmColors.dim,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
                    person.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GmColors.fg),
                  ),
                  const SizedBox(height: 3),
                  GmChip(
                    label: label,
                    background: color.withValues(alpha: 0.1),
                    foreground: color,
                    borderColor: color.withValues(alpha: 0.2),
                    fontSize: 9,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  ),
                ],
              ),
            ),
            Text(
              '${person.score}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GmColors.fg),
            ),
          ],
        ),
      ),
    );
  }
}
