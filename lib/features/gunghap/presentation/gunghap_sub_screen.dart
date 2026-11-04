// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_sub_screen.dart
// [궁합지도 Star Map 디자인 적용] gh-screens-a.jsx ScreenSub
// (03 세부 카테고리) 포팅본.
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
          for (final (i, s) in subs.indexed) ...[
            _SubCard(
              index: i,
              sub: s,
              selected: _selectedSub == s.name,
              onTap: () => setState(() => _selectedSub = s.name),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
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

class _SubCard extends StatelessWidget {
  const _SubCard({
    required this.index,
    required this.sub,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final GHSub sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GHCard(
    onTap: onTap,
    selected: selected,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    borderRadius: GHRadius.cardSm,
    minHeight: 72,
    child: Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            (index + 1).toString().padLeft(2, '0'),
            style: GHText.mono(size: 10, color: selected ? GHColors.gold : GHColors.gray),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sub.name,
                style: GHText.cardTitle(size: 15.5, color: selected ? GHColors.gold : GHColors.ivory),
              ),
              const SizedBox(height: 4),
              Text(
                sub.desc,
                style: GHText.ui(size: 12.5, height: 1.45, color: GHColors.gray),
              ),
            ],
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? GHColors.gold : GHColors.gray.withValues(alpha: .35),
            ),
          ),
          alignment: Alignment.center,
          child: selected
              ? Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GHColors.gold,
                    boxShadow: [BoxShadow(color: GHColors.glowShadow, blurRadius: 8)],
                  ),
                )
              : null,
        ),
      ],
    ),
  );
}
