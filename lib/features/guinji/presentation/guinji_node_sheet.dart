import 'package:flutter/material.dart';

import '../character/guinji_character.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// N · Node Sheet — M(My Map) 화면 위에 `showModalBottomSheet`로 띄우는
/// "04 캐릭터 카드"(§05-2).
///
/// [2026 디자인 핸드오프] 검정 테마 전면 재작성 — 좌우 10 여백 · 반경
/// 34의 바텀 카드: 상반신 300(없으면 72px 아바타로 폴백) · "{이름}님의
/// 캐릭터 · 연령대" · 이름 · 점수(유형색) · 한자 + 유형명 ·
/// relationTypeDesc · CTA "관계 자세히 보기". [showGuinjiNodeSheet]
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
    this.characterId,
  });

  final String name;
  final String birthLabel;
  final String relationKey;
  final int score;
  final String narratorText;
  final List<(String label, String value)> evidenceRows;
  final VoidCallback? onShare;
  final VoidCallback? onSeeMore;

  /// 캐릭터 카드 상반신 이미지 ID(예: 'f30b'). null이면 이름 이니셜
  /// 원형 아바타로 폴백한다(캐릭터 자동 지정은 호출부 책임).
  final String? characterId;

  static String _goodMoment(String category) {
    switch (category) {
      case 'boost':
        return '큰 결정을 앞두고 있을 때, 감정이 흔들릴 때';
      case 'path':
        return '함께 계획하고 실행할 때, 여행이나 도전';
      case 'care':
        return '거리를 두고 지내다 가끔 만날 때';
    }
    return '평범한 일상 속 짧은 만남';
  }

  static String _carefulMoment(String category) {
    switch (category) {
      case 'boost':
        return '서로 지쳐 있는 저녁 시간대의 다툼';
      case 'path':
        return '속도가 안 맞을 때 서로 답답해질 수 있어요';
      case 'care':
        return '가까이 붙어 있을 때 감정 소모가 커요';
    }
    return '무리한 부탁이나 갑작스러운 변화';
  }

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationMetaOf(relationKey);
    final color = meta.color;
    final label = meta.label;
    final hanja = meta.hanja;
    final long = meta.long;
    final category = meta.category;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
    final body = characterId != null
        ? GuinjiCharacter(characterId!, '').body
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (_, scrollController) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: GmColors.sheet,
            borderRadius: BorderRadius.circular(GmRadius.card),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 32,
                offset: Offset(0, -8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // 핸들
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: GmColors.line,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),

                // 상반신 이미지(없으면 이니셜 아바타)
                if (body != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AspectRatio(
                        aspectRatio: 300 / 300,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            body,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) => Container(
                              color: GmColors.card,
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontFamily: GmText.display,
                                  fontSize: 48,
                                  color: GmColors.fg,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.75)],
                        ),
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: GmText.display,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: GmColors.onFg,
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Column(
                    children: [
                      Text(
                        '$name님의 캐릭터',
                        style: const TextStyle(
                          fontFamily: GmText.ui,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: GmColors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: GmText.cardName,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        birthLabel,
                        style: const TextStyle(fontSize: 11, color: GmColors.dim),
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
                              fontFamily: GmText.display,
                              fontSize: 34,
                              fontWeight: FontWeight.w600,
                              color: color,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '/ 100',
                            style: TextStyle(
                              fontFamily: GmText.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: GmColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hanja,
                              style: TextStyle(
                                fontFamily: GmText.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: GmText.ui,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
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
                      color: GmColors.card,
                      border: Border.all(color: GmColors.line),
                      borderRadius: BorderRadius.circular(GmRadius.box),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GmLabelMini('관계의 결'),
                        const SizedBox(height: 10),
                        Text(
                          long,
                          style: const TextStyle(
                            fontFamily: GmText.body,
                            fontSize: 13.5,
                            height: 1.7,
                            color: GmColors.fg,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          narratorText,
                          style: const TextStyle(
                            fontFamily: GmText.ui,
                            fontSize: 12.5,
                            height: 1.6,
                            color: GmColors.muted,
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
                          color: GmColors.danger,
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
                        color: GmColors.bg,
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
                                      fontFamily: GmText.ui,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: GmColors.muted,
                                    ),
                                  ),
                                  Expanded(
                                  child: Text(
                                    value,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontFamily: GmText.ui,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: GmColors.fg,
                                    ),
                                  )
                                ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // CTA — 관계 자세히 보기
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onShare,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: GmColors.line),
                            foregroundColor: GmColors.fg,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            '공유',
                            style: TextStyle(
                              fontFamily: GmText.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: ElevatedButton(
                          onPressed: onSeeMore,
                          style: gmPrimary(),
                          child: const Text('관계 자세히 보기'),
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
              style: const TextStyle(
                fontFamily: GmText.ui,
                fontSize: 12,
                height: 1.55,
                color: GmColors.muted,
              ),
              children: [
                TextSpan(
                  text: '$label · ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: GmColors.fg),
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
/// 바텀시트로 띄운다. [절대 원칙] 시그니처는 변경하지 않는다 — M화면의
/// `_handleNodeTap()`이 이 정확한 파라미터로 호출한다.
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
