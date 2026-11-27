import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/main_bottom_nav_bar.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/shrine_v3_provider.dart';
import '../../domain/shrine_categories.dart';
import '../../domain/talisman_item.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/serena_intro_sheet.dart';
import '../widgets/shrine_asset_path.dart';
import '../widgets/talisman_thumb.dart';
import 'shrine_v3_box_screen.dart';
import 'shrine_v3_detail_screen.dart';
import 'shrine_v3_pick_screen.dart';
import 'shrine_v3_rec_screen.dart';

/// 신당(THE SHRINE) v3 — 03 메인 화면. 민세레나 인사말 + 推(추천받기)/
/// 擇(직접 고르기) 2버튼 + 부적 종류 미리보기(첫 카테고리 7종).
class ShrineV3MainScreen extends StatefulWidget {
  const ShrineV3MainScreen({super.key});

  @override
  State<ShrineV3MainScreen> createState() => _ShrineV3MainScreenState();
}

class _ShrineV3MainScreenState extends State<ShrineV3MainScreen> {
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ShrineV3Provider>();
      if (provider.catalog.isEmpty) provider.loadCatalog();
    });
  }

  void _openDetail(TalismanItem k) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShrineV3DetailScreen(talismanId: k.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineV3Provider>();
    final nickname =
        context.watch<AuthProvider>().currentUser?.nickname ?? '손님';
    final catalog = provider.catalog;
    final category = kShrineCategoryOrder[_filterIndex];
    final preview = catalog
        .where((k) => k.category == category)
        .take(7)
        .toList();

    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      // [사용자 버그 리포트 — 디자인 핸드오프 불일치 #1] 03 메인은
      // 프로토타입 <Nav/> 포함 화면이다 — MainBottomNavBar(신당부적=1번
      // 인덱스, app_shell.dart `_shrineNavIndex`와 동일한 의미)를 달아준다.
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 1),
      body: SafeArea(
        child: provider.isLoading && catalog.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _HelloCard(nickname: nickname),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _BigButton(
                          hanja: '推',
                          label: '추천받기',
                          desc: '사주와 소망으로\n골라 드려요',
                          color: ShrineV3Colors.seal,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ShrineV3RecScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BigButton(
                          hanja: '擇',
                          label: '직접 고르기',
                          desc: '원하는 부적을\n바로 써요',
                          color: ShrineV3Colors.ink2,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ShrineV3PickScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '부적 종류 ${catalog.length}',
                        style: ShrineV3TextStyles.body.copyWith(fontSize: 16),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ShrineV3PickScreen(),
                          ),
                        ),
                        child: const Text('전체 ›'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kShrineCategoryOrder.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final cat = kShrineCategoryOrder[i];
                        final on = i == _filterIndex;
                        return ChoiceChip(
                          label: Text(kShrineCategoryLabels[cat] ?? cat),
                          selected: on,
                          onSelected: (_) => setState(() => _filterIndex = i),
                          labelStyle: ShrineV3TextStyles.ui.copyWith(
                            fontSize: 12,
                            color: on
                                ? ShrineV3Colors.paper
                                : ShrineV3Colors.ink2,
                          ),
                          selectedColor: ShrineV3Colors.ink,
                          backgroundColor: ShrineV3Colors.card,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  // [부적 종류 배치 수정] 프로토타입(신당 v3.html)의
                  // `KindsMain`/`.kinds`/`.kd` 컴포넌트는 가로 스크롤이
                  // 아니라 4열 그리드이며, 각 칸은 카테고리별 틴트 배경
                  // (`--kb`) 위에 실제 부적 이미지(44×92, `PH`)를 올린다.
                  // 기존 `TalismanThumb` 이미지 위젯은 그대로 쓰고
                  // 레이아웃만 가로 스크롤 → 4열 그리드로 교체한다.
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // [사용자 버그 리포트 — 디자인 핸드오프 신규 요청 #3]
                    // "황재부 옆에 내 부적함을 넣어줘 이쁘게 박스 넣어서"
                    // (2번째 첨부 이미지 참고 — 재물 7종 미리보기 뒤 빈
                    // 8번째 칸). 원본 프로토타입(신당 v3.html)에는 이
                    // 타일이 없었다 — 이번에 신규로 추가하는 UI다. 미리보기
                    // 목록 맨 끝에 '내 부적함' 숏컷 타일을 1개 덧붙여 09
                    // 부적함으로 바로 이동하게 한다(결제 게이트를 우회하지
                    // 않음 — README §2 "07로 가는 길은 결제 게이트뿐" 규칙은
                    // 그대로 유지, 이 타일은 09만 연다).
                    itemCount: preview.length + 1,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.62,
                        ),
                    itemBuilder: (context, i) {
                      if (i == preview.length) {
                        return _MyBoxTile(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ShrineV3BoxScreen(),
                            ),
                          ),
                        );
                      }
                      final k = preview[i];
                      final tint =
                          kShrineCategoryTints[k.category] ??
                          ShrineV3Colors.paperDark;
                      return GestureDetector(
                        onTap: () => _openDetail(k),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: tint.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: TalismanThumb(
                                  talisman: k,
                                  width: 44,
                                  height: 92,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              k.name.length > 5
                                  ? k.name.substring(0, 4)
                                  : k.name,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

/// [사용자 버그 리포트 — 디자인 핸드오프 신규 요청 #3] "내 부적함" 숏컷
/// 타일. "이쁘게 박스 넣어서"라는 요청에 맞춰 일반 부적 타일(종이질감
/// 틴트 배경 + 부적 이미지)과는 다른, 금빛 테두리 + 그라데이션의 카드형
/// 박스로 시각적으로 구분한다. 색은 README §9 디자인 토큰(gold/goldDeep)
/// 그대로 사용해 기존 팔레트와 어긋나지 않게 한다.
class _MyBoxTile extends StatelessWidget {
  const _MyBoxTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ShrineV3Colors.gold.withValues(alpha: 0.35),
                    ShrineV3Colors.goldDeep.withValues(alpha: 0.22),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ShrineV3Colors.goldDeep,
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: ShrineV3Colors.ink2,
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '囊',
                    style: ShrineV3TextStyles.title.copyWith(
                      fontSize: 16,
                      color: ShrineV3Colors.ink2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '내 부적함',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ShrineV3Colors.goldDeep,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HelloCard extends StatelessWidget {
  const _HelloCard({required this.nickname});
  final String nickname;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShrineV3Colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShrineV3Colors.line),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ClipOval(
                child: Image.asset(
                  shrineSceneImage('talk'),
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 52,
                    height: 52,
                    color: ShrineV3Colors.paperDark,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: () => showShrineSerenaIntroSheet(context),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: ShrineV3Colors.seal,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '閔',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '민세레나',
                      style: ShrineV3TextStyles.ui.copyWith(fontSize: 12),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => showShrineSerenaIntroSheet(context),
                      child: const Text('소개 ›', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                Text(
                  '$nickname님, 오늘은 어떤 소망을\n담아 드릴까요?',
                  style: ShrineV3TextStyles.body.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.hanja,
    required this.label,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  final String hanja;
  final String label;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              top: -10,
              child: Text(
                hanja,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
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
