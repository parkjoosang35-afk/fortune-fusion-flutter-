import 'package:flutter/material.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../domain/guinji_owner_saju_summary.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_animated_graph.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_map_relation_detail_screen.dart';
import 'guinji_node_sheet.dart';

/// M · My Map — `/guinji-map/m`
///
/// [2026-09 새 디자인 리스킨] 새 디자인 zip
/// `lib/guiindo/widgets/node_graph.dart`(`InteractiveNodeGraph`, pan/zoom/
/// drag/tap 제스처 지원)와 `lib/guiindo/screens/result_map_screen.dart`
/// (헤더 + 그래프 + 상위 3명 + 공유 CTA) 구조를 이식했다.
///
/// [귀인지도 실구현] 실제 [GuinjiProvider.people]은 인원 수·관계유형
/// 분포가 매번 다르므로, 새 디자인의 고정 목데이터 레이아웃 대신
/// [_layoutPeople]이 참여자 수·점수 기반으로 각도/거리를 절차적으로
/// 계산한다(`InteractiveNodeGraph._rebuildLayout()`과 동일한 공식:
/// `r = 60 + (100-score)*1.6`, `radius = 22 + (score-50)*0.25`).
class GuinjiMapResultScreen extends StatefulWidget {
  const GuinjiMapResultScreen({
    super.key,
    this.ownerName = '나',
    this.people = const [],
    this.ownerSajuSummary,
    this.onNodeTap,
    this.onInvite,
    this.onOpenFriends,
  });

  static const routeName = '/guinji-map/m';

  final String ownerName;

  /// 실제 참여자 목록(`GuinjiProvider.people`에서 전달). 비어 있으면
  /// "아직 참여한 귀인이 없어요" 안내를 보여준다.
  final List<GuinjiPerson> people;

  /// [흐름 정합성 — "나는 어떤 사람인지"] 호스트 본인의 실계산 사주 요약
  /// (`GuinjiProvider.ownerSajuSummary`). null이면(아직 계산되지 않은
  /// 세션) "나는 어떤 사람인지" 섹션 자체를 숨긴다 — 목데이터로 대체하지
  /// 않는다.
  final GuinjiOwnerSajuSummary? ownerSajuSummary;

  /// 노드 탭 콜백 — 탭한 [GuinjiPerson]을 전달한다.
  final void Function(GuinjiPerson person)? onNodeTap;

  /// 공유 CTA 탭 콜백 — 기본값은 S(Share) 화면으로 push.
  final VoidCallback? onInvite;

  /// 상단 "목록 보기" 탭 콜백 — 기본값은 F(Friend List) 화면으로 push.
  final VoidCallback? onOpenFriends;

  @override
  State<GuinjiMapResultScreen> createState() => _GuinjiMapResultScreenState();
}

class _GuinjiMapResultScreenState extends State<GuinjiMapResultScreen> {
  /// 노드 탭 시 기본 동작: 상위에서 [GuinjiMapResultScreen.onNodeTap]을
  /// 지정하지 않았다면, 여기서 [GuinjiNodeSheet]을 [person]의 실제 데이터로
  /// 띄운다. "공유하기"는 바텀시트를 닫고 곧바로 S(Share) 화면으로 이동한다.
  void _handleNodeTap(GuinjiPerson person) {
    if (widget.onNodeTap != null) {
      widget.onNodeTap!(person);
      return;
    }
    final meta = guinjiRelationTypes[person.relation];
    final ohaengMeta = guinjiOhaengTypes[person.ohaeng];
    showGuinjiNodeSheet(
      context: context,
      name: person.name,
      birthLabel: person.birth,
      relationKey: person.relation,
      score: person.score,
      narratorText:
          '${person.name}님은 ${meta?.description ?? "특별한 인연"}. 곁에 두면 결이 자연스레 풀리는 관계예요.',
      evidenceRows: [
        ('오행', '${ohaengMeta?.label ?? ''} ${ohaengMeta?.name ?? ''}'.trim()),
        if (person.note.isNotEmpty) ('판정 근거', person.note),
      ],
      onShare: () {
        Navigator.of(context).maybePop();
        Navigator.of(context).pushNamed('/guinji-map/m/share');
      },
      // [귀인지도 기능 정리 — 1] 이전까지 빈 콜백(() {})이라 "더 자세히
      // 보기" 버튼이 눌러도 반응이 없던 문제를 해결한다. 바텀시트를 닫고
      // 새 디자인 톤 관계상세 화면으로 push한다.
      onSeeMore: () {
        Navigator.of(context).maybePop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GuinjiMapRelationDetailScreen(person: person),
          ),
        );
      },
    );
  }

  void _openShareSheet() {
    if (widget.onInvite != null) {
      widget.onInvite!();
      return;
    }
    Navigator.of(context).pushNamed('/guinji-map/m/share');
  }

  void _openFriends() {
    if (widget.onOpenFriends != null) {
      widget.onOpenFriends!();
      return;
    }
    Navigator.of(context).pushNamed('/guinji-map/m/friends');
  }

  // [귀인지도 기능 정리 — 2] 신규 디자인 계열에 랭킹 화면 진입점이
  // 아예 없던 문제를 해결한다. 상단 "목록 보기" 버튼 옆에 배치.
  void _openRanking() {
    Navigator.of(context).pushNamed('/guinji-map/m/ranking');
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.people.length;
    final top3 = widget.people.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final topThree = top3.take(3).toList();

    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(
        back: true,
        title: '${widget.ownerName}님의 귀인 지도',
        onShare: _openShareSheet,
      ),
      // [하단바 통일 작업] 결과(지도) 화면도 귀인지도 흐름의 메인 화면
      // 중 하나이므로 랜딩 화면과 동일하게 전역 5탭 하단바를 추가한다.
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: '지금 ',
                                  style: TextStyle(fontSize: 11, color: GmColors.inkSoft),
                                ),
                                TextSpan(
                                  text: '$total명',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: GmColors.rose700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(
                                  text: '이 함께해요',
                                  style: TextStyle(fontSize: 11, color: GmColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '노드를 눌러 관계 상세를 확인하세요',
                            style: TextStyle(fontSize: 10.5, color: GmColors.inkFaint),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _openRanking,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GmColors.rose700,
                        side: BorderSide(color: GmColors.rose300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text('랭킹', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _openFriends,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GmColors.inkSoft,
                        side: const BorderSide(color: GmColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: const Text('목록 보기', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

              // [흐름 정합성] "나는 어떤 사람인지" — 관계 그래프(아직 지인이
              // 없으면 비어 있음)보다 먼저, 실계산된 내 사주 요약을 보여준다.
              if (widget.ownerSajuSummary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: _GmOwnerSajuCard(
                    ownerName: widget.ownerName,
                    summary: widget.ownerSajuSummary!,
                  ),
                ),

              // 인터랙티브 애니메이션 노드 그래프(pan/zoom/drag/tap +
              // 회전 궤도/레이더 펄스/호흡/에너지 흐름 애니메이션).
              GuinjiAnimatedRelationGraph(
                centerTitle: '${widget.ownerName}님',
                centerSubtitle: '나',
                people: widget.people,
                onSelect: _handleNodeTap,
                emptyHint: '지인을 초대하면 여기에 표시돼요',
              ),

              // 상위 3명
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const Text(
                      '가장 강한 인연',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GmColors.ink),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _openFriends,
                      child: const Text(
                        '전체 보기',
                        style: TextStyle(fontSize: 11, color: GmColors.rose700),
                      ),
                    ),
                  ],
                ),
              ),
              if (topThree.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    '지인을 초대하면 여기에 표시돼요',
                    style: TextStyle(fontSize: 12, color: GmColors.inkFaint),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: topThree
                        .map(
                          (p) => _GmFriendRow(
                            person: p,
                            onTap: () => _handleNodeTap(p),
                          ),
                        )
                        .toList(),
                  ),
                ),

              // 공유 CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: GmRoseButton(
                  label: '친구 초대하고 지도 완성하기',
                  onPressed: _openShareSheet,
                ),
              ),

              // ★ 결과 화면(M/N) 전용 신통방통 이관 CTA — 새 디자인
              // `ResultAppHandoff` 재현(다른 화면에는 사용하지 않는다).
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: GmDarkCtaShell(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GmFreeBadge(label: '신통방통에서 계속'),
                      const SizedBox(height: 12),
                      const Text(
                        '내 귀인지도를 신통방통에서\n더 깊게 이어보세요',
                        style: TextStyle(
                          fontFamily: GmFonts.serif,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: GmColors.ivory,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GmRoseButton(
                        label: '신통방통에서 내 귀인지도 만들기',
                        icon: Icons.arrow_forward,
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/guinji-map'),
                      ),
                    ],
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

/// F/M화면 공용 컴포넌트 — 새 디자인 `friend_row.dart`의 `FriendRow` 이식.
class _GmFriendRow extends StatelessWidget {
  const _GmFriendRow({required this.person, this.onTap});

  final GuinjiPerson person;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[person.relation];
    final color = meta != null ? GmColors.categoryColor(meta.category) : GmColors.rose500;
    final label = meta?.label ?? person.relation;
    final initial = person.name.isNotEmpty ? person.name.substring(0, 1) : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: GmFonts.serif,
                  fontSize: 16,
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
                        person.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: GmColors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GmChip(
                        label: label,
                        background: color.withValues(alpha: 0.12),
                        foreground: color,
                        borderColor: color.withValues(alpha: 0.25),
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta?.short ?? person.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: GmColors.inkFaint),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${person.score}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
                const Text(
                  'SCORE',
                  style: TextStyle(fontSize: 8, letterSpacing: 0.6, color: GmColors.inkFaint),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// M화면 전용 — "나는 어떤 사람인지" 카드. [GuinjiOwnerSajuSummary](실계산
/// 결과)를 받아 일간·신강중화신약·본성·성격을 보여준다. 관계 그래프(아직
/// 지인이 없으면 텅 비어있는 상태)만 있던 화면에 "나 자신"에 대한 결과를
/// 먼저 보여줘 흐름을 자연스럽게 만든다.
class _GmOwnerSajuCard extends StatelessWidget {
  const _GmOwnerSajuCard({required this.ownerName, required this.summary});

  final String ownerName;
  final GuinjiOwnerSajuSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: GmColors.bgCream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GmColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '나는 어떤 사람인지',
            style: GmText.labelMini.copyWith(color: GmColors.rose700),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GmColors.rose100,
                  border: Border.all(color: GmColors.rose300),
                ),
                child: Text(
                  summary.dayMasterKr.isNotEmpty
                      ? summary.dayMasterKr.substring(0, 1)
                      : '?',
                  style: const TextStyle(
                    fontFamily: GmFonts.serif,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GmColors.rose700,
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
                        Flexible(
                          child: Text(
                            '$ownerName님은 ${summary.dayMasterKr} · ${summary.dayMasterImage}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: GmColors.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    GmChip(
                      label: summary.strengthLevelKr,
                      background: GmColors.rose50,
                      foreground: GmColors.rose700,
                      borderColor: GmColors.rose200,
                      fontSize: 10.5,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(summary.nature, style: GmText.bodySoft),
          const SizedBox(height: 8),
          Text(
            summary.personality,
            style: const TextStyle(fontSize: 13, height: 1.6, color: GmColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
