import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';

/// [바이럴 페이지 개편 — 2026] `/guinji-map/m`(M·My Map)의 관계 그래프에
/// 쓰던 애니메이션 로직을 공용 위젯으로 추출했다. M화면(pan/zoom/drag
/// 인터랙티브)과 게스트 결과 화면(Y·비인터랙티브, 호스트+게스트 2노드
/// 미니 지도)이 동일한 시각 언어(회전 궤도 링·레이더 펄스·호흡하는
/// 노드·에너지 흐름·등장 애니메이션)를 공유하도록 한다.
///
/// [바이럴 흐름 — "메인귀인지도 기능이 다 나온다"] 사용자가 요구한 핵심은
/// 초대 링크로 들어온 게스트가 생년월일을 입력하면, 회원가입한 본계정
/// 사용자가 보는 "내 귀인지도"(M화면)와 동일한 애니메이션 지도 경험을
/// 그 자리에서(로그인 없이) 보게 하는 것이다. 이 위젯을 양쪽에서 공유하는
/// 것이 그 요구의 기술적 구현이다.
class GuinjiGraphNode {
  GuinjiGraphNode({
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

/// [people]을 절차적으로 배치한다: 각도는 인덱스 균등분배(12시 방향부터
/// 시계방향), 중심 거리(r)와 노드 반지름은 점수에 반비례/비례한다.
List<GuinjiGraphNode> layoutGuinjiGraphNodes(
  List<GuinjiPerson> people,
  double cx,
  double cy,
) {
  if (people.isEmpty) return const [];
  final total = people.length;
  return people.asMap().entries.map((e) {
    final i = e.key;
    final p = e.value;
    final angle = (i / total) * math.pi * 2 - math.pi / 2;
    final r = 60 + (100 - p.score) * 1.6;
    final meta = guinjiRelationTypes[p.relation];
    final color = meta != null ? GmColors.categoryColor(meta.category) : GmColors.rose500;
    return GuinjiGraphNode(
      x: cx + math.cos(angle) * r,
      y: cy + math.sin(angle) * r,
      r: 22 + (p.score - 50) * 0.25,
      color: color,
      person: p,
    );
  }).toList();
}

/// 배경 반짝임용 별 하나의 사양(위치는 컨테이너 크기에 대한 0~1 비율).
class GuinjiGraphStarSpec {
  GuinjiGraphStarSpec({
    required this.dx,
    required this.dy,
    required this.phase,
    required this.speed,
    required this.maxOpacity,
    required this.radius,
    required this.gold,
  });

  final double dx, dy, phase, speed, maxOpacity, radius;
  final bool gold;
}

List<GuinjiGraphStarSpec> generateGuinjiGraphStars({int count = 18, int seed = 7}) {
  final rnd = math.Random(seed);
  return List.generate(count, (i) {
    return GuinjiGraphStarSpec(
      dx: rnd.nextDouble(),
      dy: rnd.nextDouble(),
      phase: rnd.nextDouble() * math.pi * 2,
      speed: 0.6 + rnd.nextDouble() * 1.2,
      maxOpacity: 0.25 + rnd.nextDouble() * 0.35,
      radius: 0.8 + rnd.nextDouble() * 1.4,
      gold: i.isEven,
    );
  });
}

/// 애니메이션 관계 그래프 — 화려하고 정교한 움직임을 가진 귀인지도의
/// 핵심 비주얼. [interactive]가 true면 pan(빈 공간 드래그)/zoom(pinch)/
/// drag(노드 이동)/tap(노드 선택)을 지원하고(M화면용), false면 순수
/// 감상용 애니메이션만 재생한다(게스트 결과 화면 등 미니 프리뷰용).
class GuinjiAnimatedRelationGraph extends StatefulWidget {
  const GuinjiAnimatedRelationGraph({
    super.key,
    required this.people,
    this.centerTitle = '나',
    this.centerSubtitle = '',
    this.onSelect,
    this.interactive = true,
    this.showControls = true,
    this.showLegend = true,
    this.height = 380,
    this.emptyHint,
  });

  final List<GuinjiPerson> people;

  /// 중앙 노드 위쪽 굵은 텍스트(예: "지민님", 게스트 화면에선 호스트 이름).
  final String centerTitle;

  /// 중앙 노드 아래쪽 보조 텍스트(예: "나").
  final String centerSubtitle;

  final void Function(GuinjiPerson person)? onSelect;

  /// pan/zoom/drag/tap 제스처 활성화 여부.
  final bool interactive;

  /// 우측 상단 확대/축소/리셋 컨트롤 표시 여부.
  final bool showControls;

  /// 좌측 하단 범례(카테고리 색상) 표시 여부.
  final bool showLegend;

  final double height;

  /// people이 빈 배열일 때 중앙에 표시할 안내 문구. null이면 표시하지 않음.
  final String? emptyHint;

  @override
  State<GuinjiAnimatedRelationGraph> createState() =>
      _GuinjiAnimatedRelationGraphState();
}

class _GuinjiAnimatedRelationGraphState
    extends State<GuinjiAnimatedRelationGraph> with TickerProviderStateMixin {
  final _key = GlobalKey();
  double _scale = 1;
  double _panX = 0, _panY = 0;
  double _pinchStart = 1;
  final _nodes = <GuinjiGraphNode>[];
  GuinjiGraphNode? _dragging;
  bool _panning = false;
  bool _moved = false;
  int _lastNodeCount = -1;

  /// 연속 "시계" — 12초 주기로 0→1 반복. 링 회전/펄스/호흡/에너지 흐름이
  /// 모두 이 값에서 서로 다른 배속으로 파생된다.
  late final AnimationController _timeController;

  /// 최초 진입(혹은 인원 수 변화) 시 한 번 재생되는 등장(entrance) 애니메이션.
  late final AnimationController _entranceController;

  late final List<GuinjiGraphStarSpec> _starSpecs;

  @override
  void initState() {
    super.initState();
    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _starSpecs = generateGuinjiGraphStars();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildLayout());
  }

  @override
  void didUpdateWidget(covariant GuinjiAnimatedRelationGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildLayout();
  }

  @override
  void dispose() {
    _timeController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _rebuildLayout() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final cx = size.width / 2;
    final cy = size.height / 2;
    _nodes
      ..clear()
      ..addAll(layoutGuinjiGraphNodes(widget.people, cx, cy));
    if (_nodes.isNotEmpty && _nodes.length != _lastNodeCount) {
      _lastNodeCount = _nodes.length;
      _entranceController.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  GuinjiGraphNode? _hitTest(Offset local) {
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
    final content = CustomPaint(
      key: _key,
      painter: null,
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: Listenable.merge([_timeController, _entranceController]),
          builder: (context, _) {
            return CustomPaint(
              painter: GuinjiGraphPainter(
                nodes: _nodes,
                centerTitle: widget.centerTitle,
                centerSubtitle: widget.centerSubtitle,
                scale: _scale,
                panX: _panX,
                panY: _panY,
                time: _timeController.value,
                entrance: _entranceController.value,
                draggingPerson: _dragging?.person,
                stars: _starSpecs,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );

    final gestureWrapped = widget.interactive
        ? GestureDetector(
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
              if (_dragging != null && !_moved && widget.onSelect != null) {
                widget.onSelect!(_dragging!.person);
              }
              _dragging = null;
              _panning = false;
            },
            child: content,
          )
        : IgnorePointer(child: content);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: widget.height,
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
          Positioned.fill(child: gestureWrapped),
          if (widget.people.isEmpty && widget.emptyHint != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.emptyHint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: GmColors.inkFaint),
                ),
              ),
            ),
          if (widget.interactive && widget.showControls)
            Positioned(
              top: 12,
              right: 12,
              child: _GmGraphZoomControls(
                onZoomIn: () => setState(() => _scale = (_scale + 0.2).clamp(0.6, 2.5)),
                onZoomOut: () => setState(() => _scale = (_scale - 0.2).clamp(0.6, 2.5)),
                onReset: () => setState(() {
                  _scale = 1;
                  _panX = 0;
                  _panY = 0;
                }),
              ),
            ),
          if (widget.showLegend)
            const Positioned(left: 12, bottom: 12, child: _GmGraphLegend()),
        ],
      ),
    );
  }
}

class _GmGraphZoomControls extends StatelessWidget {
  const _GmGraphZoomControls({required this.onZoomIn, required this.onZoomOut, required this.onReset});

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

class _GmGraphLegend extends StatelessWidget {
  const _GmGraphLegend();

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

/// [GuinjiAnimatedRelationGraph]의 실제 렌더링을 담당하는 CustomPainter.
/// 회전 궤도 링·레이더 펄스·호흡하는 중심/노드·에너지 흐름 입자·순차
/// 등장(stagger) 애니메이션 + 배경 별빛 반짝임을 그린다.
class GuinjiGraphPainter extends CustomPainter {
  GuinjiGraphPainter({
    required this.nodes,
    required this.centerTitle,
    required this.centerSubtitle,
    required this.scale,
    required this.panX,
    required this.panY,
    required this.time,
    required this.entrance,
    required this.stars,
    this.draggingPerson,
  });

  final List<GuinjiGraphNode> nodes;
  final String centerTitle;
  final String centerSubtitle;
  final double scale, panX, panY;

  /// 0→1 무한 반복되는 시계값(12초 주기).
  final double time;

  /// 0(등장 시작)→1(완전히 배치 완료) 등장 진행도.
  final double entrance;

  final List<GuinjiGraphStarSpec> stars;

  /// 현재 드래그 중인 노드 — breathing/float을 잠시 멈춘다.
  final GuinjiPerson? draggingPerson;

  static const _twoPi = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    // ── 배경 별빛 반짝임(팬/줌 영향을 받지 않도록 canvas 변환 전에 그린다) ──
    for (final s in stars) {
      final tw = (math.sin(time * _twoPi * s.speed + s.phase) + 1) / 2;
      final opacity = 0.15 + tw * s.maxOpacity;
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        s.radius * (0.6 + tw * 0.4),
        Paint()
          ..color = (s.gold ? GmColors.gold : GmColors.rose400)
              .withValues(alpha: opacity),
      );
    }

    canvas.save();
    canvas.translate(panX, panY);
    canvas.scale(scale);

    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── 회전하는 궤도 링(반지름별로 속도를 달리해 정교함을 살린다) ──
    final ringBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _dashed(canvas, Offset(cx, cy), 80, ringBase..color = GmColors.line,
        rotation: time * _twoPi * 0.5);
    _dashed(canvas, Offset(cx, cy), 140, ringBase..color = GmColors.line,
        rotation: -time * _twoPi * 0.32);
    _dashed(canvas, Offset(cx, cy), 200, ringBase..color = GmColors.lineSoft,
        rotation: time * _twoPi * 0.2);

    // ── 중심에서 퍼져나가는 레이더 펄스(radar ping) ──
    for (int i = 0; i < 2; i++) {
      final t = ((time + i * 0.5) % 1.0);
      final pulseRadius = 20 + t * 190;
      final pulseOpacity = (1 - t) * 0.35;
      if (pulseOpacity > 0.01) {
        canvas.drawCircle(
          Offset(cx, cy),
          pulseRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = GmColors.rose400.withValues(alpha: pulseOpacity),
        );
      }
    }

    // ── 중심→노드 연결선 + 흐르는 에너지 입자 ──
    for (final n in nodes) {
      final nodeEntrance = _entranceForNode(n, entrance);
      final ex = cx + (n.x - cx) * nodeEntrance;
      final ey = cy + (n.y - cy) * nodeEntrance;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(ex, ey),
        Paint()
          ..color = n.color.withValues(alpha: 0.4 * nodeEntrance)
          ..strokeWidth = 1,
      );
      if (nodeEntrance > 0.98) {
        for (int k = 0; k < 2; k++) {
          final flow = ((time * (0.7 + k * 0.15)) + k * 0.5) % 1.0;
          final fx = cx + (n.x - cx) * flow;
          final fy = cy + (n.y - cy) * flow;
          final fade = math.sin(flow * math.pi);
          canvas.drawCircle(
            Offset(fx, fy),
            2.2,
            Paint()..color = n.color.withValues(alpha: 0.75 * fade),
          );
        }
      }
    }

    // ── 중앙 노드: 은은한 호흡(scale) + 오라 ──
    final ownerBreath = 1 + math.sin(time * _twoPi * 0.5) * 0.035;
    canvas.drawCircle(
      Offset(cx, cy),
      40 * ownerBreath,
      Paint()..color = GmColors.gold.withValues(alpha: 0.14),
    );
    canvas.drawCircle(Offset(cx, cy), 34 * ownerBreath, Paint()..color = GmColors.ink);
    _text(canvas, Offset(cx, cy - 3), centerTitle, 10, GmColors.ivory, weight: FontWeight.w700);
    if (centerSubtitle.isNotEmpty) {
      _text(canvas, Offset(cx, cy + 10), centerSubtitle, 8, GmColors.gold);
    }

    // ── 인물 노드: 등장(scale+fade) + 호흡 + 미세 플로팅 ──
    for (final n in nodes) {
      final nodeEntrance = _entranceForNode(n, entrance);
      if (nodeEntrance <= 0.001) continue;
      final isDragging = draggingPerson == n.person;
      final seedOffset = n.person.name.hashCode % 1000 / 1000.0;
      final breathe = isDragging
          ? 1.0
          : 1 + math.sin(time * _twoPi * 0.7 + seedOffset * _twoPi) * 0.06;
      final floatY = isDragging
          ? 0.0
          : math.sin(time * _twoPi * 0.45 + seedOffset * _twoPi) * 2.5;
      final ox = n.x;
      final oy = n.y + floatY;
      final r = n.r * breathe * nodeEntrance.clamp(0.0, 1.0);
      final alpha = nodeEntrance.clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(ox, oy),
        r + 4,
        Paint()..color = n.color.withValues(alpha: 0.15 * alpha),
      );
      canvas.drawCircle(Offset(ox, oy), r, Paint()..color = n.color.withValues(alpha: alpha));
      canvas.drawCircle(
        Offset(ox, oy),
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (alpha > 0.6) {
        _text(canvas, Offset(ox, oy - 1), n.person.name, 10, Colors.white.withValues(alpha: alpha), weight: FontWeight.w700);
        _text(canvas, Offset(ox, oy + 10), '${n.person.score}', 8, Colors.white.withValues(alpha: alpha * 0.85));
      }
    }

    canvas.restore();
  }

  /// 노드별로 등장 시작 시점을 살짝 엇갈리게(stagger) 만들어 순차적으로
  /// 퍼져나가는 느낌을 준다.
  double _entranceForNode(GuinjiGraphNode n, double globalEntrance) {
    final total = nodes.length;
    if (total == 0) return globalEntrance;
    final idx = nodes.indexOf(n);
    final stagger = total <= 1 ? 0.0 : (idx / total) * 0.4;
    final local = ((globalEntrance - stagger) / (1 - 0.4)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }

  void _dashed(Canvas c, Offset center, double radius, Paint p, {double rotation = 0}) {
    const step = 6 / 180 * math.pi;
    for (double a = rotation; a < _twoPi + rotation; a += step * 2) {
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
  bool shouldRepaint(covariant GuinjiGraphPainter oldDelegate) => true;
}
