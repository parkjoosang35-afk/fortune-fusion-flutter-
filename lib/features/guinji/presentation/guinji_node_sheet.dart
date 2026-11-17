import 'package:flutter/material.dart';

import '../character/guinji_character.dart';
import '../deep/guinji_reasons.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../theme/guinji_type_spec.dart';
import '../widgets/guinji_animated_graph.dart' show parseGuinjiBirthLabel;
import '../widgets/guinji_map_widgets.dart';

/// N · Node Sheet — M(My Map) 화면 위에 `showModalBottomSheet`로 띄우는
/// 인물 상세 바텀시트.
///
/// [2026 디자인 핸드오프 v5 — "심야의 신전" 전면 교체] 기존(v2 검정 테마)
/// 레이아웃을 폐기하고 `design_handoff_guinji_map_v5/design_files/
/// guinji-temple.jsx`의 `TpPersonSheet` 구조를 1:1 이식한다:
/// 핸들 → 상반신 히어로(250, 그라데이션 페이드+닫기 버튼+이름/인장) →
/// (해금 배지) → "{name}님은 나에게 {label}이에요" → 점수 카드(점수 +
/// 등급 + 프로그레스바) → "관계의 결" → "왜 이렇게 나왔나요"(S1~S5
/// `guinjiReasons`) → "이렇게 이어가요"(tips) → footer(공유/자세히 보기).
/// 남기는 것은 로직만 — [showGuinjiNodeSheet] 함수 시그니처는 M화면의
/// `_handleNodeTap()`이 그대로 호출하므로 절대 변경하지 않는다.
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
    this.unlocked = false,
  });

  final String name;
  final String birthLabel;
  final String relationKey;
  final int score;

  /// [v5 100% 교체] 더 이상 화면에 직접 노출하지 않는다("왜 이렇게
  /// 나왔나요" 섹션이 `guinjiReasons`로 대체) — 파라미터는 호출부
  /// 호환을 위해 유지한다.
  final String narratorText;

  /// 위와 동일한 이유로 더 이상 "판정 근거" 섹션으로 직접 노출하지
  /// 않는다(파라미터만 유지 — 하위 호환).
  final List<(String label, String value)> evidenceRows;
  final VoidCallback? onShare;
  final VoidCallback? onSeeMore;

  /// 캐릭터 카드 상반신 이미지 ID(예: 'f30b'). null이면 [birthLabel]을
  /// 파싱해 자동 지정하고, 그마저 실패하면 이니셜 아바타로 폴백한다.
  final String? characterId;

  /// [v5] 결제로 이미 해금한 관계인지 — 해금 배지 + footer 문구 분기.
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final spec = guinjiTypeOf(relationKey);
    final meta = guinjiRelationMetaOf(relationKey);
    final color = spec.color;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    final GuinjiCharacter? char = characterId != null
        ? GuinjiCharacter(characterId!, '')
        : () {
            final birth = parseGuinjiBirthLabel(birthLabel);
            if (birth == null) return null;
            return GuinjiCharacter.of(birth: birth, stableKey: name);
          }();

    final reasons = guinjiReasons[relationKey] ?? const [];
    final tips = meta.tips;
    final grade = gradeOf(score);

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (_, scrollController) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF22163A), GmColors.sheet],
              stops: [0, 0.4],
            ),
            borderRadius: BorderRadius.circular(GmRadius.sheet),
            border: Border(top: BorderSide(color: color.withValues(alpha: 0.4))),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 32,
                offset: Offset(0, -8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 핸들
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0x40FFEBC8),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 캐릭터 히어로(250) ──
                      _PersonHero(
                        name: name,
                        hanja: spec.hanja,
                        label: spec.label,
                        band: char?.band ?? '',
                        bodyPath: char?.body,
                        color: color,
                        initial: initial,
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (unlocked)
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x1A6FD3A0),
                                  border: Border.all(
                                    color: const Color(0x596FD3A0),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: const [
                                    Text(
                                      '✓',
                                      style: TextStyle(
                                        color: Color(0xFF8FE0B6),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '결제 완료 · 10개 장 풀이와 편지를 언제든 다시 볼 수 있어요',
                                        style: TextStyle(
                                          fontFamily: GmText.ui,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          height: 1.4,
                                          color: Color(0xFF8FE0B6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // "{name}님은 나에게 {label}이에요"
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontFamily: GmText.body,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  height: 1.45,
                                  color: GmColors.fg,
                                ),
                                children: [
                                  TextSpan(text: '$name님은 나에게 '),
                                  TextSpan(
                                    text: spec.label,
                                    style: TextStyle(color: color),
                                  ),
                                  const TextSpan(text: '이에요'),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),
                            _ScoreCard(score: score, grade: grade, color: color),

                            const SizedBox(height: 18),
                            const GmLabelMini('관계의 결'),
                            const SizedBox(height: 9),
                            Text(
                              spec.desc,
                              style: const TextStyle(
                                fontFamily: GmText.body,
                                fontSize: 15.5,
                                height: 1.75,
                                color: GmColors.fg,
                              ),
                            ),

                            if (reasons.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const GmLabelMini('왜 이렇게 나왔나요'),
                              const SizedBox(height: 9),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: GmColors.line),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < reasons.length; i++)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 11,
                                        ),
                                        decoration: BoxDecoration(
                                          border: i > 0
                                              ? const Border(
                                                  top: BorderSide(
                                                    color: GmColors.hair,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: color.withValues(
                                                    alpha: 0.53,
                                                  ),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                reasons[i][0],
                                                style: TextStyle(
                                                  fontFamily: GmText.mono,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 10,
                                                  color: color,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                reasons[i][1],
                                                style: const TextStyle(
                                                  fontFamily: GmText.ui,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                  height: 1.5,
                                                  color: GmColors.fg,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            if (tips.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const GmLabelMini('이렇게 이어가요'),
                              const SizedBox(height: 9),
                              for (var i = 0; i < tips.length && i < 2; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontFamily: GmText.display,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          height: 1.5,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          tips[i],
                                          style: const TextStyle(
                                            fontFamily: GmText.ui,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            height: 1.6,
                                            color: GmColors.fg,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── footer: 공유 / 자세히 보기 ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: GmColors.hair)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: onShare,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: GmColors.line),
                          foregroundColor: GmColors.fg,
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
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: onSeeMore,
                          style: gmPrimary(),
                          child: Text(
                            unlocked ? '✓ 열어 둔 풀이 바로 보기' : '더 자세한 관계 보기',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 캐릭터 상반신 히어로(250) — 배경 이미지 + 하단 그라데이션 페이드 +
/// 닫기 버튼 + 좌하단(한자·연령대/이름) + 우하단 회전 인장 박스.
class _PersonHero extends StatelessWidget {
  const _PersonHero({
    required this.name,
    required this.hanja,
    required this.label,
    required this.band,
    required this.bodyPath,
    required this.color,
    required this.initial,
  });

  final String name;
  final String hanja;
  final String label;
  final String band;
  final String? bodyPath;
  final Color color;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 배경(이미지 or 폴백)
          if (bodyPath != null)
            Image.asset(
              bodyPath!,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.7),
              errorBuilder: (_, __, ___) => _HeroFallback(
                color: color,
                initial: initial,
              ),
            )
          else
            _HeroFallback(color: color, initial: initial),

          // 하단 그라데이션 페이드(→ sheet 색으로 자연스럽게 이어짐)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.4, 1.0],
                colors: [Color(0x00170E29), GmColors.sheet],
              ),
            ),
          ),

          // 닫기 버튼
          Positioned(
            right: 14,
            top: 8,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GmColors.line),
                  color: const Color(0x800A0716),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '✕',
                  style: TextStyle(color: GmColors.fg, fontSize: 15),
                ),
              ),
            ),
          ),

          // 좌하단: 한자·연령대 + 이름 / 우하단: 회전 인장 박스
          Positioned(
            left: 20,
            right: 20,
            bottom: 6,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        band.isEmpty ? hanja : '$hanja · $band',
                        style: TextStyle(
                          fontFamily: GmText.mono,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2.5,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: GmText.display,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: GmColors.fg,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.rotate(
                  angle: -5 * 3.1415926535 / 180,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hanja,
                            style: TextStyle(
                              fontFamily: GmText.display,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1,
                              color: GmColors.onFg,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: GmText.ui,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: GmColors.onFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.color, required this.initial});

  final Color color;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.35), const Color(0xFF2A1D40)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: GmText.display,
            fontWeight: FontWeight.w800,
            fontSize: 64,
            color: GmColors.fg,
          ),
        ),
      ),
    );
  }
}

/// 점수 카드 — 큰 점수 + 케미 점수/등급 + 프로그레스 바 + 안내 문구.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.score,
    required this.grade,
    required this.color,
  });

  final int score;
  final String grade;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: GmColors.card,
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // [반응형 화면 규격 통일 — v5 포팅 회귀 수정] 좁은 화면(320)에서
          // textScale을 2.0~2.5까지 올리면 38px 점수 숫자가 Row 폭을
          // 과도하게 차지해 오른쪽 Expanded 영역이 밀려 넘친다.
          // FittedBox로 감싸 필요시 축소되도록 한다
          // (test/guinji_node_sheet_overflow_test.dart 회귀 검증).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$score',
              style: TextStyle(
                fontFamily: GmText.display,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        '케미 점수',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GmText.ui,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                          color: GmColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$grade등급',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontFamily: GmText.ui,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: GmColors.fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x1AFFEBC8),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: (score.clamp(0, 100)) / 100,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: color),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  '점수가 높을수록 지도 가운데에 가까워요',
                  style: TextStyle(
                    fontFamily: GmText.ui,
                    fontSize: 11.5,
                    color: GmColors.dim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// M화면에서 노드를 탭했을 때 이 함수를 호출해 [GuinjiNodeSheet]을
/// 바텀시트로 띄운다. [절대 원칙] 기존 필수 파라미터는 변경하지 않는다 —
/// M화면의 `_handleNodeTap()`이 이 파라미터들로 호출한다.
///
/// [SPEC §6 H5 + QA_CHECKLIST.md "해금 분기(결제 완료 박스 + 버튼 문구)"]
/// [unlocked]는 선택 파라미터로 신규 추가했다(기본값 false로 기존 호출부
/// 호환 유지). 이전까지는 이 헬퍼가 `unlocked`를 아예 받지 않아
/// [GuinjiNodeSheet]에 항상 기본값(false)이 전달됐다 — 이미 결제로 해금한
/// 관계를 다시 열어도 시트에 결제완료 박스가 뜨지 않고 버튼도 항상
/// "더 자세한 관계 보기"(미해금 문구)로 보여 QA 요구를 위반했다.
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
  bool unlocked = false,
}) {
  return showGmBottomSheet(
    context: context,
    builder: (_) => GuinjiNodeSheet(
      name: name,
      birthLabel: birthLabel,
      relationKey: relationKey,
      score: score,
      narratorText: narratorText,
      evidenceRows: evidenceRows,
      onShare: onShare,
      onSeeMore: onSeeMore,
      unlocked: unlocked,
    ),
  );
}
