// ═══════════════════════════════════════════════════════════════
// FILE: relation_sheet.dart
// [궁합지도 「인연지도」 디자인 핸드오프 2차 반영] design_handoff_gunghap_map
// (1).zip `MAP_HOME_SPEC.md` §4 "오행 관계도" + `flutter_starter/lib/
// gunghap/map/relation_sheet.dart` 참고 구현을 이 프로젝트의 실제 서버
// 데이터에 맞춰 이식했다.
//
// [FACT 재사용 — 하드코딩 금지] 참고 구현의 `ghRelationFromWood`(나=木
// 고정 하드코딩 테이블)는 쓰지 않는다 — 대신
// `GunghapProvider.fetchRelation(resultId)`(`GET /gunghap/relation/
// {resultId}`)를 호출해 서버가 실제 두 사람의 일간 오행으로 계산한
// `elementRelation()` 결과를 그대로 받아 표시한다(admin_web
// `relation/[resultId]/route.ts` 참고 — 비화/상생out/상생in/상극out/
// 상극in 5종 템플릿 중 서버가 고른 1개).
//
// 구성 (위→아래)
//  1. 헤더: RELATION · {분야 한자} / "나 ✦ {이름}" · 분야 칩 · ✕
//  2. 점수 카드: 링 게이지(40~100 → 0~100%) · "{세부} 점수" · "{밴드} 사이"
//  3. 오행 관계도: [나] — 生/比/剋 + 화살표 + 한자 — [상대] · 하단 칩
//  4. 두 사람의 관계 (해석 1문단)
//  5. 관계의 강점 / 살펴볼 부분 (2열 카드)
//  6. {이름} 님과 본 궁합 · n (히스토리 — 구매행은 보고서로, 나머지는 결과로)
//  7. 근거 문구
//  Footer: [＋ 궁합 추가] [{분야} 궁합 결과 보기]
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/gunghap_provider.dart';
import '../domain/gunghap_map_models.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import 'gh_button.dart';

({String label, Color color}) ghScoreBand(int s) => s >= 85
    ? (label: '아주 잘 맞는', color: const Color(0xFFF0D9A8))
    : s >= 70
    ? (label: '잘 맞는', color: GHColors.gold)
    : s >= 55
    ? (label: '맞춰 가는', color: GHColors.gray)
    : (label: '노력이 필요한', color: GHColors.violet);

/// 별 탭 시 열리는 RelationSheet. [provider]로 `GET /gunghap/relation/
/// {resultId}`를 호출해 오행 관계 FACT를 조회한 뒤 보여준다.
///
/// [onOpenResult] 결과 상세(`GunghapResultScreen`)를 열 때 호출된다 —
/// 상세 보고서 해금 여부(`unlocked`)는 그 화면 내부에서 처리하므로
/// "결과"와 "보고서"를 별도 화면으로 분리하지 않는다(히스토리 각 행도
/// 자신의 `resultId`로 동일 화면을 연다).
Future<void> showRelationSheet(
  BuildContext context,
  MapPerson p, {
  required GunghapProvider provider,
  required String majorName,
  required String majorHanja,
  required ValueChanged<String> onOpenResult,
  required VoidCallback onAddGunghap,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: GHColors.scrim,
    builder: (ctx) => _RelationSheet(
      p: p,
      provider: provider,
      majorName: majorName,
      majorHanja: majorHanja,
      onOpenResult: onOpenResult,
      onAdd: onAddGunghap,
    ),
  );
}

class _RelationSheet extends StatefulWidget {
  const _RelationSheet({
    required this.p,
    required this.provider,
    required this.majorName,
    required this.majorHanja,
    required this.onOpenResult,
    required this.onAdd,
  });

  final MapPerson p;
  final GunghapProvider provider;
  final String majorName, majorHanja;
  final ValueChanged<String> onOpenResult;
  final VoidCallback onAdd;

  @override
  State<_RelationSheet> createState() => _RelationSheetState();
}

class _RelationSheetState extends State<_RelationSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _relationData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final data = await widget.provider.fetchRelation(widget.p.resultId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (data == null) {
        _error = widget.provider.error ?? '관계 정보를 불러오지 못했습니다.';
      } else {
        _relationData = data;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .86),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF222D4A), GHColors.bg1],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: GHColors.gray.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: GHColors.gold),
                        ),
                      ),
                    )
                  : _error != null
                  ? _buildError(context)
                  : _buildBody(context),
            ),
            if (!_loading && _error == null) _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center, style: GHText.ui(color: GHColors.gray)),
          const SizedBox(height: 16),
          GHButton(
            label: '닫기',
            variant: GHButtonVariant.secondary,
            size: GHButtonSizeT.md,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final p = widget.p;
    final rel = _relationData!['relation'] as Map<String, dynamic>? ?? const {};
    final relShort = rel['short'] as String? ?? '比';
    final relHanja = rel['hanja'] as String? ?? '比和';
    final relKo = rel['ko'] as String? ?? '비화';
    final relLabel = rel['label'] as String? ?? '같은 기운의 관계';
    final relArrow = rel['arrow'] as String? ?? '⇆';
    final body = _relationData!['body'] as String? ?? '';
    final good = (_relationData!['good'] as List?)?.whereType<String>().toList() ?? const [];
    final care = (_relationData!['care'] as List?)?.whereType<String>().toList() ?? const [];

    final band = ghScoreBand(p.score);
    final relColor = relShort == '生'
        ? GHColors.gold
        : relShort == '比'
        ? GHColors.ivory
        : GHColors.violetText;
    final pct = (p.score.clamp(40, 100) - 40) / 60;
    final meElement = widget.provider.mapMe?.element ?? '木';
    final meStem = widget.provider.mapMe?.stem ?? '甲';
    final subLabel = p.history.isNotEmpty ? p.history.first.sub : widget.majorName;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RELATION · ${widget.majorHanja}', style: GHText.mono(color: GHColors.gold)),
                    const SizedBox(height: 6),
                    Text(
                      '나 ✦ ${p.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GHText.display(size: 21),
                    ),
                  ],
                ),
              ),
              _chip(widget.majorName),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Text('✕', style: TextStyle(color: GHColors.ivory)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 2. score card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: band.color.withValues(alpha: .4)),
              gradient: LinearGradient(
                colors: [band.color.withValues(alpha: .12), GHColors.bg2.withValues(alpha: .6)],
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 4,
                        color: band.color,
                        backgroundColor: GHColors.gray.withValues(alpha: .15),
                      ),
                      Text('${p.score}', style: GHText.display(size: 21)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$subLabel 점수', style: GHText.caption()),
                      Text('${band.label} 사이', style: GHText.cardTitle(size: 17, color: band.color)),
                      Text('점수가 높을수록 지도에서 나와 가까워요', style: GHText.caption()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 3. element diagram
          Container(
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: GHColors.divider),
              color: GHColors.bg2.withValues(alpha: .55),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _node('$meStem$meElement', '나', _elementColor(meElement))),
                    SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          Text(relShort, style: GHText.display(size: 20, color: relColor)),
                          Text(relArrow, style: TextStyle(fontSize: 18, color: relColor)),
                          Text(relHanja, style: GHText.title(size: 11, color: relColor)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _node('${p.stem}${p.element}', p.name, _elementColor(p.element)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _chip('$relKo · $relLabel', color: relColor),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 4. interpretation
          Text('두 사람의 관계', style: GHText.mono()),
          const SizedBox(height: 8),
          Text(body, style: GHText.reportBody().copyWith(fontSize: 15, height: 1.85)),
          const SizedBox(height: 14),
          // 5. good / care
          Row(
            children: [
              Expanded(child: _list('✦ 관계의 강점', good, GHColors.mint)),
              const SizedBox(width: 8),
              Expanded(child: _list('◇ 살펴볼 부분', care, GHColors.rose)),
            ],
          ),
          const SizedBox(height: 18),
          // 6. history
          Text('${p.name} 님과 본 궁합 · ${p.history.length}', style: GHText.mono()),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GHColors.lineSoft),
            ),
            child: Column(
              children: [
                for (final h in p.history)
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenResult(h.resultId);
                    },
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              h.sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GHText.cardTitle(size: 14),
                            ),
                          ),
                          if (h.paid)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('REPORT', style: GHText.mono(color: GHColors.mint, size: 8.5)),
                            ),
                          Text(
                            '${h.score}',
                            style: GHText.display(size: 14, color: ghScoreBand(h.score).color),
                          ),
                          const SizedBox(width: 10),
                          Text(_formatDate(h.date), style: GHText.mono(size: 9.5)),
                          const Text('  ›', style: TextStyle(color: GHColors.gray)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '거리는 궁합 점수(40~100), 선은 두 사람의 일간 오행 관계(FACT)로 정해져요. 저장된 점수는 다시 열어도 바뀌지 않아요.',
            style: GHText.caption(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          GHButton(
            label: '＋ 궁합 추가',
            variant: GHButtonVariant.secondary,
            size: GHButtonSizeT.md,
            expand: false,
            onPressed: () {
              Navigator.of(context).pop();
              widget.onAdd();
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GHButton(
              label: '${widget.majorName.replaceAll(' 궁합', '')} 궁합 결과 보기',
              size: GHButtonSizeT.md,
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOpenResult(widget.p.resultId);
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _elementColor(String element) => Color(ghElementColorValue[element] ?? 0xFFE2C07F);

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('yy.MM.dd').format(d.toLocal());
  }

  Widget _chip(String t, {Color color = GHColors.gold}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: .6)),
    ),
    child: Text(t, style: GHText.ui(size: 12.5, weight: FontWeight.w700, color: color)),
  );

  Widget _node(String hj, String name, Color color) => Column(
    children: [
      Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: .55)),
          gradient: RadialGradient(
            colors: [color.withValues(alpha: .15), GHColors.bg2.withValues(alpha: .8)],
          ),
        ),
        child: Text(hj, style: GHText.display(size: 22, color: color)),
      ),
      const SizedBox(height: 8),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GHText.cardTitle(size: 14.5)),
    ],
  );

  Widget _list(String t, List<String> items, Color c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: GHColors.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GHColors.lineSoft),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: GHText.ui(size: 12, weight: FontWeight.w700, color: c)),
        const SizedBox(height: 6),
        for (final x in items) Text(x, style: GHText.ui(size: 13)),
      ],
    ),
  );
}
