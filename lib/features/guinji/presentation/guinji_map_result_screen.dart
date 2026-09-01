import 'package:flutter/material.dart';

import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_sigil_ring.dart';
import '../widgets/guinji_ui_kit.dart';
import 'guinji_node_sheet.dart';

/// M · My Map — `/guinji/m/:mapId`
///
/// [design_handoff_guinji_web/Guinji Section.html] 1546~1655줄 마크업을
/// 재현한다. 중앙 `我`(나) 노드 + 4개 점선 orbit(100/170/240/300px) +
/// 11개 관계 노드(고정 % 좌표, HTML 그대로) + 회전 sigil(90s, opacity 0.35)
/// + 필터 칩 + 지인초대 FAB. 노드 탭 시 [onNodeTap]으로 N(Node Sheet)을
/// 바텀시트로 띄운다(상위 라우팅에서 처리).
class GuinjiMapResultScreen extends StatefulWidget {
  const GuinjiMapResultScreen({
    super.key,
    this.ownerName = '지민',
    this.onNodeTap,
    this.onInvite,
  });

  static const routeName = '/guinji/m';

  final String ownerName;

  /// 노드 탭 콜백 — (name, relationKey)를 전달한다.
  final void Function(String name, String relationKey)? onNodeTap;
  final VoidCallback? onInvite;

  @override
  State<GuinjiMapResultScreen> createState() => _GuinjiMapResultScreenState();
}

/// HTML `.map-node` 11개의 고정 좌표(left%/top%)·관계키·이름을 그대로
/// 이식한 스펙.
class _MapNodeSpec {
  const _MapNodeSpec({
    required this.name,
    required this.relationKey,
    required this.left,
    required this.top,
  });

  final String name;
  final String relationKey;
  final double left; // 0~1
  final double top; // 0~1
}

const _mapNodes = [
  // Inner orbit
  _MapNodeSpec(name: '수아', relationKey: 'CHEON_GWII', left: 0.50, top: 0.32),
  _MapNodeSpec(name: '민서', relationKey: 'NA_SALRIDA', left: 0.70, top: 0.42),
  _MapNodeSpec(name: '유진', relationKey: 'JORYEOK', left: 0.62, top: 0.62),
  _MapNodeSpec(name: '도윤', relationKey: 'GACHI_BICH', left: 0.38, top: 0.62),
  _MapNodeSpec(name: '서연', relationKey: 'GAMJEONG', left: 0.30, top: 0.42),
  // Middle orbit
  _MapNodeSpec(name: '하늘', relationKey: 'KKEURIDA', left: 0.82, top: 0.30),
  _MapNodeSpec(name: '예린', relationKey: 'DEUNGDEUNG', left: 0.88, top: 0.65),
  _MapNodeSpec(name: '지호', relationKey: 'JAGEUKJE', left: 0.20, top: 0.78),
  _MapNodeSpec(name: '태오', relationKey: 'CHANG_GYIM', left: 0.15, top: 0.30),
  // Outer orbit
  _MapNodeSpec(name: '은채', relationKey: 'GINGJANG', left: 0.50, top: 0.12),
  _MapNodeSpec(name: '나연', relationKey: 'NA_SALJINDA', left: 0.50, top: 0.88),
];

class _GuinjiMapResultScreenState extends State<GuinjiMapResultScreen> {
  int _filterIndex = 0;
  static const _filters = ['전체', '貴 귀인', '조력자', '인연', '랭킹'];

  /// 노드 탭 시 기본 동작: 상위에서 [GuinjiMapResultScreen.onNodeTap]을
  /// 지정하지 않았다면, 여기서 [GuinjiNodeSheet]을 목데이터로 띄운다.
  /// 실제 API 연동(관계 상세 조회) 시 상위 라우팅에서 onNodeTap을 지정해
  /// 이 기본 동작을 오버라이드하면 된다.
  void _handleNodeTap(String name, String relationKey) {
    if (widget.onNodeTap != null) {
      widget.onNodeTap!(name, relationKey);
      return;
    }
    final meta = guinjiRelationTypes[relationKey];
    showGuinjiNodeSheet(
      context: context,
      name: name,
      birthLabel: '1998 · 05 · 14 · 火時',
      relationKey: relationKey,
      score: 80,
      narratorText:
          '$name님은 ${meta?.description ?? "특별한 인연"}. 곁에 두면 결이 자연스레 풀리는 관계예요.',
      evidenceRows: const [
        ('오행 보충도', '+0.82'),
        ('희신 일치', '✓ 木·水'),
        ('합·충·형·파·해', '합 2 · 충 0'),
        ('십성', '정인 · 편인'),
        ('시간 확정 보너스', '+5'),
      ],
      onShare: () => Navigator.of(context).maybePop(),
      onSeeMore: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  trailing: GuinjiIconButton(icon: '⋯', onPressed: () {}),
                ),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        '貴 8명 · 총 12명',
                        style: TextStyle(
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
              child: _Fab(onPressed: widget.onInvite),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({required this.side, this.onNodeTap});

  final double side;
  final void Function(String name, String relationKey)? onNodeTap;

  static const _orbitRatios = [100 / 300, 170 / 300, 240 / 300, 300 / 300];

  @override
  Widget build(BuildContext context) {
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
          // 11개 노드
          for (final node in _mapNodes)
            Positioned(
              left: node.left * side - side * 0.05,
              top: node.top * side - side * 0.05,
              child: _MapNode(side: side, node: node, onTap: onNodeTap),
            ),
        ],
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  const _MapNode({required this.side, required this.node, this.onTap});

  final double side;
  final _MapNodeSpec node;
  final void Function(String name, String relationKey)? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[node.relationKey];
    final color = meta?.color ?? GuinjiColors.lavender;
    final hanja = meta?.hanja ?? '?';
    final nodeSize = side * 0.10;
    return GestureDetector(
      onTap: () => onTap?.call(node.name, node.relationKey),
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
            node.name,
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
