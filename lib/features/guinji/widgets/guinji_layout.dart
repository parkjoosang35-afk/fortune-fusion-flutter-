// lib/features/guinji/widgets/guinji_layout.dart
// [2026 디자인 핸드오프 v5 — "심야의 신전" 지도 비주얼 전면 재작성]
// 기존 이 파일의 `computeGuinjiLayout()`은 "guinji-data.js layout()과 1:1
// 이식"이라는 주석이 달려 있었으나, 실제로는 이전 버전(v2/v3)의
// `GJ.layout()`을 이식한 것이었다. v5의 실제 지도 컴포넌트 `TpMap`은
// `guinji-data.js`의 `layout()`을 전혀 쓰지 않고, `guinji-temple.jsx`
// 자체에 정의된 별도 함수 `tpPlace(members)`(179~212줄)를 사용한다.
// 이 파일은 `tpPlace()`를 Dart로 1:1 포팅한 것으로 전면 교체한다.
//
// 핵심 차이(구버전 대비):
//  - 각도: 유형마다 "고정 60도 방향"(`base = k*60-90`)을 차지한다(가변
//    부채꼴이 아님). 같은 유형 내 여러 명은 기준각 좌우로 최대 ±22도
//    스프레드(`spread`)된다.
//  - 거리: `k = (100-score)/60` (0~1, score 높을수록 중심 가까이) →
//    타원 반지름 `rx = 62+k*76, ry = 78+k*118`로 변환.
//  - 충돌 해소: 260회 반복, 각도(ang)와 거리계수(k)를 동시에 밀어내며,
//    각도는 항상 `[base-29, base+29]` 범위로 강제된다(유형 방향을 벗어나지
//    않음).
//  - 좌표계: 컨테이너 크기와 무관한 **고정 캔버스** 390×520(중심
//    195,262) — v5 SVG `viewBox="0 0 390 520"`와 동일. 실제 화면 크기에는
//    렌더링 단계(바깥쪽 CustomPainter)에서 "contain" 방식으로 맞춘다.
import 'dart:math' as math;

import '../theme/guinji_type_spec.dart';

/// 지도에 배치할 사람 1명의 입력 데이터.
class GuinjiNodeIn {
  final String id, name, type;
  final int score;
  const GuinjiNodeIn(this.id, this.name, this.type, this.score);
}

/// v5 `tpDense(n)` 1:1 포팅 — 인원수에 따라 노드 반지름(NR)·폰트(fs)·
/// 유형 간 간격(gap)을 조절해 인원이 많아져도 지도가 터지지 않게 한다.
class GuinjiTpDensity {
  final double nr; // 노드 반지름(얼굴 원)
  final double fs; // 이름/점수 라벨 폰트 크기
  final double gap; // (범례용 여백, 현재 레이아웃 계산에는 미사용이나 1:1 보존)
  const GuinjiTpDensity(this.nr, this.fs, this.gap);

  factory GuinjiTpDensity.of(int n) {
    if (n <= 10) return const GuinjiTpDensity(16, 10.5, 18);
    if (n <= 18) return const GuinjiTpDensity(13.5, 9.5, 15);
    return const GuinjiTpDensity(10.5, 8.5, 12);
  }
}

/// `tpPlace()`가 배치한 사람 1명 — 각도(ang)·거리계수(k)·최종 좌표(x,y)를
/// 함께 들고 있다. 충돌 해소 단계에서 ang/k가 반복적으로 수정되므로
/// mutable 필드로 둔다(핸드오프 원본의 `{...m, base, ang, k}` 객체와 동일).
class GuinjiTpNode {
  GuinjiTpNode({
    required this.m,
    required this.base,
    required this.ang,
    required this.k,
  });

  final GuinjiNodeIn m;

  /// 이 사람이 속한 관계유형의 고정 기준각(도 단위, `k*60-90`).
  final double base;

  /// 현재 각도(도 단위) — 충돌 해소로 base±29 범위 내에서 조정된다.
  double ang;

  /// 중심으로부터의 거리 계수(0=가장 가까움 near 0, 1.08=가장 멈 near max).
  double k;

  double x = 0, y = 0;

  String get id => m.id;
  String get name => m.name;
  String get type => m.type;
  int get score => m.score;
}

class GuinjiTpPlacement {
  GuinjiTpPlacement(this.nodes, this.density);
  final List<GuinjiTpNode> nodes;
  final GuinjiTpDensity density;
}

// ── v5 고정 캔버스 상수 (`guinji-temple.jsx` 176줄) ──────────────────
const double tpCanvasWidth = 390;
const double tpCanvasHeight = 520;
const double tpCenterX = 195;
const double tpCenterY = 262;

/// "나"(소유자) 중앙 노드 반지름 — v5 `ME = 32`.
const double tpOwnerRadius = 32;

double tpClampScore(num v) => v.toDouble().clamp(40.0, 100.0);
double tpRad(double deg) => deg * math.pi / 180;

/// v5 `tpDense(n)` — [GuinjiTpDensity.of]로 이식.
GuinjiTpDensity tpDense(int n) => GuinjiTpDensity.of(n);

/// v5 `tpPlace(members)`(179~212줄) 1:1 포팅.
///
/// 1) 관계유형 순서([guinjiTypeOrder], v5 `TYPE_ORDER`)대로 각 유형에
///    고정 60도 방향(`base = k*60-90`, 12시=−90°부터 시계방향)을 배정.
/// 2) 같은 유형 내 여러 명은 점수 내림차순 정렬 후, 기준각 좌우로
///    `spread` 만큼(최대 ±22도) 지그재그 배치.
/// 3) 거리 계수 `k = (100-score)/60`(0~1)로 타원 반지름을 계산해 좌표화.
/// 4) 260회 반복으로 겹치는 노드 박스(W×Hh)를 각도+거리 동시 조정으로
///    밀어내되, 각도는 항상 `[base-29, base+29]`를 벗어나지 않게 강제.
GuinjiTpPlacement computeGuinjiTpPlacement(List<GuinjiNodeIn> members) {
  final d = GuinjiTpDensity.of(members.length);
  final out = <GuinjiTpNode>[];
  for (var k = 0; k < guinjiTypeOrder.length; k++) {
    final t = guinjiTypeOrder[k];
    final g = members.where((m) => m.type == t).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final n = g.length;
    for (var i = 0; i < n; i++) {
      final m = g[i];
      final spread = n > 1
          ? ((i.isOdd ? 1 : -1) * ((i / 2).ceil())) /
                math.max(1, ((n - 1) / 2).ceil()) *
                22
          : 0.0;
      final base = k * 60 - 90.0;
      out.add(
        GuinjiTpNode(
          m: m,
          base: base,
          ang: base + spread,
          k: (100 - tpClampScore(m.score)) / 60,
        ),
      );
    }
  }

  (double, double) pos(GuinjiTpNode p) {
    final rx = 62 + p.k * 76, ry = 78 + p.k * 118;
    final a = tpRad(p.ang);
    return (tpCenterX + math.cos(a) * rx, tpCenterY + math.sin(a) * ry);
  }

  final w = math.max(d.nr * 2, d.fs * 2.6) + 6; // 가로: 얼굴/이름 중 넓은 쪽
  final hh = d.nr * 2 + d.fs + 8; // 세로: 얼굴 + 이름 줄

  for (var it = 0; it < 260; it++) {
    var moved = false;
    for (var i = 0; i < out.length; i++) {
      for (var j = i + 1; j < out.length; j++) {
        final a = out[i], b = out[j];
        final (ax, ay) = pos(a);
        final (bx, by) = pos(b);
        final ox = w - (ax - bx).abs();
        final oy = hh - (ay - by).abs();
        if (ox > 0 && oy > 0) {
          moved = true;
          final f = math.min(ox / w, oy / hh) + .05;
          var da = b.ang - a.ang;
          while (da > 180) {
            da -= 360;
          }
          while (da < -180) {
            da += 360;
          }
          final s = da >= 0 ? 1 : -1;
          a.ang -= s * f * 2.4;
          b.ang += s * f * 2.4;
          final GuinjiTpNode inn = a.k <= b.k ? a : b;
          final GuinjiTpNode ou = a.k <= b.k ? b : a;
          inn.k = math.max(0, inn.k - f * .025);
          ou.k = math.min(1.08, ou.k + f * .025);
        }
      }
    }
    for (final p in out) {
      p.ang = math.max(p.base - 29, math.min(p.base + 29, p.ang));
    }
    if (!moved) break;
  }
  for (final p in out) {
    final (x, y) = pos(p);
    p.x = x;
    p.y = y;
  }
  return GuinjiTpPlacement(out, d);
}

/// v5 `GJ.counts(members)` — 관계유형별 인원수 집계(0도 포함, 범례/필터용).
Map<String, int> guinjiTpCounts(List<GuinjiNodeIn> members) {
  final c = <String, int>{for (final t in guinjiTypeOrder) t: 0};
  for (final m in members) {
    c[m.type] = (c[m.type] ?? 0) + 1;
  }
  return c;
}

/// v5 `TP_SLOTS`(219~224줄) — 아직 8명이 채워지지 않았을 때, 지도에 함께
/// 표시되는 "빈 자리 별"(엄마/절친/연인/동료/아빠/선배/형제자매/친구).
/// `a`는 각도(도), `kk`는 거리 계수(0~1).
class GuinjiTpSlot {
  const GuinjiTpSlot(this.label, this.hint, this.angleDeg, this.k);
  final String label;
  final String hint;
  final double angleDeg;
  final double k;
}

const List<GuinjiTpSlot> guinjiTpSlots = [
  GuinjiTpSlot('엄마', '가장 가까운 사람', -90, .45),
  GuinjiTpSlot('절친', '오래 곁에 있을 사람', -38, .85),
  GuinjiTpSlot('연인', '마음이 가는 사람', 8, .55),
  GuinjiTpSlot('동료', '매일 마주치는 사람', 55, .95),
  GuinjiTpSlot('아빠', '말보다 마음인 사람', 100, .5),
  GuinjiTpSlot('선배', '먼저 길을 걸어 본 사람', 148, .9),
  GuinjiTpSlot('형제·자매', '함께 자란 사람', 192, .55),
  GuinjiTpSlot('친구', '편하게 웃는 사이', 236, .92),
];

const int tpSlotTotal = 8;

/// v5 바깥 유형 호+라벨(범례 겸 필터) 좌표 — `lx=TCX+cos(la)*176,
/// ly=TCY+sin(la)*240`(287~288줄). 유형 인덱스(k, [guinjiTypeOrder]
/// 순서)를 받아 (x,y)를 반환한다.
(double, double) tpTypeLegendPos(int typeIndex) {
  final base = typeIndex * 60 - 90.0;
  final la = tpRad(base);
  return (
    tpCenterX + math.cos(la) * 176,
    tpCenterY + math.sin(la) * 240,
  );
}
