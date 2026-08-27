import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import '../widgets/guinji_chemistry_candle.dart';
import '../widgets/guinji_orbit_map.dart';
import 'guinji_relation_detail_screen.dart';

/// 귀인지도(Guinji Map) — 07. 랭킹 화면.
///
/// [Phase G-5] `GUINJI_SCREENS.md` "07 · 랭킹" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `RankingScreen`): 케미 점수 순위 리스트 + "1등
/// 귀인" 강조 + Top3 촛불 포디움 + 전체 리스트 + 결과카드 공유 CTA.
///
/// [Phase G-5 범위] "결과 카드로 공유하기"(S10 결과카드 → S8 공유)는
/// 아직 구현되어 있지 않아 토스트로 대체한다. 리스트 항목 탭 시
/// 관계상세(S6)로는 실제 이동한다(기존 지도메인과 동일 패턴).
class GuinjiRankingScreen extends StatelessWidget {
  const GuinjiRankingScreen({super.key, this.people = guinjiSamplePeople});

  final List<GuinjiPerson> people;

  @override
  Widget build(BuildContext context) {
    final sorted = [...people]..sort((a, b) => b.score.compareTo(a.score));
    final first = sorted.isNotEmpty ? sorted[0] : null;
    final second = sorted.length > 1 ? sorted[1] : null;
    final third = sorted.length > 2 ? sorted[2] : null;

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      const _MonoLabel('RANKING · CHEMISTRY'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          '나에게 1등 귀인은',
                          style: TextStyle(
                            fontFamily: GuinjiFonts.display,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.4,
                            color: GuinjiColors.textPrimary,
                          ),
                        ),
                        Text(
                          first?.name ?? '-',
                          style: const TextStyle(
                            fontFamily: GuinjiFonts.display,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.4,
                            color: GuinjiColors.lavender,
                            shadows: [
                              Shadow(
                                color: GuinjiColors.glowShadow,
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (sorted.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PodiumSlot(person: second, place: 2),
                        const SizedBox(width: 12),
                        _PodiumSlot(person: first, place: 1),
                        const SizedBox(width: 12),
                        _PodiumSlot(person: third, place: 3),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final p = sorted[index];
                        return _RankRow(
                          rank: index + 1,
                          person: p,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  GuinjiRelationDetailScreen(person: p),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryCta(
                    label: '결과 카드로 공유하기',
                    onPressed: () =>
                        AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: 10,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: GuinjiColors.textSecondary,
      ),
    );
  }
}

/// Top3 촛불 포디움 슬롯 — 1등은 가운데·크게, 2등 왼쪽/3등 오른쪽.
class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.person, required this.place});

  final GuinjiPerson? person;
  final int place;

  @override
  Widget build(BuildContext context) {
    if (person == null) {
      return const SizedBox(width: 70);
    }
    final isFirst = place == 1;
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GuinjiChemistryCandle(
            score: person!.score,
            size: isFirst ? 46 : 34,
            showScore: false,
          ),
          const SizedBox(height: 4),
          Text(
            person!.name,
            style: const TextStyle(
              fontFamily: GuinjiFonts.display,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: GuinjiColors.textPrimary,
            ),
          ),
          Text(
            '${person!.score}pt',
            style: TextStyle(
              fontFamily: GuinjiFonts.mono,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 2.0,
              color: isFirst
                  ? GuinjiColors.lavender
                  : GuinjiColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isFirst ? GuinjiColors.lavender : GuinjiColors.surfaceCard,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'N°$place',
              style: TextStyle(
                fontFamily: GuinjiFonts.mono,
                fontWeight: FontWeight.w700,
                fontSize: 9,
                letterSpacing: 2.0,
                color: isFirst ? GuinjiColors.ink : GuinjiColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 전체 순위 리스트 한 행.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.person,
    required this.onTap,
  });

  final int rank;
  final GuinjiPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final relation = guinjiRelationTypes[person.relation]!;
    final ohaeng = guinjiOhaengTypes[person.ohaeng]!;
    final top3 = rank <= 3;

    return Material(
      color: GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GuinjiFonts.mono,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.0,
                    color: top3
                        ? GuinjiColors.lavender
                        : GuinjiColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GuinjiPersonNode(person: person, size: 30, showLabel: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontFamily: GuinjiFonts.body,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: GuinjiColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _RelationBadgeSm(relation: relation),
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ohaeng.color,
                            boxShadow: [
                              BoxShadow(
                                color: ohaeng.color.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GuinjiChemistryCandle(
                score: person.score,
                size: 20,
                showScore: false,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '${person.score}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: GuinjiColors.textPrimary,
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

class _RelationBadgeSm extends StatelessWidget {
  const _RelationBadgeSm({required this.relation});

  final GuinjiRelationMeta relation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: relation.color.withValues(alpha: 0.22),
        border: Border.all(color: relation.color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${relation.hanja} ${relation.label}',
        style: TextStyle(
          fontFamily: GuinjiFonts.body,
          fontWeight: FontWeight.w600,
          fontSize: 9,
          color: relation.color,
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: GuinjiColors.lavender,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: GuinjiColors.glowShadow, blurRadius: 18),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: GuinjiFonts.body,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: GuinjiColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
