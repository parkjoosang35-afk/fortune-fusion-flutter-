// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_combos.dart — 7.29READINGS (5원형 오브 다중토글,
// 조합코드계산)
// 출처: design_files/engine-app.jsx Combos().
// State: comboSel(Set<EngineId>) — README "State Management" 표 2행.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_data.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

class FeCombosSection extends StatefulWidget {
  const FeCombosSection({super.key});
  @override
  State<FeCombosSection> createState() => _FeCombosSectionState();
}

class _FeCombosSectionState extends State<FeCombosSection> {
  Set<FeEngineId> _sel = {FeEngineId.s, FeEngineId.g, FeEngineId.t};
  String? _pkg;

  static const _tiers = [
    [
      '단일',
      '5',
      ['S', 'G', 'T', 'F', 'P'],
      '5',
    ],
    [
      '듀오',
      '10',
      ['SG', 'ST', 'SF', 'SP', 'GT', 'GF', 'GP', 'TF', 'TP', 'FP'],
      'C(5,2)',
    ],
    [
      '트리오',
      '10',
      ['SGT', 'SGF', 'SGP', 'STF', 'STP', 'SFP', 'GTF', 'GTP', 'GFP', 'TFP'],
      'C(5,3)',
    ],
    [
      '종합',
      '1',
      ['SGTFP'],
      '五鏡',
    ],
    [
      '패키지',
      '3',
      ['PKG1', 'PKG2', 'PKG3'],
      'LIFE',
    ],
  ];

  void _toggle(FeEngineId id) {
    setState(() {
      _pkg = null;
      if (_sel.contains(id)) {
        _sel = {..._sel}..remove(id);
      } else {
        _sel = {..._sel, id};
      }
    });
  }

  void _selectCode(String code) {
    setState(() {
      if (code.startsWith('PKG')) {
        _pkg = code;
      } else {
        _pkg = null;
        _sel = code
            .split('')
            .map((c) => FeEngineId.values.firstWhere((e) => e.code == c))
            .toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = feComboCode(_sel);
    final active = _pkg ?? code;
    String title, line;
    if (_pkg != null) {
      title = _pkg == 'PKG1'
          ? '연애·결혼 심층'
          : _pkg == 'PKG2'
          ? '커리어·재물 심층'
          : '학업·시험 심층';
      line = feCatalog[_pkg]!;
    } else if (code.isEmpty) {
      title = '엔진을 골라보세요';
      line = '가벼운 단일 리딩부터 다섯 엔진의 오경 종합까지';
    } else if (code.length == 4) {
      title = '네 엔진 조합은 오경 종합으로';
      line = '하나를 더하면 다섯 엔진이 서로를 견제하는 오경 종합이 됩니다';
    } else {
      final full = feCatalog[code]!;
      if (full.contains(' — ')) {
        final parts = full.split(' — ');
        title = parts[0];
        line = parts.sublist(1).join(' — ');
      } else {
        title = code
            .split('')
            .map((c) => feEngineOf(c).ko)
            .join(code.length == 2 ? '×' : '·');
        line = full;
      }
    }
    final kind = _pkg != null
        ? '패키지'
        : code.length == 1
        ? '단일'
        : code.length == 2
        ? '듀오'
        : code.length == 3
        ? '트리오'
        : code.length == 5
        ? '종합'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FeSpace.screenH,
        FeSpace.sectionTop,
        FeSpace.screenH,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FeReveal(
            child: FeSectionHead(
              hanja: '二十九',
              mono: '29 READINGS · 06',
              title: Text('29가지 리딩\n— 전부, 공정하게'),
              sub:
                  '골라지는 조합이 아니라, 있는 조합 전부입니다. 조합이 좁을수록 하나의 관점, 넓을수록 하나의 대조를 얻습니다.',
            ),
          ),
          Row(
            children: feEngines.map((e) {
              final on = _pkg == null && _sel.contains(e.id);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => _toggle(e.id),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 450),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: on
                              ? null
                              : Colors.black.withValues(alpha: 0.25),
                          gradient: on
                              ? RadialGradient(
                                  colors: [
                                    e.color.withValues(alpha: 0.35),
                                    Colors.transparent,
                                  ],
                                  radius: 0.85,
                                )
                              : null,
                          border: Border.all(
                            color: on ? e.color : FeColors.line,
                          ),
                          boxShadow: on
                              ? [
                                  BoxShadow(
                                    color: e.color.withValues(alpha: 0.5),
                                    blurRadius: 20,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          e.hanja,
                          style: TextStyle(
                            fontFamily: FeFonts.display,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: on ? e.color : FeColors.fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: feEngines.map((e) {
              return Expanded(
                child: Center(
                  child: Text(
                    e.short,
                    style: const TextStyle(fontSize: 11, color: FeColors.muted),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Container(
              key: ValueKey('$active$title'),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                border: Border.all(color: FeColors.line),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        active.isEmpty ? '· · ·' : active,
                        style: const TextStyle(
                          fontFamily: FeFonts.mono,
                          fontSize: 22,
                          letterSpacing: 3,
                          color: FeColors.glow,
                        ),
                      ),
                      if (kind.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: FeColors.glow),
                          ),
                          child: Text(
                            kind,
                            style: const TextStyle(
                              fontFamily: FeFonts.ui,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: FeColors.glow,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: FeFonts.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    line,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: FeColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: fePackageSeals.entries.map((entry) {
              final id = entry.key;
              final h = entry.value;
              final n = id == 'PKG1'
                  ? '연애·결혼 심층'
                  : (id == 'PKG2' ? '커리어·재물 심층' : '학업·시험 심층');
              final on = _pkg == id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _pkg = _pkg == id ? null : id),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: on
                            ? FeColors.accent.withValues(alpha: 0.14)
                            : FeColors.card,
                        border: Border.all(
                          color: on ? FeColors.accent : FeColors.line,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: on
                            ? [
                                BoxShadow(
                                  color: FeColors.accent.withValues(alpha: 0.3),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FeSeal(h, size: 28, color: FeColors.accent),
                          const SizedBox(height: 6),
                          Text(
                            n,
                            style: const TextStyle(
                              fontFamily: FeFonts.body,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          FeReveal(
            child: FeGlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < _tiers.length; i++) ...[
                          Column(
                            children: [
                              Text(
                                _tiers[i][1] as String,
                                style: const TextStyle(
                                  fontFamily: FeFonts.display,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _tiers[i][0] as String,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: FeColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _tiers[i][3] as String,
                                style: const TextStyle(
                                  fontFamily: FeFonts.mono,
                                  fontSize: 7.5,
                                  color: FeColors.glow,
                                ),
                              ),
                            ],
                          ),
                          if (i < _tiers.length - 1)
                            const Text(
                              '+',
                              style: TextStyle(
                                fontSize: 13,
                                color: FeColors.muted,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                        Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (b) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [FeColors.glowLight, FeColors.glow],
                              ).createShader(b),
                              child: const Text(
                                '29',
                                style: TextStyle(
                                  fontFamily: FeFonts.display,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Text(
                              '전수',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: FeColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: FeColors.line, height: 1),
                  const SizedBox(height: 10),
                  ..._tiers.map((t) {
                    final h = t[0] as String;
                    final codes = t[2] as List<String>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              h,
                              style: const TextStyle(
                                fontFamily: FeFonts.body,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: codes.map((c) {
                                final hit = c == active;
                                return GestureDetector(
                                  onTap: () => _selectCode(c),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hit
                                          ? FeColors.glow
                                          : FeColors.card,
                                      border: Border.all(
                                        color: hit
                                            ? FeColors.glow
                                            : FeColors.line,
                                      ),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      c,
                                      style: TextStyle(
                                        fontFamily: FeFonts.mono,
                                        fontSize: 10.5,
                                        letterSpacing: 0.5,
                                        color: hit
                                            ? FeColors.ink
                                            : FeColors.muted,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  const Text(
                    '조합 개수는 마케팅 숫자가 아니라 조합론적 전수 구조입니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: FeColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
