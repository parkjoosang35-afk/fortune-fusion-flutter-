// ============================================================
// [정통사주 결과 화면 개편 - Dawn Paper] TopBar + Hero.
//
// HTML 레퍼런스 `.topbar`(스크롤 시 하단 border 등장)와 `.hero`(cat-badge +
// hero-title + hero-sub + hero-meta 칩들)를 그대로 옮긴다. 스크롤 감지는
// 원본이 `window.scrollY > 6`를 쓰지만, Flutter에서는 호출부가 이미 갖고
// 있는 [ScrollController]의 offset을 그대로 넘겨받아 그림자 유무만
// 판단한다(새 스크롤 로직을 만들지 않고 상위 ListView/CustomScrollView의
// 컨트롤러를 재사용하는 설계).
// ============================================================

import 'package:flutter/material.dart';

import 'saju_dawn_data_models.dart';
import 'saju_dawn_tokens.dart';

/// 상단 고정 바 — `신통 · 정통사주` 브랜드 + 뒤로가기 + (옵션) 즐겨찾기.
/// [scrolled]가 true면 하단 테두리가 나타난다(HTML `.topbar.scrolled`).
class SajuDawnTopBar extends StatelessWidget implements PreferredSizeWidget {
  final bool scrolled;
  final VoidCallback? onBack;
  final Widget? trailing;

  const SajuDawnTopBar({
    super.key,
    required this.scrolled,
    this.onBack,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: SajuDawnMotion.topbarTransition,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SajuDawnColors.bg, Color(0xDCF5EDD8)],
        ),
        border: Border(
          bottom: BorderSide(
            color: scrolled
                ? SajuDawnColors.line
                : SajuDawnColors.line.withValues(alpha: 0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Center(
              child: _BrandMark(),
            ),
          ),
          trailing ?? const SizedBox(width: 38, height: 38),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '神通',
          style: TextStyle(
            fontFamily: SajuDawnFonts.serif,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: SajuDawnColors.gold,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '·',
          style: TextStyle(color: SajuDawnColors.ink4),
        ),
        const SizedBox(width: 6),
        Text(
          '정통사주',
          style: TextStyle(
            fontSize: 13,
            color: SajuDawnColors.ink3,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  // ignore: unused_element_parameter
  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, size: 19, color: color ?? SajuDawnColors.ink2),
        ),
      ),
    );
  }
}

/// Hero 섹션 — 카테고리 배지(命 + 코드 + "평생운 · 7번째 이야기") + 제목 +
/// 부제 + 메타 칩(일간/신강신약/조력형/대카테고리).
class SajuDawnHero extends StatelessWidget {
  final SajuResultData data;
  final String strengthLabel; // "신강(身强)" 등 — 이미 계산된 문자열 그대로.
  final String? typeLabel; // "조력형 助力型" 등, 없으면 생략.

  const SajuDawnHero({
    super.key,
    required this.data,
    required this.strengthLabel,
    this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = data.ilganTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatBadge(data: data),
          const SizedBox(height: 16),
          Text(data.title, style: SajuDawnText.heroTitle),
          const SizedBox(height: 8),
          Text(
            data.subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: SajuDawnColors.ink3,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip.rich('일간 ', '${theme.hangul}(${theme.hanja})'),
              _MetaChip(strengthLabel),
              if (typeLabel != null) _MetaChip(typeLabel!),
              _MetaChip(data.categoryGroup.split(' · ').first),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatBadge extends StatelessWidget {
  final SajuResultData data;
  const _CatBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      decoration: BoxDecoration(
        color: SajuDawnColors.paper,
        borderRadius: BorderRadius.circular(SajuDawnRadius.pill),
        border: Border.all(color: SajuDawnColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: SajuDawnColors.brown,
              shape: BoxShape.circle,
            ),
            child: Text(
              data.categoryHanja,
              style: const TextStyle(
                fontFamily: SajuDawnFonts.serif,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SajuDawnColors.paper,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            data.categoryCode,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: SajuDawnColors.ink3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: SajuDawnColors.ink4,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            data.categoryGroup,
            style: const TextStyle(
              fontSize: 12,
              color: SajuDawnColors.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final String? boldSuffix;

  const _MetaChip(this.text) : boldSuffix = null;
  const _MetaChip.rich(this.text, this.boldSuffix);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: SajuDawnColors.paper2,
        border: Border.all(color: SajuDawnColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: boldSuffix == null
          ? Text(text, style: SajuDawnText.metaChip)
          : Text.rich(
              TextSpan(
                style: SajuDawnText.metaChip,
                children: [
                  TextSpan(text: text),
                  TextSpan(
                    text: boldSuffix,
                    style: const TextStyle(
                      color: SajuDawnColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
