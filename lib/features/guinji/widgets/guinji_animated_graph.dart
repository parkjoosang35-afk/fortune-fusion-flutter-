// lib/features/guinji/widgets/guinji_animated_graph.dart
// [2026 디자인 핸드오프 v5 — "심야의 신전" 지도 비주얼 전면 재작성]
// `design_handoff_guinji_map_v5/design_files/guinji-temple.jsx`의
// `TpMap`(SVG, 228~394줄)을 Flutter `CustomPainter`로 1:1 변환한다.
// README §3 지시: "귀인지도 전 화면을 이 디자인으로 100% 교체. 기존
// 화면의 레이아웃·색·폰트·문구·컴포넌트는 하나도 남기지 않는다. 남기는
// 것은 로직만"에 따라, 이전(v2/v3) 스타일의 회전 궤도 링·레이더 펄스
// 비주얼은 완전히 제거하고 v5 고유의 비주얼(오로라 성운·금빛 광선·별
// 먼지·반짝임·별똥별·한자 인장 범례·육각 궤도 배치)로 교체한다.
// 유지하는 로직: 배치 알고리즘은 `guinji_layout.dart`의 `tpPlace()` 포팅을
// 그대로 쓰고, 공개 위젯 API([GuinjiAnimatedRelationGraph] 생성자 파라미터
// 대부분)와 [parseGuinjiBirthLabel] 유틸은 호출부(여러 화면)가 그대로
// 참조하므로 보존한다.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/zoom/pinch_zoom_exclusion.dart';
import '../character/guinji_character.dart';
import '../domain/guinji_person.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import 'guinji_layout.dart';

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

/// v5 `tpPlace()` 결과 1명분 + 렌더링에 필요한 파생 정보(색·얼굴 경로).
/// x,y는 드래그(제스처)로 즉석에서 바뀔 수 있어 mutable.
class GuinjiTpRenderNode {
  GuinjiTpRenderNode({
    required this.person,
    required this.type,
    required this.score,
    required this.x,
    required this.y,
    required this.color,
    this.facePath,
  });

  final GuinjiPerson person;
  final String type;
  final int score;
  double x, y; // 캔버스 좌표계(390×520) 기준.
  final Color color;
  final String? facePath;
}

List<GuinjiTpRenderNode> _buildRenderNodes(List<GuinjiPerson> people) {
  if (people.isEmpty) return const [];
  final nodeIns = people
      .map((p) => GuinjiNodeIn(p.id, p.name, p.relation, p.score))
      .toList();
  final placement = computeGuinjiTpPlacement(nodeIns);
  final byId = {for (final p in people) p.id: p};
  return placement.nodes.map((n) {
    final p = byId[n.id]!;
    final spec = guinjiTypeOf(n.type);
    final birth = parseGuinjiBirthLabel(p.birth);
    final facePath = birth == null
        ? null
        : GuinjiCharacter.of(
            birth: birth,
            gender: GuinjiCharacter.fromKey(p.gender),
            stableKey: p.id,
          ).face;
    return GuinjiTpRenderNode(
      person: p,
      type: n.type,
      score: n.score,
      x: n.x,
      y: n.y,
      color: spec.color,
      facePath: facePath,
    );
  }).toList();
}

/// 애니메이션 관계 그래프 — v5 "심야의 신전" 귀인 마법진(`TpMap`)의
/// Flutter 이식. [interactive]가 true면 pan(빈 공간 드래그)/zoom(pinch)/
/// drag(노드 이동)/tap(노드 선택)을 지원하고(M화면용), false면 순수
/// 감상용 애니메이션만 재생한다(게스트 결과 화면 등 미니 프리뷰용).
class GuinjiAnimatedRelationGraph extends StatefulWidget {
  const GuinjiAnimatedRelationGraph({
    super.key,
    required this.people,
    this.centerTitle = '나',
    this.centerSubtitle = '',
    this.ownerFacePath,
    this.onSelect,
    this.onTypeTap,
    this.onEmptySlotTap,
    this.interactive = true,
    this.showControls = true,
    this.height = 500,
    this.emptyHint,
    this.filter,
  });

  final List<GuinjiPerson> people;

  /// [v5] 중앙 "나" 노드는 항상 소유자 얼굴 고정이므로 중앙 타이틀/서브
  /// 타이틀은 지도 위가 아니라 호출부 헤더에서 이미 보여준다. 다만 기존
  /// 호출부가 여전히 넘겨주는 값이라 파라미터는 유지한다(현재 지도
  /// 렌더링에는 사용하지 않음 — v5 TpMap은 중앙에 "나" 캡슐만 표시).
  final String centerTitle;
  final String centerSubtitle;

  /// 입력 화면에서 선택된 소유자의 얼굴. 참여자 얼굴과 분리한다.
  final String? ownerFacePath;

  final void Function(GuinjiPerson person)? onSelect;

  /// [v5 `onSeat`/`setFilter` 이식] 바깥 한자 인장(관계유형 범례)을 탭했을
  /// 때 호출된다. 인원이 있는 유형이면 "그 유형만 강조 필터 토글", 없는
  /// 유형이면 "그 유형으로 추가하기" 의미로 호출부가 해석해 처리한다.
  final void Function(String type)? onTypeTap;

  /// [v5 `onSlot` 이식] 빈 자리 별(엄마/절친/연인 등)을 탭했을 때 호출.
  final void Function(GuinjiTpSlot slot)? onEmptySlotTap;

  /// pan/zoom/drag/tap 제스처 활성화 여부.
  final bool interactive;

  /// 우측 상단 "원래 크기" 리셋 컨트롤 표시 여부(확대 중에만 노출).
  final bool showControls;

  final double height;

  /// people이 빈 배열일 때 중앙 아래에 표시할 안내 문구. null이면 표시 안 함.
  final String? emptyHint;

  /// [v5 `filter` 상태 이식] 관계 유형(6종 키) 하나를 지정하면 해당
  /// 유형의 노드/방사선/오로라만 강조하고, 나머지는 흐리게 처리한다.
  final String? filter;

  @override
  State<GuinjiAnimatedRelationGraph> createState() =>
      _GuinjiAnimatedRelationGraphState();
}

class _GuinjiAnimatedRelationGraphState
    extends State<GuinjiAnimatedRelationGraph>
    with TickerProviderStateMixin {
  static const double _minScale = 1.0;
  static const double _maxScale = 1.8;

  final _key = GlobalKey();
  double _scale = 1;
  double _panX = 0, _panY = 0;
  double _pinchStart = 1;
  List<GuinjiTpRenderNode> _nodes = const [];
  GuinjiPerson? _dragging;
  bool _panning = false;
  bool _moved = false;
  int _lastNodeCount = -1;

  /// 캔버스(390×520) → 실제 위젯 픽셀 변환 스케일/오프셋. [_rebuildLayout]에서
  /// RenderBox 크기가 바뀔 때마다 다시 계산한다(히트테스트에 필요).
  double _fitScale = 1;
  double _fitDy = 0;

  GuinjiPerson? _selected;

  /// 0→1로 무한 반복되는 긴 주기(1시간) 컨트롤러 — `elapsedSeconds =
  /// value * period`로 모든 배경 애니메이션(오로라·광선·먼지·반짝임·
  /// 별똥별·호흡·펄스)의 위상을 파생한다. v5가 CSS `animation-duration`별로
  /// 각자 다른 주기를 쓰는 것과 동일하게, Painter가 `elapsedSeconds`를
  /// 받아 레이어마다 다른 주기로 나눠 쓴다.
  static const double _timePeriodSeconds = 3600;
  late final AnimationController _timeController;

  /// 최초 진입(혹은 인원 수 변화) 시 한 번 재생되는 등장(entrance) 애니메이션.
  late final AnimationController _entranceController;

  final Map<String, ui.Image> _faceImageCache = {};
  final Set<String> _faceLoading = {};
  ui.Image? _ownerFaceImage;

  @override
  void initState() {
    super.initState();
    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3600),
    )..repeat();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildLayout());
    _loadFaceImage(
      _ownerFaceAsset(fallback: 'assets/images/guinji/chars/f30_face.jpg'),
      isOwner: true,
    );
  }

  @override
  void didUpdateWidget(covariant GuinjiAnimatedRelationGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildLayout();
    if (oldWidget.ownerFacePath != widget.ownerFacePath) {
      _ownerFaceImage = null;
      _loadFaceImage(
        _ownerFaceAsset(fallback: 'assets/images/guinji/chars/f30_face.jpg'),
        isOwner: true,
      );
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _rebuildLayout() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return;
    _fitScale = size.width / tpCanvasWidth;
    _fitDy = (size.height - tpCanvasHeight * _fitScale) / 2;
    final nodes = _buildRenderNodes(widget.people);
    _nodes = nodes;
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

  String _ownerFaceAsset({required String fallback}) {
    return widget.ownerFacePath ?? fallback;
  }

  Future<void> _loadFaceImage(String assetPath, {bool isOwner = false}) async {
    final cached = _faceImageCache[assetPath];
    if (cached != null) {
      if (isOwner && mounted) setState(() => _ownerFaceImage = cached);
      return;
    }
    if (_faceLoading.contains(assetPath)) return;
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
      // 에셋이 없으면 폴백(유형색 원+이니셜) 렌더로 자연스럽게 이어진다.
    } finally {
      _faceLoading.remove(assetPath);
    }
  }

  /// 위젯 로컬 좌표(픽셀) → 캔버스 좌표계(390×520)로 역변환.
  Offset _toCanvasSpace(Offset local) {
    final fx = (local.dx - _panX) / _scale;
    final fy = (local.dy - _panY) / _scale;
    return Offset((fx) / _fitScale, (fy - _fitDy) / _fitScale);
  }

  GuinjiTpRenderNode? _hitTestNode(Offset local) {
    final c = _toCanvasSpace(local);
    final density = GuinjiTpDensity.of(widget.people.length);
    final r = density.nr;
    for (final n in _nodes.reversed) {
      final dx = c.dx - n.x;
      final dy = c.dy - n.y;
      if (dx * dx + dy * dy <= r * r * 1.6) return n;
    }
    return null;
  }

  /// 바깥 유형 한자 인장(범례) 히트테스트 — v5 `lx,ly` 좌표 반경 18px
  /// (캔버스 좌표계) 안을 탭하면 해당 유형으로 판정한다.
  String? _hitTestTypeLegend(Offset local) {
    final c = _toCanvasSpace(local);
    for (var k = 0; k < guinjiTypeOrder.length; k++) {
      final (lx, ly) = tpTypeLegendPos(k);
      final dx = c.dx - lx, dy = c.dy - ly;
      if (dx * dx + dy * dy <= 18 * 18) return guinjiTypeOrder[k];
    }
    return null;
  }

  GuinjiTpSlot? _hitTestEmptySlot(Offset local) {
    final c = _toCanvasSpace(local);
    final filled = widget.people.map((p) => p.name).toSet();
    final slots = guinjiTpSlots
        .where((s) => !filled.contains(s.label))
        .take(math.max(0, tpSlotTotal - widget.people.length));
    for (final s in slots) {
      final a = tpRad(s.angleDeg);
      final x = tpCenterX + math.cos(a) * (62 + s.k * 76);
      final y = tpCenterY + math.sin(a) * (78 + s.k * 118);
      final dx = c.dx - x, dy = c.dy - y;
      if (dx * dx + dy * dy <= 22 * 22) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final content = CustomPaint(
      key: _key,
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: Listenable.merge([_timeController, _entranceController]),
          builder: (context, _) {
            return CustomPaint(
              painter: GuinjiTempleMapPainter(
                nodes: _nodes,
                people: widget.people,
                scale: _scale,
                panX: _panX,
                panY: _panY,
                elapsedSeconds: _timeController.value * _timePeriodSeconds,
                entrance: _entranceController.value,
                draggingPerson: _dragging,
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
            onDoubleTap: () => setState(() {
              _scale = 1;
              _panX = 0;
              _panY = 0;
            }),
            onScaleStart: (details) {
              _moved = false;
              final n = _hitTestNode(details.localFocalPoint);
              if (n != null) {
                _dragging = n.person;
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
                  _scale = (_pinchStart * details.scale).clamp(
                    _minScale,
                    _maxScale,
                  );
                });
                return;
              }
              if (details.focalPointDelta.distance > 3) _moved = true;
              setState(() {
                if (_dragging != null) {
                  final node = _nodes
                      .where((n) => n.person == _dragging)
                      .cast<GuinjiTpRenderNode?>()
                      .firstWhere((_) => true, orElse: () => null);
                  if (node != null) {
                    final denom = _scale * _fitScale;
                    node.x += details.focalPointDelta.dx / denom;
                    node.y += details.focalPointDelta.dy / denom;
                  }
                } else if (_panning) {
                  _panX += details.focalPointDelta.dx;
                  _panY += details.focalPointDelta.dy;
                }
              });
            },
            onScaleEnd: (details) {
              if (_dragging != null && !_moved) {
                final tapped = _dragging!;
                setState(() {
                  _selected = _selected == tapped ? null : tapped;
                });
                widget.onSelect?.call(tapped);
              } else if (_dragging == null && !_moved && !_panning) {
                // no-op: 아래 onTapUp 전용 레이어가 범례/슬롯을 처리.
              }
              _dragging = null;
              _panning = false;
            },
            onTapUp: (details) {
              if (_moved) return;
              // 제스처 아레나 특성상 "이동 없는 단순 탭"은 onScaleStart/End가
              // 호출되지 않고 onTapUp만 발동한다. 따라서 노드(얼굴) 탭 선택
              // 판정도 여기서 함께 처리해야 한다(드래그 종료 후 선택은
              // onScaleEnd가 계속 담당).
              final n = _hitTestNode(details.localPosition);
              if (n != null) {
                final tapped = n.person;
                setState(() {
                  _selected = _selected == tapped ? null : tapped;
                });
                widget.onSelect?.call(tapped);
                return;
              }
              final type = _hitTestTypeLegend(details.localPosition);
              if (type != null) {
                widget.onTypeTap?.call(type);
                return;
              }
              final slot = _hitTestEmptySlot(details.localPosition);
              if (slot != null) widget.onEmptySlotTap?.call(slot);
            },
            child: content,
          )
        : IgnorePointer(child: content);

    final container = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: GmColors.bgGradient),
            ),
          ),
          Positioned.fill(child: gestureWrapped),
          // [SPEC §6 H4 "0명이면 말풍선 `empty.coach`(노랑, 지도 16% 지점,
          // 위아래 흔들림)"] 이전까지는 평범한 회색 텍스트였다 — 색(노랑)·
          // 위치(지도 16% 지점)·형태(말풍선)·애니메이션(위아래 흔들림) 네
          // 가지 모두 SPEC을 위반해 [_GmEmptyCoachBubble]로 전면 교체한다.
          if (widget.people.isEmpty && widget.emptyHint != null)
            Align(
              alignment: const Alignment(0, -0.68), // 지도 높이의 약 16% 지점
              child: _GmEmptyCoachBubble(text: widget.emptyHint!),
            ),
          if (widget.interactive && widget.showControls && _scale > 1.0)
            Positioned(
              top: 12,
              right: 12,
              child: _GmGraphResetButton(
                onReset: () => setState(() {
                  _scale = 1;
                  _panX = 0;
                  _panY = 0;
                }),
              ),
            ),
        ],
      ),
    );

    return widget.interactive ? PinchZoomDisabled(child: container) : container;
  }
}

/// [SPEC §6 H4 "0명이면 말풍선 `empty.coach`(노랑, 지도 16% 지점, 위아래
/// 흔들림)"] 지도가 비어 있을 때 보여 주는 말풍선 코치마크. 꼬리(삼각형)가
/// 달린 노란 알약 모양 + 상시 위아래 흔들림 애니메이션으로 구현한다.
class _GmEmptyCoachBubble extends StatefulWidget {
  const _GmEmptyCoachBubble({required this.text});
  final String text;

  @override
  State<_GmEmptyCoachBubble> createState() => _GmEmptyCoachBubbleState();
}

class _GmEmptyCoachBubbleState extends State<_GmEmptyCoachBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final dy = -4 + 8 * Curves.easeInOut.transform(_bob.value);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: GmColors.gold,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: GmColors.gold.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GmText.ui,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GmColors.onPrimary,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(14, 7),
            painter: _GmBubbleTailPainter(color: GmColors.gold),
          ),
        ],
      ),
    );
  }
}

class _GmBubbleTailPainter extends CustomPainter {
  const _GmBubbleTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GmBubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// [v5 §05-2 "⌖ 원래 크기" 버튼 1:1 이식] 확대 중(scale > 1)에만 나타나는
/// 단일 리셋 버튼.
class _GmGraphResetButton extends StatelessWidget {
  const _GmGraphResetButton({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GmColors.card.withValues(alpha: 0.9),
      shape: const StadiumBorder(side: BorderSide(color: GmColors.line)),
      child: InkWell(
        onTap: onReset,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.center_focus_strong, size: 14, color: GmColors.fg),
              SizedBox(width: 4),
              Text(
                '원래 크기',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: GmColors.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 배경 레이어(오로라·광선·먼지·반짝임·별똥별) 각 장식 하나의 고정
/// 사양. 매 프레임 재계산하지 않도록 painter 밖(top-level 캐시)에서
/// 한 번만 생성한다(v5 `tpM(() => ..., [])`와 동일한 "최초 1회 계산" 의도).
class _TpDustSpec {
  const _TpDustSpec(this.x, this.y, this.r, this.duration, this.delay);
  final double x, y, r, duration, delay;
}

class _TpSparkSpec {
  const _TpSparkSpec(this.x, this.y, this.r, this.duration, this.delay, this.color);
  final double x, y, r, duration, delay;
  final Color color;
}

final List<_TpDustSpec> _tpDust = List.generate(26, (i) {
  return _TpDustSpec(
    (i * 53 + 17) % tpCanvasWidth.toInt().toDouble(),
    (i * 97 + 31) % tpCanvasHeight.toInt().toDouble(),
    .6 + (i % 3) * .5,
    6 + (i % 5) * 1.6,
    (i % 7) * .9,
  );
});

const List<Color> _tpSparkColors = [
  Color(0xFFFFF6D8),
  Color(0xFFF5CF6A),
  Color(0xFFD9B8FF),
  Color(0xFFFFD1E0),
];

final List<_TpSparkSpec> _tpSparks = List.generate(16, (i) {
  return _TpSparkSpec(
    (i * 71 + 23) % tpCanvasWidth.toInt().toDouble(),
    (i * 113 + 41) % tpCanvasHeight.toInt().toDouble(),
    1 + (i % 3) * .6,
    2.4 + (i % 5) * .7,
    (i % 8) * .5,
    _tpSparkColors[i % 4],
  );
});

/// v5 고정 3개 별똥별 좌표(`[[x,y,delay], ...]`, 283줄).
const List<List<double>> _tpMeteors = [
  [330, 40, 0],
  [380, 150, 3.5],
  [250, 10, 7],
];

/// [GuinjiAnimatedRelationGraph]의 실제 렌더링을 담당하는 CustomPainter.
///
/// v5 `TpMap`(SVG) 레이어를 순서대로 1:1 재현한다:
/// 1) 유형별 오로라 성운(회전·확대 호흡) 2) 중심에서 퍼지는 금빛 광선
/// (90초 1회전) 3) 금빛 먼지 + 반짝이는 십자 플레어 4) 별똥별 5) 바깥
/// 유형 한자 인장 범례(필터 겸용) 6) 중앙 코어 글로우+플레어 7) 중심→
/// 노드 연결선(유형색·점수 기반 굵기·흐르는 에너지 입자) 8) 인물 노드
/// (원형 얼굴+유형색 헤일로+호흡+플로팅+라벨) 9) 빈 자리 별(8명 미만일
/// 때) 10) 중앙 "나" 노드(점선 회전 링+펄스+골드 캡슐).
class GuinjiTempleMapPainter extends CustomPainter {
  GuinjiTempleMapPainter({
    required this.nodes,
    required this.people,
    required this.scale,
    required this.panX,
    required this.panY,
    required this.elapsedSeconds,
    required this.entrance,
    required this.faceImages,
    this.ownerFaceImage,
    this.draggingPerson,
    this.selectedPerson,
    this.filter,
  });

  final List<GuinjiTpRenderNode> nodes;
  final List<GuinjiPerson> people;
  final double scale, panX, panY;

  /// `AnimationController.value * period` — 계속 증가하는 경과 초.
  final double elapsedSeconds;

  /// 0(등장 시작)→1(완전히 배치 완료) 등장 진행도.
  final double entrance;

  final Map<String, ui.Image> faceImages;
  final ui.Image? ownerFaceImage;
  final GuinjiPerson? draggingPerson;
  final GuinjiPerson? selectedPerson;
  final String? filter;

  static const _twoPi = math.pi * 2;

  bool _isOff(GuinjiTpRenderNode n) {
    if (selectedPerson != null && selectedPerson != n.person) return true;
    if (filter != null && filter != n.type) return true;
    return false;
  }

  double _entranceForNode(int index, int total) {
    if (total == 0) return entrance;
    // [SPEC §5-4 진입 애니메이션 순서] "0.9s~: 선 shoot" — 인장 stamp(아래
    // [_legendEntranceFor])가 먼저 끝난 뒤에 선이 중심에서 뻗어나가도록,
    // 전체 등장 타임라인(0→1)의 앞쪽 30%는 비워 두고 그 이후 구간에서만
    // 진행한다(비워두는 비율만큼 shifted로 재정규화해 entrance=1일 때
    // 모든 노드가 확실히 완전히 등장하도록 보장).
    const beginAt = 0.3;
    final shifted = ((entrance - beginAt) / (1 - beginAt)).clamp(0.0, 1.0);
    final stagger = total <= 1 ? 0.0 : (index / total) * 0.4;
    final local = ((shifted - stagger) / (1 - 0.4)).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
  }

  /// [SPEC §5-4 "0.6s~: 인장 stamp (scale 2.2→1, 0.08s 간격)"] 바깥 유형
  /// 한자 인장이 등장할 때 확대 축소되며 "쿵" 찍히는 효과. 전체 등장
  /// 타임라인의 초반 40% 구간 안에서, 유형 순서(k)에 따라 조금씩 늦게
  /// 시작한다 — 나(§_paintOwnerBack) 등장 직후 · 선이 뻗기 전에 끝난다.
  double _legendEntranceFor(int k) {
    const windowEnd = 0.4;
    final stagger = k * 0.045;
    final raw = ((entrance - stagger) / windowEnd).clamp(0.0, 1.0);
    return raw;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fitScale = size.width / tpCanvasWidth;
    final fitDy = (size.height - tpCanvasHeight * fitScale) / 2;

    canvas.save();
    canvas.translate(panX, panY);
    canvas.scale(scale);
    canvas.translate(0, fitDy);
    canvas.scale(fitScale);

    const cx = tpCenterX, cy = tpCenterY;
    final many = people.length > 12;
    final counts = guinjiTpCounts(
      people.map((p) => GuinjiNodeIn(p.id, p.name, p.relation, p.score)).toList(),
    );

    _paintAurora(canvas, counts);
    _paintGoldenRays(canvas);
    _paintDustAndSparks(canvas);
    _paintMeteors(canvas);
    _paintTypeLegend(canvas, counts);
    _paintCenterCore(canvas);
    _paintConnections(canvas, cx, cy, many);
    _paintOwnerBack(canvas, cx, cy);
    _paintPersonNodes(canvas, many);
    _paintEmptySlots(canvas, cx, cy);
    _paintOwnerFront(canvas, cx, cy);

    canvas.restore();
  }

  // ── 1. 유형별 오로라 성운 (258~266줄) ──────────────────────────
  void _paintAurora(Canvas canvas, Map<String, int> counts) {
    const cx = tpCenterX, cy = tpCenterY;
    // 중앙 보라 성운 바탕(`tp-neb`).
    final nebPaint = Paint()
      ..shader = ui.Gradient.radial(const Offset(cx, cy), 190, [
        const Color(0xFF7A3FC0).withValues(alpha: .34),
        const Color(0xFF4A2380).withValues(alpha: .12),
        const Color(0xFF2A1050).withValues(alpha: 0),
      ], [0, 0.6, 1])
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..blendMode = BlendMode.screen;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, cy), width: 380, height: 500),
      nebPaint,
    );

    for (var k = 0; k < guinjiTypeOrder.length; k++) {
      final t = guinjiTypeOrder[k];
      final n = counts[t] ?? 0;
      if (n == 0) continue;
      final a = tpRad(k * 60 - 90.0);
      final ax = cx + math.cos(a) * 112, ay = cy + math.sin(a) * 158;
      final spec = guinjiTypeOf(t);
      final on = filter == t;
      final opacity = filter != null && !on ? .05 : (on ? .5 : .26);
      final period = 7 + k;
      final delay = k * .6;
      final breathe =
          1 + 0.09 * (1 + math.sin((elapsedSeconds - delay) / period * _twoPi)) / 2 * 1.3;
      final rx = (52 + math.min(n, 6) * 6) * breathe;
      final ry = (70 + math.min(n, 6) * 8) * breathe;
      final rot = k * 60 * math.pi / 180 +
          math.sin((elapsedSeconds - delay) / period * _twoPi) * .1;
      canvas.save();
      canvas.translate(ax, ay);
      canvas.rotate(rot);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        Paint()
          ..color = spec.color.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
          ..blendMode = BlendMode.screen,
      );
      canvas.restore();
    }
  }

  // ── 2. 중심에서 퍼지는 금빛 광선 (267~273줄) ───────────────────
  void _paintGoldenRays(Canvas canvas) {
    const cx = tpCenterX, cy = tpCenterY;
    final spin = (elapsedSeconds / 90) * _twoPi;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(spin);
    canvas.translate(-cx, -cy);
    for (var i = 0; i < 16; i++) {
      final a = tpRad(i * 22.5);
      final len = i.isOdd ? 150.0 : 230.0;
      final w = i.isOdd ? 4.0 : 7.0;
      final px = -math.sin(a) * w, py = math.cos(a) * w;
      final tipX = cx + math.cos(a) * len, tipY = cy + math.sin(a) * len * 1.15;
      final period = 3 + (i % 4);
      final delay = i * .25;
      final tw = (1 + math.sin((elapsedSeconds - delay) / period * _twoPi)) / 2;
      final baseOpacity = i.isOdd ? .35 : .55;
      final opacity = baseOpacity * (0.2 + tw * 0.5) / 0.7;
      final path = Path()
        ..moveTo(cx + px, cy + py)
        ..lineTo(cx - px, cy - py)
        ..lineTo(tipX, tipY)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx, cy),
            Offset(tipX, tipY),
            [
              const Color(0xFFFFE9A8).withValues(alpha: .55),
              const Color(0xFFFFE9A8).withValues(alpha: 0),
            ],
          )
          ..color = Color.fromRGBO(255, 233, 168, opacity.clamp(0.0, 1.0))
          ..blendMode = BlendMode.screen,
      );
    }
    canvas.restore();
  }

  // ── 3. 금빛 먼지 + 반짝이는 십자 플레어 (274~281줄) ────────────
  void _paintDustAndSparks(Canvas canvas) {
    for (var i = 0; i < _tpDust.length; i++) {
      final s = _tpDust[i];
      final t = (((elapsedSeconds - s.delay) % s.duration) / s.duration).clamp(
        0.0,
        1.0,
      );
      double opacity;
      if (t < 0.3) {
        opacity = (t / 0.3) * .7;
      } else if (t < 0.7) {
        opacity = .7 - (t - 0.3) / 0.4 * .2;
      } else {
        opacity = .5 * (1 - (t - 0.7) / 0.3);
      }
      final dy = -30 * t;
      canvas.drawCircle(
        Offset(s.x, s.y + dy),
        s.r,
        Paint()
          ..color = (i % 4 == 0 ? GmColors.gold : Colors.white)
              .withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
    }
    for (final s in _tpSparks) {
      final phase = ((elapsedSeconds - s.delay) % s.duration) / s.duration;
      final swing = math.sin(phase * _twoPi);
      final scalePulse = (0.2 + (swing + 1) / 2 * 0.8).clamp(0.0, 1.0);
      final opacity = ((swing + 1) / 2).clamp(0.0, 1.0);
      final rot = phase * math.pi / 4 + math.pi / 4;
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(rot);
      canvas.scale(scalePulse <= 0 ? 0.01 : scalePulse);
      final path = Path()
        ..moveTo(0, -s.r * 4)
        ..lineTo(s.r * .5, 0)
        ..lineTo(0, s.r * 4)
        ..lineTo(-s.r * .5, 0)
        ..close()
        ..moveTo(-s.r * 4, 0)
        ..lineTo(0, s.r * .5)
        ..lineTo(s.r * 4, 0)
        ..lineTo(0, -s.r * .5)
        ..close();
      canvas.drawPath(path, Paint()..color = s.color.withValues(alpha: opacity));
      canvas.drawCircle(Offset.zero, s.r * .8, Paint()..color = Colors.white.withValues(alpha: opacity));
      canvas.restore();
    }
  }

  // ── 4. 별똥별 (282~284줄) ───────────────────────────────────
  void _paintMeteors(Canvas canvas) {
    for (final m in _tpMeteors) {
      final x = m[0], y = m[1], delay = m[2];
      const dur = 9.0;
      final t = ((elapsedSeconds - delay) % dur) / dur;
      double opacity = 0;
      if (t < 0.02) {
        opacity = t / 0.02;
      } else if (t < 0.10) {
        opacity = 1 - (t - 0.02) / 0.08;
      }
      if (opacity <= 0) continue;
      final progress = (t / 0.10).clamp(0.0, 1.0);
      final sx = x - 260 * (t < 0.10 ? progress : 1);
      final sy = y + 125 * (t < 0.10 ? progress : 1);
      canvas.drawLine(
        Offset(sx, sy),
        Offset(sx + 46, sy - 22),
        Paint()
          ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0))
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── 바깥 유형 호 + 라벨 (= 범례 겸 필터, 286~298줄) ────────────
  void _paintTypeLegend(Canvas canvas, Map<String, int> counts) {
    for (var k = 0; k < guinjiTypeOrder.length; k++) {
      final t = guinjiTypeOrder[k];
      final spec = guinjiTypeOf(t);
      final on = filter == t;
      final lit = (counts[t] ?? 0) > 0;
      final (lx, ly) = tpTypeLegendPos(k);
      final groupOpacity = filter != null && !on ? .3 : 1.0;

      // [SPEC §5-4 "0.6s~: 인장 stamp (scale 2.2→1, 0.08s 간격)"] 1회성
      // 등장 애니메이션 — 각 인장이 2.2배로 컸다가 1배로 "쿵" 줄어든다.
      final legendT = _legendEntranceFor(k);
      final stampScale = legendT >= 1
          ? 1.0
          : (2.2 - 1.2 * Curves.easeOutBack.transform(legendT))
                .clamp(1.0, 2.2);
      final stampAlpha = legendT.clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(lx, ly);
      canvas.rotate(-4 * math.pi / 180);
      canvas.scale(stampScale);
      final rrect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -12, 24, 24),
        const Radius.circular(6),
      );
      if (on) {
        canvas.drawRRect(rrect, Paint()..color = spec.color.withValues(alpha: groupOpacity));
      } else if (lit) {
        canvas.drawRRect(
          rrect,
          Paint()..color = const Color(0xFF1D1130).withValues(alpha: groupOpacity),
        );
      }
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = spec.color.withValues(alpha: (lit ? 1.0 : .35) * groupOpacity),
      );
      canvas.restore();

      _paintTextCentered(
        canvas,
        Offset(lx, ly + .5),
        spec.hanja,
        13,
        (on ? GmColors.onFg : spec.color).withValues(
          alpha: (lit ? 1.0 : .5) * groupOpacity * stampAlpha,
        ),
        weight: FontWeight.w900,
        fontFamily: GmText.display,
      );
      if (lit) {
        final bx = lx + 11, by = ly - 11;
        canvas.drawCircle(
          Offset(bx, by),
          7,
          Paint()..color = spec.color.withValues(alpha: groupOpacity * stampAlpha),
        );
        canvas.drawCircle(
          Offset(bx, by),
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF120A22).withValues(alpha: groupOpacity * stampAlpha),
        );
        _paintTextCentered(
          canvas,
          Offset(bx, by + .5),
          '${counts[t] ?? 0}',
          8,
          GmColors.onFg.withValues(alpha: groupOpacity * stampAlpha),
          weight: FontWeight.w800,
        );
      }
      _paintTextCentered(
        canvas,
        Offset(lx, ly + 22),
        spec.short,
        9.5,
        (on ? spec.color : GmColors.muted).withValues(
          alpha: (lit ? 1.0 : .45) * groupOpacity * stampAlpha,
        ),
        weight: FontWeight.w700,
      );
    }
  }

  // ── 중앙 코어 (300~305줄) ────────────────────────────────────
  void _paintCenterCore(Canvas canvas) {
    const cx = tpCenterX, cy = tpCenterY;
    final breathe = 1 + math.sin(elapsedSeconds / 4 * _twoPi) * 0.06;
    canvas.drawCircle(
      const Offset(cx, cy),
      96 * breathe,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(cx, cy), 96 * breathe, [
          GmColors.gold.withValues(alpha: .5),
          GmColors.gold.withValues(alpha: .12),
          GmColors.gold.withValues(alpha: 0),
        ], [0, 0.4, 1]),
    );
    final flareBreathe = 1 + math.sin(elapsedSeconds / 3 * _twoPi) * 0.12;
    final flarePaint = Paint()
      ..color = Colors.white.withValues(alpha: .18 * flareBreathe)
      ..blendMode = BlendMode.screen;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, cy), width: 240 * flareBreathe, height: 4.4),
      flarePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(cx, cy), width: 4.4, height: 300 * flareBreathe),
      flarePaint,
    );
    canvas.drawCircle(
      const Offset(cx, cy),
      54 * flareBreathe * .7,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(cx, cy), 54 * flareBreathe, [
          const Color(0xFFFFF6D8).withValues(alpha: .63),
          GmColors.gold.withValues(alpha: .3),
          GmColors.gold.withValues(alpha: 0),
        ], [0, 0.25, 1]),
    );
  }

  // ── 연결선 (307~324줄) ───────────────────────────────────────
  void _paintConnections(Canvas canvas, double cx, double cy, bool many) {
    const ownerR = tpOwnerRadius;
    final density = GuinjiTpDensity.of(people.length);
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final nodeEntrance = _entranceForNode(i, nodes.length);
      final spec = guinjiTypeOf(n.type);
      final isSel = selectedPerson == n.person;
      final dim = (filter != null && filter != n.type) ||
          (selectedPerson != null && !isSel);

      final ex = cx + (n.x - cx) * nodeEntrance;
      final ey = cy + (n.y - cy) * nodeEntrance;
      final dx = ex - cx, dy = ey - cy;
      final len = math.sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);
      final ux = dx / len, uy = dy / len;
      final x1 = cx + ux * (ownerR + 3), y1 = cy + uy * (ownerR + 3);
      final x2 = ex - ux * (density.nr + 2), y2 = ey - uy * (density.nr + 2);
      final w = (many ? .7 : 1.0) + (n.score / 100) * (many ? 1.0 : 1.6);
      final opacity = dim ? .1 : 1.0;

      if (isSel) {
        canvas.drawLine(
          Offset(x1, y1),
          Offset(x2, y2),
          Paint()
            ..color = spec.color.withValues(alpha: .45 * opacity)
            ..strokeWidth = w + 7
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
      }
      final linePaint = Paint()
        ..color = spec.color.withValues(
          alpha: (isSel ? 1.0 : many ? .5 : .75) * opacity,
        )
        ..strokeWidth = isSel ? w + 1.2 : w
        ..strokeCap = StrokeCap.round;
      if (spec.dash != null) {
        _drawDashedLine(
          canvas,
          Offset(x1, y1),
          Offset(x2, y2),
          linePaint,
          spec.dash!.map((v) => v * .55).toList(),
        );
      } else {
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
      }

      final flow = isSel || (!many && selectedPerson == null);
      if (flow && nodeEntrance > 0.98 && !dim) {
        final dur = isSel ? 1.0 : 2.6 - n.score / 100;
        for (var k = 0; k < 2; k++) {
          final t = ((elapsedSeconds + k * dur / 2) % dur) / dur;
          final fx = x2 + (x1 - x2) * t;
          final fy = y2 + (y1 - y2) * t;
          final fade = math.sin(t * math.pi);
          canvas.drawCircle(
            Offset(fx, fy),
            isSel ? 2.6 : 1.7,
            Paint()..color = const Color(0xFFFFF8E6).withValues(alpha: fade.clamp(0.0, 1.0)),
          );
        }
      }
    }
  }

  // ── 인물 노드 (326~344줄) ────────────────────────────────────
  void _paintPersonNodes(Canvas canvas, bool many) {
    final density = GuinjiTpDensity.of(people.length);
    final nr = density.nr;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final nodeEntrance = _entranceForNode(i, nodes.length);
      if (nodeEntrance <= 0.001) continue;
      final isDragging = draggingPerson == n.person;
      final isSel = selectedPerson == n.person;
      final off = _isOff(n);
      final seed = n.person.name.hashCode % 1000 / 1000.0;
      final floatY = isDragging
          ? 0.0
          : math.sin(elapsedSeconds / (4 + (i % 3)) * _twoPi + seed * _twoPi) * 2.5;
      final ox = cx(n), oy = cy(n) + floatY;
      final selR = isSel ? nr + 3 : nr;
      final r = selR * nodeEntrance.clamp(0.0, 1.0);
      final alpha = nodeEntrance.clamp(0.0, 1.0) * (off ? .22 : 1.0);

      // 등장 링 울림(ripple) — 처음 한 번만, entrance 초입 구간에서만 표시.
      if (nodeEntrance < 0.65 && nodeEntrance > 0.02) {
        final rippleT = (nodeEntrance / 0.65).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(ox, oy),
          (nr + 5) * (1 + rippleT * 1.3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = n.color.withValues(alpha: (1 - rippleT) * .8),
        );
      }

      if (isSel) {
        canvas.drawCircle(
          Offset(ox, oy),
          r + 10,
          Paint()..color = n.color.withValues(alpha: 0.26 * alpha),
        );
        final pulseT = (elapsedSeconds % 1.4) / 1.4;
        canvas.drawCircle(
          Offset(ox, oy),
          (r + 5) * (1 + pulseT * .9),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = n.color.withValues(alpha: (1 - pulseT) * .6),
        );
      }
      // 유형색 헤일로(글로우).
      canvas.drawCircle(
        Offset(ox, oy),
        r * 1.9,
        Paint()
          ..shader = ui.Gradient.radial(Offset(ox, oy), r * 1.9, [
            n.color.withValues(alpha: .7 * alpha),
            n.color.withValues(alpha: 0),
          ])
          ..color = n.color.withValues(alpha: (isSel ? 1.0 : .5) * alpha),
      );

      final faceImage = n.facePath != null ? faceImages[n.facePath] : null;
      if (faceImage != null && r > 0) {
        _drawFaceImage(canvas, faceImage, Offset(ox, oy), r, alpha);
      } else {
        canvas.drawCircle(Offset(ox, oy), r, Paint()..color = const Color(0xFF2A1D40).withValues(alpha: alpha));
        if (alpha > 0.5 && n.person.name.isNotEmpty) {
          _paintTextCentered(
            canvas,
            Offset(ox, oy),
            n.person.name.substring(0, 1),
            r * 0.7,
            Colors.white.withValues(alpha: alpha),
            weight: FontWeight.w700,
          );
        }
      }
      canvas.drawCircle(
        Offset(ox, oy),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 2.4 : 1.6
          ..color = n.color.withValues(alpha: alpha),
      );

      if (alpha > 0.55) {
        final labelY = oy + r + density.fs + 1;
        final nameSpan = TextSpan(
          text: n.person.name,
          style: TextStyle(
            fontSize: density.fs,
            fontWeight: FontWeight.w700,
            fontFamily: GmText.ui,
            color: (isSel ? n.color : GmColors.fg).withValues(alpha: alpha),
          ),
          children: (isSel || !many)
              ? [
                  TextSpan(
                    text: ' ${n.score}',
                    style: TextStyle(
                      fontFamily: GmText.mono,
                      fontSize: density.fs - .5,
                      color: n.color.withValues(alpha: alpha),
                    ),
                  ),
                ]
              : null,
        );
        _paintOutlinedRichText(canvas, Offset(ox, labelY), nameSpan);
      }
    }
  }

  double cx(GuinjiTpRenderNode n) => n.x;
  double cy(GuinjiTpRenderNode n) => n.y;

  // ── 빈 자리 별 (369~379줄) ───────────────────────────────────
  void _paintEmptySlots(Canvas canvas, double cx, double cy) {
    final filled = people.map((p) => p.name).toSet();
    final slots = guinjiTpSlots
        .where((s) => !filled.contains(s.label))
        .take(math.max(0, tpSlotTotal - people.length))
        .toList();
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      final a = tpRad(s.angleDeg);
      final x = cx + math.cos(a) * (62 + s.k * 76);
      final y = cy + math.sin(a) * (78 + s.k * 118);
      final fadeIn = (entrance).clamp(0.0, 1.0);
      if (fadeIn <= 0.01) continue;

      _drawDashedLine(
        canvas,
        Offset(cx + math.cos(a) * 36, cy + math.sin(a) * 36),
        Offset(x - math.cos(a) * 18, y - math.sin(a) * 18),
        Paint()
          ..color = GmColors.gold.withValues(alpha: .22 * fadeIn)
          ..strokeWidth = .8,
        const [2, 4],
      );
      final pulseT = ((elapsedSeconds + i * .35) % 2.8) / 2.8;
      canvas.drawCircle(
        Offset(x, y),
        13 * (1 + pulseT * 1.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = GmColors.gold.withValues(alpha: (1 - pulseT) * .6 * fadeIn),
      );
      final seatT = (0.5 + 0.5 * math.sin((elapsedSeconds + i * .3) / 2.4 * _twoPi));
      canvas.drawCircle(
        Offset(x, y),
        13,
        Paint()..color = const Color(0xFF1A0D2E).withValues(alpha: .75 * fadeIn),
      );
      _drawDashedCircle(
        canvas,
        Offset(x, y),
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = GmColors.gold.withValues(alpha: (.5 + seatT * .5) * fadeIn),
      );
      _paintTextCentered(
        canvas,
        Offset(x, y + .5),
        '+',
        14,
        const Color(0xFFFFE9A8).withValues(alpha: fadeIn),
        weight: FontWeight.w600,
      );
      _paintOutlinedRichText(
        canvas,
        Offset(x, y + 26),
        TextSpan(
          text: s.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: GmText.body,
            color: GmColors.muted.withValues(alpha: fadeIn),
          ),
        ),
      );
    }
  }

  // ── 나(소유자) 노드 배경(링류) — 인물보다 먼저, 341~344 사이 느낌으로
  // 사람 노드보다는 먼저 그려 사람 노드가 위에 오지 않게(실제 v5는 나
  // 노드가 가장 마지막 — 381~391줄)에 맞춰, 배경 장식 링만 먼저 그리고
  // 얼굴은 [_paintOwnerFront]에서 맨 위에 그린다.
  void _paintOwnerBack(Canvas canvas, double cx, double cy) {
    const r = tpOwnerRadius;
    // [SPEC §5-4 "0.2s: 나 pop + 금 burst 링(scale 5까지, 1.2s)"] 진입
    // 시 단 1회만 재생되는 금 테두리 확산 효과. 이전에는
    // `elapsedSeconds % 1.2`로 영구 반복되어 "진입 애니메이션 순서"(1회성
    // 연출이어야 함) QA 항목을 위반했다 — 1회성인 [entrance](0→1, 노드
    // 개수가 바뀔 때만 재생)를 그대로 진행도로 써서 등장 시 한 번만
    // 확산되고 끝나게 한다.
    if (entrance < 0.999) {
      final burstT = entrance.clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(cx, cy),
        (r + 2) + burstT * (r + 2) * 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(.5, 6 * (1 - burstT))
          ..color = GmColors.gold.withValues(alpha: 1 - burstT),
      );
    }
  }

  void _paintOwnerFront(Canvas canvas, double cx, double cy) {
    const r = tpOwnerRadius;
    // [SPEC §5-4 "0.2s: 나 pop (scale .4→1, overshoot)"] 등장 시 1회
    // 튕기듯 커지는 효과 — elasticOut 커브로 0.4배에서 1배를 살짝 넘겼다가
    // 안착한다. entrance가 1에 도달하면(재생 종료) 항상 1.0으로 고정.
    final popScale = entrance >= 0.999
        ? 1.0
        : (0.4 + 0.6 * Curves.elasticOut.transform(entrance)).clamp(0.0, 1.3);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(popScale);
    canvas.translate(-cx, -cy);
    final pulseT = (elapsedSeconds % 3.2) / 3.2;
    canvas.drawCircle(
      Offset(cx, cy),
      (r + 2) * (1 + pulseT * .9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = GmColors.gold.withValues(alpha: (1 - pulseT) * .5),
    );
    final spin = (elapsedSeconds / 30) * _twoPi;
    _drawDashedCircle(
      canvas,
      Offset(cx, cy),
      r + 9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = GmColors.gold.withValues(alpha: .55),
      dashPattern: const [1.5, 5],
      rotation: spin,
    );
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFF2A1D40));
    if (ownerFaceImage != null) {
      _drawFaceImage(canvas, ownerFaceImage!, Offset(cx, cy), r, 1.0);
    }
    canvas.drawCircle(
      Offset(cx, cy),
      r + .5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = GmColors.gold,
    );
    final capsuleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + r), width: 30, height: 15),
      const Radius.circular(7.5),
    );
    canvas.drawRRect(capsuleRect, Paint()..color = GmColors.gold);
    _paintTextCentered(
      canvas,
      Offset(cx, cy + r + .5),
      '나',
      9,
      GmColors.onFg,
      weight: FontWeight.w800,
    );
    canvas.restore();
  }

  // ── 그리기 헬퍼 ──────────────────────────────────────────────
  void _drawFaceImage(Canvas canvas, ui.Image image, Offset o, double r, double alpha) {
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: o, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    final srcSize = image.width < image.height
        ? image.width.toDouble()
        : image.height.toDouble();
    final src = Rect.fromCenter(
      center: Offset(image.width / 2, image.height / 2),
      width: srcSize,
      height: srcSize,
    );
    canvas.drawImageRect(
      image,
      src,
      rect,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.restore();
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    List<double> pattern,
  ) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = (to - from) / total;
    double covered = 0;
    var idx = 0;
    while (covered < total) {
      final segLen = pattern[idx % pattern.length];
      final on = idx.isEven;
      final segEnd = math.min(covered + segLen, total);
      if (on) {
        canvas.drawLine(from + dir * covered, from + dir * segEnd, paint);
      }
      covered += segLen;
      idx++;
    }
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    List<double> dashPattern = const [2.5, 2.5],
    double rotation = 0,
  }) {
    final circumference = _twoPi * radius;
    final dashLen = dashPattern[0], gapLen = dashPattern.length > 1 ? dashPattern[1] : dashPattern[0];
    final step = (dashLen + gapLen) / radius;
    for (double a = rotation; a < _twoPi + rotation; a += step) {
      final a2 = a + dashLen / radius;
      canvas.drawLine(
        Offset(center.dx + math.cos(a) * radius, center.dy + math.sin(a) * radius),
        Offset(center.dx + math.cos(a2) * radius, center.dy + math.sin(a2) * radius),
        paint,
      );
    }
    // circumference 참조는 스타일 일관성을 위해 남겨둔다(향후 dash 밀도
    // 조정 시 참고용 — 현재는 step 계산에 radius로 충분).
    assert(circumference >= 0);
  }

  void _paintTextCentered(
    Canvas canvas,
    Offset o,
    String text,
    double fontSize,
    Color color, {
    FontWeight weight = FontWeight.w600,
    String fontFamily = GmText.ui,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    tp.paint(canvas, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
  }

  /// [v5 `paintOrder: stroke` 이식] 어두운 외곽선(stroke)을 먼저 그려 밝은
  /// 글자가 배경과 섞이지 않고 또렷하게 보이게 한다(지도 배경이 복잡해도
  /// 라벨 가독성 유지).
  void _paintOutlinedRichText(Canvas canvas, Offset center, TextSpan span) {
    TextSpan withForeground(TextSpan s, Paint p) {
      return TextSpan(
        text: s.text,
        style: (s.style ?? const TextStyle()).copyWith(foreground: p),
        children: s.children
            ?.map((c) => withForeground(c as TextSpan, p))
            .toList(),
      );
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xF2140A22);
    final strokeTp = TextPainter(
      text: withForeground(span, strokePaint),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    strokeTp.paint(canvas, Offset(center.dx - strokeTp.width / 2, center.dy - strokeTp.height / 2));

    final fillTp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    fillTp.paint(canvas, Offset(center.dx - fillTp.width / 2, center.dy - fillTp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GuinjiTempleMapPainter oldDelegate) => true;
}
