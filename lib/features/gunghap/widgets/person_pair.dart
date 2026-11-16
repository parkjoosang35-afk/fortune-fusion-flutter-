// ═══════════════════════════════════════════════════════════════
// FILE: person_pair.dart
// [궁합지도 핸드오프 v4] `00_DEV_MAPPING.md` §4 공용 컴포넌트 표
// (line 299-300, 698-699) — PersonPair / ElementBars.
//
// PersonPair: 2열 카드(초대한 사람/초대받은 사람) · 이름 · 일간 한자
// (Noto Serif 900 22) · "갑목 · 목 우세" + 가운데 관계(相生 + →).
// ElementBars: 5행(木火土金水) · 좌 나(accent 막대) · 가운데 한자 ·
// 우 상대(violet) · 상단 범례.
//
// [API 의존성 — 2026-11 추가] 두 위젯 모두 `owner`/`member` 두 사람의
// 일간·오행 개수가 필요한데, 과거 궁합지도 3개 응답(`g/[token]/join`,
// `direct`, `results/[resultId]`)은 상대방(member) 일간만 노출하고
// 초대자(owner) 쪽 데이터는 전혀 내려주지 않았다. 이번 작업에서
// admin_web 세 라우트에 하위호환 신규 필드(`owner: {dayMasterKr,
// dayMasterElement, elementCounts}`, `member: {...}`)를 추가해 해결했다
// (기존 top-level 필드는 전혀 건드리지 않음 — 순수 추가).
//
// [방어적 구현] 그래도 혹시 구버전 캐시 응답이거나 필드가 비어 있는
// 경우를 대비해, [PersonPair]/[ElementBars] 둘 다 owner/member 데이터가
// 없으면 위젯 자체가 아무것도 그리지 않는다(`SizedBox.shrink()`) —
// 화면이 깨지거나 로딩 스피너가 멈추는 대신, 그 섹션만 조용히 생략된다.
import 'package:flutter/material.dart';

import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';

/// `fact.owner`/`fact.member`(SajuSummary)에서 노출된 일간·오행 정보.
/// `Map<String, dynamic>?` 형태의 API 응답 조각을 그대로 파싱한다.
class GhPersonSaju {
  const GhPersonSaju({
    required this.dayMasterKr,
    required this.dayMasterElement,
    required this.elementCounts,
  });

  /// 일간 한글(예: "갑"). 한자 변환은 [GhHanja.stemHanja] 참고.
  final String dayMasterKr;

  /// 일간 오행(한글, 예: "목").
  final String dayMasterElement;

  /// 오행별 개수(한글 키 "목"/"화"/"토"/"금"/"수" → 0~8).
  final Map<String, int> elementCounts;

  static GhPersonSaju? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final dayMasterKr = raw['dayMasterKr'] as String?;
    final dayMasterElement = raw['dayMasterElement'] as String?;
    final countsRaw = raw['elementCounts'];
    if (dayMasterKr == null || dayMasterElement == null || countsRaw is! Map) {
      return null;
    }
    final counts = <String, int>{};
    countsRaw.forEach((k, v) {
      if (k is String && v is num) counts[k] = v.toInt();
    });
    return GhPersonSaju(
      dayMasterKr: dayMasterKr,
      dayMasterElement: dayMasterElement,
      elementCounts: counts,
    );
  }
}

/// 한글 → 한자 변환 + 오행 상생/상극 판정(결정론적 — 서버 호출 없음).
abstract final class GhHanja {
  static const _stemHanja = {
    '갑': '甲', '을': '乙', '병': '丙', '정': '丁', '무': '戊',
    '기': '己', '경': '庚', '신': '辛', '임': '壬', '계': '癸',
  };
  static const _elementHanja = {'목': '木', '화': '火', '토': '土', '금': '金', '수': '水'};

  /// "갑" → "甲". 매핑에 없으면 입력 그대로 반환.
  static String stemHanja(String kr) => _stemHanja[kr] ?? kr;

  /// "목" → "木". 매핑에 없으면 입력 그대로 반환.
  static String elementHanja(String kr) => _elementHanja[kr] ?? kr;

  /// "갑목" 형태(일간 한글 + 오행 한글)로 조합.
  static String stemWithElement(GhPersonSaju p) => '${p.dayMasterKr}${p.dayMasterElement}';

  // 오행 상생 순환: 목생화 · 화생토 · 토생금 · 금생수 · 수생목.
  static const _generates = {'목': '화', '화': '토', '토': '금', '금': '수', '수': '목'};

  /// a(나)가 b(상대)를 상생/상극하는지 판정 — PersonPair 가운데 아이콘용.
  /// 반환값: ('生'|'剋'|'比', 화살표 방향이 a→b인지).
  static (String, bool) relationGlyph(String elementA, String elementB) {
    if (elementA == elementB) return ('比', true);
    if (_generates[elementA] == elementB) return ('生', true);
    if (_generates[elementB] == elementA) return ('生', false);
    // 상극(剋) 판정: 목극토·토극수·수극화·화극금·금극목.
    const controls = {'목': '토', '토': '수', '수': '화', '화': '금', '금': '목'};
    if (controls[elementA] == elementB) return ('剋', true);
    return ('剋', false);
  }
}

/// [PersonPair] 2열 카드 — 초대한 사람(owner) / 초대받은 사람(member).
class PersonPair extends StatelessWidget {
  const PersonPair({
    super.key,
    required this.ownerName,
    required this.memberName,
    required this.owner,
    required this.member,
  });

  final String ownerName;
  final String memberName;
  final GhPersonSaju? owner;
  final GhPersonSaju? member;

  @override
  Widget build(BuildContext context) {
    final owner = this.owner;
    final member = this.member;
    if (owner == null || member == null) return const SizedBox.shrink();

    final dominantA = _dominantElement(owner.elementCounts) ?? owner.dayMasterElement;
    final dominantB = _dominantElement(member.elementCounts) ?? member.dayMasterElement;
    final (glyph, aToB) = GhHanja.relationGlyph(owner.dayMasterElement, member.dayMasterElement);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _PersonCard(name: ownerName, saju: owner, dominant: dominantA, color: GHColors.accent),
        ),
        SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(glyph, style: GHText.ui(size: 18, weight: FontWeight.w800, color: GHColors.violetText)),
              const SizedBox(height: 2),
              Icon(
                aToB ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                size: 14,
                color: GHColors.gray,
              ),
            ],
          ),
        ),
        Expanded(
          child: _PersonCard(name: memberName, saju: member, dominant: dominantB, color: GHColors.violet),
        ),
      ],
    );
  }

  static String? _dominantElement(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    var best = '';
    var bestN = -1;
    counts.forEach((k, v) {
      if (v > bestN) {
        bestN = v;
        best = k;
      }
    });
    return best.isEmpty ? null : best;
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.saju,
    required this.dominant,
    required this.color,
  });
  final String name;
  final GhPersonSaju saju;
  final String dominant;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(GHRadius.cardSm),
      border: Border.all(color: GHColors.lineSoft),
    ),
    child: Column(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GHText.ui(size: 13, weight: FontWeight.w700, color: GHColors.fg),
        ),
        const SizedBox(height: 6),
        Text(
          GhHanja.stemHanja(saju.dayMasterKr),
          style: TextStyle(
            fontFamily: 'NotoSerifKR',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${GhHanja.stemWithElement(saju)} · $dominant 우세',
          textAlign: TextAlign.center,
          style: GHText.ui(size: 11, color: GHColors.gray),
        ),
      ],
    ),
  );
}

/// [ElementBars] 5행(木火土金水) 오행 개수 비교 막대.
class ElementBars extends StatelessWidget {
  const ElementBars({
    super.key,
    required this.owner,
    required this.member,
  });

  final GhPersonSaju? owner;
  final GhPersonSaju? member;

  static const _order = ['목', '화', '토', '금', '수'];

  @override
  Widget build(BuildContext context) {
    final owner = this.owner;
    final member = this.member;
    if (owner == null || member == null) return const SizedBox.shrink();

    final maxCount = [
      ...owner.elementCounts.values,
      ...member.elementCounts.values,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Legend(color: GHColors.accent, label: '나'),
            const SizedBox(width: 16),
            _Legend(color: GHColors.violet, label: '상대'),
          ],
        ),
        const SizedBox(height: 10),
        for (final el in _order) ...[
          _ElementRow(
            hanja: GhHanja.elementHanja(el),
            aCount: owner.elementCounts[el] ?? 0,
            bCount: member.elementCounts[el] ?? 0,
            maxCount: maxCount,
          ),
          if (el != _order.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: GHText.ui(size: 11.5, color: GHColors.gray)),
    ],
  );
}

class _ElementRow extends StatelessWidget {
  const _ElementRow({
    required this.hanja,
    required this.aCount,
    required this.bCount,
    required this.maxCount,
  });
  final String hanja;
  final int aCount;
  final int bCount;
  final int maxCount;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Bar(count: aCount, maxCount: maxCount, color: GHColors.accent, alignEnd: true),
      ),
      SizedBox(
        width: 28,
        child: Text(
          hanja,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'NotoSerifKR',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: GHColors.fg,
          ),
        ),
      ),
      Expanded(
        child: _Bar(count: bCount, maxCount: maxCount, color: GHColors.violet, alignEnd: false),
      ),
    ],
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.count,
    required this.maxCount,
    required this.color,
    required this.alignEnd,
  });
  final int count;
  final int maxCount;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount == 0 ? 0.0 : (count / maxCount).clamp(0.0, 1.0);
    final label = Text('$count', style: GHText.ui(size: 11, color: GHColors.gray));
    final bar = LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth * ratio).clamp(count == 0 ? 0.0 : 6.0, constraints.maxWidth);
        return Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: w,
            height: 14,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          ),
        );
      },
    );
    return Row(
      children: alignEnd
          ? [Expanded(child: bar), const SizedBox(width: 6), label]
          : [label, const SizedBox(width: 6), Expanded(child: bar)],
    );
  }
}
