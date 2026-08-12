import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_counsel_provider.dart';
import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';
import '../widgets/wish_counsel_chip.dart';
import 'wish_counsel_character_detail_screen.dart';

/// CHARACTER LIST — `mc-screen-list.jsx` 이식.
/// 카테고리 인트로 배지+제목, 필터칩(전체/스타일태그 그룹), 캐릭터 카드 3개.
class WishCounselCharacterListScreen extends StatefulWidget {
  const WishCounselCharacterListScreen({super.key, required this.category});

  final CounselCategory category;

  @override
  State<WishCounselCharacterListScreen> createState() =>
      _WishCounselCharacterListScreenState();
}

class _WishCounselCharacterListScreenState
    extends State<WishCounselCharacterListScreen> {
  String _filter = '전체';

  @override
  Widget build(BuildContext context) {
    final t = WishCounselColors.of(widget.category);
    final provider = context.watch<WishCounselProvider>();
    final all = provider.byCategory(widget.category);
    final filters = ['전체', ...{for (final c in all) ...c.styleTags}.take(3)];
    final list = _filter == '전체'
        ? all
        : all.where((c) => c.styleTags.contains(_filter)).toList();

    return Scaffold(
      backgroundColor: WishCounselColors.bg1,
      appBar: AppBar(
        backgroundColor: WishCounselColors.bg1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WishCounselColors.fg),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          '${t.label.toUpperCase()} · ${t.hanja}',
          style: WishCounselText.monoLabel(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text('${t.desc}\n사람', style: WishCounselText.display2()),
            const SizedBox(height: 14),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = filters[i];
                  return WishCounselChip(
                    label: f,
                    active: _filter == f,
                    activeColor: t.soft,
                    activeGlow: t.glow,
                    onTap: () => setState(() => _filter = f),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ...list.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CharacterCard(
                  character: c,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          WishCounselCharacterDetailScreen(character: c),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, required this.onTap});

  final CounselCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = character.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: WishCounselColors.card2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WishCounselColors.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 3,
                    child: Image.asset(
                      character.avatarAsset,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.5),
                      errorBuilder: (_, __, ___) =>
                          Container(color: t.bg2),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            WishCounselColors.bg2.withValues(alpha: 0.95),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 10,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(character.name, style: WishCounselText.title()),
                        const SizedBox(width: 6),
                        Text(
                          character.nameSub,
                          style: WishCounselText.caption(color: t.accent),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0A0A12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 7,
                            color: Color(0xFF6FE3A0),
                          ),
                          const SizedBox(width: 4),
                          Text('ONLINE', style: WishCounselText.monoLabel()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: t.soft,
                      border: Border.all(
                        color: t.glow,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '"${character.sampleQuestions.first}"',
                      style: WishCounselText.bodySmall(color: t.accent),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: character.styleTags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WishCounselColors.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: WishCounselColors.line),
                            ),
                            child: Text(
                              tag,
                              style: WishCounselText.caption(),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '★ ${character.rating}',
                        style: WishCounselText.caption(color: t.accent),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '· ${character.sessions}회 상담',
                        style: WishCounselText.caption(),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [t.glow, t.accent],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '대화하기 →',
                          style: WishCounselText.uiLabel(
                            color: const Color(0xFF0A0A12),
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
