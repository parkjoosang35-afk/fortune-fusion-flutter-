import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../application/guinji_provider.dart';
import '../domain/guinji_owner_saju_summary.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import '../widgets/guinji_animated_graph.dart';
import '../widgets/guinji_arrival_overlay.dart';
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
    this.ownerFacePath,
    this.onNodeTap,
    this.onInvite,
    this.onOpenFriends,
  });

  static const routeName = '/guinji-map/m';

  final String ownerName;
  final String? ownerFacePath;

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
  /// [핸드오프 `CMain` filter 상태 이식] 유형 칩을 탭하면 해당 유형만
  /// 지도에서 강조한다(다시 탭하면 해제). null = 필터 없음.
  String? _filter;

  /// [05-4 지인 도착 애니메이션 연동] 이번에 "새로 도착"으로 판정된
  /// 지인 목록 — 비어 있지 않으면 [GuinjiArrivalOverlay]를 Stack 맨 위에
  /// 겹쳐 띄운다. 오버레이가 스스로 닫히거나 "왜 그런지 보기"를 누르면
  /// 비운다([_dismissArrivalOverlay]).
  List<GuinjiPerson> _pendingArrivals = const [];

  /// 중복 조회 방지 — 직전에 비교했던 참여자 수(명단이 실제로 늘어난
  /// 경우에만 [GuinjiArrivalSeenStore.findNewArrivals]를 다시 호출한다).
  int? _lastCheckedPeopleCount;

  @override
  void initState() {
    super.initState();
    // [친구 초대 마일스톤 — 축하 UI 트리거] M(내 지도) 화면은 지도를 만든
    // 이후 사용자가 가장 자주 돌아오는 메인 화면이므로, 서버가 방금(이번
    // `loadMyMap` 호출에서) 마일스톤 보너스를 지급했다면 여기서 축하
    // 다이얼로그를 1회 띄운다. 프레임이 그려진 뒤 확인해야
    // `ScaffoldMessenger`/`showDialog`가 안전하게 동작한다.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowMilestoneCelebration(),
    );
    unawaited(_checkArrivals());
  }

  @override
  void didUpdateWidget(covariant GuinjiMapResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // [05-4] `GuinjiProvider.people`이 바뀌었을 때만(=새로고침으로 참여자
    // 수가 달라졌을 때만) 다시 비교한다 — 매 리렌더마다 재조회하면
    // 이미 띄워 둔 오버레이가 깜빡이며 리셋될 수 있다.
    if (widget.people.length != oldWidget.people.length) {
      unawaited(_checkArrivals());
    }
  }

  /// [05-4 지인 도착 애니메이션] 핸드오프: "지도 화면에서 … GET /maps/me
  /// 비교. 본 사람은 SharedPreferences: seenMemberIds에 저장" — 이
  /// 화면은 [GuinjiProvider.people]이 바뀐 시점(= 최신 `/maps/me` 응답이
  /// 반영된 시점)에 [GuinjiArrivalSeenStore]와 비교해 새로 합류한 지인을
  /// 찾는다. 이미 오버레이가 떠 있으면(`_pendingArrivals`가 비어있지 않음)
  /// 재생 중인 애니메이션을 방해하지 않도록 건너뛴다.
  Future<void> _checkArrivals() async {
    if (!mounted) return;
    if (_pendingArrivals.isNotEmpty) return;
    if (_lastCheckedPeopleCount == widget.people.length) return;
    _lastCheckedPeopleCount = widget.people.length;

    final arrivals = await GuinjiArrivalSeenStore.findNewArrivals(
      widget.people,
    );
    if (!mounted || arrivals.isEmpty) return;
    setState(() => _pendingArrivals = arrivals);
  }

  /// 오버레이를 닫는다 — 본 사람으로 영속화한 뒤 목록을 비워 Stack에서
  /// 제거되게 한다.
  void _dismissArrivalOverlay() {
    final ids = _pendingArrivals.map((p) => p.id).toList();
    setState(() => _pendingArrivals = const []);
    unawaited(GuinjiArrivalSeenStore.markSeen(ids));
  }

  /// 결과 카드 "왜 그런지 보기" — 오버레이를 닫고 곧바로 관계상세 화면으로
  /// push한다(핸드오프 `CArrivalScreen`의 "왜 그런지 보기" 버튼 동작과
  /// 동일 — 노드 바텀시트를 거치지 않고 바로 상세로 이동).
  void _openArrivalRelation(GuinjiPerson person) {
    _dismissArrivalOverlay();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuinjiMapRelationDetailScreen(person: person),
      ),
    );
  }

  void _maybeShowMilestoneCelebration() {
    if (!mounted) return;
    final provider = context.read<GuinjiProvider>();
    if (!provider.milestoneJustReached) return;

    final rewardPoint = provider.milestoneRewardPoint;
    // [1회성 소비] 다이얼로그를 띄우기 전에 먼저 꺼서, 다이얼로그가 열려
    // 있는 동안 다른 리스너의 재렌더로 인해 중복 호출되지 않게 한다.
    provider.consumeMilestoneJustReached();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: GmColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '축하 이벤트 달성',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: GmColors.fg,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '친구 3명이 귀인지도에 모였어요.\n고마운 마음을 담아 복주머니 ${rewardPoint > 0 ? rewardPoint : 30}개를 보내드려요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: GmColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GmColors.gold,
                    foregroundColor: GmColors.onFg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    '좋아요',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 노드 탭 시 기본 동작: 상위에서 [GuinjiMapResultScreen.onNodeTap]을
  /// 지정하지 않았다면, 여기서 [GuinjiNodeSheet]을 [person]의 실제 데이터로
  /// 띄운다. "공유하기"는 바텀시트를 닫고 곧바로 S(Share) 화면으로 이동한다.
  void _handleNodeTap(GuinjiPerson person) {
    if (widget.onNodeTap != null) {
      widget.onNodeTap!(person);
      return;
    }
    final meta = guinjiRelationMetaOf(person.relation);
    final ohaengMeta = guinjiOhaengTypes[person.ohaeng];
    showGuinjiNodeSheet(
      context: context,
      name: person.name,
      birthLabel: person.birth,
      relationKey: person.relation,
      score: person.score,
      narratorText:
          '${person.name}님은 ${meta.description}. 곁에 두면 결이 자연스레 풀리는 관계예요.',
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

    return Stack(
      children: [
        _buildScaffold(total, topThree),
        // [05-4 지인 도착 애니메이션] 지도(M)를 보고 있을 때 새 멤버가
        // 감지되면 화면 전체 위에 겹쳐 재생한다(핸드오프 "지도를 보고
        // 있을 때 재생" — 지도 자체는 가리지 않고 그 위에 효과만 더함).
        if (_pendingArrivals.isNotEmpty)
          Positioned.fill(
            child: GuinjiArrivalOverlay(
              arrivals: _pendingArrivals,
              onOpenRelation: _openArrivalRelation,
              onClose: _dismissArrivalOverlay,
            ),
          ),
      ],
    );
  }

  Widget _buildScaffold(int total, List<GuinjiPerson> topThree) {
    return Scaffold(
      backgroundColor: GmColors.bg,
      appBar: GmTopBar(
        back: true,
        title: '${widget.ownerName}님의 귀인 지도',
        onShare: _openShareSheet,
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 헤더
              // [핸드오프 `CMain` 헤더 1:1 이식] 원본은 "{members.length}명과
              // 연결되어 있어요" 문구 + 버튼 2개(♛ 랭킹 / ＋ 초대)만 있다.
              // "목록 보기"는 CMain 헤더에 없는 버튼이었다(유형별 목록은
              // 랭킹 화면의 두 번째 탭으로만 진입 가능) — ＋ 초대로 교체.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$total명과 연결되어 있어요',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: GmColors.muted,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _openRanking,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GmColors.fg,
                        side: const BorderSide(color: GmColors.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '♛ ',
                              style: TextStyle(color: GmColors.gold),
                            ),
                            TextSpan(text: '랭킹'),
                          ],
                        ),
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: _openShareSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GmColors.fg,
                        foregroundColor: GmColors.onFg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                      ),
                      child: const Text(
                        '＋ 초대',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                ownerFacePath: widget.ownerFacePath,
                people: widget.people,
                onSelect: _handleNodeTap,
                // [핸드오프 `CEmpty` 안내문구 1:1 이식]
                emptyHint: '링크를 받은 지인이 생년월일을 입력하면\n이곳에 한 명씩 연결돼요',
                filter: _filter,
              ),

              // [핸드오프 `CMain` 유형 필터 칩 이식] 실제 참여한 관계유형만
              // 칩으로 노출하고, 탭하면 지도에서 해당 유형만 강조한다.
              if (widget.people.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _GmTypeFilterRow(
                    people: widget.people,
                    selected: _filter,
                    onSelect: (key) =>
                        setState(() => _filter = _filter == key ? null : key),
                  ),
                ),

              // [핸드오프 `CMain` 3명 미만 배너 이식, `top:584`] 원본은
              // 고정 캔버스(CW×CH) 위에 절대좌표로 지도와 겹쳐 배치되지만,
              // 이 화면은 스크롤 레이아웃이라 같은 의도(지도 바로 아래,
              // "가장 강한 인연" 리스트보다 먼저)로 그래프 직후에 둔다.
              if (widget.people.isNotEmpty && widget.people.length < 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _GmFewMembersBanner(count: widget.people.length),
                ),

              // [웹 일반 AdSense 전체 확장 — 귀인지도] 노드 그래프(콘텐츠)와
              // "가장 강한 인연" 리스트(콘텐츠) 사이 — CTA("친구 초대하고
              // 지도 완성하기")와는 충분히 떨어져 있어 혼동 우려가 없다.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: const WebAdInPage(
                  surface: WebAdSurface.guinji,
                  adSlot: '',
                ),
              ),

              // 상위 3명
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const Text(
                      '가장 강한 인연',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: GmColors.fg,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _openFriends,
                      child: const Text(
                        '전체 보기',
                        style: TextStyle(fontSize: 11, color: GmColors.gold),
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
                    style: TextStyle(fontSize: 12, color: GmColors.dim),
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

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// [핸드오프 `CMain` 유형 필터 칩 이식] 실제 참여한 관계유형만 한 줄로
/// 보여주고, 탭하면 지도에서 해당 유형만 강조(`GuinjiAnimatedRelationGraph.
/// filter`)한다. 다시 탭하면 해제.
class _GmTypeFilterRow extends StatelessWidget {
  const _GmTypeFilterRow({
    required this.people,
    required this.selected,
    required this.onSelect,
  });

  final List<GuinjiPerson> people;
  final String? selected;
  final void Function(String key) onSelect;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final p in people) {
      counts[p.relation] = (counts[p.relation] ?? 0) + 1;
    }
    final keys = guinjiTypeOrder.where((t) => (counts[t] ?? 0) > 0).toList();
    if (keys.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final key in keys) ...[
            _buildChip(key, counts[key]!),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String key, int count) {
    final spec = guinjiTypeOf(key);
    final on = selected == key;
    return GestureDetector(
      onTap: () => onSelect(key),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: on ? spec.color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: on ? spec.color : Colors.transparent),
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: spec.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${spec.short} $count',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: on ? spec.color : GmColors.muted,
              ),
            ),
          ],
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
    final meta = guinjiRelationMetaOf(person.relation);
    final color = meta.color;
    final label = meta.label;
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
                  fontFamily: GmText.display,
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
                          color: GmColors.fg,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GmChip(
                        label: label,
                        background: color.withValues(alpha: 0.12),
                        foreground: color,
                        borderColor: color.withValues(alpha: 0.25),
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta.short,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: GmColors.dim),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${person.score}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Text(
                  'SCORE',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 0.6,
                    color: GmColors.dim,
                  ),
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
        color: GmColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GmColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '나는 어떤 사람인지',
            style: TextStyle(
              fontSize: 11.5,
              height: 1,
              letterSpacing: 1.2,
              color: GmColors.gold,
              fontWeight: FontWeight.w600,
            ),
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
                  color: GmColors.gold.withValues(alpha: 0.15),
                  border: Border.all(
                    color: GmColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  summary.dayMasterKr.isNotEmpty
                      ? summary.dayMasterKr.substring(0, 1)
                      : '?',
                  style: const TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GmColors.gold,
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
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: GmColors.fg,
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
                      background: GmColors.gold.withValues(alpha: 0.12),
                      foreground: GmColors.gold,
                      borderColor: GmColors.gold.withValues(alpha: 0.3),
                      fontSize: 10.5,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // [100자 요약 + 가독성 확대 — 사용자 피드백] 본문(일간 본성+성격
          // 해설)에 룰 DB의 강점·유의 키워드를 합쳐 100자 내외로 구성하고,
          // 글씨를 13px대 → 15.5/13.5px로 키운다. 하단에 근거(일간·신강약)
          // 한 줄을 명시해 "왜 이런 말이 나왔는지"가 화면에 보이게 한다.
          Text(
            '${summary.nature}\n${summary.personality}',
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.7,
              color: GmColors.fg,
            ),
          ),
          if (summary.strengths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '강점 · ${summary.strengths.take(3).join(' · ')}',
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: GmColors.fg,
              ),
            ),
          ],
          if (summary.weaknesses.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '유의 · ${summary.weaknesses.take(2).join(' · ')}',
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: GmColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            summary.basisLabel,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: GmColors.dim,
            ),
          ),
        ],
      ),
    );
  }
}

/// [핸드오프 `CMain` 3명 미만 배너 1:1 이식] "N명만 더 모이면 축하
/// 이벤트와 랭킹이 열려요" + 0/1/2 진행 막대(골드로 채워짐). 원본
/// `{3 - members.length}명만 더 모이면...`, `{members.length}/3` 문구와
/// `[0,1,2].map(i => i < members.length ? 채움 : 안채움)` 로직을 그대로
/// 따른다.
class _GmFewMembersBanner extends StatelessWidget {
  const _GmFewMembersBanner({required this.count});

  /// 현재 참여자 수(0~2 범위에서만 렌더됨 — 호출부에서 `< 3` 체크).
  final int count;

  @override
  Widget build(BuildContext context) {
    final remain = 3 - count;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: GmColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GmColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '$remain명만 더 모이면 축하 이벤트와 랭킹이 열려요',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: GmColors.fg,
                  ),
                ),
              ),
              Text(
                '$count/3',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: GmColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final filled = i < count;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                  decoration: BoxDecoration(
                    color: filled
                        ? GmColors.gold
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
