import 'package:flutter/material.dart';
import '../theme/tarot_colors.dart';
import '../theme/tarot_text_styles.dart';
import '../theme/tarot_tokens.dart';
import '../../domain/tarot_result_view_model.dart';

/// [결과 공유 콘텐츠 부실 버그 수정 — "이미지로 공유하기"가 결과 전체가
/// 아니라 카드 한 장짜리 미니카드([TarotShareCard])만 캡처하던 문제]
///
/// [배경] 사용자 리포트: "이미지을 보내려면 요 이미지가 타로 결과
/// 페이지도 아닌데 요거 보내면 모하냐 타로 결과 전체을 보내야지". 기존
/// [TarotShareCard]는 카드 이미지 + 한줄운세 + 행운의 색/숫자만 있는
/// 360x450 미니카드로, 실제 결과화면(질문/AI 총평/포지션별 해석/조언/
/// AI 한마디 7섹션)과는 전혀 다른 정보량이었다.
///
/// [해결] 이 위젯은 [TarotResultView]가 이미 갖고 있는 정보를 그대로
/// 다시 사용해(신규 계산 로직 없음 — 결과화면과 동일한 값 객체 재사용),
/// "질문 → 카드 → 한줄운세 → AI 카드풀이(총평) → 포지션별 해석(있으면)
/// → 오늘의 조언 → 행운의 색/숫자 → AI 한마디" 순서로 실제 결과화면의
/// 축소 리포트를 만든다. 캡처 후 이미지로 보내면 받는 사람이 실제 타로
/// 결과를 충분히 파악할 수 있는 정보량을 담는다.
///
/// [캡처 규격] 기존 [TarotShareCard]와 동일한 논리 폭(360)에 높이는
/// 콘텐츠에 맞춰 가변적으로 늘어나며(Column의 자연 높이), 캡처 시
/// [capturePixelRatio]를 그대로 곱해 고해상도 PNG를 만든다.
class TarotShareReportCard extends StatelessWidget {
  const TarotShareReportCard({super.key, required this.view, this.nickname});

  final TarotResultView view;

  /// [공유카드 회원 닉네임 표시] 비로그인/게스트면 null.
  final String? nickname;

  static const double logicalWidth = 360;
  static const double capturePixelRatio = 3.0;

  @override
  Widget build(BuildContext context) {
    final result = view.result;
    // [정보량 제한] 카톡/문자로 보내는 이미지가 지나치게 길어지면 보는
    // 사람이 부담스러우므로, 포지션별 해석은 최대 3개까지만(대부분의
    // 스프레드가 1~5장이므로 5카드 스프레드에서도 과도하게 길어지지
    // 않도록)만 담는다 — 전체 포지션은 앱/공유 링크에서 볼 수 있다.
    final positions = result.positions.take(3).toList();

    return Container(
      width: logicalWidth,
      decoration: const BoxDecoration(gradient: TarotColors.nightGradient),
      padding: const EdgeInsets.all(TarotTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🔮', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nickname == null || nickname!.trim().isEmpty
                      ? '타로 카드 풀이'
                      : '$nickname님의 타로 카드 풀이',
                  style: TarotTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          // 질문
          _ReportSectionLabel(icon: '❓', label: '질문'),
          const SizedBox(height: 6),
          Text(
            result.question,
            style: TarotTextStyles.categoryTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          // 카드 이미지 + 이름
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    view.heroCard.imageAssetPath,
                    width: 96,
                    height: 148,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(
                      view.heroCard.icon,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                ),
                const SizedBox(height: TarotTokens.spaceSm),
                Text(
                  '${view.heroCard.nameKr}${view.heroCard.isReversed ? " (역방향)" : ""}',
                  style: TarotTextStyles.categoryTitle.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          // 한줄운세
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TarotTokens.spaceLg),
            decoration: BoxDecoration(
              color: TarotColors.surfaceCard,
              borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
              border: Border.all(color: TarotColors.borderGlow),
            ),
            child: Text(
              '"${view.oneLiner}"',
              textAlign: TextAlign.center,
              style: TarotTextStyles.bodyStrong.copyWith(
                color: TarotColors.pinkGlow,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          // AI 카드풀이(총평)
          _ReportSectionLabel(icon: '🔮', label: view.aiReadingLabel),
          const SizedBox(height: 6),
          Text(
            result.summary,
            style: TarotTextStyles.body.copyWith(fontSize: 12.5),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          // 포지션별 해석(3카드/5카드/YES-NO/A-B 등 다중 스프레드인 경우만)
          if (positions.length > 1) ...[
            const SizedBox(height: TarotTokens.spaceLg),
            _ReportSectionLabel(icon: '🗺️', label: '상세 리딩'),
            const SizedBox(height: 6),
            for (final p in positions) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: TarotTextStyles.body.copyWith(fontSize: 12),
                    children: [
                      TextSpan(
                        text: '${p.label}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: TarotColors.pinkGlow,
                        ),
                      ),
                      TextSpan(text: p.interpretation),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
          const SizedBox(height: TarotTokens.spaceLg),
          // 오늘의 조언
          _ReportSectionLabel(icon: '🧭', label: view.adviceLabel),
          const SizedBox(height: 6),
          Text(
            view.advice,
            style: TarotTextStyles.body.copyWith(fontSize: 12.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          // 행운의 색/숫자
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: view.luckyColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '행운의 색 ${view.luckyColorName} · 행운의 숫자 ${view.luckyNumber}',
                style: TarotTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          // AI 한마디
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TarotTokens.spaceMd),
            decoration: BoxDecoration(
              color: TarotColors.surfaceCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(TarotTokens.radiusMd),
              border: Border.all(
                color: TarotColors.borderGlow.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    view.aiClosing,
                    style: TarotTextStyles.body.copyWith(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TarotTokens.spaceLg),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  gradient: TarotColors.goldAccentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: TarotColors.bgVoid,
                ),
              ),
              const SizedBox(width: 6),
              Text('Fortune Fusion · 신통방통 타로', style: TarotTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportSectionLabel extends StatelessWidget {
  const _ReportSectionLabel({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TarotTextStyles.caption.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
