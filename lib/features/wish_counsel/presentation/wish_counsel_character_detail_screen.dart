import 'package:flutter/material.dart';

import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';
import 'wish_counsel_chat_screen.dart';

/// DETAIL — `mc-screen-detail.jsx` 이식.
/// 전체화면 이미지 + 투명 NavBar, 헤더정보, 통계 3분할, 스타일태그,
/// 전문분야 2열 그리드, 샘플 질문 리스트, 하단 sticky CTA.
class WishCounselCharacterDetailScreen extends StatelessWidget {
  const WishCounselCharacterDetailScreen({super.key, required this.character});

  final CounselCharacter character;

  @override
  Widget build(BuildContext context) {
    final t = character.theme;
    return Scaffold(
      backgroundColor: WishCounselColors.bg1,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                backgroundColor: WishCounselColors.bg1,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _RoundIconBtn(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        character.avatarAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: t.bg2),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              WishCounselColors.bg1,
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.label.toUpperCase()} · ${character.role}',
                        style: WishCounselText.monoLabel(color: t.accent),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(character.name, style: WishCounselText.title()),
                          const SizedBox(width: 8),
                          Text(
                            character.nameSub,
                            style: WishCounselText.bodySmall(color: t.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(character.intro, style: WishCounselText.bodyText()),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _StatCol(
                            value: '★ ${character.rating}',
                            label: '평점',
                          ),
                          _StatCol(
                            value: _formatCount(character.sessions),
                            label: '누적 상담',
                          ),
                          const _StatCol(value: '98%', label: '재방문율'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: character.styleTags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: t.soft,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: t.glow),
                                ),
                                child: Text(
                                  tag,
                                  style: WishCounselText.caption(color: t.accent),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 22),
                      Text('전문 분야', style: WishCounselText.heading()),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.6,
                        children: character.specialties
                            .map(
                              (s) => Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: WishCounselColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: WishCounselColors.line),
                                ),
                                child: Text(
                                  s,
                                  style: WishCounselText.bodySmall(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 22),
                      Text('샘플 질문', style: WishCounselText.heading()),
                      const SizedBox(height: 10),
                      ...character.sampleQuestions.map(
                        (q) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WishCounselColors.card2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: WishCounselColors.line2),
                          ),
                          child: Text(
                            q,
                            style: WishCounselText.bodyText(size: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: WishCounselColors.bg1.withValues(alpha: 0.96),
                border: const Border(
                  top: BorderSide(color: WishCounselColors.line),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            WishCounselChatScreen(character: character),
                      ),
                    ),
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [t.glow, t.accent]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: t.shadow,
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Text(
                        '◈ 대화 시작하기',
                        style: WishCounselText.uiLabel(
                          color: const Color(0xFF0A0A12),
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '첫 5분 무료 · 이후 코인 1개/분',
                    style: WishCounselText.caption(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return '$n';
  }
}

class _RoundIconBtn extends StatelessWidget {
  const _RoundIconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WishCounselColors.card,
          border: Border.all(color: WishCounselColors.line),
        ),
        child: Icon(icon, color: WishCounselColors.fg, size: 18),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: WishCounselText.title()),
          const SizedBox(height: 2),
          Text(label, style: WishCounselText.caption()),
        ],
      ),
    );
  }
}
