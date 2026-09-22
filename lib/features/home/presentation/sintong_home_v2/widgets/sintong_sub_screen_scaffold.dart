// ═══════════════════════════════════════════════════════════════
// FILE: sintong_sub_screen_scaffold.dart
// [신통방통 홈 v2] 5개 카테고리 진입 목차 화면(귀인지도/정통사주/타로/
// 소원방/손금관상) 공통 레이아웃. README.md prototype/screens/_shared.css
// 의 구조(status→hdr→hero-strip→quote→section-head/sub→opt-list→cta)를
// 그대로 재현한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../../../../core/router/main_bottom_nav_bar.dart';
import '../sintong_home_v2_data.dart';
import '../sintong_home_v2_tokens.dart';
import '../sintong_home_v2_routing.dart';

class SintongSubScreenScaffold extends StatelessWidget {
  const SintongSubScreenScaffold({super.key, required this.category});

  final SHomeV2Category category;

  @override
  Widget build(BuildContext context) {
    final options = sHomeV2Options[category] ?? const [];

    return Scaffold(
      backgroundColor: SHomeV2Colors.subScaffoldBg,
      // [하단바 통일 작업] 이 화면들은 홈 v2의 push 인스턴스이므로 전역
      // 5탭 하단바(MainBottomNavBar)를 동일하게 노출한다. 귀인지도/타로/
      // 소원방/손금은 개념상 "운세"(index 1)에 속하지만, 소원방은 자체
      // 탭(index 2)이 있으므로 그것만 예외로 맞춘다.
      bottomNavigationBar: MainBottomNavBar(
        currentIndex: category == SHomeV2Category.wish ? 2 : 1,
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _Header(category: category),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroStrip(category: category),
                        const SizedBox(height: 18),
                        _Quote(category: category),
                        Text(
                          category.sectionHead,
                          style: SHomeV2Text.sectionHead(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.sectionSub,
                          style: SHomeV2Text.sectionSub(),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            for (int i = 0; i < options.length; i++) ...[
                              _OptionRow(
                                option: options[i],
                                onTap: () =>
                                    openSubOption(context, category, i),
                              ),
                              if (i != options.length - 1)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // CTA — README `.cta-wrap`(position:absolute; bottom:32)과
            // 동일한 시각효과. 하단바 위에 겹쳐 떠 있는 형태로 배치한다.
            SintongSubScreenCta(category: category),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.category});
  final SHomeV2Category category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              category.subHeaderTitle,
              textAlign: TextAlign.center,
              style: SHomeV2Text.subHeaderTitle(),
            ),
          ),
          _IconBtn(icon: Icons.more_horiz_rounded, onTap: () {}),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x14FFFFFF),
          border: Border.all(color: const Color(0x2EFFFFFF), width: 0.5),
        ),
        child: Icon(icon, size: 14, color: Colors.white),
      ),
    );
  }
}

class _HeroStrip extends StatelessWidget {
  const _HeroStrip({required this.category});
  final SHomeV2Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.only(top: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SHomeV2Radii.heroStrip),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(category.subHeroAsset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0),
                  Colors.black.withValues(alpha: 0),
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.subHeroEyebrow,
                  style: SHomeV2Text.subHeroEyebrow(),
                ),
                const SizedBox(height: 8),
                Text(
                  category.subHeroTitle,
                  style: SHomeV2Text.subHeroTitle(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.category});
  final SHomeV2Category category;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: SHomeV2Colors.subQuoteBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SHomeV2Colors.subQuoteBorder, width: 0.5),
      ),
      child: RichText(
        text: TextSpan(
          style: SHomeV2Text.quote(),
          children: [
            if (category.quotePrefix.isNotEmpty)
              TextSpan(text: category.quotePrefix),
            TextSpan(
              text: category.quoteEmphasis,
              style: SHomeV2Text.quote(color: SHomeV2Colors.glow).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: '${category.quoteMiddle}\n'),
            TextSpan(text: category.quoteSuffix),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.option, required this.onTap});
  final SHomeV2Option option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SHomeV2Colors.subOptBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: SHomeV2Colors.subOptBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SHomeV2Colors.subGlyphBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option.glyph,
                  style: option.glyphIsLatin
                      ? GoogleFontsInterFallback.mono
                      : SHomeV2Text.optGlyph(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title, style: SHomeV2Text.optTitle()),
                    const SizedBox(height: 3),
                    Text(option.sub, style: SHomeV2Text.optSub()),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0x59FAF9F9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 라틴 glyph(예: '1장', '3장')는 Noto Serif KR 대신 Inter 600 13px로
/// 렌더링한다(README saju.html style 인라인 지정과 동일).
class GoogleFontsInterFallback {
  static const TextStyle mono = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: SHomeV2Colors.glow,
  );
}

/// 서브 화면 하단 고정 CTA 버튼(README `.cta-wrap` — absolute bottom:32).
class SintongSubScreenCta extends StatelessWidget {
  const SintongSubScreenCta({super.key, required this.category});
  final SHomeV2Category category;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 32,
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: () => openSubCta(context, category),
          style: ElevatedButton.styleFrom(
            backgroundColor: SHomeV2Colors.ctaBg,
            foregroundColor: SHomeV2Colors.ctaFg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SHomeV2Radii.pill),
            ),
          ),
          child: Text(category.ctaLabel, style: SHomeV2Text.cta()),
        ),
      ),
    );
  }
}
