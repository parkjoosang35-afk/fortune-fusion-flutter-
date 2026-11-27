import 'package:flutter/material.dart';

import '../character/guinji_character.dart';
import '../domain/guinji_person.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import '../widgets/guinji_animated_graph.dart' show parseGuinjiBirthLabel;
import '../widgets/guinji_map_widgets.dart';
import 'guinji_map_relation_detail_screen.dart';
import 'guinji_result_card_screen.dart';
import '../navigation/guinji_page_route.dart';

/// 랭킹 · 유형별 목록 — `/guinji-map/m/ranking` (`/guinji-map/*` 신규 디자인).
///
/// [핸드오프 §05-3 `RankScreen` 1:1 이식] 랭킹과 유형별 목록을 **한 화면
/// 두 탭**으로 합친다(핸드오프 스펙 "유형별 목록 (참여자): 랭킹 화면의
/// 두 번째 탭(기존 F화면과 통합)" — 과거에 별도 라우트/화면
/// `/guinji-map/m/friends`(`GuinjiFriendListScreen`)로 분리 구현했던
/// 것은 핸드오프와 불일치하는 구조였으므로 이 화면 안으로 통합했다).
/// 실제 참여자 데이터는 [GuinjiProvider.people]에서 그대로 전달받는다.
class GuinjiMapRankingScreen extends StatefulWidget {
  const GuinjiMapRankingScreen({
    super.key,
    required this.people,
    this.ownerName = '나',
    this.initialTab = 0,
    this.onInvite,
    this.onMemberDelete,
  });

  static const routeName = '/guinji-map/m/ranking';

  final List<GuinjiPerson> people;

  /// [귀인지도 기능 정리 — 3, 이상한 부분] 결과 카드 공유 시 실제 지도
  /// 소유자 이름을 전달한다(하드코딩 "지민" 제거).
  final String ownerName;

  /// 0 = 랭킹 탭(핸드오프 `initTab='rank'`), 1 = 유형별 목록 탭(`'list'`).
  final int initialTab;

  /// 참여자 3명 미만일 때 "지인 초대하기" CTA(핸드오프 `onInvite`).
  final VoidCallback? onInvite;

  /// [멤버 삭제] 유형별 목록 탭의 ⋯ → 확인 다이얼로그 승인 시 호출.
  /// null이면 삭제 UI를 노출하지 않는다.
  final void Function(GuinjiPerson person)? onMemberDelete;

  @override
  State<GuinjiMapRankingScreen> createState() => _GuinjiMapRankingScreenState();
}

class _GuinjiMapRankingScreenState extends State<GuinjiMapRankingScreen> {
  late int _tab = widget.initialTab;
  String? _filter;

  List<GuinjiPerson> get _sorted =>
      [...widget.people]..sort((a, b) => b.score.compareTo(a.score));

  void _openDetail(GuinjiPerson p) {
    Navigator.of(
      context,
    ).push(guinjiPageRoute(GuinjiMapRelationDetailScreen(person: p)));
  }

  Future<void> _confirmDelete(GuinjiPerson p) async {
    // [QA 대조 — SPEC §6 H11 "삭제 다이얼로그: 중앙, 라운드 22, #1C1230 ·
    // 얼굴 56 · 제목 18 · 본문 13.5 · 버튼 46h (취소 Ghost / 빼기
    // danger)"] design_files/guinji-rank.jsx 원문의 `del &&` 블록을
    // 1:1 이식 — 기존 코드는 얼굴 이미지가 없고 버튼이 기본 TextButton
    // (우측 정렬, 높이/배경/테두리 없음)이라 SPEC과 불일치했다.
    final type = guinjiTypeOf(p.relation);
    final birth = parseGuinjiBirthLabel(p.birth);
    final character = birth == null
        ? null
        : GuinjiCharacter.of(
            birth: birth,
            gender: GuinjiCharacter.fromKey(p.gender),
            stableKey: p.id,
          );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: GmColors.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF222222),
                  image: character == null
                      ? null
                      : DecorationImage(
                          image: AssetImage(character.face),
                          fit: BoxFit.cover,
                          onError: (_, _) {},
                        ),
                  border: Border.all(color: type.color, width: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${p.name}님을 지도에서 뺄까요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: GmColors.fg,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '관계 결과와 열어 둔 풀이도 함께 사라져요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GmText.ui,
                  fontSize: 13.5,
                  height: 1.55,
                  color: GmColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GmColors.fg,
                          side: const BorderSide(color: GmColors.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontFamily: GmText.ui,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GmColors.danger,
                          foregroundColor: GmColors.onFg,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        child: const Text(
                          '빼기',
                          style: TextStyle(
                            fontFamily: GmText.ui,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) widget.onMemberDelete?.call(p);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    final title = _tab == 0 ? '케미 랭킹' : '참여자 ${sorted.length}명';

    return Scaffold(
      backgroundColor: GmColors.bg,
      appBar: GmTopBar(back: true, title: title),
      // [2026-12 보강 — SPEC §2 `bgGlow` 전역 배경] `design_files/
      // guinji-rank.jsx`의 `RankScreen` 자체는 배경을 지정하지 않고
      // 상위 데모 셸(`CPhone`)의 배경을 그대로 물려받는 구조다 —
      // `CPhone`의 배경은 `TpBg`와 동일한 3겹 라디얼 글로우 그라데이션
      // (`guinji-clean.jsx` 12줄)이므로, 여기서도 [GmTempleBg]를 적용해
      // 단색(`GmColors.bg`) 배경을 글로우·별로 보강한다.
      body: GmTempleBg(
        child: SafeArea(
          child: Column(
            children: [
              // 탭(핸드오프: 랭킹 / 유형별 목록, 배경 pill 2종)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    // [QA 대조 — SPEC §6 H11 "세그먼트 2탭: 배경
                    // rgba(255,235,200,.05)"] design_files/guinji-rank.jsx
                    // 기준 흰색이 아닌 따뜻한 톤(cardTint) — 기존 코드는
                    // 순수 흰색 5%를 쓰고 있었다.
                    color: GmColors.cardTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          label: '랭킹',
                          active: _tab == 0,
                          onTap: () => setState(() => _tab = 0),
                        ),
                      ),
                      Expanded(
                        child: _TabButton(
                          label: '유형별 목록',
                          active: _tab == 1,
                          onTap: () => setState(() => _tab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _tab == 0
                    ? _RankTab(
                        sorted: sorted,
                        onPick: _openDetail,
                        onInvite:
                            widget.onInvite ??
                            () => Navigator.of(
                              context,
                            ).pushNamed('/guinji-map/m/share'),
                        onShare: sorted.length >= 3
                            ? () => Navigator.of(context).push(
                                // [QA 대조 — SPEC §6 H12 "→ 바텀시트"] H12가
                                // 투명 Scaffold + 하단카드 구조로 전환됨에
                                // 따라, 다른 바텀시트 화면(H9/H10)과 동일하게
                                // guinjiPageRoute(불투명 다크 배경)로 push
                                // 해야 전환 중 흰 배경이 비치지 않는다 —
                                // 기존 MaterialPageRoute는 이 화면이
                                // 전체화면이던 시절의 호출 방식이었다.
                                guinjiPageRoute(
                                  GuinjiResultCardScreen(
                                    people: widget.people,
                                    ownerName: widget.ownerName,
                                  ),
                                ),
                              )
                            : null,
                      )
                    : _ListTab(
                        list: sorted,
                        filter: _filter,
                        onFilter: (t) => setState(() => _filter = t),
                        onPick: _openDetail,
                        onDelete: widget.onMemberDelete == null
                            ? null
                            : _confirmDelete,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // [QA 대조 — SPEC §6 H11 "세그먼트 2탭: 선택 금 배경 + ink
          // 글자"] design_files/guinji-rank.jsx 기준 선택 배경은 금색
          // (CK.gold)이다 — 기존 코드는 GmColors.fg(크림 흰색)를 써서
          // 금색 강조가 빠져 있었다.
          color: active ? GmColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: GmText.ui,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? GmColors.onFg : GmColors.muted,
          ),
        ),
      ),
    );
  }
}

/// 랭킹 탭 — 3명 미만 빈 상태 / 포디움(1~3위) + 4위부터 전체 순위 리스트.
class _RankTab extends StatelessWidget {
  const _RankTab({
    required this.sorted,
    required this.onPick,
    required this.onInvite,
    required this.onShare,
  });

  final List<GuinjiPerson> sorted;
  final void Function(GuinjiPerson) onPick;
  final VoidCallback onInvite;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    if (sorted.length < 3) {
      // [핸드오프 `list.length < 3` 분기 1:1 이식] 왕관(♛ 반투명) +
      // "지인 3명이 모이면 케미 랭킹이 열려요" + 현재/남은 인원 + CTA.
      final remain = 3 - sorted.length;
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 70, 10, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '♛',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
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
                  fontWeight: FontWeight.w800,
                  color: GmColors.fg,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '지금 ${sorted.length}명 · $remain명만 더 초대해 보세요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: GmText.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.6,
                  color: GmColors.muted,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: gmPrimary(),
                  onPressed: onInvite,
                  child: const Text('지인 초대하기'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final top = sorted.take(3).toList();
    // 핸드오프: podium = [top[1], top[0], top[2]] (2위-1위-3위 순서 배치).
    final podium = <GuinjiPerson?>[
      top.length > 1 ? top[1] : null,
      top[0],
      top.length > 2 ? top[2] : null,
    ];
    final rest = sorted.skip(3).toList();

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, onShare != null ? 110 : 20),
          children: [
            // 포디움
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in podium)
                  Expanded(
                    child: p == null
                        ? const SizedBox.shrink()
                        : _PodiumSlot(
                            person: p,
                            rank: sorted.indexOf(p) + 1,
                            onTap: () => onPick(p),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
              child: Text(
                '전체 순위 · 케미 점수 높은 순',
                style: TextStyle(
                  fontFamily: GmText.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: GmColors.dim,
                ),
              ),
            ),
            for (var i = 0; i < rest.length; i++)
              _RankRow(
                rank: i + 4,
                person: rest[i],
                onTap: () => onPick(rest[i]),
              ),
          ],
        ),
        if (onShare != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: 34,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: gmPrimary(),
                onPressed: onShare,
                child: const Text('랭킹 결과 카드로 공유하기'),
              ),
            ),
          ),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.person,
    required this.rank,
    required this.onTap,
  });
  final GuinjiPerson person;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = guinjiTypeOf(person.relation);
    final big = rank == 1;
    final d = big ? 84.0 : 64.0;
    // 핸드오프: 단상 높이 74(1위) / 52(2위) / 38(3위).
    final barHeight = big ? 74.0 : (rank == 2 ? 52.0 : 38.0);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: d,
            height: d + (big ? 22 : 0),
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                if (big)
                  const Positioned(
                    top: 0,
                    child: Text(
                      '♛',
                      style: TextStyle(
                        fontFamily: GmText.display,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: GmColors.gold,
                      ),
                    ),
                  ),
                Positioned(
                  top: big ? 22 : 0,
                  child: Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage(GuinjiCharacter(person.id, '').face),
                        fit: BoxFit.cover,
                        onError: (_, _) {},
                      ),
                      border: Border.all(
                        color: big ? GmColors.gold : type.color,
                        width: 1.5,
                      ),
                      boxShadow: big
                          ? [
                              BoxShadow(
                                color: GmColors.gold.withValues(alpha: 0.4),
                                blurRadius: 20,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: big ? -4 : -2,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: big ? GmColors.gold : const Color(0xFF2A2A2E),
                      border: Border.all(color: GmColors.bg, width: 2),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontFamily: GmText.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: big ? GmColors.onFg : GmColors.fg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            person.name,
            style: TextStyle(
              fontFamily: GmText.ui,
              fontSize: big ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: GmColors.fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            type.label,
            style: TextStyle(
              fontFamily: GmText.ui,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: type.color,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: double.infinity,
            height: barHeight,
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: big
                    ? [
                        GmColors.gold.withValues(alpha: 0.28),
                        GmColors.gold.withValues(alpha: 0.04),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.01),
                      ],
              ),
            ),
            child: Text(
              '${person.score}',
              style: TextStyle(
                fontFamily: GmText.display,
                fontSize: big ? 24 : 19,
                fontWeight: FontWeight.w800,
                color: big ? GmColors.gold : GmColors.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    this.rank,
    required this.person,
    required this.onTap,
    this.onDelete,
  });
  final int? rank;
  final GuinjiPerson person;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final type = guinjiTypeOf(person.relation);
    final birth = parseGuinjiBirthLabel(person.birth);
    final character = birth == null
        ? null
        : GuinjiCharacter.of(
            birth: birth,
            gender: GuinjiCharacter.fromKey(person.gender),
            stableKey: person.id,
          );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: GmColors.hair)),
        ),
        child: Row(
          children: [
            // [핸드오프 `Row({ rank })`] rank가 null이면(유형별 목록 탭)
            // 순위 숫자를 표시하지 않는다.
            if (rank != null)
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: GmColors.dim,
                  ),
                ),
              ),
            if (rank != null) const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222222),
                image: character == null
                    ? null
                    : DecorationImage(
                        image: AssetImage(character.face),
                        fit: BoxFit.cover,
                        onError: (_, _) {},
                      ),
                border: Border.all(color: type.color, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: GmColors.fg,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        type.hanja,
                        style: TextStyle(
                          fontFamily: GmText.display,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: type.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontFamily: GmText.ui,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: type.color,
                        ),
                      ),
                      Text(
                        character != null ? ' · ${character.band}' : '',
                        style: const TextStyle(
                          fontFamily: GmText.ui,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: GmColors.dim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 54,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (person.score / 100).clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: type.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                '${person.score}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: GmColors.fg,
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.more_horiz,
                  color: GmColors.dim,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
          ],
        ),
      ),
    );
  }
}

/// 유형별 목록 탭 — [핸드오프 스펙] "필터 칩: 전체 + 6종" + 유형 그룹별
/// 점수 내림차순 + "⋯ → 삭제 확인" + "해당 유형의 참여자가 아직 없어요".
class _ListTab extends StatelessWidget {
  const _ListTab({
    required this.list,
    required this.filter,
    required this.onFilter,
    required this.onPick,
    this.onDelete,
  });

  final List<GuinjiPerson> list;
  final String? filter;
  final void Function(String?) onFilter;
  final void Function(GuinjiPerson) onPick;
  final void Function(GuinjiPerson)? onDelete;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final p in list) {
      counts[p.relation] = (counts[p.relation] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      children: [
        // 필터 칩 — 전체 + 6종(핸드오프: "전체/귀인/인연/조율 4개 → 7개로 확장").
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                // [QA 대조 — SPEC §6 H11 "칩 줄: 선택 시 유형색 22% /
                // 전체는 금"] design_files/guinji-rank.jsx 기준 "전체"
                // 칩의 강조색은 금(CK.gold)이다 — 기존 코드는
                // GmColors.fg(크림 흰색)를 써서 전체 선택 시 다른
                // 유형 칩과 시각적으로 구분되지 않았다.
                label: '전체 ${list.length}',
                hanja: null,
                color: GmColors.gold,
                active: filter == null,
                onTap: () => onFilter(null),
              ),
              for (final t in guinjiTypeOrder)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterChip(
                    label: '${guinjiTypeOf(t).short} ${counts[t] ?? 0}',
                    hanja: guinjiTypeOf(t).hanja,
                    color: guinjiTypeOf(t).color,
                    active: filter == t,
                    onTap: () => onFilter(t),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final t in guinjiTypeOrder.where(
          (t) => filter == null || filter == t,
        ))
          _TypeGroup(
            type: t,
            members: list.where((p) => p.relation == t).toList()
              ..sort((a, b) => b.score.compareTo(a.score)),
            showEmptyNotice: filter != null,
            onPick: onPick,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.hanja,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final String? hanja;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color : GmColors.line),
          // [QA 대조 — SPEC §6 H11 "칩 줄: 선택 시 유형색 22% / 전체는
          // 금"] design_files/guinji-rank.jsx 원문: `background: on
          // ? (t ? c + '22' : CK.gold) : 'transparent'` — 유형 칩은
          // 자기 색 22% 배경, "전체" 칩은 금색 단색 배경이다. 기존
          // 코드는 "전체" 칩 배경을 GmColors.fg(크림 흰색)로
          // 하드코딩해 둬서, 호출부에서 color 파라미터를 금색으로
          // 바꿔도 배경에는 반영되지 않는 버그가 있었다.
          color: active
              ? (hanja != null ? color.withValues(alpha: 0.13) : color)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hanja != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  hanja!,
                  style: TextStyle(
                    fontFamily: GmText.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active ? color : GmColors.muted,
                  ),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontFamily: GmText.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active
                    ? (hanja != null ? color : GmColors.onFg)
                    : GmColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeGroup extends StatelessWidget {
  const _TypeGroup({
    required this.type,
    required this.members,
    required this.showEmptyNotice,
    required this.onPick,
    this.onDelete,
  });
  final String type;
  final List<GuinjiPerson> members;
  final bool showEmptyNotice;
  final void Function(GuinjiPerson) onPick;
  final void Function(GuinjiPerson)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      if (!showEmptyNotice) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            '해당 유형의 참여자가 아직 없어요',
            style: TextStyle(
              fontFamily: GmText.ui,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              height: 1.6,
              color: GmColors.muted,
            ),
          ),
        ),
      );
    }
    final spec = guinjiTypeOf(type);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: spec.color),
                ),
                child: Text(
                  spec.hanja,
                  style: TextStyle(
                    fontFamily: GmText.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: spec.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                spec.label,
                style: const TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: GmColors.fg,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${members.length}명',
                style: const TextStyle(
                  fontFamily: GmText.ui,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: GmColors.dim,
                ),
              ),
            ],
          ),
          for (final m in members)
            _RankRow(
              person: m,
              onTap: () => onPick(m),
              onDelete: onDelete == null ? null : () => onDelete!(m),
            ),
        ],
      ),
    );
  }
}
