import 'dart:async';

import 'package:flutter/material.dart';
import '../navigation/guinji_page_route.dart';
import 'package:provider/provider.dart';

import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../../../core/widgets/result_text_scale_overlay.dart';
import '../application/guinji_provider.dart';
import '../domain/guinji_owner_saju_summary.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import '../widgets/guinji_animated_graph.dart';
import '../widgets/guinji_arrival_overlay.dart';
import '../widgets/guinji_layout.dart' show GuinjiTpSlot;
import '../widgets/guinji_map_widgets.dart';
import 'guinji_h4_sheets.dart';
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
  /// 동일 — 노드 바텀시트를 거치지 않고 바로 상세로 이동. SPEC §6
  /// `TpPersonSheet` → H5 / `PaySheet` → H6 매핑 기준으로는 H6).
  void _openArrivalRelation(GuinjiPerson person) {
    _dismissArrivalOverlay();
    Navigator.of(
      context,
    ).push(guinjiPageRoute(GuinjiMapRelationDetailScreen(person: person)));
  }

  /// [2026-12 보강 — SPEC §5-6 AT+2.2 "H5 자동 오픈"] 공식 소스
  /// `design_files/guinji-temple.jsx` 635줄 `setSel(arriver.id)` 1:1 —
  /// 사용자가 노드를 직접 탭한 것과 동일하게 H5(`GuinjiNodeSheet`)를
  /// 자동으로 연다(위의 "왜 그런지 보기"가 여는 H6 결제 시트와는 다른
  /// 목적지). 오버레이를 먼저 닫아 바텀시트와 겹치지 않게 한다.
  void _autoOpenNodeSheetFromArrival(GuinjiPerson person) {
    _dismissArrivalOverlay();
    _handleNodeTap(person);
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
          // [오버플로 수정] 320x568@2.5 textScale에서 제목+본문+버튼으로
          // 구성된 Column이 Dialog 높이를 142px 초과하는 RenderFlex
          // 오버플로 발생을 확인. 커스텀 Dialog(AlertDialog 아님)라 내장
          // scrollable 옵션이 없으므로 SingleChildScrollView로 감싸
          // 해결 (디자인/색상/애니메이션 변경 없음).
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '축하 이벤트 달성',
                  style: TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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
      // [SPEC §6 H5 "해금 분기"] 서버 `/maps/me` members[].unlocked를
      // 그대로 전달 — 결제완료 사용자는 시트에 성공 박스 + "✓ 열어 둔
      // 풀이 바로 보기" 버튼이 보이게 한다(QA_CHECKLIST.md H5 행).
      unlocked: person.unlocked,
      onShare: () {
        Navigator.of(context).maybePop();
        Navigator.of(context).pushNamed('/guinji-map/m/share');
      },
      // [귀인지도 기능 정리 — 1] 이전까지 빈 콜백(() {})이라 "더 자세히
      // 보기" 버튼이 눌러도 반응이 없던 문제를 해결한다. 바텀시트를 닫고
      // 새 디자인 톤 관계상세 화면으로 push한다.
      onSeeMore: () {
        Navigator.of(context).maybePop();
        Navigator.of(
          context,
        ).push(guinjiPageRoute(GuinjiMapRelationDetailScreen(person: person)));
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

  // [귀인지도 기능 정리 — 2] 신규 디자인 계열에 랭킹 화면 진입점이
  // 아예 없던 문제를 해결한다. 상단 "목록 보기" 버튼 옆에 배치.
  void _openRanking() {
    Navigator.of(context).pushNamed('/guinji-map/m/ranking');
  }

  // [귀인지도 DIRECT — 궁합지도 DIRECT 방식과 동일한 개념] 소유자가 초대
  // 링크 없이 지인 정보를 직접 입력해 즉시 등록하는 화면으로 이동한다.
  // [SPEC §6 H4-a cta.2] 빈 자리 시트에서 넘어올 때는 슬롯 이름(예: "엄마")을
  // 미리 채워서 이동한다 — [prefillName]이 null이면 기존처럼 빈 칸.
  void _openDirectAdd({String? prefillName}) {
    Navigator.of(
      context,
    ).pushNamed('/guinji-map/m/add-direct', arguments: prefillName);
  }

  /// [SPEC §5-5 인터랙션 표] 빈 자리 별을 탭하면 H4-a 시트를 띄운다.
  /// footer: Primary(초대장 보내기 → H9) / Ghost(직접 입력, 이름 미리
  /// 채움 → H10). 이전까지는 시트 없이 바로 H10으로 직행했다.
  void _handleEmptySlotTap(GuinjiTpSlot slot) {
    showGuinjiEmptySlotSheet(
      context: context,
      slot: slot,
      filled: widget.people.length,
      onInvite: _openShareSheet,
      onDirect: (name) => _openDirectAdd(prefillName: name),
    );
  }

  /// [SPEC §5-5 인터랙션 표] 바깥 인장(유형)을 탭하면: 인원이 있으면 기존
  /// 필터 토글(강조), 인원이 0명이면 H4-b 유형 안내 시트를 띄운다.
  /// 이전까지는 인원 0인 유형도 필터 토글만 수행해 의미가 없었다.
  void _handleTypeTap(String key) {
    final hasAny = widget.people.any((p) => p.relation == key);
    if (hasAny) {
      setState(() => _filter = _filter == key ? null : key);
      return;
    }
    showGuinjiTypeInfoSheet(
      context: context,
      typeKey: key,
      people: widget.people,
      onPerson: _handleNodeTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.people.length;

    return Stack(
      children: [
        _buildScaffold(total),
        // [05-4 지인 도착 애니메이션] 지도(M)를 보고 있을 때 새 멤버가
        // 감지되면 화면 전체 위에 겹쳐 재생한다(핸드오프 "지도를 보고
        // 있을 때 재생" — 지도 자체는 가리지 않고 그 위에 효과만 더함).
        if (_pendingArrivals.isNotEmpty)
          Positioned.fill(
            child: GuinjiArrivalOverlay(
              arrivals: _pendingArrivals,
              onOpenRelation: _openArrivalRelation,
              onClose: _dismissArrivalOverlay,
              onAutoOpenNode: _autoOpenNodeSheetFromArrival,
            ),
          ),
      ],
    );
  }

  Widget _buildScaffold(int total) {
    const slotTotal = 8; // v5 TP_SLOT_TOTAL
    final empty = total == 0;
    final recent = widget.people.reversed.take(3).toList();

    return ResultTextScaleOverlay(
      child: Scaffold(
        backgroundColor: GmColors.bgBottom,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: GmColors.fg, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            '귀인지도',
            style: TextStyle(
              fontFamily: GmText.body,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: GmColors.fg,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: GmColors.fg, size: 22),
              tooltip: '귀인 초대',
              onPressed: _openShareSheet,
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: GmColors.bgGradient),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).padding.top + 56,
                  ),
                  // ── 헤더: GUINJI·貴人之圖 + 타이틀 + 케미 랭킹 버튼 ──
                  // (v5 TpMain 헤더 1:1 이식)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GUINJI · 貴人之圖',
                                style: TextStyle(
                                  fontFamily: GmText.mono,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 2.6,
                                  color: GmColors.gold,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                empty
                                    ? '빈 자리에 귀인의\n별을 띄워 보세요'
                                    : total < slotTotal
                                    ? '귀인지도를\n조금 더 채워 볼까요'
                                    : '${widget.ownerName}님을 비추는',
                                style: const TextStyle(
                                  fontFamily: GmText.display,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                  height: 1.28,
                                  color: GmColors.fg,
                                ),
                              ),
                              if (!empty && total >= slotTotal)
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$total명',
                                        style: const TextStyle(
                                          color: GmColors.gold,
                                        ),
                                      ),
                                      const TextSpan(text: '의 귀인'),
                                    ],
                                  ),
                                  style: const TextStyle(
                                    fontFamily: GmText.display,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                    height: 1.28,
                                    color: GmColors.fg,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // 케미 랭킹 버튼(왕관)
                        GestureDetector(
                          onTap: _openRanking,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: GmColors.gold.withValues(alpha: 0.4),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  GmColors.gold.withValues(alpha: 0.16),
                                  GmColors.gold.withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  color: GmColors.gold,
                                  size: 22,
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  '케미 랭킹',
                                  style: TextStyle(
                                    fontFamily: GmText.ui,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: GmColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 지도(전체 폭) — 인터랙티브 애니메이션 노드 그래프.
                  // [2026 디자인 핸드오프 v5] QA_CHECKLIST.md §2 H4 행
                  // "줌 버튼 · 범례 칩 · 3명 배너 · 가장 강한 인연 없음" 요구에
                  // 따라 "원래 크기" 리셋 버튼을 끈다(핀치 줌 제스처 자체는
                  // SPEC에 금지 문구가 없어 유지 — 조작감 저하 없이 버튼만 제거).
                  GuinjiAnimatedRelationGraph(
                    centerTitle: '${widget.ownerName}님',
                    centerSubtitle: '나',
                    ownerFacePath: widget.ownerFacePath,
                    people: widget.people,
                    showControls: false,
                    onSelect: _handleNodeTap,
                    // [v5 `onSeat`/`setFilter` 이식] 바깥 한자 인장을 탭하면
                    // 해당 유형 필터를 토글한다(상단 칩과 동일한 상태 공유).
                    onTypeTap: _handleTypeTap,
                    // [SPEC §5-5] 빈 자리 별을 탭하면 H4-a 시트를 띄운다.
                    onEmptySlotTap: _handleEmptySlotTap,
                    // [COPY.md "empty.coach"] 고정 문구. 말풍선 스타일(노랑·
                    // 지도 16% 지점·위아래 흔들림)은 그래프 위젯 내부
                    // [_GmEmptyCoachBubble]에서 처리한다.
                    emptyHint: '빈 자리를 눌러 보세요',
                    filter: _filter,
                  ),

                  // 진행 표시(귀인 N명 · 빈 자리 M) — v5 8명 기준 점 표시.
                  if (!empty && total < slotTotal)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: GmColors.bgBottom.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: GmColors.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: List.generate(slotTotal, (i) {
                                  final filled = i < total;
                                  return Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: filled
                                          ? GmColors.gold
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: GmColors.gold.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '귀인 $total명 · 빈 자리 ${slotTotal - total}',
                                style: const TextStyle(
                                  fontFamily: GmText.ui,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: GmColors.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // 안내 문구.
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      total < slotTotal
                          ? '점선 별은 빈 자리예요 · 누르면 채우는 방법이 열려요'
                          : '가운데에 가까울수록 케미가 높아요 · 바깥 인장을 누르면 유형별로 모아 봐요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: GmText.ui,
                        fontSize: 12,
                        height: 1.6,
                        color: GmColors.dim,
                      ),
                    ),
                  ),

                  // [흐름 정합성] 나는 어떤 사람일까 카드.
                  if (widget.ownerSajuSummary != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: _GmOwnerSajuCard(
                        ownerName: widget.ownerName,
                        summary: widget.ownerSajuSummary!,
                      ),
                    ),

                  // [2026 디자인 핸드오프 v5] QA_CHECKLIST.md §2 H4 행
                  // "줌 버튼 · 범례 칩 · 3명 배너 · 가장 강한 인연 없음" 요구에
                  // 따라, 헤더 아래에 있던 유형 필터 칩 행(`_GmTypeFilterRow`)과
                  // 3명 미만 배너(`_GmFewMembersBanner`)를 제거했다. SPEC §6 H4
                  // 구성(1~10번)에 이 두 섹션은 존재하지 않는다 — 유형 필터
                  // 자체는 지도 바깥 인장(한자) 탭(§5-5 "바깥 인장 탭")으로
                  // 이미 동일하게 동작하므로 기능 손실 없음. 두 위젯 클래스는
                  // 더는 쓰이지 않아 삭제했다.

                  // 귀인 초대장 박스(적색 그라데이션 — v5 "請" 봉인 디자인).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _GuinjiInviteBox(onTap: _openShareSheet),
                  ),
                  // 직접 추가 박스(v5 "記" 디자인).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: _GuinjiDirectAddBox(onTap: _openDirectAdd),
                  ),

                  // 여섯 가지 인연 알아보기 — 2열 그리드.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: _GuinjiTypeGuideSection(
                      people: widget.people,
                      onTapType: (key) {
                        // 해당 유형으로 필터 후 랭킹 화면 2번째 탭으로
                        // 이동(상세 유형 안내 시트는 후속 작업).
                        setState(() => _filter = key);
                      },
                    ),
                  ),

                  // 최근 들어온 인연.
                  if (!empty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      child: _GuinjiRecentSection(
                        people: recent,
                        onOpenAll: _openRanking,
                        onTapPerson: _handleNodeTap,
                      ),
                    ),

                  // 웹 일반 AdSense.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: const WebAdInPage(
                      surface: WebAdSurface.guinji,
                      adSlot: '',
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// v5 TpMain "귀인 초대장 보내기" 박스 — 적색 그라데이션 봉인 디자인.
class _GuinjiInviteBox extends StatelessWidget {
  const _GuinjiInviteBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GmColors.gold.withValues(alpha: 0.45)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB8402F), Color(0xFF8A2A22), Color(0xFF5E1A1E)],
          ),
          boxShadow: [
            BoxShadow(
              color: GmColors.red.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Transform.rotate(
              angle: -0.09,
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: GmColors.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '請',
                  style: TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF5E1A1E),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '귀인 초대장 보내기',
                    style: TextStyle(
                      fontFamily: GmText.body,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFF3DC),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '카카오톡으로 보내면 지인이 직접 입력해요\n앱으로 참여하면 +20P',
                    style: TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xC7FFEBD2),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: GmColors.gold, size: 22),
          ],
        ),
      ),
    );
  }
}

/// v5 TpMain "생년월일을 알아요 · 직접 추가" 박스.
class _GuinjiDirectAddBox extends StatelessWidget {
  const _GuinjiDirectAddBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GmColors.line),
          color: GmColors.card.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Transform.rotate(
              angle: -0.09,
              child: Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GmColors.gold),
                ),
                child: const Text(
                  '記',
                  style: TextStyle(
                    fontFamily: GmText.display,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: GmColors.gold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '생년월일을 알아요 · 직접 추가',
                    style: TextStyle(
                      fontFamily: GmText.body,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: GmColors.fg,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '가족·연인처럼 생일을 아는 사람은 바로 볼 수 있어요',
                    style: TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 12.5,
                      height: 1.45,
                      color: GmColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: GmColors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

/// v5 TpMain "여섯 가지 인연 알아보기" — 2열 그리드(관계유형 6종 카드).
class _GuinjiTypeGuideSection extends StatelessWidget {
  const _GuinjiTypeGuideSection({required this.people, required this.onTapType});

  final List<GuinjiPerson> people;
  final void Function(String key) onTapType;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final p in people) {
      counts[p.relation] = (counts[p.relation] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GUIDE · 06',
          style: TextStyle(
            fontFamily: GmText.mono,
            fontSize: 10,
            letterSpacing: 2.6,
            color: GmColors.dim,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '여섯 가지 인연 알아보기',
          style: TextStyle(
            fontFamily: GmText.body,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: GmColors.fg,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [
            for (final t in guinjiTypeOrder)
              _TypeGuideCard(
                spec: guinjiTypeOf(t),
                count: counts[t] ?? 0,
                onTap: () => onTapType(t),
              ),
          ],
        ),
      ],
    );
  }
}

class _TypeGuideCard extends StatelessWidget {
  const _TypeGuideCard({
    required this.spec,
    required this.count,
    required this.onTap,
  });

  final GuinjiTypeSpec spec;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GmColors.hair),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              spec.color.withValues(alpha: 0.08),
              GmColors.card.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: spec.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    spec.hanja,
                    style: const TextStyle(
                      fontFamily: GmText.display,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: GmColors.onFg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  spec.label,
                  style: const TextStyle(
                    fontFamily: GmText.body,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: GmColors.fg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Expanded(
              child: Text(
                spec.desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: GmText.ui,
                  fontSize: 12,
                  height: 1.4,
                  color: GmColors.muted,
                ),
              ),
            ),
            Text(
              '$count명 · 자세히 ›',
              style: TextStyle(
                fontFamily: GmText.ui,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: spec.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// v5 TpMain "최근 들어온 인연" 섹션.
class _GuinjiRecentSection extends StatelessWidget {
  const _GuinjiRecentSection({
    required this.people,
    required this.onOpenAll,
    required this.onTapPerson,
  });

  final List<GuinjiPerson> people;
  final VoidCallback onOpenAll;
  final void Function(GuinjiPerson person) onTapPerson;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RECENT',
                    style: TextStyle(
                      fontFamily: GmText.mono,
                      fontSize: 10,
                      letterSpacing: 2.6,
                      color: GmColors.dim,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '최근 들어온 인연',
                    style: TextStyle(
                      fontFamily: GmText.body,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GmColors.fg,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onOpenAll,
              child: const Text(
                '전체 목록 ›',
                style: TextStyle(fontSize: 13, color: GmColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GmColors.hair),
            color: GmColors.card.withValues(alpha: 0.2),
          ),
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++)
                _RecentRow(
                  person: people[i],
                  showDivider: i != 0,
                  onTap: () => onTapPerson(people[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.person,
    required this.showDivider,
    required this.onTap,
  });

  final GuinjiPerson person;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = guinjiTypeOf(person.relation);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(top: BorderSide(color: GmColors.hair))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: spec.color.withValues(alpha: 0.16),
                border: Border.all(color: spec.color),
              ),
              child: Text(
                person.name.isNotEmpty ? person.name.substring(0, 1) : '?',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: spec.color,
                ),
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
                      fontFamily: GmText.body,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: GmColors.fg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: spec.hanja,
                          style: const TextStyle(
                            fontFamily: GmText.display,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: ' ${spec.label}'),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: GmText.ui,
                      fontSize: 12,
                      color: spec.color,
                    ),
                  ),
                  // [COPY.md "badge.unlocked" = "풀이 열림"] QA_CHECKLIST.md
                  // H4 행 "최근 3명 + 풀이 열림 뱃지" 요구 — person.unlocked가
                  // true(서버 `/maps/me` members[].unlocked)일 때만 노출한다.
                  if (person.unlocked) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: GmColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: GmColors.gold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Text(
                        '✓ 풀이 열림',
                        style: TextStyle(
                          fontFamily: GmText.ui,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: GmColors.gold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${person.score}',
              style: const TextStyle(
                fontFamily: GmText.display,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: GmColors.fg,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: GmColors.dim),
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
                    fontWeight: FontWeight.w800,
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


