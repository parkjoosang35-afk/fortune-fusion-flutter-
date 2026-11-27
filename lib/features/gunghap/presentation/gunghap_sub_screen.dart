// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_sub_screen.dart
// [궁합지도 Star Map 디자인 적용] gh-screens-a.jsx ScreenSub
// (03 세부 카테고리) 포팅본.
//
// [v4 핸드오프 반영 — S09] 00_DEV_MAPPING.md §5 S09 명세 기준 재작성:
// 기존 텍스트 전용 카드(번호+텍스트+체크원)를 2열 그리드
// (이미지 4:5 + 체크원 + 흰 정보칸) 구조로 전면 교체.
// 세부 수 홀수면 마지막 카드는 2열 전체 폭 + 1:1 이미지로 특수 처리.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../../core/router/main_bottom_nav_bar.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/cat_icon.dart';
import '../domain/gunghap_data.dart';
import 'gunghap_direct_input_screen.dart';
import 'gunghap_invite_screen.dart';

class GunghapSubScreen extends StatefulWidget {
  const GunghapSubScreen({super.key, required this.method, required this.majorId});
  final String method;
  final String majorId;

  @override
  State<GunghapSubScreen> createState() => _GunghapSubScreenState();
}

class _GunghapSubScreenState extends State<GunghapSubScreen> {
  late String _majorId = widget.majorId;
  String? _selectedSub;

  @override
  Widget build(BuildContext context) {
    final major = ghMajorById(_majorId);
    final subs = ghSubs[_majorId] ?? const [];
    return GHScreen(
      // [하단바 누락 수정] 기존 공용 하단바 재사용(currentIndex: 0=홈).
      // GHScreen의 _Footer가 hasNav 여부로 CTA와 하단바 사이 패딩을
      // 자동 조정하므로 겹침 없이 함께 표시된다.
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(title: major.name, onBack: () => Navigator.of(context).pop()),
      footer: GHButton(
        label: _selectedSub != null ? '$_selectedSub으로 진행' : '세부 궁합을 선택해 주세요',
        onPressed: _selectedSub == null
            ? null
            // [궁합지도 Phase 4 §2] method == 'direct'일 때만 신규 직접
            // 입력 화면으로 분기한다. method == 'invite'는 기존
            // GunghapInviteScreen 경로를 그대로 유지해 기존 초대장 기능을
            // 전혀 건드리지 않는다(회귀 방지).
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => widget.method == 'direct'
                      ? GunghapDirectInputScreen(
                          majorId: _majorId,
                          subName: _selectedSub,
                        )
                      : GunghapInviteScreen(
                          method: widget.method,
                          majorId: _majorId,
                          subName: _selectedSub,
                        ),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GHSteps(step: 1),
          // major switcher chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ghMajors.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final m = ghMajors[i];
                return GHChip(
                  label: m.name,
                  active: m.id == _majorId,
                  onTap: () => setState(() {
                    _majorId = m.id;
                    _selectedSub = null;
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: GHColors.gold.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: GHColors.divider),
                ),
                alignment: Alignment.center,
                child: CatIcon(kind: major.icon, size: 40, active: true),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GHMono('${major.hanja} · ${subs.length} TYPES', color: GHColors.gold),
                    const SizedBox(height: 6),
                    Text('세부 궁합을 골라 주세요', style: GHText.display(size: 21)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // [v4 S09] 2열 그리드 + 세부 수 홀수면 마지막 카드만 전체 폭.
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final colWidth = (constraints.maxWidth - gap) / 2;
              final isOdd = subs.length.isOdd;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final (i, s) in subs.indexed)
                    SizedBox(
                      width: (isOdd && i == subs.length - 1) ? constraints.maxWidth : colWidth,
                      child: _SubCard(
                        majorId: _majorId,
                        sub: s,
                        fullWidth: isOdd && i == subs.length - 1,
                        selected: _selectedSub == s.name,
                        onTap: () => setState(() => _selectedSub = s.name),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GHColors.lineSoft, style: BorderStyle.solid),
            ),
            child: Text(
              '세부 궁합은 계속 늘어나요. 원하는 분야가 없다면 가장 가까운 항목을 골라 주세요.',
              style: GHText.ui(size: 12, height: 1.5, color: GHColors.gray),
            ),
          ),
        ],
      ),
    );
  }
}

/// [v4 핸드오프 S09] 2열 카드: 상단 이미지(4:5, 홀수 마지막 카드는 1:1)
/// + 우상 체크원 + 하단 흰 정보칸(이름/설명).
/// 선택 시 2px accent + 3px 핑크18% 링 + translateY -2 + 이미지 scale 1.06.
class _SubCard extends StatefulWidget {
  const _SubCard({
    required this.majorId,
    required this.sub,
    required this.fullWidth,
    required this.selected,
    required this.onTap,
  });
  final String majorId;
  final GHSub sub;
  final bool fullWidth;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SubCard> createState() => _SubCardState();
}

class _SubCardState extends State<_SubCard> {
  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: GHColors.card,
          borderRadius: BorderRadius.circular(GHRadius.imageCard),
          border: Border.all(
            color: selected ? GHColors.accent : GHColors.lineSoft,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: GHColors.accent.withValues(alpha: .18),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                  ...GHShadow.imageCard,
                ]
              : GHShadow.imageCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: widget.fullWidth ? 1 : 4 / 5,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOut,
                    scale: selected ? 1.06 : 1.0,
                    child: Image.asset(
                      ghArtSub(widget.majorId, widget.sub.name),
                      fit: BoxFit.cover,
                      alignment: Alignment(0, ghArtAlign(widget.majorId, widget.sub.name)),
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: GHColors.bg2.withValues(alpha: .7),
                        child: const Center(child: Icon(Icons.image_outlined, color: GHColors.gray)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? GHColors.accent : Colors.white.withValues(alpha: .35),
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
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 11, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.sub.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GHText.cardTitle(size: 14.5, color: selected ? GHColors.accent : GHColors.ivory),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.sub.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GHText.ui(size: 11.5, height: 1.4, color: GHColors.gray),
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
