import 'package:flutter/material.dart';

import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_ui_kit.dart';

/// N · Node Sheet — `/guinji/m/:mapId?node=:nodeId` (바텀시트)
///
/// [design_handoff_guinji_web/Guinji Section.html] 1706~1774줄 마크업을
/// 재현한다. M(My Map) 화면 위에 `showModalBottomSheet`로 띄우는 것을
/// 전제로 하며, backdrop(blur+dim)은 `showModalBottomSheet`의 barrierColor로
/// 대체한다.
///
/// 사용 예:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   barrierColor: const Color(0x99000000),
///   builder: (_) => GuinjiNodeSheet(
///     name: '수아', birthLabel: '1998 · 05 · 14 · 火時',
///     relationKey: 'CHEON_GWII', score: 92,
///     narratorText: '수아님은 ...',
///     evidenceRows: const [('오행 보충도', '+0.82'), ...],
///   ),
/// );
/// ```
class GuinjiNodeSheet extends StatelessWidget {
  const GuinjiNodeSheet({
    super.key,
    required this.name,
    required this.birthLabel,
    required this.relationKey,
    required this.score,
    required this.narratorText,
    required this.evidenceRows,
    this.onShare,
    this.onSeeMore,
  });

  final String name;
  final String birthLabel;
  final String relationKey;
  final int score;
  final String narratorText;
  final List<(String label, String value)> evidenceRows;
  final VoidCallback? onShare;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[relationKey];
    final color = meta?.color ?? GuinjiColors.lavender;
    final hanja = meta?.hanja ?? '?';
    final label = meta?.label ?? relationKey;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(GuinjiColors.backgroundSoft, color, 0.06)!,
              GuinjiColors.backgroundDeep,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: GuinjiColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // n-header
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: GuinjiColors.surfaceCardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.25),
                        border: Border.all(color: color, width: 2),
                      ),
                      child: Text(
                        hanja,
                        style: TextStyle(
                          fontFamily: GuinjiFonts.display,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: GuinjiFonts.body,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: GuinjiColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            birthLabel.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: GuinjiFonts.mono,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: GuinjiColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.display,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color,
                        shadows: [
                          Shadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // n-badge
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GuinjiRelationBadge(
                  code: relationKey,
                  koreanLabel: label,
                  color: color,
                ),
              ),
              // Doryeong narrator + n-body
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/guinji/doryeong/pointing.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: GuinjiColors.lavender.withValues(alpha: 0.04),
                          border: Border.all(
                            color: GuinjiColors.surfaceCardBorder,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          narratorText,
                          style: const TextStyle(
                            fontFamily: GuinjiFonts.body,
                            fontSize: 12.5,
                            height: 1.7,
                            color: GuinjiColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // n-basis rows
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    for (final (rowLabel, value) in evidenceRows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              rowLabel,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: GuinjiColors.textSecondary,
                              ),
                            ),
                            Text(
                              value,
                              style: const TextStyle(
                                fontFamily: GuinjiFonts.body,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: GuinjiColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // 더 자세한 풀이 보기 (업셀)
              InkWell(
                onTap: onSeeMore,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: GuinjiColors.lavender.withValues(alpha: 0.06),
                    border: Border.all(
                      color: GuinjiColors.lavender.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GuinjiColors.lavender.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '+',
                          style: TextStyle(
                            fontFamily: GuinjiFonts.display,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: GuinjiColors.lavender,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '더 자세한 풀이 보기',
                              style: TextStyle(
                                fontFamily: GuinjiFonts.body,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: GuinjiColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '오행 · 십성 · 대운 흐름',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 10,
                                color: GuinjiColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '›',
                        style: TextStyle(
                          fontSize: 14,
                          color: GuinjiColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GuinjiGhostButton(
                label: '이 관계 공유하기',
                icon: '↗',
                onPressed: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M화면에서 노드를 탭했을 때 이 함수를 호출해 [GuinjiNodeSheet]을
/// 바텀시트로 띄운다.
Future<void> showGuinjiNodeSheet({
  required BuildContext context,
  required String name,
  required String birthLabel,
  required String relationKey,
  required int score,
  required String narratorText,
  required List<(String label, String value)> evidenceRows,
  VoidCallback? onShare,
  VoidCallback? onSeeMore,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99000000),
    builder: (_) => GuinjiNodeSheet(
      name: name,
      birthLabel: birthLabel,
      relationKey: relationKey,
      score: score,
      narratorText: narratorText,
      evidenceRows: evidenceRows,
      onShare: onShare,
      onSeeMore: onSeeMore,
    ),
  );
}
