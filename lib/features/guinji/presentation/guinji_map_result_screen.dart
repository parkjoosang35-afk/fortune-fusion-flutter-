import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../domain/guinji_owner_saju_summary.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';
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
      onSeeMore: () {},
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

              // 인터랙티브 노드 그래프(pan/zoom/drag/tap)
              _InteractiveGuinjiGraph(
                ownerName: widget.ownerName,
                people: widget.people,
                onSelect: _handleNodeTap,
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

/// [person]에 계산된 화면 좌표(px, 중심 기준 상대 오프셋)를 더한 배치 결과.
class _NodeState {
  _NodeState({
    required this.x,
    required this.y,
    required this.r,
    required this.color,
    required this.person,
  });

  double x, y, r;
  final Color color;
  final GuinjiPerson person;
}

/// [people]을 새 디자인의 `InteractiveNodeGraph._rebuildLayout()` 공식으로
/// 절차적으로 배치한다: 각도는 인덱스 균등분배(12시 방향부터 시계방향),
/// 중심 거리(r)와 노드 반지름은 점수에 반비례/비례한다.
List<_NodeState> _layoutPeople(List<GuinjiPerson> people, double cx, double cy) {
  if (people.isEmpty) return const [];
  final total = people.length;
  return people.asMap().entries.map((e) {
    final i = e.key;
    final p = e.value;
    final angle = (i / total) * math.pi * 2 - math.pi / 2;
    final r = 60 + (100 - p.score) * 1.6;
    final meta = guinjiRelationTypes[p.relation];
    final color = meta != null ? GmColors.categoryColor(meta.category) : GmColors.rose500;
    return _NodeState(
      x: cx + math.cos(angle) * r,
      y: cy + math.sin(angle) * r,
      r: 22 + (p.score - 50) * 0.25,
      color: color,
      person: p,
    );
  }).toList();
}

/// 인터랙티브 노드 그래프 — pan(빈 공간 드래그) / zoom(pinch) / drag(노드
/// 이동) / tap(노드 선택)을 하나의 GestureDetector로 처리한다. 새 디자인
/// `InteractiveNodeGraph`와 동일한 구조.
class _InteractiveGuinjiGraph extends StatefulWidget {
  const _InteractiveGuinjiGraph({
    required this.ownerName,
    required this.people,
    required this.onSelect,
  });

  final String ownerName;
  final List<GuinjiPerson> people;
  final void Function(GuinjiPerson person) onSelect;

  @override
  State<_InteractiveGuinjiGraph> createState() => _InteractiveGuinjiGraphState();
}

class _InteractiveGuinjiGraphState extends State<_InteractiveGuinjiGraph> {
  final _key = GlobalKey();
  double _scale = 1;
  double _panX = 0, _panY = 0;
  double _pinchStart = 1;
  final _nodes = <_NodeState>[];
  _NodeState? _dragging;
  bool _panning = false;
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildLayout());
  }

  @override
  void didUpdateWidget(covariant _InteractiveGuinjiGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildLayout();
  }

  void _rebuildLayout() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    _nodes
      ..clear()
      ..addAll(_layoutPeople(widget.people, cx, cy));
    if (mounted) setState(() {});
  }

  _NodeState? _hitTest(Offset local) {
    final tx = (local.dx - _panX) / _scale;
    final ty = (local.dy - _panY) / _scale;
    for (final n in _nodes.reversed) {
      final dx = tx - n.x;
      final dy = ty - n.y;
      if (dx * dx + dy * dy <= n.r * n.r * 1.4) return n;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 380,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GmColors.bgIvory, GmColors.bgCream.withValues(alpha: 0.6)],
        ),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _moved = false;
                final n = _hitTest(details.localFocalPoint);
                if (n != null) {
                  _dragging = n;
                  _panning = false;
                } else {
                  _panning = true;
                  _dragging = null;
                }
                _pinchStart = _scale;
              },
              onScaleUpdate: (details) {
                if (details.pointerCount >= 2) {
                  setState(() {
                    _scale = (_pinchStart * details.scale).clamp(0.6, 2.5);
                  });
                  return;
                }
                if (details.focalPointDelta.distance > 3) _moved = true;
                setState(() {
                  if (_dragging != null) {
                    _dragging!.x += details.focalPointDelta.dx / _scale;
                    _dragging!.y += details.focalPointDelta.dy / _scale;
                  } else if (_panning) {
                    _panX += details.focalPointDelta.dx;
                    _panY += details.focalPointDelta.dy;
                  }
                });
              },
              onScaleEnd: (details) {
                if (_dragging != null && !_moved) {
                  widget.onSelect(_dragging!.person);
                }
                _dragging = null;
                _panning = false;
              },
              child: CustomPaint(
                painter: _GraphPainter(
                  nodes: _nodes,
                  ownerName: widget.ownerName,
                  scale: _scale,
                  panX: _panX,
                  panY: _panY,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          if (widget.people.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '지인을 초대하면 여기에 표시돼요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: GmColors.inkFaint),
                ),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: _ZoomControls(
              onZoomIn: () => setState(() => _scale = (_scale + 0.2).clamp(0.6, 2.5)),
              onZoomOut: () => setState(() => _scale = (_scale - 0.2).clamp(0.6, 2.5)),
              onReset: () => setState(() {
                _scale = 1;
                _panX = 0;
                _panY = 0;
              }),
            ),
          ),
          const Positioned(left: 12, bottom: 12, child: _Legend()),
        ],
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut, required this.onReset});

  final VoidCallback onZoomIn, onZoomOut, onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _btn(Icons.add, onZoomIn),
          const SizedBox(height: 4),
          _btn(Icons.remove, onZoomOut),
          const SizedBox(height: 4),
          _btn(Icons.restart_alt, onReset),
        ],
      ),
    );
  }

  Widget _btn(IconData i, VoidCallback tap) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(width: 28, height: 28, child: Icon(i, size: 14, color: GmColors.ink)),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '거리 = 관계 거리',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: GmColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _swatch(GmColors.categoryBoost, '귀인'),
              const SizedBox(width: 8),
              _swatch(GmColors.categoryPath, '인연'),
              const SizedBox(width: 8),
              _swatch(GmColors.categoryWarm, '보완'),
              const SizedBox(width: 8),
              _swatch(GmColors.categoryCare, '조심'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatch(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: GmColors.ink)),
    ],
  );
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.nodes,
    required this.ownerName,
    required this.scale,
    required this.panX,
    required this.panY,
  });

  final List<_NodeState> nodes;
  final String ownerName;
  final double scale, panX, panY;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panX, panY);
    canvas.scale(scale);

    final cx = size.width / 2;
    final cy = size.height / 2;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = GmColors.line;
    _dashed(canvas, Offset(cx, cy), 80, ring);
    _dashed(canvas, Offset(cx, cy), 140, ring);
    _dashed(canvas, Offset(cx, cy), 200, ring..color = GmColors.lineSoft);

    for (final n in nodes) {
      canvas.drawLine(
        Offset(cx, cy),
        Offset(n.x, n.y),
        Paint()
          ..color = n.color.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
    }

    canvas.drawCircle(Offset(cx, cy), 34, Paint()..color = GmColors.ink);
    _text(canvas, Offset(cx, cy - 3), '$ownerName님', 10, GmColors.ivory, weight: FontWeight.w700);
    _text(canvas, Offset(cx, cy + 10), '나', 8, GmColors.gold);

    for (final n in nodes) {
      canvas.drawCircle(Offset(n.x, n.y), n.r + 4, Paint()..color = n.color.withValues(alpha: 0.15));
      canvas.drawCircle(Offset(n.x, n.y), n.r, Paint()..color = n.color);
      canvas.drawCircle(
        Offset(n.x, n.y),
        n.r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _text(canvas, Offset(n.x, n.y - 1), n.person.name, 10, Colors.white, weight: FontWeight.w700);
      _text(canvas, Offset(n.x, n.y + 10), '${n.person.score}', 8, Colors.white.withValues(alpha: 0.85));
    }

    canvas.restore();
  }

  void _dashed(Canvas c, Offset center, double radius, Paint p) {
    const step = 6 / 180 * math.pi;
    for (double a = 0; a < math.pi * 2; a += step * 2) {
      c.drawLine(
        Offset(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius),
        Offset(center.dx + math.cos(a + step) * radius, center.dy + math.sin(a + step) * radius),
        p,
      );
    }
  }

  void _text(Canvas c, Offset o, String s, double size, Color color, {FontWeight weight = FontWeight.w600}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.panX != panX ||
      oldDelegate.panY != panY ||
      oldDelegate.nodes != nodes;
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
