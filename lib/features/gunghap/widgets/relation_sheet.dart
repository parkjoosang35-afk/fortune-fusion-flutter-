// ═══════════════════════════════════════════════════════════════
// FILE: relation_sheet.dart
// [궁합지도 핸드오프 v4 반영] design_handoff_gunghap_map_v4
// `00_DEV_MAPPING.md` §5 S05(RelationSheet) + `flutter_starter/lib/
// gunghap/map/relation_sheet.dart` UI 레이아웃을 이 프로젝트의 실제
// 서버 데이터(비동기 fetch 구조)에 맞춰 이식했다.
//
// [FACT 재사용 — 하드코딩 금지] v4 참고 구현은 `Relation` 객체를
// 호출부가 미리 계산해 전달하는 구조지만, 이 프로젝트는 시트가 열릴 때
// `GunghapProvider.fetchRelation(resultId)`(`GET /gunghap/relation/
// {resultId}`)를 직접 호출해 서버가 실제 두 사람의 일간 오행으로 계산한
// `elementRelation()` 결과를 받아와 표시한다(admin_web
// `relation/[resultId]/route.ts` 참고 — 비화/상생out/상생in/상극out/
// 상극in 5종 템플릿 중 서버가 고른 1개). 이 비동기 fetch 구조는 절대
// 유지한다 — v4 Relation 모델은 UI 레이아웃 참고용으로만 사용했다.
//
// 구성 (위→아래, v4 §5 S05 8개 유지)
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
        decoration: BoxDecoration(
          gradient: GHGradients.sheet,
          border: const Border(top: BorderSide(color: GHColors.line, width: GHBorder.width)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(GHRadius.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: GHColors.lineSoft,
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
          Text(_error!, textAlign: TextAlign.center, style: GHText.body(color: GHColors.muted)),
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

    final band = GHBand.of(p.score);
    final relColor = relShort == '生'
        ? GHElement.relGen
        : relShort == '比'
        ? GHElement.relSame
        : GHElement.relKe;
    final pct = (p.score.clamp(40, 100) - 40) / 60;
    final meElement = widget.provider.mapMe?.element ?? '木';
    final meStem = widget.provider.mapMe?.stem ?? '甲';
    final subLabel = p.history.isNotEmpty ? p.history.first.sub : widget.majorName;
    final anyPaid = p.history.any((h) => h.paid);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RELATION · ${widget.majorHanja}', style: GHText.mono()),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '나 '),
                          TextSpan(
                            text: '✦',
                            style: TextStyle(color: GHColors.accent, fontSize: 21 * .75),
                          ),
                          TextSpan(text: ' ${p.name}'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GHText.sheetTitle(),
                    ),
                  ],
                ),
              ),
              _chip(widget.majorName, filled: false),
              const SizedBox(width: 6),
              _iconBtn('✕', () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 14),
          // 2. score card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: band.c1.withValues(alpha: .4), width: GHBorder.width),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [band.c1.withValues(alpha: .12), GHColors.fieldBg.withValues(alpha: .6)],
              ),
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => SizedBox.square(
                          dimension: 60,
                          child: CircularProgressIndicator(
                            value: v,
                            strokeWidth: 4,
                            strokeCap: StrokeCap.round,
                            color: band.c1,
                            backgroundColor: band.c1.withValues(alpha: .15),
                          ),
                        ),
                      ),
                      Text('${p.score}', style: GHText.sheetTitle(size: 21)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$subLabel 점수', style: GHText.caption()),
                      const SizedBox(height: 2),
                      Text(
                        band.label,
                        style: GHText.body(size: 17, weight: FontWeight.w700, color: band.c1),
                      ),
                      const SizedBox(height: 2),
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
              border: Border.all(color: GHColors.line, width: GHBorder.width),
              gradient: RadialGradient(
                colors: [relColor.withValues(alpha: .08), Colors.white],
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _node('$meStem$meElement', '나', meElement)),
                    SizedBox(
                      width: 92,
                      child: Column(
                        children: [
                          Text(relShort, style: GHText.hanja(size: 20, color: relColor)),
                          Text(
                            relArrow,
                            style: TextStyle(fontSize: 18, color: relColor, height: 1.2),
                          ),
                          Text(
                            relHanja,
                            style: GHText.hanja(size: 11, color: relColor, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _node('${p.stem}${p.element}', p.name, p.element)),
                  ],
                ),
                const SizedBox(height: 12),
                _chip('$relKo · $relLabel', filled: true, color: relColor),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 4. interpretation
          Text(
            '두 사람의 관계',
            style: GHText.caption(color: GHColors.accent).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(body, style: GHText.body(size: 15).copyWith(height: 1.85)),
          const SizedBox(height: 14),
          // 5. good / care
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _list('✦ 관계의 강점', good, GHColors.mint)),
                const SizedBox(width: 8),
                Expanded(child: _list('◇ 살펴볼 부분', care, GHColors.rose)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 6. history
          Text(
            '${p.name} 님과 본 궁합 · ${p.history.length}'
            '${p.history.length > 1 ? ' · 최신 1건만 지도에 반영' : ''}',
            style: GHText.caption(color: GHColors.accent).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GHColors.lineSoft, width: GHBorder.width),
            ),
            child: Column(
              children: [
                for (var i = 0; i < p.history.length; i++)
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onOpenResult(p.history[i].resultId);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : const Border(top: BorderSide(color: GHColors.lineSoft, width: GHBorder.width)),
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.history[i].sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GHText.body(size: 14, weight: FontWeight.w700),
                            ),
                          ),
                          if (i == 0 && p.history.length > 1) _mini('지도 반영', GHColors.accent),
                          if (p.history[i].paid) _mini('REPORT', GHColors.mint),
                          const Spacer(),
                          Text(
                            '${p.history[i].score}',
                            style: GHText.body(
                              size: 14,
                              weight: FontWeight.w900,
                              color: GHBand.of(p.history[i].score).c1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_formatDate(p.history[i].date), style: GHText.mono(size: 9.5)),
                          const Text('  ›', style: TextStyle(color: GHColors.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 7. 근거
          Text(
            '거리는 궁합 점수(40~100), 선은 두 사람의 일간 오행 관계(FACT)로 정해져요. 저장된 점수는 다시 열어도 바뀌지 않아요.'
            '${anyPaid ? '' : ' 상세 보고서에서 고른 궁합만 더 깊이 볼 수 있어요.'}',
            style: GHText.caption().copyWith(fontSize: 11.5),
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

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return DateFormat('yy.MM.dd').format(d.toLocal());
  }

  Widget _iconBtn(String g, VoidCallback onTap) => InkResponse(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .7),
        border: Border.all(color: GHColors.lineSoft, width: GHBorder.width),
      ),
      child: Text(g, style: const TextStyle(fontSize: 16, color: GHColors.fg)),
    ),
  );

  Widget _chip(String t, {required bool filled, Color color = GHColors.accent}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: filled ? color : color.withValues(alpha: .12),
      border: filled ? null : Border.all(color: color, width: 1),
    ),
    child: Text(
      t,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GHText.body(
        size: filled ? 12.5 : 12,
        weight: FontWeight.w700,
        color: filled ? Colors.white : color,
      ),
    ),
  );

  Widget _mini(String t, Color c) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c.withValues(alpha: .6)),
    ),
    child: Text(t, style: GHText.mono(size: 8.5, color: c).copyWith(letterSpacing: 1)),
  );

  Widget _node(String hj, String name, String element) {
    final c = GHElement.of(element);
    const koName = {'木': '목', '火': '화', '土': '토', '金': '금', '水': '수'};
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: .12),
            border: Border.all(color: c, width: 1.5),
          ),
          child: Text(hj, style: GHText.hanja(size: 20, color: c)),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GHText.body(size: 14.5, weight: FontWeight.w800),
        ),
        Text('${koName[element] ?? ''} 기운', style: GHText.caption()),
      ],
    );
  }

  Widget _list(String t, List<String> items, Color c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: GHColors.lineSoft, width: GHBorder.width),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: GHText.body(size: 12.5, weight: FontWeight.w700, color: c)),
        const SizedBox(height: 6),
        for (final x in items) Text(x, style: GHText.body(size: 13).copyWith(height: 1.6)),
      ],
    ),
  );
}
