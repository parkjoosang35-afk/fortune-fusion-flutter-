import 'package:flutter/material.dart';

import '../theme/guinji_theme.dart';
import 'guinji_star_field.dart';

/// 귀인지도 8화면(L·I·C·M·N·S·F·Y) 공통 UI 키트.
///
/// [design_handoff_guinji_web/Guinji Section.html]의 `.screen`/`.content`/
/// `.top-bar`/`.title-block`/`.field`/`.chip`/`.toggle`/`.btn-primary`/
/// `.stat-row` 등 반복 CSS 클래스를 Flutter 위젯으로 1:1 대응시킨다.
/// 8화면 모두 이 키트를 사용해 시각적 일관성을 보장한다.

/// `.screen` + `.bg-layer`(radial gradient) + `.stars` + `.content`(padding
/// 20/20/24, flex column)을 한 번에 구성하는 화면 스캐폴드.
class GuinjiScreenScaffold extends StatelessWidget {
  const GuinjiScreenScaffold({
    super.key,
    required this.child,
    this.bgAlignment = const Alignment(0, -0.4),
    this.bgOpacity = 0.14,
    this.starCount = 20,
    this.starSeed = 42,
    this.extraBackground,
  });

  final Widget child;
  final Alignment bgAlignment;
  final double bgOpacity;
  final int starCount;
  final int starSeed;

  /// C/M 화면의 회전 sigil 등, 별빛 위·컨텐츠 아래에 그려질 추가 배경 위젯.
  final Widget? extraBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GuinjiColors.backgroundSoft, GuinjiColors.backgroundDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: bgAlignment,
                  radius: 0.9,
                  colors: [
                    GuinjiColors.lavender.withValues(alpha: bgOpacity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: GuinjiStarField(starCount: starCount, seed: starSeed),
          ),
          if (extraBackground != null) Positioned.fill(child: extraBackground!),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.top-bar` — 좌측(뒤로가기/여백) · 중앙(breadcrumb) · 우측(아이콘/여백).
class GuinjiTopBar extends StatelessWidget {
  const GuinjiTopBar({
    super.key,
    required this.breadcrumb,
    this.onBack,
    this.trailing,
  });

  final String breadcrumb;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          onBack != null
              ? GuinjiIconButton(icon: '←', onPressed: onBack!)
              : const SizedBox(width: 32),
          Text(
            breadcrumb.toUpperCase(),
            style: const TextStyle(
              fontFamily: GuinjiFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 3,
              color: GuinjiColors.textSecondary,
            ),
          ),
          trailing ?? const SizedBox(width: 32),
        ],
      ),
    );
  }
}

/// `.icon-btn` — 32x32 원형 버튼(카드 배경 + 테두리).
class GuinjiIconButton extends StatelessWidget {
  const GuinjiIconButton({super.key, required this.icon, this.onPressed});

  final String icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GuinjiColors.surfaceCard,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: GuinjiColors.surfaceCardBorder),
        ),
        child: Text(
          icon,
          style: const TextStyle(fontSize: 16, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

/// `.title-block` + `.title`(accent span) + `.subtitle`.
class GuinjiTitleBlock extends StatelessWidget {
  const GuinjiTitleBlock({
    super.key,
    required this.titleSpans,
    this.subtitle,
    this.fontSize = 22,
  });

  /// [Text.rich]에 그대로 전달할 InlineSpan 리스트. accent 구간은
  /// [GuinjiAccentSpan]으로 감싸 골드→라벤더 그라디언트를 근사한다
  /// (Flutter는 텍스트별 그라디언트를 위해 ShaderMask가 필요하지만, 여기서는
  /// 단순화하여 라벤더 단색으로 accent를 표현한다).
  final List<InlineSpan> titleSpans;
  final String? subtitle;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: titleSpans,
              style: TextStyle(
                fontFamily: GuinjiFonts.display,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1.3,
                letterSpacing: -0.4,
                color: GuinjiColors.textPrimary,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: GuinjiFonts.body,
                fontSize: 12,
                height: 1.6,
                color: GuinjiColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// title 중 `.accent` 구간(골드→라벤더 그라디언트 텍스트) — 단순화하여
/// 라벤더 색으로 표시.
TextSpan guinjiAccentSpan(String text) {
  return TextSpan(text: text, style: const TextStyle(color: GuinjiColors.lavender));
}

/// `.field` + `.field-label` + `.field-input-wrap` + `.field-input` +
/// `.field-hint`.
class GuinjiField extends StatelessWidget {
  const GuinjiField({
    super.key,
    required this.label,
    this.required = false,
    this.hint,
    this.child,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.maxLength,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final bool required;
  final String? hint;
  /// 커스텀 입력 위젯(예: 3분할 생년월일)을 넣고 싶을 때 사용. 지정 시
  /// controller/placeholder 등 단일 입력 필드 관련 파라미터는 무시된다.
  final Widget? child;
  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: GuinjiColors.textPrimary,
                ),
                children: required
                    ? [
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: GuinjiColors.lavender),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          child ?? _singleInput(),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                hint!,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 10,
                  color: GuinjiColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _singleInput() {
    return GuinjiInputBox(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      maxLength: maxLength,
      textAlign: textAlign,
    );
  }
}

/// `.field-input-wrap` + `.field-input` 단독 사용(3분할 입력 등에 재사용).
class GuinjiInputBox extends StatelessWidget {
  const GuinjiInputBox({
    super.key,
    this.controller,
    this.placeholder,
    this.keyboardType,
    this.maxLength,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: GuinjiColors.surfaceCard,
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        textAlign: textAlign,
        style: const TextStyle(
          fontFamily: GuinjiFonts.body,
          fontSize: 14,
          color: GuinjiColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(color: Color(0x59DCD2F5)),
          border: InputBorder.none,
          isDense: true,
          counterText: '',
        ),
      ),
    );
  }
}

/// `.chips` + `.chip`/`.chip.active`.
class GuinjiChip extends StatelessWidget {
  const GuinjiChip({
    super.key,
    required this.label,
    required this.active,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? GuinjiColors.lavender.withValues(alpha: 0.22)
              : GuinjiColors.surfaceCard,
          border: Border.all(
            color: active
                ? GuinjiColors.lavender.withValues(alpha: 0.5)
                : GuinjiColors.surfaceCardBorder,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: GuinjiColors.glowShadow,
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? GuinjiColors.lavender : GuinjiColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// `.toggle` + `.toggle-track`(스위치).
class GuinjiToggle extends StatelessWidget {
  const GuinjiToggle({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: GuinjiColors.surfaceCard,
          border: Border.all(color: GuinjiColors.surfaceCardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: GuinjiFonts.body,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 10,
                        color: GuinjiColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34,
              height: 20,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value
                    ? GuinjiColors.lavender
                    : const Color(0x33DCC8FF),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: value
                      ? const Color(0xFF2A1A3A)
                      : GuinjiColors.textPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.btn-primary` — 라벤더 배경 풀 위드 버튼.
class GuinjiPrimaryButton extends StatelessWidget {
  const GuinjiPrimaryButton({
    super.key,
    required this.label,
    this.icon = '✧',
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final String icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: GuinjiColors.lavender,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: GuinjiColors.glowShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2A1A3A),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A1A3A),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-ghost` — 투명 배경 + 테두리 버튼.
class GuinjiGhostButton extends StatelessWidget {
  const GuinjiGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final String? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          side: const BorderSide(color: GuinjiColors.surfaceCardBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Text(icon!, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: GuinjiFonts.body,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GuinjiColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.stat-row` + `.stat`(num/label).
class GuinjiStatRow extends StatelessWidget {
  const GuinjiStatRow({super.key, required this.items});

  final List<(String num, String label)> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (num, label) in items) ...[
          Expanded(child: _Stat(num: num, label: label)),
          if (items.last.$1 != num || items.last.$2 != label)
            const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.num, required this.label});

  final String num;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: GuinjiColors.surfaceCard,
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // [렌더 버그 수정 — 사용자 리포트] "128,542"처럼 자릿수가 많은
          // 숫자가 좁은 스탯 박스 폭에서 두 줄로 줄바꿈되어 표시되는
          // 문제가 있었다("128,54" / "2"로 쪼개짐). `FittedBox` +
          // `maxLines: 1` + `softWrap: false`로 항상 한 줄로 유지하고,
          // 폭이 부족하면 폰트를 축소해서라도 한 줄에 맞춘다(디자인
          // 핸드오프의 `.stat-num { font: 900 20px/1 }` 한 줄 표시와
          // 동일하게 재현).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              num,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontFamily: GuinjiFonts.display,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: GuinjiColors.lavender,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontFamily: GuinjiFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.6,
              color: GuinjiColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.n-badge` — 관계 라벨 배지(원형 배경 + 테두리, 관계색 사용).
class GuinjiRelationBadge extends StatelessWidget {
  const GuinjiRelationBadge({
    super.key,
    required this.code,
    required this.koreanLabel,
    required this.color,
  });

  final String code;
  final String koreanLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$code · $koreanLabel',
        style: TextStyle(
          fontFamily: GuinjiFonts.body,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
