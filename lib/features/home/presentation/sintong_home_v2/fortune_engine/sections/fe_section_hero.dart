// ═══════════════════════════════════════════════════════════════
// FILE: fe_section_hero.dart — 0.TopBar / 1.Hero / 1b.Marquee
// 출처: design_files/engine-app.jsx Hero() + App() 상단 topbar/Marquee.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../fe_engine_visuals.dart';
import '../fe_tokens.dart';
import '../fe_widgets.dart';

/// 0. 상단 고정 바 (pinned, 56h) — "← / 운세 엔진 / " 3열 그리드.
class FeTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FeTopBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: FeColors.bg2.withValues(alpha: 0.55),
        border: Border(bottom: BorderSide(color: FeColors.line)),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: FeColors.card,
                  border: Border.all(color: FeColors.line),
                ),
                child: const Text(
                  '←',
                  style: TextStyle(color: FeColors.fg, fontSize: 16),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '운세 엔진',
              textAlign: TextAlign.center,
              style: FeText.topBar,
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// 1. 히어로 — 타이틀 + 오빗 + 통계 4칸.
class FeHeroSection extends StatelessWidget {
  const FeHeroSection({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FeSpace.screenH,
        30,
        FeSpace.screenH,
        26,
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: FeDust(count: 14, color: FeColors.glow)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SINTONG · ENGINE ROOM · fortune_engine 1.1',
                style: FeText.mono,
              ),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    FeColors.glowLight,
                    FeColors.glow,
                    FeColors.glowDark,
                  ],
                  stops: [0, 0.55, 1],
                ).createShader(bounds),
                child: const Text('운세 엔진', style: FeText.heroTitle),
              ),
              const SizedBox(height: 14),
              RichText(
                text: const TextSpan(
                  style: FeText.lead,
                  children: [
                    TextSpan(text: '운세를 '),
                    TextSpan(
                      text: '지어내지 않습니다',
                      style: TextStyle(
                        color: FeColors.glow,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: '.\n계산하고, 대조하고, 근거를 보여드립니다.'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Center(child: FeHeroOrbit()),
              const SizedBox(height: 10),
              Row(
                children: const [
                  _FeHeroStat('5', '검증된 엔진'),
                  SizedBox(width: 6),
                  _FeHeroStat('29', '조합 리딩'),
                  SizedBox(width: 6),
                  _FeHeroStat('6', '대조 차원'),
                  SizedBox(width: 6),
                  _FeHeroStat('30', '검증 테스트 통과'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeHeroStat extends StatelessWidget {
  final String n, l;
  const _FeHeroStat(this.n, this.l);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: FeColors.bg2.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FeColors.line),
        ),
        child: Column(
          children: [
            Text(
              n,
              style: const TextStyle(
                fontFamily: FeFonts.display,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: FeColors.glow,
                shadows: [Shadow(color: FeColors.glowShadow, blurRadius: 14)],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: FeColors.muted,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1b. 무한 스크롤 띠.
class FeMarqueeSection extends StatelessWidget {
  const FeMarqueeSection({super.key});
  @override
  Widget build(BuildContext context) {
    return const FeMarquee(
      items: [
        '신통방통, 사실이 신통하다',
        '다섯 개의 거울, 하나의 대조',
        '갈림까지 보여주는 운세',
        '적중률 대신 근거를',
        '29가지 조합, 공정하게 전부',
      ],
    );
  }
}
