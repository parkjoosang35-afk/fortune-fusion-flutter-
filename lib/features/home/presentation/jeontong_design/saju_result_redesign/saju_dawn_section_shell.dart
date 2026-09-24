// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] 섹션 공용 셸.
//
// HTML 레퍼런스(`사주 결과페이지.html`)의 `.section`/`.section-label`
// 패턴을 그대로 옮긴다 — 壹~柒 7개 챕터 섹션이 모두 이 셸을 공유한다
// (원본 CSS: `.section { padding: 26px 22px 0 }`,
// `.section-label { display:flex; gap:10px; margin-bottom:12px }`).
// ============================================================

import 'package:flutter/material.dart';

import 'saju_dawn_animations.dart';
import 'saju_dawn_tokens.dart';

/// 壹·ONE / 貳·TWO ... 섹션 라벨(한자 순번 + 영문 + 이름 + 그라데이션 선).
class SajuDawnSectionLabel extends StatelessWidget {
  final String num; // "壹 · ONE"
  final String name; // "당신의 일간"

  const SajuDawnSectionLabel({super.key, required this.num, required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            num,
            style: const TextStyle(
              fontFamily: SajuDawnFonts.serif,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.92,
              color: SajuDawnColors.goldDeep,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.26,
              color: SajuDawnColors.ink2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    SajuDawnColors.line2,
                    SajuDawnColors.line2.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.section` 래퍼 — [RevealOnScroll]로 스크롤 진입 시 페이드업 + 섹션 라벨
/// + 본문(child)을 세로로 쌓는다. [revealKey]는 화면 안에서 유일해야 한다
/// (VisibilityDetector 필수 요구사항).
class SajuDawnSectionShell extends StatelessWidget {
  final String num;
  final String name;
  final String revealKey;
  final Widget child;

  const SajuDawnSectionShell({
    super.key,
    required this.num,
    required this.name,
    required this.revealKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RevealOnScroll(
      uniqueKey: revealKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SajuDawnSpacing.screenPadding,
          SajuDawnSpacing.xl,
          SajuDawnSpacing.screenPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SajuDawnSectionLabel(num: num, name: name),
            child,
          ],
        ),
      ),
    );
  }
}

/// 카드 공용 배경(`.ilgan-card`/`.wongook`/`.ohaeng-card`/`.story` 등이
/// 공유하는 `background: paper; border: 1px solid line; border-radius: 18`).
class SajuDawnCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SajuDawnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SajuDawnSpacing.cardPadding),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: SajuDawnColors.paper,
        borderRadius: BorderRadius.circular(SajuDawnRadius.card),
        border: Border.all(color: SajuDawnColors.line),
      ),
      child: child,
    );
  }
}
