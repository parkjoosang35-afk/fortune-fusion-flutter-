// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_major_screen.dart
// [궁합지도 Star Map 디자인 적용] gh-screens-a.jsx ScreenMajor
// (02 대분류 선택) 포팅본.
//
// [v4 핸드오프 반영 — S08] 00_DEV_MAPPING.md §5 S08 명세 기준 재작성:
// 기존 텍스트 전용 카드(GHCard+50x50아이콘박스)를
// 정사각 이미지 cover + 그라데이션 + 좌상 흰배지 + 우상 체크원 +
// 하단 흰 텍스트(이름/설명) 구조로 전면 교체.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../../core/router/main_bottom_nav_bar.dart';
import '../theme/gh_tokens.dart';
import '../widgets/gh_screen.dart';
import '../widgets/cat_icon.dart';
import '../domain/gunghap_data.dart';
import 'gunghap_sub_screen.dart';

class GunghapMajorScreen extends StatefulWidget {
  const GunghapMajorScreen({
    super.key,
    required this.method,
    this.initialMajorId,
    this.skipToSub = false,
  });

  /// 'direct' | 'invite' — 홈 CTA 중 무엇을 눌렀는지.
  final String method;
  final String? initialMajorId;

  /// 홈 2열 카테고리 타일을 바로 눌렀을 때: 선택 애니메이션 없이
  /// 바로 03 화면으로 이동(gh-screens-a.jsx 대분류 타일 탭 동작).
  final bool skipToSub;

  @override
  State<GunghapMajorScreen> createState() => _GunghapMajorScreenState();
}

class _GunghapMajorScreenState extends State<GunghapMajorScreen> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialMajorId;
    if (widget.skipToSub && widget.initialMajorId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GunghapSubScreen(
              method: widget.method,
              majorId: widget.initialMajorId!,
            ),
          ),
        );
      });
    }
  }

  void _pick(String id) {
    setState(() => _selected = id);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GunghapSubScreen(method: widget.method, majorId: id),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.skipToSub) {
      // 전환 애니메이션 대기 중 — 빈 배경만 보여준다(깜빡임 방지).
      return const Scaffold(backgroundColor: GHColors.bg2, body: SizedBox.shrink());
    }
    return GHScreen(
      // [하단바 누락 수정] 기존 공용 하단바 재사용(currentIndex: 0=홈).
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(title: '궁합 분야 선택', onBack: () => Navigator.of(context).pop()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GHSteps(step: 1),
          const GHTitle(
            mono: 'STEP 01 · CATEGORY',
            title: '어떤 인연을\n살펴볼까요',
            sub: '두 사람의 관계에 가장 가까운 분야를 골라 주세요',
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 165 / 168,
            children: [
              for (final m in ghMajors)
                _MajorCard(
                  major: m,
                  selected: _selected == m.id,
                  onTap: () => _pick(m.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [v4 핸드오프 S08] 정사각 이미지 카드: 이미지 cover + 하단 그라데이션
/// + 좌상 흰 아이콘배지 + 우상 체크원 + 하단 흰 텍스트(이름/설명).
/// 선택 시 2px accent 보더 + 3px 핑크18% 링 + 그림자.
class _MajorCard extends StatelessWidget {
  const _MajorCard({required this.major, required this.selected, required this.onTap});
  final GHMajor major;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GHColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? GHColors.accent : Colors.transparent,
          width: 2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: GHColors.accent.withValues(alpha: .18),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
                ...GHShadow.card,
              ]
            : GHShadow.card,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            ghArtSquare(major.id),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(
              color: GHColors.bg2.withValues(alpha: .7),
              child: Center(child: CatIcon(kind: major.icon, size: 36, active: true)),
            ),
          ),
          // 하단 그라데이션(텍스트 가독성 확보).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF140C24).withValues(alpha: .72),
                ],
                stops: const [0.45, 1.0],
              ),
            ),
          ),
          // 좌상단 흰 아이콘 배지.
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: CatIcon(kind: major.icon, size: 28, active: true),
            ),
          ),
          // 우상단 체크원.
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GHColors.accent : Colors.white.withValues(alpha: .25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 0 : .7),
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Text(
                      '✓',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    )
                  : null,
            ),
          ),
          // 하단 텍스트.
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  major.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  major.desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: .88),
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
