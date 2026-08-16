// ============================================================
// 사주 원국판 (4 기둥 × 天干/地支) — 정통사주 전용 Dawn Hanji 디자인.
//
// [naming collision 회피] 원본 flutter_handoff.zip의 PillarBoard는 자체
// `Pillar(pos, gan, ji)` 모델(data/models/saju_result.dart)에 의존했지만,
// 이 프로젝트는 PHASE1~4 최종 계산 기준 `SajuProfile.Pillar`
// (manseryeok/saju_profile.dart, stemHanja/branchHanja/... 필드)를 이미
// 갖고 있다. 두 `Pillar` 클래스는 이름은 같지만 필드가 완전히 다르므로,
// 새 모델을 도입하지 않고 이 위젯이 직접
// `SajuProfile.pillarsByPosition`(Map<String, ManseryeokPillar>)을 받아
// 렌더링하도록 설계해 이름 충돌 자체를 원천적으로 피한다(§ naming
// collision 3건 중 Pillar 대응 — "실제 계산 결과를 그대로 렌더링"
// 원칙 유지, 별도 변환 계층 없음).
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/manseryeok/saju_profile.dart' show Pillar;
import 'hanji_design_tokens.dart';
import 'saju_seal.dart';

/// 오행 한자 → 표시용 값은 [Pillar.stemElement]/[Pillar.branchElement]에
/// 이미 한글('목'/'화'/'토'/'금'/'수')로 계산되어 있으므로 별도 매핑 테이블이
/// 필요 없다(원본의 `_kGanWuxing`/`_kJiWuxing` 하드코딩 제거 — 실계산 결과
/// 재사용 원칙).
class PillarBoard extends StatelessWidget {
  /// key: 'year' | 'month' | 'day' | 'hour' — [SajuProfile.pillarsByPosition]
  /// 형식과 동일.
  final Map<String, Pillar> pillarsByPosition;

  const PillarBoard({super.key, required this.pillarsByPosition});

  @override
  Widget build(BuildContext context) {
    const posMap = {
      'hour': ['시주', 'HOUR'],
      'day': ['일주', 'DAY'],
      'month': ['월주', 'MONTH'],
      'year': ['년주', 'YEAR'],
    };
    const order = ['hour', 'day', 'month', 'year'];
    final ordered = order
        .where((pos) => pillarsByPosition.containsKey(pos))
        .map((pos) => MapEntry(pos, pillarsByPosition[pos]!))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5A2B).withValues(alpha: 0.05),
        border: Border.all(color: HanjiColors.line),
        borderRadius: BorderRadius.circular(HanjiRadii.hero - 4),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              for (final e in ordered)
                Expanded(
                  child: Center(child: MonoLabel(posMap[e.key]![1])),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _Row(
            label: '천간',
            hanja: '天干',
            cells: ordered
                .map((e) => _Cell(
                      ch: e.value.stemHanja,
                      wuxing: e.value.stemElement,
                      me: e.key == 'day',
                    ))
                .toList(),
          ),
          const Divider(color: HanjiColors.line, height: 16),
          _Row(
            label: '지지',
            hanja: '地支',
            cells: ordered
                .map((e) => _Cell(
                      ch: e.value.branchHanja,
                      wuxing: e.value.branchElement,
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text(
                      '五行',
                      style: TextStyle(
                        color: HanjiColors.muted,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              for (final e in ordered)
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Dot(wx: e.value.stemElement),
                        const SizedBox(width: 3),
                        _Dot(wx: e.value.branchElement),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, hanja;
  final List<_Cell> cells;
  const _Row({required this.label, required this.hanja, required this.cells});

  @override
  Widget build(BuildContext context) {
    // [버그 수정 - 정식 오픈 전 긴급] 이 위젯이 결과 화면의 ListView 안에
    // 직접 들어가면서 부모로부터 무한대(Infinity) 높이 제약을 받는다.
    // CrossAxisAlignment.stretch는 유한한 높이가 있어야 자식을 늘려
    // 채울 수 있는데, 무한 높이가 들어오면 Flutter가
    // "BoxConstraints forces an infinite height" 렌더링 예외를 던지고
    // 그 결과 천간/지지 칸 전체가 렌더링되지 않고 빈 공간만 남는다
    // (실제 사주 계산 데이터 자체는 정상 — 계산 로직 문제 아님).
    // IntrinsicHeight로 감싸 Row에 유한한 높이를 제공해 해결한다.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label,
                    style: HanjiTextStyles.bodyTitle(color: HanjiColors.muted)
                        .copyWith(fontSize: 11)),
                Text(hanja,
                    style: const TextStyle(
                        color: HanjiColors.muted, fontSize: 10, letterSpacing: 2)),
                const SizedBox(width: 4),
              ],
            ),
          ),
          for (final c in cells)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String ch;
  final String wuxing;
  final bool me;
  const _Cell({required this.ch, required this.wuxing, this.me = false});

  @override
  Widget build(BuildContext context) {
    final color = HanjiColors.wuxingColor(wuxing);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: me
              ? HanjiColors.glow.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.14),
          border: Border.all(
            color: me ? HanjiColors.glow : color.withValues(alpha: 0.35),
            width: me ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(HanjiRadii.chip),
          boxShadow: me
              ? [BoxShadow(color: HanjiColors.glowShadow, blurRadius: 16)]
              : null,
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(ch,
                style: HanjiTextStyles.display1(color: color).copyWith(fontSize: 26)),
            if (me)
              Positioned(
                top: -6,
                right: -6,
                child: Transform.rotate(
                  angle: 0.1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: HanjiColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('ME',
                        style: TextStyle(
                            color: Color(0xFFFFF9E8),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final String wx;
  const _Dot({required this.wx});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: HanjiColors.wuxingColor(wx),
        shape: BoxShape.circle,
      ),
    );
  }
}
