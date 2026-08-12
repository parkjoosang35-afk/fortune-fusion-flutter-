import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_counsel_provider.dart';
import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart';
import '../theme/wish_counsel_text_styles.dart';
import '../widgets/wish_counsel_avatar.dart';
import 'wish_counsel_character_list_screen.dart';

/// HOME — `mc-screen-home.jsx` 이식.
/// 인사말+날짜, 3개 카테고리 히어로카드, "오늘 잘 통할 사람들"(가로스크롤),
/// "오늘의 화두" 칩까지 구현. 하단 내비게이션은 앱 전역 5탭 셀을 그대로
/// 쓰므로 이 화면에는 별도 BottomNav를 두지 않는다(모달/스택 진입 화면).
class WishCounselHomeScreen extends StatefulWidget {
  const WishCounselHomeScreen({super.key});

  @override
  State<WishCounselHomeScreen> createState() => _WishCounselHomeScreenState();
}

class _WishCounselHomeScreenState extends State<WishCounselHomeScreen> {
  static const List<Map<String, String>> _todayTopics = [
    {'label': '오늘의 인간관계'},
    {'label': '이번주 결정'},
    {'label': '마음 정리'},
    {'label': '내일의 시작'},
  ];

  void _openCategory(BuildContext context, CounselCategory cat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WishCounselCharacterListScreen(category: cat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WishCounselProvider>();
    final now = DateTime.now();
    final dateStr =
        '${now.year} · ${now.month.toString().padLeft(2, '0')} · ${now.day.toString().padLeft(2, '0')}';

    // "오늘 잘 통할 사람들" — 임의로 카테고리별 대표 1명씩 노출.
    final featured = [
      provider.byCategory(CounselCategory.counsel).first,
      provider.byCategory(CounselCategory.tarot).first,
    ];

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
          'MIDNIGHT COMFORT',
          style: WishCounselText.monoLabel(),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(dateStr, style: WishCounselText.monoLabel()),
            const SizedBox(height: 10),
            Text('오늘 어떤 마음이\n가장 무겁나요', style: WishCounselText.display1()),
            const SizedBox(height: 8),
            Text(
              '천천히 골라도 돼요. 밤은 길어요.',
              style: WishCounselText.bodySmall(),
            ),
            const SizedBox(height: 20),
            ..._categoryCards(context),
            const SizedBox(height: 28),
            Text('오늘 잘 통할 사람들', style: WishCounselText.heading()),
            const SizedBox(height: 12),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _FeaturedCard(
                  character: featured[i],
                  onTap: () => _openCategory(context, featured[i].category),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('오늘의 화두', style: WishCounselText.heading()),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _todayTopics
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: WishCounselColors.card,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: WishCounselColors.line),
                      ),
                      child: Text(
                        t['label']!,
                        style: WishCounselText.caption(),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _categoryCards(BuildContext context) {
    const cats = [
      CounselCategory.saju,
      CounselCategory.tarot,
      CounselCategory.counsel,
    ];
    return cats.map((cat) {
      final t = WishCounselColors.of(cat);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () => _openCategory(context, cat),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [t.bg1, t.bg2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: t.glow.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.soft,
                    border: Border.all(color: t.glow, width: 1.4),
                  ),
                  child: Text(
                    t.hanja,
                    style: TextStyle(
                      fontFamily: WishCounselText.display,
                      fontSize: 20,
                      color: t.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(t.label, style: WishCounselText.title()),
                          const SizedBox(width: 6),
                          Text(
                            '· 3명',
                            style: WishCounselText.caption(color: t.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(t.desc, style: WishCounselText.bodySmall()),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: t.glow),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.character, required this.onTap});

  final CounselCharacter character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = character.theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WishCounselColors.card2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: WishCounselColors.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WishCounselAvatar(character: character, size: 48, online: true),
            const SizedBox(height: 10),
            Text(
              character.name,
              style: WishCounselText.uiLabel(size: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              character.role,
              style: WishCounselText.caption(color: t.accent),
            ),
            const Spacer(),
            Text(
              '★ ${character.rating}',
              style: WishCounselText.caption(),
            ),
          ],
        ),
      ),
    );
  }
}
