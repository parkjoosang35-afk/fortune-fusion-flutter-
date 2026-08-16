// 한자 인장(도장) — 命 運 年 今 緣 特 壽 福 一 二 三 등에 사용
// 원본: flutter_handoff.zip widgets/saju_seal.dart (값 100% 동일, 토큰만 Hanji* 격리)
//
// [naming collision 없음] SajuSeal/MonoLabel/SajuCtxBar 는 기존 프로젝트에
// 존재하지 않는 이름이므로 그대로 사용한다(조사 결과 확정).

import 'package:flutter/material.dart';
import 'hanji_design_tokens.dart';

class SajuSeal extends StatelessWidget {
  final String glyph;
  final double size;
  final Color? color;
  final double rotation;

  const SajuSeal({
    super.key,
    required this.glyph,
    this.size = 40,
    this.color,
    this.rotation = -0.052,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? HanjiColors.accent;
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(HanjiRadii.seal),
          border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          glyph,
          style: HanjiTextStyles.display2(color: const Color(0xFFFFF9E8))
              .copyWith(
                fontSize: size * 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

/// 모노 라벨: `SAJU · 01 / 04` 같은 UPPERCASE + tracked 라벨.
class MonoLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const MonoLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: HanjiTextStyles.monoSmall(color: color),
    );
  }
}

/// 상단 컨텍스트 바 (뒤로가기 + 몰노 라벨 + 사주 코드 + 제목).
class SajuCtxBar extends StatelessWidget {
  final String tag;
  final String code;
  final String title;
  final VoidCallback? onBack;

  const SajuCtxBar({
    super.key,
    required this.tag,
    required this.code,
    required this.title,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HanjiSpacing.xl,
        HanjiSpacing.md,
        HanjiSpacing.xl,
        HanjiSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _RoundIconBtn(
            icon: '←',
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: HanjiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonoLabel(tag),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$code  ',
                        style: HanjiTextStyles.bodyTitle(
                          color: HanjiColors.muted,
                        ).copyWith(fontSize: 13),
                      ),
                      TextSpan(
                        text: title,
                        style: HanjiTextStyles.bodyTitle().copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const _RoundIconBtn(icon: '⋯'),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? onTap;
  const _RoundIconBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 20,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: HanjiColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: HanjiColors.line),
        ),
        alignment: Alignment.center,
        child: Text(
          icon,
          style: HanjiTextStyles.ui(
            color: HanjiColors.fg,
          ).copyWith(fontSize: 14),
        ),
      ),
    );
  }
}
