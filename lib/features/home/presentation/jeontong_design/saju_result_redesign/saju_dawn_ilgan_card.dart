// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] 壹(ONE) 일간 카드.
//
// HTML `.ilgan-card`(grid 100px 1fr) + `.ilgan-visual`(방사형 glow +
// [BrushInHanja] 붓글씨 등장 + 하단 tag pill) + `.ilgan-body`(라벨/제목/
// 설명)를 그대로 옮긴다. [BrushInHanja]/[SajuDawnColors]/[IlganTheme]는
// 모두 이미 존재하는 헬퍼를 그대로 사용한다(새 계산 없음).
// ============================================================

import 'package:flutter/material.dart';

import 'saju_dawn_animations.dart';
import 'saju_dawn_data_models.dart';
import 'saju_dawn_ilgan_theme.dart';
import 'saju_dawn_section_shell.dart';
import 'saju_dawn_tokens.dart';

class SajuDawnIlganCard extends StatelessWidget {
  final SajuResultData data;

  const SajuDawnIlganCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = data.ilganTheme;
    return SajuDawnCard(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // `.ilgan-card::before` 방사형 glow(우상단).
          Positioned(
            top: -40,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.soft.withValues(alpha: 0.8),
                      theme.soft.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IlganVisual(theme: theme),
              const SizedBox(width: 18),
              Expanded(child: _IlganBody(theme: theme, data: data)),
            ],
          ),
        ],
      ),
    );
  }
}

class _IlganVisual extends StatelessWidget {
  final IlganTheme theme;
  const _IlganVisual({required this.theme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 116, // 100 + tag가 절반 튀어나오는 여유(HTML translateY(50%)).
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.soft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.line, width: 1.5),
            ),
            child: BrushInHanja(
              text: theme.hanja,
              color: theme.main,
              fontSize: 52,
            ),
          ),
          // `.tag` — 바닥 중앙, 아래로 50% 튀어나온 pill.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.main,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${theme.element.hanja} · ${theme.elementEn}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IlganBody extends StatelessWidget {
  final IlganTheme theme;
  final SajuResultData data;
  const _IlganBody({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日干 · ILGAN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.76,
            color: SajuDawnColors.goldDeep,
          ),
        ),
        const SizedBox(height: 6),
        Text(theme.symbolName, style: SajuDawnText.cardTitle),
        const SizedBox(height: 8),
        Text(
          data.ilganDescription,
          style: SajuDawnText.cardBody,
        ),
      ],
    );
  }
}
