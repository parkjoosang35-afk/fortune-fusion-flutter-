import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_sigil_ring.dart';
import '../widgets/guinji_ui_kit.dart';
import 'guinji_node_sheet.dart';

/// M · My Map — `/guinji-map/m`
///
/// [design_handoff_guinji_web/Guinji Section.html] 1546~1655줄 마크업을
/// 재현한다. 중앙 `我`(나) 노드 + 4개 점선 orbit(100/170/240/300px) +
/// [people] 각 인원을 궤도 위 노드로 표시(회전 sigil 90s, opacity 0.35) +
/// 필터 칩 + 지인초대 FAB. 노드 탭 시 [onNodeTap]으로 N(Node Sheet)을
/// 바텀시트로 띄운다(상위 라우팅에서 처리).
///
/// [귀인지도 실구현] 원래 HTML 목데이터는 11개 노드에 고정 % 좌표를
/// 하드코딩했지만(정확히 11종 관계유형 각 1명), 실제 [GuinjiProvider.people]은
/// 인원 수·관계유형 분포가 매번 다르므로 고정 좌표를 쓸 수 없다. 대신
/// [_layoutPeople]이 인원 수에 맞춰 궤도(ring)와 각도를 절차적으로
/// 계산한다 — 궤도당 최대 6명, 넘치면 다음 궤도로 넘어간다.
class GuinjiMapResultScreen extends StatefulWidget {
  const GuinjiMapResultScreen({
    super.key,
    this.ownerName = '나',
    this.people = const [],
    this.onNodeTap,
    this.onInvite,
    this.onOpenFriends,
  });

  static const routeName = '/guinji-map/m';

  final String ownerName;

  /// 실제 참여자 목록(`GuinjiProvider.people`에서 전달). 비어 있으면
  /// "아직 참여한 귀인이 없어요" 안내를 보여준다.
  final List<GuinjiPerson> people;

  /// 노드 탭 콜백 — 탭한 [GuinjiPerson]을 전달한다.
  final void Function(GuinjiPerson person)? onNodeTap;

  /// 지인초대 FAB 탭 콜백 — 기본값은 S(Share) 화면으로 push.
  final VoidCallback? onInvite;

  /// 상단 `⋯` 탭 콜백 — 기본값은 F(Friend List) 화면으로 push.
  final VoidCallback? onOpenFriends;

  @override
  State<GuinjiMapResultScreen> createState() => _GuinjiMapResultScreenState();
}

class _GuinjiMapResultScreenState extends State<GuinjiMapResultScreen> {
  int _filterIndex = 0;
  static const _filters = ['전체', '貴 귀인', '조력자', '인연', '랭킹'];

  /// 노드 탭 시 기본 동작: 상위에서 [GuinjiMapResultScreen.onNodeTap]을
  /// 지정하지 않았다면, 여기서 [GuinjiNodeSheet]을 [person]의 실제 데이터로
  /// 띄운다. "공유하기"는 바텀시트를 닫고 곧바로 S(Share) 화면으로 이동한다.
  void _handleNodeTap(GuinjiPerson person) {
    if (widget.onNodeTap != null) {
      widget.onNodeTap!(person);
      return;
    }
    final meta = guinjiRelationTypes[person.relation];
    final ohaengMeta = guinjiOhaengTypes[person.ohaeng];
    showGuinjiNodeSheet(
      context: context,
      name: person.name,
      birthLabel: person.birth,
      relationKey: person.relation,
      score: person.score,
      narratorText:
          '${person.name}님은 ${meta?.description ?? "특별한 인연"}. 곁에 두면 결이 자연스레 풀리는 관계예요.',
      evidenceRows: [
        ('오행', '${ohaengMeta?.label ?? ''} ${ohaengMeta?.name ?? ''}'.trim()),
        if (person.note.isNotEmpty) ('판정 근거', person.note),
      ],
      onShare: () {
        Navigator.of(context).maybePop();
        Navigator.of(context).pushNamed('/guinji-map/m/share');
      },
      onSeeMore: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.people.length;
    final guiCount =
        widget.people.where((p) => p.relation == 'CHEON_GWII').length;
    final headerText =
        total == 0 ? '아직 참여한 귀인이 없어요' : '貴 $guiCount명 · 총 $total명';

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.2),
        bgOpacity: 0.12,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GuinjiTopBar(
                  breadcrumb: 'M · MY GUINJI',
                  onBack: () => Navigator.of(context).maybePop(),
                  trailing: GuinjiIconButton(
                    icon: '⋯',
                    onPressed: widget.onOpenFriends ??
                        () => Navigator.of(context)
                            .pushNamed('/guinji-map/m/friends'),
                  ),
                ),
                Center(
                  child: Column(
                    children: [
                      Text(
                        headerText,
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.mono,
                          fontSize: 9,
                          letterSpacing: 2,
                          color: GuinjiColors.lavender,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.ownerName}의 귀인지도',
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.display,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: GuinjiColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth < constraints.maxHeight
                          ? constraints.maxWidth
                          : constraints.maxHeight;
                      return Center(
                        child: SizedBox(
                          width: side,
                          height: side,
                          child: _MapCanvas(
                            side: side,
                            people: widget.people,
                            onNodeTap: _handleNodeTap,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) => GuinjiChip(
                      label: _filters[i],
                      active: _filterIndex == i,
                      onTap: () => setState(() => _filterIndex = i),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
            Positioned(
              bottom: 8,
              right: 0,
              child: _Fab(
                onPressed: widget.onInvite ??
                    () => Navigator.of(context)
                        .pushNamed('/guinji-map/m/share'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [person]에 계산된 화면 좌표(0~1 비율)를 더한 배치 결과.
class _PositionedPerson {
  const _PositionedPerson({
    required this.person,
    required this.left,
    required this.top,
  });

  final GuinjiPerson person;
  final double left; // 0~1
  final double top; // 0~1
}

/// [people]을 궤도(ring)별로 절차적으로 배치한다. 궤도당 최대 6명이며,
/// 넘치면 다음(더 바깥) 궤도로 넘어간다. 각 궤도 안에서는 정각도로
/// 균등 분배해 원 위에 배치한다(12시 방향부터 시계방향).
List<_PositionedPerson> _layoutPeople(List<GuinjiPerson> people) {
  if (people.isEmpty) return const [];
  const perRing = 6;
  const ringRatios = [100 / 300, 170 / 300, 240 / 300, 300 / 300];

  final result = <_PositionedPerson>[];
  for (var i = 0; i < people.length; i++) {
    final ringIndex = math.min(i ~/ perRing, ringRatios.length - 1);
    final ringStart = ringIndex * perRing;
    final countInRing = math.min(perRing, people.length - ringStart);
    final indexInRing = i - ringStart;
    final angle =
        (2 * math.pi * indexInRing / countInRing) - (math.pi / 2);
    final ratio = ringRatios[ringIndex];
    final left = 0.5 + 0.5 * ratio * math.cos(angle);
    final top = 0.5 + 0.5 * ratio * math.sin(angle);
    result.add(_PositionedPerson(person: people[i], left: left, top: top));
  }
  return result;
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.side,
    required this.people,
    this.onNodeTap,
  });

  final double side;
  final List<GuinjiPerson> people;
  final void Function(GuinjiPerson person)? onNodeTap;

  static const _orbitRatios = [100 / 300, 170 / 300, 240 / 300, 300 / 300];

  @override
  Widget build(BuildContext context) {
    final positioned = _layoutPeople(people);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        gradient: RadialGradient(
          radius: 0.9,
          colors: [
            GuinjiColors.lavender.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 90s 회전 sigil (opacity 0.35)
          Opacity(
            opacity: 0.35,
            child: GuinjiSigilRing(
              size: side * 0.68,
              color: GuinjiColors.lavender,
              opacity: 0.6,
              duration: const Duration(seconds: 90),
            ),
          ),
          // 4개 점선 orbit
          for (final ratio in _orbitRatios)
            Container(
              width: side * ratio,
              height: side * ratio,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: GuinjiColors.lavender.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
          // 중앙 我
          Container(
            width: side * 0.15,
            height: side * 0.15,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.4),
                colors: [
                  GuinjiColors.lavender,
                  GuinjiColors.lavender.withValues(alpha: 0.6),
                ],
              ),
              border: Border.all(color: GuinjiColors.lavender, width: 2),
              boxShadow: [
                BoxShadow(color: GuinjiColors.glowShadow, blurRadius: 30),
              ],
            ),
            child: Text(
              '我',
              style: TextStyle(
                fontFamily: GuinjiFonts.display,
                fontSize: side * 0.06,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2A1A3A),
              ),
            ),
          ),
          // 실제 참여자 노드
          for (final p in positioned)
            Positioned(
              left: p.left * side - side * 0.05,
              top: p.top * side - side * 0.05,
              child: _MapNode(side: side, person: p.person, onTap: onNodeTap),
            ),
          // 빈 상태 안내
          if (people.isEmpty)
            Positioned(
              bottom: side * 0.06,
              child: Text(
                '지인을 초대하면 여기에 표시돼요',
                style: TextStyle(
                  fontFamily: GuinjiFonts.body,
                  fontSize: side * 0.032,
                  color: GuinjiColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  const _MapNode({required this.side, required this.person, this.onTap});

  final double side;
  final GuinjiPerson person;
  final void Function(GuinjiPerson person)? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[person.relation];
    final color = meta?.color ?? GuinjiColors.lavender;
    final hanja = meta?.hanja ?? '?';
    final nodeSize = side * 0.10;
    return GestureDetector(
      onTap: () => onTap?.call(person),
      child: Column(
        children: [
          Container(
            width: nodeSize,
            height: nodeSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.22),
              border: Border.all(color: color, width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
              ],
            ),
            child: Text(
              hanja,
              style: TextStyle(
                fontFamily: GuinjiFonts.display,
                fontSize: nodeSize * 0.4,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            person.name,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontSize: 9,
              color: GuinjiColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.gold,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: GuinjiColors.gold.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2A1A08),
                ),
              ),
              SizedBox(width: 6),
              Text(
                '지인 초대',
                style: TextStyle(
                  fontFamily: GuinjiFonts.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2A1A08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
