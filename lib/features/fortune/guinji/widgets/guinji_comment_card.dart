// ═══════════════════════════════════════════════════════════════
// FILE: guinji_comment_card.dart
// PURPOSE: 결과 리포트 화면의 귀인선녀 총평 카드
// USED IN: 관상 결과, 손금 결과 화면 상단
//
// 데이터 매핑:
//   AnalyzeResponse.summary → bodyText
//   AnalyzeResponse.intentionScore → starRating
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../theme/guinji_colors.dart';
import '../theme/guinji_typography.dart';
import 'guinji_fairy_avatar.dart';

class GuinjiCommentCard extends StatelessWidget {
  /// 귀인선녀 총평 본문 (여러 줄, `\n`으로 구분)
  final String bodyText;

  /// 귀인선녀가 사용자에게 던지는 짧은 인트로. 예: "당신의 얼굴을 들여다보니…"
  final String intro;

  /// 좌측 헤더 라벨. 예: '方通仙女 · 總評'
  final String header;

  /// 별점 (0~5). 소수점 지원
  final double starRating;

  /// 별점 옆 라벨. 예: 'INTENTION · 4.2'
  final String scoreLabel;

  const GuinjiCommentCard({
    super.key,
    required this.bodyText,
    required this.intro,
    this.header = '方通仙女 · 總評',
    required this.starRating,
    required this.scoreLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GuinjiColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GuinjiColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (귀인선녀 얼굴 + 인트로)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const GuinjiFairyAvatar(size: 38, borderWidth: 1.5),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header,
                      style: GuinjiType.monoSm.copyWith(
                        color: GuinjiColors.accent,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      intro,
                      style: GuinjiType.bodySmall.copyWith(
                        color: GuinjiColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: GuinjiColors.line,
                  style: BorderStyle.solid,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 총평 본문
          Text(
            bodyText,
            style: GuinjiType.bodyText.copyWith(fontSize: 14),
          ),

          const SizedBox(height: 10),

          // 별점 + 라벨
          Row(
            children: [
              _StarGauge(rating: starRating),
              const SizedBox(width: 6),
              Text(
                scoreLabel,
                style: GuinjiType.monoSm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarGauge extends StatelessWidget {
  final double rating;
  const _StarGauge({required this.rating});

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final empty = 5 - full;
    return Text(
      '★' * full + '☆' * empty,
      style: TextStyle(
        color: GuinjiColors.glow,
        fontSize: 12,
        letterSpacing: 0.6,
      ),
    );
  }
}
