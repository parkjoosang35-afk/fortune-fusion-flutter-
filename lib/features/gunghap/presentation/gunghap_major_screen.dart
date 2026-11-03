// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_major_screen.dart
// [궁합지도 Star Map 디자인 적용] gh-screens-a.jsx ScreenMajor
// (02 대분류 선택) 포팅본.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
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
            childAspectRatio: 150 / 156,
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

class _MajorCard extends StatelessWidget {
  const _MajorCard({required this.major, required this.selected, required this.onTap});
  final GHMajor major;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GHCard(
    onTap: onTap,
    selected: selected,
    padding: const EdgeInsets.all(14),
    borderRadius: GHRadius.card,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: selected
                    ? GHColors.gold.withValues(alpha: .12)
                    : GHColors.bg2.withValues(alpha: .6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? GHColors.gold.withValues(alpha: .5) : GHColors.lineSoft,
                ),
              ),
              alignment: Alignment.center,
              child: CatIcon(kind: major.icon, size: 36, active: selected),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GHColors.gold : Colors.transparent,
                border: Border.all(
                  color: selected ? GHColors.gold : GHColors.gray.withValues(alpha: .35),
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Text('✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GHColors.ink))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          major.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GHText.cardTitle(size: 15.5, color: selected ? GHColors.gold : GHColors.ivory),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Text(
            major.desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GHText.ui(size: 12, height: 1.5, color: GHColors.gray),
          ),
        ),
      ],
    ),
  );
}
