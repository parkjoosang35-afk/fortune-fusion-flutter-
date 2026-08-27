import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../../wish_room/widgets/wish_room_sigil.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import '../widgets/guinji_orbit_map.dart';
import 'guinji_relation_detail_screen.dart';

/// 귀인지도(Guinji Map) — 05. 지도 메인 화면.
///
/// [Phase G-3] `GUINJI_SCREENS.md` "05 · 지도 메인" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `MapScreen` + `GuinjiComponents.jsx` → `OrbitMap`).
/// 지인들이 나 중심 동심원 궤도에 관계 유형별로 배치된 코어 화면이다.
///
/// [Phase G-3 범위] 아직 백엔드 API(§5 신규 테이블 5개)가 없으므로
/// [guinjiSamplePeople] 목데이터로 렌더링한다. 관계상세(S6) 이동·랭킹(S7)·
/// 공유(S8)·지인초대(S9)는 이 Phase에서 화면 뼈대만 라우팅하거나 토스트로
/// 대체한다.
class GuinjiMapScreen extends StatefulWidget {
  const GuinjiMapScreen({super.key, this.people = guinjiSamplePeople});

  final List<GuinjiPerson> people;

  @override
  State<GuinjiMapScreen> createState() => _GuinjiMapScreenState();
}

class _GuinjiMapScreenState extends State<GuinjiMapScreen> {
  String _filter = 'all';

  List<GuinjiPerson> get _filtered {
    if (_filter == 'all') return widget.people;
    return widget.people.where((p) => p.relation == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final guinCount = widget.people.where((p) => p.relation == 'guin').length;

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const _MonoLabel('MY GUINJI · N°01'),
                      _IconButton(
                        icon: Icons.ios_share,
                        onPressed: () =>
                            AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _MonoLabel(
                    '귀인 $guinCount명 · 총 ${widget.people.length}명',
                    color: GuinjiColors.lavender,
                    fontSize: 9,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '지민의 귀인지도',
                    style: TextStyle(
                      fontFamily: GuinjiFonts.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.4,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const WishRoomSigilRing(
                                size: 210,
                                color: GuinjiColors.lavender,
                                opacity: 0.35,
                              ),
                              GuinjiOrbitMap(
                                people: _filtered,
                                size: 300,
                                onSelect: (p) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          GuinjiRelationDetailScreen(person: p),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 4,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              _CornerLegend(
                                lines: ['← INNER · 貴', 'OUTER → 師'],
                                align: TextAlign.left,
                              ),
                              _CornerLegend(
                                lines: ['2026 · 08 · 26', '火'],
                                align: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: '전체 · ${widget.people.length}',
                          active: _filter == 'all',
                          color: GuinjiColors.lavender,
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        for (final key in guinjiRelationOrder) ...[
                          _FilterChip(
                            label:
                                '${guinjiRelationTypes[key]!.hanja} '
                                '${guinjiRelationTypes[key]!.label} · '
                                '${widget.people.where((p) => p.relation == key).length}',
                            active: _filter == key,
                            color: guinjiRelationTypes[key]!.color,
                            onTap: () => setState(() => _filter = key),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GhostActionButton(
                          label: '✧ 랭킹 보기',
                          onPressed: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PrimaryActionButton(
                          label: '+ 지인 초대하기',
                          onPressed: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.color, this.fontSize = 10});

  final String text;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: fontSize,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: color ?? GuinjiColors.textSecondary,
      ),
    );
  }
}

class _CornerLegend extends StatelessWidget {
  const _CornerLegend({required this.lines, required this.align});

  final List<String> lines;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.left
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        for (final line in lines)
          Text(
            line,
            textAlign: align,
            style: const TextStyle(
              fontFamily: GuinjiFonts.mono,
              fontSize: 9,
              letterSpacing: 1.5,
              height: 1.3,
              color: GuinjiColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color : GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: active
                ? null
                : Border.all(color: GuinjiColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: GuinjiFonts.ui,
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: active ? GuinjiColors.ink : GuinjiColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostActionButton extends StatelessWidget {
  const _GhostActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: GuinjiColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.lavender,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: GuinjiColors.glowShadow, blurRadius: 16),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: GuinjiColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
