import 'package:flutter/material.dart';

import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// N · Node Sheet — M(My Map) 화면 위에 `showModalBottomSheet`로 띄우는
/// 관계 상세 바텀시트.
///
/// [2026-09 새 디자인 리스킨] 새 디자인 zip
/// `lib/guiindo/widgets/node_detail_sheet.dart`의 UI(DraggableScrollableSheet
/// + 72px 아바타 + ChipPill + 44px 점수 + "관계의 결" 박스 + 좋은/조심할
/// 순간 2줄 + 세부지표 + 액션버튼 2개)를 이식했다. [showGuinjiNodeSheet]
/// 함수 시그니처는 M화면의 `_handleNodeTap()`이 그대로 호출하므로 절대
/// 변경하지 않는다.
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

  static String _goodMoment(String category) {
    switch (category) {
      case 'boost':
        return '큰 결정을 앞두고 있을 때, 감정이 흔들릴 때';
      case 'path':
        return '함께 계획하고 실행할 때, 여행이나 도전';
      case 'warm':
        return '일이 벅찰 때 잠깐 만나 대화를 나눌 때';
      case 'care':
        return '무대 위, 새로운 자극이 필요할 때';
    }
    return '평범한 일상 속 짧은 만남';
  }

  static String _carefulMoment(String category) {
    switch (category) {
      case 'boost':
        return '서로 지쳐 있는 저녁 시간대의 다툼';
      case 'path':
        return '속도가 안 맞을 때 서로 답답해질 수 있어요';
      case 'warm':
        return '너무 자주 만나면 서로 무뎌질 수 있어요';
      case 'care':
        return '가까이 붙어 있을 때 감정 소모가 커요';
    }
    return '무리한 부탁이나 갑작스러운 변화';
  }

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[relationKey];
    final color = meta != null
        ? GmColors.categoryColor(meta.category)
        : GmColors.rose500;
    final label = meta?.label ?? relationKey;
    final long = meta?.long ?? narratorText;
    final category = meta?.category ?? 'boost';
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: GmColors.bgIvory,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // 핸들
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: GmColors.line,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),

                // 헤더(프로필+라벨+점수)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [color, color.withValues(alpha: 0.85)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: GmFonts.serif,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GmChip(
                        label: label,
                        background: color.withValues(alpha: 0.12),
                        foreground: color,
                        borderColor: color.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 10),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            fontFamily: GmFonts.serif,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: GmColors.ink,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(text: '$name님은\n'),
                            TextSpan(
                              text: meta?.short ?? label,
                              style: TextStyle(color: color),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        birthLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: GmColors.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: color,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '/ 100',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: GmColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '관계 케미 점수',
                        style: TextStyle(fontSize: 10.5, color: GmColors.inkFaint),
                      ),
                    ],
                  ),
                ),

                // 관계의 결
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      border: Border.all(color: GmColors.line),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GmLabelMini('관계의 결'),
                        const SizedBox(height: 10),
                        Text(
                          long,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.7,
                            color: GmColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          narratorText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            color: GmColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _MomentRow(
                          color: color,
                          label: '함께 있으면 좋은 순간',
                          desc: _goodMoment(category),
                        ),
                        const SizedBox(height: 8),
                        _MomentRow(
                          color: GmColors.rose800,
                          label: '조심할 순간',
                          desc: _carefulMoment(category),
                        ),
                      ],
                    ),
                  ),
                ),

                // 판정 근거(세부 지표)
                if (evidenceRows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: GmColors.bgCream.withValues(alpha: 0.6),
                        border: Border.all(color: GmColors.line),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          for (final (rowLabel, value) in evidenceRows)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    rowLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: GmColors.inkSoft,
                                    ),
                                  ),
                                  Text(
                                    value,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: GmColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // 액션 버튼 2개
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSeeMore,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: GmColors.line),
                            foregroundColor: GmColors.ink,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '더 자세히 보기',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: GmColors.gradientRose,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextButton(
                            onPressed: onShare,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              '이 관계 공유하기',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MomentRow extends StatelessWidget {
  const _MomentRow({required this.color, required this.label, required this.desc});

  final Color color;
  final String label;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, height: 1.55, color: GmColors.inkSoft),
              children: [
                TextSpan(
                  text: '$label · ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: GmColors.ink),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// M화면에서 노드를 탭했을 때 이 함수를 호출해 [GuinjiNodeSheet]을
/// 바텀시트로 띄운다. [2026-09 새 디자인 리스킨] 시그니처는 절대 변경하지
/// 않는다 — M화면의 `_handleNodeTap()`이 이 정확한 파라미터로 호출한다.
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
