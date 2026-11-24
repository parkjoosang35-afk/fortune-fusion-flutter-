// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_engines.dart — 5.FIVEENGINES (5탭 인터랙션)
// 출처: design_files/engine-app.jsx FiveEngines().
// State: currentEngine(EngineId) — README "State Management" 표 1행.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_data.dart';
import '../fe_engine_visuals.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

class FeEnginesSection extends StatefulWidget {
  const FeEnginesSection({super.key});
  @override
  State<FeEnginesSection> createState() => _FeEnginesSectionState();
}

class _FeEnginesSectionState extends State<FeEnginesSection> {
  FeEngineId _cur = FeEngineId.s;

  @override
  Widget build(BuildContext context) {
    final e = feEngineOf(_cur.code);
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
              hanja: '五鏡',
              mono: 'FIVE ENGINES · 04',
              title: Text('다섯 개의\n검증된 엔진'),
              sub: '엔진마다 다루는 데이터와 기준이 다릅니다. 눌러서 하나씩 살펴보세요.',
            ),
          ),
          Row(
            children: feEngines.map((x) {
              final on = _cur == x.id;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => setState(() => _cur = x.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on
                            ? x.color.withValues(alpha: 0.14)
                            : FeColors.card,
                        border: Border.all(color: on ? x.color : FeColors.line),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: on
                            ? [
                                BoxShadow(
                                  color: x.color.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            x.hanja,
                            style: TextStyle(
                              fontFamily: FeFonts.display,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: on ? x.color : FeColors.fg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            x.short,
                            style: TextStyle(
                              fontFamily: FeFonts.body,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: on ? x.color : FeColors.fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: Container(
              key: ValueKey(_cur),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: e.color.withValues(alpha: 0.35)),
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.2,
                  colors: [e.color.withValues(alpha: 0.18), FeColors.card],
                  stops: const [0, 0.6],
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -6,
                    top: -14,
                    child: Opacity(
                      opacity: 0.08,
                      child: Text(
                        e.hanja,
                        style: TextStyle(
                          fontFamily: FeFonts.display,
                          fontWeight: FontWeight.w900,
                          fontSize: 90,
                          color: e.color,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.tag,
                        style: TextStyle(
                          fontFamily: FeFonts.mono,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 3,
                          color: e.color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        e.ko,
                        style: const TextStyle(
                          fontFamily: FeFonts.display,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final idx = e.mottoPlain.indexOf(e.mottoBold);
                          final before = idx >= 0
                              ? e.mottoPlain.substring(0, idx)
                              : e.mottoPlain;
                          final after = idx >= 0
                              ? e.mottoPlain.substring(idx + e.mottoBold.length)
                              : '';
                          return RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: FeFonts.body,
                                fontSize: 14,
                                height: 1.5,
                                color: FeColors.fg,
                              ),
                              children: [
                                TextSpan(text: before),
                                if (idx >= 0)
                                  TextSpan(
                                    text: e.mottoBold,
                                    style: TextStyle(
                                      color: e.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                TextSpan(text: after),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      feEngineVis[_cur]!(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.only(top: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: FeColors.line,
                              style: BorderStyle.solid,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 54,
                                  child: Text(
                                    'INPUT',
                                    style: TextStyle(
                                      fontFamily: FeFonts.mono,
                                      fontSize: 10,
                                      letterSpacing: 1.6,
                                      color: FeColors.muted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    e.input,
                                    style: const TextStyle(
                                      fontFamily: FeFonts.body,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 54,
                                  child: Text(
                                    'METHOD',
                                    style: TextStyle(
                                      fontFamily: FeFonts.mono,
                                      fontSize: 10,
                                      letterSpacing: 1.6,
                                      color: FeColors.muted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    e.method,
                                    style: const TextStyle(
                                      fontFamily: FeFonts.body,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: e.color.withValues(alpha: 0.4),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '◈ 근거 카드 · 실측 예시',
                              style: TextStyle(
                                fontFamily: FeFonts.mono,
                                fontSize: 9.5,
                                color: e.color,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.evidence,
                              style: const TextStyle(
                                fontFamily: FeFonts.body,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          '"${e.line}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: FeFonts.body,
                            fontSize: 13,
                            height: 1.5,
                            color: e.color,
                          ),
                        ),
                      ),
                    ],
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
