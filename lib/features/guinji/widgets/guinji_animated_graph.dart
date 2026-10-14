import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../character/guinji_character.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import 'guinji_layout.dart';

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
    required this.labelTop,
    this.facePath,
  });

  double x, y, r;
  final Color color;
  final GuinjiPerson person;

  /// handoff `n.side === 'top'` — true면 이름표가 노드 위쪽(노드가 지도
  /// 하반부에 있을 때), false면 아래쪽.
  final bool labelTop;

  /// 캐릭터 얼굴 에셋 경로(`assets/images/guinji/chars/*_face.jpg`).
  /// 생년월일을 파싱할 수 없으면 null — 폴백(색상 원+이니셜)으로 렌더.
  final String? facePath;
}

/// 지도 배치 결과 — 노드 목록 + 실제 중심 좌표(핸드오프 `GJ.layout()`의
/// `cx,cy`와 동일한 공식으로 계산됨, size.width/2·height/2와는 padT/padB
/// 만큼 미세하게 다를 수 있어 별도로 전달한다).
class GuinjiGraphLayoutResult {
  GuinjiGraphLayoutResult(this.nodes, this.center);
  final List<GuinjiGraphNode> nodes;
  final Offset center;
}

/// "YYYY·MM·DD" 형식의 [GuinjiPerson.birth] 문자열을 [DateTime]으로
/// 변환한다. 파싱할 수 없으면 null(캐릭터 사진 없이 폴백 렌더).
DateTime? parseGuinjiBirthLabel(String label) {
  final parts = label.split('·');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  try {
    return DateTime(y, m, d);
  } catch (_) {
    return null;
  }
}

/// [people]을 핸드오프 원본 `GJ.layout()`(`guinji_layout.dart`
/// `computeGuinjiLayout`)과 동일한 알고리즘으로 배치한다: ①각도는
/// 관계유형별 부채꼴(천생귀인 12시부터 시계방향) ②거리는 점수(높을수록
/// 중심 가까이) ③중심에서 뻗는 직선이라 교차 불가 ④라벨은 위/아래 노드
/// 측면 자동 배정 ⑤노드·라벨·중앙·경계 충돌을 2D로 밀어내기(최대 400회).
GuinjiGraphLayoutResult layoutGuinjiGraphNodes(
  List<GuinjiPerson> people,
  Size size,
) {
  if (people.isEmpty || size.width <= 0 || size.height <= 0) {
    return GuinjiGraphLayoutResult(
      const [],
      Offset(size.width / 2, size.height / 2),
    );
  }
  final nodeIns = people
      .map((p) => GuinjiNodeIn(p.id, p.name, p.relation, p.score))
      .toList();
  final layout = computeGuinjiLayout(nodeIns, size);
  final byId = {for (final p in people) p.id: p};
  final nodes = layout.nodes.map((n) {
    final p = byId[n.m.id]!;
    final meta = guinjiRelationMetaOf(p.relation);
    final birth = parseGuinjiBirthLabel(p.birth);
    final facePath = birth == null
        ? null
        : GuinjiCharacter.of(
            birth: birth,
            gender: GuinjiCharacter.fromKey(p.gender),
            stableKey: p.id,
          ).face;
    return GuinjiGraphNode(
      x: n.x,
      y: n.y,
      r: layout.d.nodeD / 2,
      color: meta.color,
      person: p,
      labelTop: n.labelTop,
      facePath: facePath,
    );
  }).toList();
  return GuinjiGraphLayoutResult(nodes, layout.center);
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

List<GuinjiGraphStarSpec> generateGuinjiGraphStars({
  int count = 18,
  int seed = 7,
}) {
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
    this.height = 500, // [사용자 피드백 — 지도를 더 크게] 기본 380 → 500
    this.emptyHint,
    this.filter,
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

  /// [핸드오프 `CMain` filter 상태 이식] 관계 유형(6종 키) 하나를 지정하면
  /// 해당 유형의 노드/방사선만 강조하고, 나머지는 흐리게 처리한다. null이면
  /// 필터 없음(전체 표시). 외부(M화면의 유형 칩)에서 제어한다.
  final String? filter;

  @override
  State<GuinjiAnimatedRelationGraph> createState() =>
      _GuinjiAnimatedRelationGraphState();
}

class _GuinjiAnimatedRelationGraphState
    extends State<GuinjiAnimatedRelationGraph>
    with TickerProviderStateMixin {
  final _key = GlobalKey();
  double _scale = 1;
  double _panX = 0, _panY = 0;
  double _pinchStart = 1;
  final _nodes = <GuinjiGraphNode>[];
  Offset _center = Offset.zero;
  GuinjiGraphNode? _dragging;
  bool _panning = false;
  bool _moved = false;
  int _lastNodeCount = -1;

  /// [핸드오프 `sel` 상태 이식] 탭으로 선택된 노드 — 드래그 종료 후에도
  /// 유지되어(onSelect 콜백이 N·Sheet을 띄우고 닫혀도) 방사선/링 강조가
  /// 계속 표시된다. 다시 탭하면 토글(선택 해제).
  GuinjiPerson? _selected;

  /// 연속 "시계" — 12초 주기로 0→1 반복. 링 회전/펄스/호흡/에너지 흐름이
  /// 모두 이 값에서 서로 다른 배속으로 파생된다.
  late final AnimationController _timeController;

  /// 최초 진입(혹은 인원 수 변화) 시 한 번 재생되는 등장(entrance) 애니메이션.
  late final AnimationController _entranceController;

  late final List<GuinjiGraphStarSpec> _starSpecs;

  /// [핸드오프 `Face` 이식 — 사진 노드] 캐릭터 얼굴 jpg를 미리 디코드해
  /// 캐시한다(CustomPainter는 동기 렌더만 가능하므로, 로드 완료 후
  /// setState로 다시 그린다). 키 = facePath.
  final Map<String, ui.Image> _faceImageCache = {};
  final Set<String> _faceLoading = {};

  /// 소유자("나") 얼굴 캐시 — 데모 고정 ID.
  ui.Image? _ownerFaceImage;

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
    _loadFaceImage(_ownerFaceAsset(fallback: 'assets/images/guinji/chars/f30_face.jpg'), isOwner: true);
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
    final result = layoutGuinjiGraphNodes(widget.people, size);
    _nodes
      ..clear()
      ..addAll(result.nodes);
    _center = result.center;
    if (_nodes.isNotEmpty && _nodes.length != _lastNodeCount) {
      _lastNodeCount = _nodes.length;
      _entranceController.forward(from: 0);
    }
    for (final n in _nodes) {
      final path = n.facePath;
      if (path != null) _loadFaceImage(path);
    }
    if (mounted) setState(() {});
  }

  /// [핸드오프 `Face` 이식] 에셋 jpg를 [ui.Image]로 비동기 디코드해
  /// 캐시한다. 이미 캐시되었거나 로딩 중이면 중복 로드하지 않는다.
  String _ownerFaceAsset({required String fallback}) {
    // [성별 캐릭터 버그 수정 — 2026-10-14] 하드코딩된 여성 얼굴(f30) 대신
    // 소유자 GuinjiPerson의 birth+gender로 캐릭터를 산출한다(지도에 소유자가
    // 없으면 기존 기본값 유지). 가운데 표시 문자는 '나' 고정 관례를 따른다.
    try {
      final people = widget.people;
      if (people.isEmpty) return fallback;
      final owner = people.where((p0) => p0.id == 'owner').firstOrNull ?? people.first;
      final birth = parseGuinjiBirthLabel(owner.birth);
      if (birth == null) return fallback;
      return GuinjiCharacter.of(
        birth: birth,
        gender: GuinjiCharacter.fromKey(owner.gender),
        stableKey: owner.id,
      ).face;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _loadFaceImage(String assetPath, {bool isOwner = false}) async {
    if (_faceImageCache.containsKey(assetPath) ||
        _faceLoading.contains(assetPath)) {
      return;
    }
    _faceLoading.add(assetPath);
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _faceImageCache[assetPath] = frame.image;
        if (isOwner) _ownerFaceImage = frame.image;
      });
    } catch (_) {
      // 에셋이 없으면 폴백(색상 원+이니셜) 렌더로 자연스럽게 이어진다.
    } finally {
      _faceLoading.remove(assetPath);
    }
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
                center: _center,
                centerTitle: widget.centerTitle,
                centerSubtitle: widget.centerSubtitle,
                scale: _scale,
                panX: _panX,
                panY: _panY,
                time: _timeController.value,
                entrance: _entranceController.value,
                draggingPerson: _dragging?.person,
                stars: _starSpecs,
                faceImages: _faceImageCache,
                ownerFaceImage: _ownerFaceImage,
                selectedPerson: _selected,
                filter: widget.filter,
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
              if (_dragging != null && !_moved) {
                final tapped = _dragging!.person;
                setState(() {
                  _selected = _selected == tapped ? null : tapped;
                });
                widget.onSelect?.call(tapped);
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
          colors: [GmColors.bg, GmColors.card.withValues(alpha: 0.6)],
        ),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: gestureWrapped),
          // [핸드오프 `CEmpty` 이식] 6슬롯 점선 방사형 비주얼은
          // [GuinjiGraphPainter]가 캔버스 위에 직접 그린다(위 CustomPaint).
          // 여기서는 그 아래(하단)에 안내 문구만 겹치지 않게 배치한다.
          if (widget.people.isEmpty && widget.emptyHint != null)
            Align(
              alignment: const Alignment(0, 0.72),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.emptyHint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: GmColors.dim,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          if (widget.interactive && widget.showControls)
            Positioned(
              top: 12,
              right: 12,
              child: _GmGraphZoomControls(
                onZoomIn: () =>
                    setState(() => _scale = (_scale + 0.2).clamp(0.6, 2.5)),
                onZoomOut: () =>
                    setState(() => _scale = (_scale - 0.2).clamp(0.6, 2.5)),
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
  const _GmGraphZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn, onZoomOut, onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GmColors.card.withValues(alpha: 0.9),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _btn(Icons.add, onZoomIn),
          const SizedBox(height: 4.0),
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
    child: SizedBox(
      width: 28,
      height: 28,
      child: Icon(i, size: 14, color: GmColors.fg),
    ),
  );
}

class _GmGraphLegend extends StatelessWidget {
  const _GmGraphLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GmColors.card.withValues(alpha: 0.9),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '거리 = 관계 거리',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: GmColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final cat in guinjiCategoryOrder) ...[
                _swatch(_categoryColor(cat.key), cat.title),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatch(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: GmColors.fg)),
    ],
  );
}

/// 카테고리(boost/path/care) 대표 색상 — 해당 카테고리에 속한 첫 관계
/// 유형의 색을 그대로 사용한다(V2 6종, 2종씩 묶음).
Color _categoryColor(String category) {
  final keys = guinjiRelationKeysByCategory[category];
  if (keys == null || keys.isEmpty) return GmColors.gold;
  return guinjiRelationMetaOf(keys.first).color;
}

/// [GuinjiAnimatedRelationGraph]의 실제 렌더링을 담당하는 CustomPainter.
///
/// [핸드오프 `CleanMap` 1:1 이식] 중심에서 뻗는 방사선(흰색 22%) + 같은
/// 유형끼리의 이웃 연결선(그물망, 흰색 10%) + 사진 노드(원형 얼굴, 선택
/// 시 유형색 링+글로우+1.12배 확대) + 이름+한자/유형 라벨(노드 위/아래
/// 자동 배정) 위에, 기존에 만들어둔 회전 궤도 링·레이더 펄스·호흡·에너지
/// 흐름 애니메이션을 그대로 겹쳐 그린다(핸드오프에는 없는 추가 생동감).
class GuinjiGraphPainter extends CustomPainter {
  GuinjiGraphPainter({
    required this.nodes,
    required this.center,
    required this.centerTitle,
    required this.centerSubtitle,
    required this.scale,
    required this.panX,
    required this.panY,
    required this.time,
    required this.entrance,
    required this.stars,
    required this.faceImages,
    this.ownerFaceImage,
    this.draggingPerson,
    this.selectedPerson,
    this.filter,
  });

  final List<GuinjiGraphNode> nodes;

  /// 레이아웃이 계산한 실제 중심 좌표(핸드오프 `GJ.layout()`의 cx,cy).
  final Offset center;
  final String centerTitle;
  final String centerSubtitle;
  final double scale, panX, panY;

  /// 0→1 무한 반복되는 시계값(12초 주기).
  final double time;

  /// 0(등장 시작)→1(완전히 배치 완료) 등장 진행도.
  final double entrance;

  final List<GuinjiGraphStarSpec> stars;

  /// facePath → 디코드된 이미지 캐시(공유 — 매 프레임 재디코드하지 않음).
  final Map<String, ui.Image> faceImages;

  /// "나" 중앙 노드 얼굴(없으면 골드 원+이니셜 폴백).
  final ui.Image? ownerFaceImage;

  /// 현재 드래그 중인 노드 — breathing/float을 잠시 멈춘다.
  final GuinjiPerson? draggingPerson;

  /// 현재 선택된 노드(탭/드래그로 선택) — 핸드오프 `sel` 상태와 동일하게
  /// 링+글로우+확대 및 방사선 강조 처리.
  final GuinjiPerson? selectedPerson;

  /// [핸드오프 `filter` 상태 이식] 특정 관계유형 키만 강조(`off(n)` 로직:
  /// 선택 또는 필터와 무관한 노드는 opacity 0.28로 흐리게 처리).
  final String? filter;

  static const _twoPi = math.pi * 2;

  /// 핸드오프 `off(n)` — 선택된 노드가 있는데 이 노드가 아니거나, 필터가
  /// 지정됐는데 이 노드 유형이 아니면 흐리게 처리해야 함.
  bool _isOff(GuinjiGraphNode n) {
    if (selectedPerson != null && selectedPerson != n.person) return true;
    if (filter != null && filter != n.person.relation) return true;
    return false;
  }

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
          ..color = (s.gold ? GmColors.gold : GmColors.fg).withValues(
            alpha: opacity,
          ),
      );
    }

    canvas.save();
    canvas.translate(panX, panY);
    canvas.scale(scale);

    final cx = center.dx;
    final cy = center.dy;

    // ── 중앙 광량(핸드오프: radial-gradient 흰색 9% → 투명, 반경 130) ──
    canvas.drawCircle(
      Offset(cx, cy),
      130,
      Paint()
        ..shader = ui.Gradient.radial(Offset(cx, cy), 130, [
          Colors.white.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0),
        ]),
    );

    // ── 회전하는 궤도 링(반지름별로 속도를 달리해 정교함을 살린다) ──
    final ringBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _dashed(
      canvas,
      Offset(cx, cy),
      80,
      ringBase..color = GmColors.line,
      rotation: time * _twoPi * 0.5,
    );
    _dashed(
      canvas,
      Offset(cx, cy),
      140,
      ringBase..color = GmColors.line,
      rotation: -time * _twoPi * 0.32,
    );
    _dashed(
      canvas,
      Offset(cx, cy),
      200,
      ringBase..color = GmColors.hair,
      rotation: time * _twoPi * 0.2,
    );

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
            ..color = GmColors.gold.withValues(alpha: pulseOpacity),
        );
      }
    }

    // ── [핸드오프 `CEmpty` 이식] 지인이 한 명도 없을 때, 6개의 점선
    // 슬롯("＋")을 중심에서 방사형으로 배치해 "앞으로 채워질 자리"임을
    // 보여준다. 원본 좌표(CW=390 기준 `cx+cos(a)*125, cy+sin(a)*135`,
    // 각도 `-90°+i*60°+0.2rad`)를 현재 캔버스 폭 비율로 스케일링한다.
    if (nodes.isEmpty) {
      final emptyScale = (size.width / 390.0).clamp(0.6, 1.4);
      final dashedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22);
      for (int i = 0; i < 6; i++) {
        final angle = -math.pi / 2 + i * math.pi / 3 + 0.2;
        final sx = cx + math.cos(angle) * 125 * emptyScale;
        final sy = cy + math.sin(angle) * 135 * emptyScale;
        _dashedLine(
          canvas,
          Offset(cx, cy),
          Offset(sx, sy),
          Paint()
            ..strokeWidth = 1
            ..color = Colors.white.withValues(alpha: 0.12),
        );
        _dashed(canvas, Offset(sx, sy), 23 * emptyScale, dashedPaint);
        _text(
          canvas,
          Offset(sx, sy),
          '+',
          15 * emptyScale,
          GmColors.dim,
          weight: FontWeight.w400,
        );
      }
    }

    // ── [핸드오프 `webs`] 같은 유형끼리 정렬 순서로 인접한 노드를 연결하는
    // 그물망(흰색 10%, 선택/필터 중엔 무관한 쪽 0.04로 더 흐리게) ──
    for (final t in guinjiTypeOrder) {
      final group = nodes.where((n) => n.person.relation == t).toList();
      for (var i = 0; i < group.length - 1; i++) {
        final a = group[i], b = group[i + 1];
        final ae = _entranceForNode(a, entrance);
        final be = _entranceForNode(b, entrance);
        if (ae < 0.98 || be < 0.98) continue;
        final dimmed =
            (selectedPerson != null || filter != null) &&
            !((selectedPerson != null &&
                    (selectedPerson == a.person ||
                        selectedPerson == b.person)) ||
                filter == t);
        canvas.drawLine(
          Offset(a.x, a.y),
          Offset(b.x, b.y),
          Paint()
            ..color = Colors.white.withValues(alpha: dimmed ? 0.04 : 0.1)
            ..strokeWidth = 1,
        );
      }
    }

    // ── 중심→노드 방사선(핸드오프: 흰색 22%, 선택/필터 시 유형색 강조,
    // 무관한 노드는 0.05로 흐리게) + 흐르는 에너지 입자 ──
    for (final n in nodes) {
      final nodeEntrance = _entranceForNode(n, entrance);
      final ex = cx + (n.x - cx) * nodeEntrance;
      final ey = cy + (n.y - cy) * nodeEntrance;
      final isSelected = selectedPerson == n.person;
      final isFiltered = filter != null && filter == n.person.relation;
      final off = _isOff(n);
      final lineAlpha = isSelected
          ? 0.9
          : isFiltered
          ? 0.6
          : off
          ? 0.05
          : 0.22;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(ex, ey),
        Paint()
          ..color = (isSelected || isFiltered ? n.color : Colors.white)
              .withValues(alpha: lineAlpha * nodeEntrance)
          ..strokeWidth = isSelected ? 2 : 1,
      );
      if (nodeEntrance > 0.98 && !off) {
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

    // ── 중앙 노드("나"): 사진(있으면) + 은은한 호흡(scale) + 오라 ──
    final ownerBreath = 1 + math.sin(time * _twoPi * 0.5) * 0.035;
    const ownerR = 34.0;
    canvas.drawCircle(
      Offset(cx, cy),
      (ownerR + 6) * ownerBreath,
      Paint()..color = GmColors.gold.withValues(alpha: 0.14),
    );
    if (ownerFaceImage != null) {
      _drawFaceImage(
        canvas,
        ownerFaceImage!,
        Offset(cx, cy),
        ownerR * ownerBreath,
        1.0,
        ringColor: Colors.white.withValues(alpha: 0.7),
      );
    } else {
      canvas.drawCircle(
        Offset(cx, cy),
        ownerR * ownerBreath,
        Paint()..color = GmColors.card,
      );
    }
    _text(
      canvas,
      Offset(cx, cy + ownerR * ownerBreath + 16),
      centerTitle,
      11,
      GmColors.fg,
      weight: FontWeight.w600,
    );
    if (centerSubtitle.isNotEmpty) {
      _text(
        canvas,
        Offset(cx, cy + ownerR * ownerBreath + 30),
        centerSubtitle,
        9,
        GmColors.muted,
      );
    }

    // ── 인물 노드: 등장(scale+fade) + 호흡 + 미세 플로팅 + 사진 + 라벨 ──
    for (final n in nodes) {
      final nodeEntrance = _entranceForNode(n, entrance);
      if (nodeEntrance <= 0.001) continue;
      final isDragging = draggingPerson == n.person;
      final isSelected = selectedPerson == n.person;
      final seedOffset = n.person.name.hashCode % 1000 / 1000.0;
      final breathe = isDragging
          ? 1.0
          : 1 + math.sin(time * _twoPi * 0.7 + seedOffset * _twoPi) * 0.06;
      final floatY = isDragging
          ? 0.0
          : math.sin(time * _twoPi * 0.45 + seedOffset * _twoPi) * 2.5;
      final ox = n.x;
      final oy = n.y + floatY;
      final selScale = isSelected ? 1.12 : 1.0;
      final r = n.r * breathe * selScale * nodeEntrance.clamp(0.0, 1.0);
      // [핸드오프 off(n)] 선택/필터와 무관한 노드는 투명도 0.28로 흐리게.
      final offAlpha = _isOff(n) ? 0.28 : 1.0;
      final alpha = nodeEntrance.clamp(0.0, 1.0) * offAlpha;
      final faceImage = n.facePath != null ? faceImages[n.facePath] : null;

      if (isSelected) {
        canvas.drawCircle(
          Offset(ox, oy),
          r + 10,
          Paint()..color = n.color.withValues(alpha: 0.26 * alpha),
        );
      }

      if (faceImage != null) {
        _drawFaceImage(
          canvas,
          faceImage,
          Offset(ox, oy),
          r,
          alpha,
          ringColor: (isSelected
              ? n.color
              : Colors.white.withValues(alpha: 0.18)),
          ringWidth: isSelected ? 1.5 : 1,
        );
      } else {
        // 폴백: 핸드오프 사진 에셋이 아직 없을 때 — 유형색 원 + 이니셜.
        canvas.drawCircle(
          Offset(ox, oy),
          r,
          Paint()..color = n.color.withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(ox, oy),
          r,
          Paint()
            ..color = Colors.white.withValues(
              alpha: alpha * (isSelected ? 1 : 0.5),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 1.5 : 1,
        );
        if (alpha > 0.5 && n.person.name.isNotEmpty) {
          _text(
            canvas,
            Offset(ox, oy),
            n.person.name.substring(0, 1),
            r * 0.7,
            Colors.white.withValues(alpha: alpha),
            weight: FontWeight.w700,
          );
        }
      }

      if (alpha > 0.6) {
        final spec = guinjiTypeOf(n.person.relation);
        final labelY = n.labelTop ? oy - r - 8 : oy + r + 8;
        final nameY = n.labelTop ? labelY - 14 : labelY + 7;
        final typeY = n.labelTop ? labelY : labelY + 21;
        _text(
          canvas,
          Offset(ox, nameY),
          n.person.name,
          11,
          (isSelected ? GmColors.fg : const Color(0xC7F2F0EC)).withValues(
            alpha: alpha,
          ),
          weight: FontWeight.w600,
        );
        _text(
          canvas,
          Offset(ox, typeY),
          '${spec.hanja} ${spec.short}',
          9.5,
          n.color.withValues(alpha: alpha * 0.92),
          weight: FontWeight.w600,
        );
      }
    }

    canvas.restore();
  }

  /// [핸드오프 `Face` 이식] 원형으로 클리핑한 캐릭터 얼굴 이미지를 그린다.
  /// 테두리(ring)와 중심 좌표 기준 글로우를 함께 처리한다.
  void _drawFaceImage(
    Canvas canvas,
    ui.Image image,
    Offset o,
    double r,
    double alpha, {
    Color? ringColor,
    double ringWidth = 1,
  }) {
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: o, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    // 이미지를 커버 방식으로 중앙 정사각 크롭해 원형 안에 그린다.
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final srcSize = image.width < image.height
        ? image.width.toDouble()
        : image.height.toDouble();
    final srcSquare = Rect.fromCenter(
      center: src.center,
      width: srcSize,
      height: srcSize,
    );
    canvas.drawImageRect(
      image,
      srcSquare,
      rect,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.restore();
    if (ringColor != null) {
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..color = ringColor.withValues(alpha: ringColor.a * alpha),
      );
    }
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

  void _dashed(
    Canvas c,
    Offset center,
    double radius,
    Paint p, {
    double rotation = 0,
  }) {
    const step = 6 / 180 * math.pi;
    for (double a = rotation; a < _twoPi + rotation; a += step * 2) {
      c.drawLine(
        Offset(
          center.dx + math.cos(a) * radius,
          center.dy + math.sin(a) * radius,
        ),
        Offset(
          center.dx + math.cos(a + step) * radius,
          center.dy + math.sin(a + step) * radius,
        ),
        p,
      );
    }
  }

  /// [핸드오프 `CEmpty` 이식] 두 점을 잇는 점선(`stroke-dasharray: 3 5`에
  /// 해당하는 느낌의 짧은 선분 반복). `_dashed`는 원(링)용이라 직선에는
  /// 쓸 수 없어 별도 헬퍼를 둔다.
  void _dashedLine(Canvas c, Offset from, Offset to, Paint p) {
    const dashLen = 4.0, gapLen = 5.0;
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = (to - from) / total;
    double covered = 0;
    while (covered < total) {
      final segEnd = math.min(covered + dashLen, total);
      c.drawLine(from + dir * covered, from + dir * segEnd, p);
      covered += dashLen + gapLen;
    }
  }

  void _text(
    Canvas c,
    Offset o,
    String s,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GuinjiGraphPainter oldDelegate) => true;
}
