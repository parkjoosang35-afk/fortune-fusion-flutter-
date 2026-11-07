/// [기간별 운세 — 공통 UI 프리미티브]
///
/// `fortune-ui.jsx`/`fortune.css`의 버튼(`.btn-primary`/`.btn-ghost`/
/// `.btn-secondary`)·세그먼트(`.seg`)·필드 라벨을 백자 팔레트로 포팅한
/// 공통 위젯. 이 기능(`fortune_period`) 내부에서만 사용한다.
library;

import 'package:flutter/material.dart';
import '../theme/fortune_period_theme.dart';

/// `.btn-primary` — 메인 CTA.
class FortunePrimaryButton extends StatelessWidget {
  const FortunePrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF6B4FD8), FortunePeriodColors.glow],
                )
              : null,
          color: enabled ? null : FortunePeriodColors.card,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: FortunePeriodColors.glow.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
          border: enabled ? null : Border.all(color: FortunePeriodColors.line),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: enabled
                          ? FortunePeriodType.btnPrimary
                          : FortunePeriodType.btnPrimary.copyWith(
                              color: FortunePeriodColors.muted,
                            ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-ghost`
class FortuneGhostButton extends StatelessWidget {
  const FortuneGhostButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: FortunePeriodColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
          ),
        ),
        child: Text(label, style: FortunePeriodType.btnGhost),
      ),
    );
  }
}

/// `.btn-secondary`
class FortuneSecondaryButton extends StatelessWidget {
  const FortuneSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: FortunePeriodColors.card,
          side: const BorderSide(color: FortunePeriodColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
          ),
        ),
        child: Text(label, style: FortunePeriodType.btnSecondary),
      ),
    );
  }
}

/// `.seg` — 2지선다 세그먼트 컨트롤 (성별, 양/음력 등).
class FortuneSeg extends StatelessWidget {
  const FortuneSeg({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<MapEntry<String, String>> options; // key -> label
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFF4F1F8),
        border: Border.all(color: FortunePeriodColors.line),
      ),
      child: Row(
        children: options.map((o) {
          final selected = o.key == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                alignment: Alignment.center,
                margin: EdgeInsets.only(right: o == options.last ? 0 : 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF6B4FD8), FortunePeriodColors.glow],
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: FortunePeriodColors.glow.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  o.value,
                  style: TextStyle(
                    fontFamily: FortunePeriodType.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: selected ? Colors.white : FortunePeriodColors.muted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// `FieldLabel` — 번호 + 라벨 + (선택) 힌트.
class FortuneFieldLabel extends StatelessWidget {
  const FortuneFieldLabel({
    super.key,
    required this.no,
    required this.label,
    this.hint,
  });

  final String no;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$no  ',
                    style: const TextStyle(
                      fontFamily: FortunePeriodType.mono,
                      fontSize: 10,
                      letterSpacing: 1.0,
                      color: FortunePeriodColors.glow,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                      fontFamily: FortunePeriodType.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: FortunePeriodColors.fg,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hint != null)
            Text(
              hint!,
              style: const TextStyle(
                fontFamily: FortunePeriodType.body,
                fontSize: 11.5,
                color: FortunePeriodColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}

/// `.card` — 백자 카드 컨테이너(그림자 포함).
class FortuneCard extends StatelessWidget {
  const FortuneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: FortunePeriodColors.card,
        borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
        border: Border.all(color: FortunePeriodColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3C2864),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0F5B3FC4),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// `.policy-note` — 최초 입력 시 정책 안내 목록.
class FortunePolicyNote extends StatelessWidget {
  const FortunePolicyNote({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FortunePeriodRadius.lg),
        border: Border.all(
          color: FortunePeriodColors.line,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4, right: 6),
                  child: Text(
                    '◈',
                    style: TextStyle(
                      fontSize: 9,
                      color: FortunePeriodColors.glow,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: FortunePeriodType.body,
                      fontSize: 13.5,
                      height: 1.6,
                      color: FortunePeriodColors.fg,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 텍스트 입력 박스 (이름/닉네임 등) — `.inp`.
class FortuneTextField extends StatelessWidget {
  const FortuneTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hintText;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: FortunePeriodType.body,
        fontSize: 15,
        color: FortunePeriodColors.fg,
      ),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: FortunePeriodType.body,
          fontSize: 15,
          color: FortunePeriodColors.muted,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FortunePeriodColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FortunePeriodColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: FortunePeriodColors.glow,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
