import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';

/// 케미 촛불 — 점수(0~100)가 높을수록 크고 밝게 빛나는 촛불 아이콘.
///
/// 원본 `GuinjiComponents.jsx` → `ChemistryCandle`(내부 `Candle` SVG 참조는
/// 프로토타입 소스에서 발견되지 않아, 스펙 설명("점수 높을수록 크고
/// 밝음")을 근거로 Flutter 네이티브 도형(불꽃 모양 아이콘 + glow)으로
/// 재구현했다).
class GuinjiChemistryCandle extends StatelessWidget {
  const GuinjiChemistryCandle({
    super.key,
    required this.score,
    this.size = 54,
    this.showScore = true,
  });

  final int score;
  final double size;
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final scale = 0.55 + (score / 100) * 0.6;
    final glowStrength = 0.3 + (score / 100) * 0.7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * 1.4,
          child: Center(
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: size * 0.34,
                height: size,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [GuinjiColors.lavender, GuinjiColors.lavenderSoft],
                  ),
                  borderRadius: BorderRadius.circular(size * 0.17),
                  boxShadow: [
                    BoxShadow(
                      color: GuinjiColors.lavender.withValues(
                        alpha: glowStrength,
                      ),
                      blurRadius: 18 * glowStrength,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: size * 0.02),
                    child: Icon(
                      Icons.local_fire_department,
                      size: size * 0.32,
                      color: GuinjiColors.paper,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showScore) ...[
          const SizedBox(height: 4),
          Text(
            '$score',
            style: const TextStyle(
              fontFamily: GuinjiFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: GuinjiColors.textPrimary,
              shadows: [Shadow(color: GuinjiColors.glowShadow, blurRadius: 12)],
            ),
          ),
        ],
      ],
    );
  }
}
