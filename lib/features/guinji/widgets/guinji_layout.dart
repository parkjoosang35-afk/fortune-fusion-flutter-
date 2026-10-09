// lib/features/guinji/widgets/guinji_layout.dart
// [귀인지도 v2 리스킨 — 핸드오프 이식] 지도 배치 알고리즘 — 시안
// (guinji-data.js layout)과 1:1 이식.
//  1) 각도 = 관계 유형 부채꼴 (천생귀인 12시부터 시계방향, 그룹 사이 0.7칸 여백)
//  2) 거리 = 점수 (높을수록 중심 가까이)
//  3) 선 = 중심 한 점에서 뻗는 직선 → 노드를 어디로 밀어도 선끼리 교차 불가
//  4) 라벨 = 위쪽 노드는 위, 나머지는 아래
//  5) (노드+라벨) 상자 충돌 · 중앙 · 경계 · 고정 UI 영역을 2D로 밀어내기 (최대 400회)
// 데이터가 바뀔 때만 1회 계산하고 결과를 캐시할 것 (build 마다 호출 금지).
//
// `귀인지도_최종_핸드오프.html` `window.GJ_CODE_FILES`의
// `lib/features/guinji_map/widgets/guinji_layout.dart`를 1:1 이식(패키지
// 경로만 기존 프로젝트 구조에 맞춤, import 경로를 `../theme/guinji_type_spec.dart`로 조정).
import 'dart:math' as math;
import 'dart:ui';

import '../theme/guinji_type_spec.dart';

class GuinjiNodeIn {
  final String id, name, type;
  final int score;
  const GuinjiNodeIn(this.id, this.name, this.type, this.score);
}

class GuinjiDensity {
  final double nodeD, centerD, nameFs, typeFs, labelH;
  const GuinjiDensity(this.nodeD, this.centerD, this.nameFs, this.typeFs, this.labelH);

  /// 최종 v2 값: 10명 이하 42/58, 11명 이상 34/50.
  factory GuinjiDensity.of(int n) => n <= 10
      ? const GuinjiDensity(42, 58, 12.5, 11, 32)
      : const GuinjiDensity(34, 50, 11.5, 10.5, 30);
}

class PlacedNode {
  final GuinjiNodeIn m;
  double x, y;
  final double hx, hy;
  final bool labelTop;
  final double labelW;
  PlacedNode(this.m, this.x, this.y, this.labelTop, this.labelW)
      : hx = x,
        hy = y;
}

class GuinjiLayout {
  final List<PlacedNode> nodes;
  final Offset center;
  final GuinjiDensity d;
  GuinjiLayout(this.nodes, this.center, this.d);
}

int _h997(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) % 997;
  }
  return h;
}

GuinjiLayout computeGuinjiLayout(
  List<GuinjiNodeIn> members,
  Size area, {
  double padT = 4,
  double padB = 4,
  double padX = 6,
  List<Rect> avoid = const [],
  bool jitter = true,
}) {
  final d = GuinjiDensity.of(members.length);
  final w = area.width, h = area.height;
  final cx = w / 2, cy = padT + (h - padT - padB) / 2;
  final r = d.nodeD / 2;
  final rxOut = math.max(60.0, w / 2 - padX - math.max(r, 34) - 2);
  final ryOut = math.max(60.0, (h - padT - padB) / 2 - r - d.labelH * 0.6 - 6);
  final rMin = d.centerD / 2 + r + 26;
  Offset ell(double t) => Offset(rMin + (rxOut - rMin) * t, rMin + (ryOut - rMin) * t);

  final sorted = [...members]..sort((a, b) {
    final o = guinjiTypeOrder.indexOf(a.type).compareTo(guinjiTypeOrder.indexOf(b.type));
    return o != 0 ? o : b.score.compareTo(a.score);
  });
  final groups = [
    for (final t in guinjiTypeOrder) sorted.where((s) => s.type == t).toList(),
  ]..removeWhere((g) => g.isEmpty);
  final gap = groups.length > 1 ? 0.7 : 0.0;
  final step = 2 * math.pi / math.max(sorted.length + groups.length * gap, 1);
  var cur = -math.pi / 2 - (groups.isEmpty ? 0 : groups.first.length * step / 2) - gap * step / 2;

  final nodes = <PlacedNode>[];
  for (final g in groups) {
    cur += gap / 2 * step;
    for (var gi = 0; gi < g.length; gi++) {
      final m = g[gi];
      var t = ((100 - m.score) / 62).clamp(0.0, 1.0);
      if (members.length > 6) t = 0.25 + t * 0.75; // 중심 주변 비우기
      if (members.length > 9 && gi.isOdd) {
        t = math.min(1, t + 0.18); // 같은 유형 지그재그
      }
      var a = cur + step / 2;
      if (jitter) {
        t = (t + ((_h997(m.id + m.name) % 21) - 10) / 70).clamp(0.0, 1.0);
        a += (((m.score * 7) % 11) - 5) / 60;
      }
      final e = ell(t);
      final lw = math.max(m.name.length * d.nameFs * 1.02 + 6, (d.typeFs * 2.1) + 18);
      nodes.add(
        PlacedNode(
          m,
          cx + math.cos(a) * e.dx,
          cy + math.sin(a) * e.dy,
          math.sin(a) < -0.5,
          lw,
        ),
      );
      cur += step;
    }
    cur += gap / 2 * step;
  }

  Rect box(PlacedNode n) {
    final half = math.max(r, n.labelW / 2);
    return n.labelTop
        ? Rect.fromLTRB(n.x - half, n.y - r - 5 - d.labelH, n.x + half, n.y + r)
        : Rect.fromLTRB(n.x - half, n.y - r, n.x + half, n.y + r + 5 + d.labelH);
  }

  const margin = 5.0;
  final cr = d.centerD / 2 + 12;
  for (var it = 0; it < 400; it++) {
    var moved = 0;
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final a = nodes[i], b = nodes[j];
        final boxA = box(a), boxB = box(b);
        final ox = math.min(boxA.right, boxB.right) - math.max(boxA.left, boxB.left) + margin;
        final oy = math.min(boxA.bottom, boxB.bottom) - math.max(boxA.top, boxB.top) + margin;
        if (ox > 0 && oy > 0) {
          moved++;
          if (ox < oy) {
            final s = (a.x < b.x ? -1 : 1) * math.min(ox, 6) / 2;
            a.x += s;
            b.x -= s;
          } else {
            final s = ((boxA.top + boxA.bottom) < (boxB.top + boxB.bottom) ? -1 : 1) *
                math.min(oy, 6) /
                2;
            a.y += s;
            b.y -= s;
          }
        }
      }
    }
    for (final n in nodes) {
      final bx = box(n);
      final nx = cx.clamp(bx.left, bx.right), ny = cy.clamp(bx.top, bx.bottom);
      final dist = math.sqrt(math.pow(nx - cx, 2) + math.pow(ny - cy, 2));
      if (dist < cr) {
        moved++;
        final l = math.sqrt(math.pow(n.x - cx, 2) + math.pow(n.y - cy, 2)).clamp(1.0, double.infinity);
        n.x += (n.x - cx) / l * math.min(4, cr - dist);
        n.y += (n.y - cy) / l * math.min(4, cr - dist);
      }
      n.x += (n.hx - n.x) * 0.012; // 약한 복원력
      n.y += (n.hy - n.y) * 0.012;
      final b2 = box(n);
      if (b2.left < 2) n.x += 2 - b2.left;
      if (b2.right > w - 2) n.x -= b2.right - (w - 2);
      if (b2.top < padT) n.y += padT - b2.top;
      if (b2.bottom > h - padB) n.y -= b2.bottom - (h - padB);
      for (final o in avoid) {
        final b3 = box(n);
        final ox = math.min(b3.right, o.right) - math.max(b3.left, o.left) + 4;
        final oy = math.min(b3.bottom, o.bottom) - math.max(b3.top, o.top) + 4;
        if (ox > 0 && oy > 0) {
          moved++;
          if (ox < oy) {
            n.x -= math.min(ox, 5);
          } else {
            n.y -= math.min(oy, 5);
          }
        }
      }
    }
    if (moved == 0 && it > 20) break;
  }
  return GuinjiLayout(nodes, Offset(cx, cy), d);
}

// ── 그리기 규칙 (CustomPainter) ───────────────────────────────
// 방사선: 중심 → 노드 중심, 흰색 22% 1px. 선택된 노드만 유형색 90% 2px (+ dash 스펙)
// 필터 중: 해당 유형 선 유형색 60%, 나머지 노드 opacity 0.28 · 선 0.05
// 이웃선: 같은 유형 안에서 정렬 순서로 인접한 두 노드를 흰색 10% 1px 로 연결 (각도상 인접이라 교차 없음)
// 중앙 광량: 반지름 130 radial, 흰색 9% → 0
// 노드: 원형 얼굴(cacheWidth 128) + 테두리 흰색 18% 1px · 선택 시 유형색 1.5px + glow + scale 1.12
// 라벨: 이름(nodeName) / 한자+짧은이름(유형색) 2줄 · 노드에서 6px
