// ═══════════════════════════════════════════════════════════════
// FILE: sintong_section_photo_card.dart
// [전체보기 6섹션 개편 — design_handoff_main_all_sections.zip]
// 기존 3열×2행(흰 라벨박스+사진) 그리드를 2열×3행 "사진이 카드 전체를
// 채우는" 포토 카드로 교체. 스펙 원본: design_files/sections-photo.css
// (가로1:세로0.82, 하단 블랙 그라데이션, 금빛 이중 테두리, 섹션명 +
// 원형 화살표 버튼). 설명 문구는 노출하지 않는다(README "사진 가독성
// 우선").
// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

/// 포토 카드 1장의 데이터 — 섹션명/이미지/버튼 틴트/탭 콜백.
class SHomeV2PhotoCard {
  const SHomeV2PhotoCard({
    required this.title,
    required this.asset,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String asset;
  final Color tint;
  final VoidCallback onTap;
}

/// 2열 그리드, gap 9px, 카드 비율 1:0.82 — README "레이아웃" 표 그대로.
class SintongSectionPhotoGrid extends StatelessWidget {
  const SintongSectionPhotoGrid({super.key, required this.cards});

  final List<SHomeV2PhotoCard> cards;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 1 / 0.82,
      ),
      itemBuilder: (context, i) => _SectionPhotoCard(
        card: cards[i],
        // README "등장" 인터랙션 — 카드별 0.1s 지연 fade+slide.
        delay: Duration(milliseconds: 100 * i),
      ),
    );
  }
}

class _SectionPhotoCard extends StatefulWidget {
  const _SectionPhotoCard({required this.card, required this.delay});

  final SHomeV2PhotoCard card;
  final Duration delay;

  @override
  State<_SectionPhotoCard> createState() => _SectionPhotoCardState();
}

class _SectionPhotoCardState extends State<_SectionPhotoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: card.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x66F5CF6A)),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                  const BoxShadow(color: Color(0x0AF5CF6A), blurRadius: 14),
                  if (_pressed)
                    BoxShadow(
                      color: card.tint.withValues(alpha: 0.35),
                      blurRadius: 24,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ① 사진 — 카드 전체 채움, cover, top center.
                    Container(
                      color: const Color(0xFF120A1E),
                      child: Image.asset(
                        card.asset,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    // ② 하단 그라데이션(README 스펙 stops 그대로).
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 0.70, 1.0],
                          colors: [
                            Color(0x000A0716),
                            Color(0x8C0A0716),
                            Color(0xEB0A0716),
                          ],
                        ),
                      ),
                    ),
                    // ④ 안쪽 테두리(inset 3px, radius 11).
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: const Color(0x24F5CF6A)),
                        ),
                      ),
                    ),
                    // ⑤ 섹션명.
                    Positioned(
                      left: 11,
                      right: 44,
                      bottom: 15,
                      child: Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'NotoSerifKR',
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          height: 1.1,
                          letterSpacing: -0.42,
                          color: Color(0xFFF8F2E6),
                          shadows: [
                            Shadow(
                              color: Color(0xD9000000),
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ⑥ 원형 화살표 버튼(장식 — 카드 전체가 터치 영역).
                    Positioned(
                      right: 9,
                      bottom: 9,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.4),
                            colors: [Colors.white, card.tint],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: card.tint.withValues(alpha: 0.55),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFF1A0D2E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
