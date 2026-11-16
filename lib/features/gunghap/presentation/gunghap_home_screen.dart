// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_home_screen.dart
// [궁합지도 Star Map 디자인 적용] design_handoff_gunghap_map.zip
// `design_files/gunghap/gh-screens-a.jsx` ScreenHome(01 메인 홈) 포팅본.
//
// [2026-11 「인연지도」 디자인 핸드오프 2차 반영] `MAP_HOME_SPEC.md`에
// 따라 메인 그래픽을 2인 전용 [StarMap]에서 다인 궤도 [DestinyMap]으로
// 교체했다 — `GunghapProvider.fetchGunghapMap()`(`GET /gunghap/map`)의
// 실제 서버 응답(사람별 그룹화·점수·황금각 배치 완료)만 사용하며, 로컬
// 하드코딩 데이터는 쓰지 않는다. [StarMap]은 삭제하지 않고 2인 전용
// 화면(초대/결과)에서 계속 쓰인다 — 서로 대체 관계가 아니다(역할 분리).
//
// [v4 핸드오프 전면 재작성 — 00_DEV_MAPPING.md §5 S01] 아래 변경을
// 반영한다.
//  - 카테고리 타일(`_MajorTile`)을 가로형 아이콘+텍스트에서 명세대로
//    "정사각 이미지(`sq/{id}.jpg`) + 흰 정보칸" 카드로 전면 교체.
//  - 우상단 68×68 "궁합지도" 소개 버튼(introGrad 배경) 신규 추가 →
//    탭 시 S07 소개 바텀시트([showGunghapIntroSheet])를 연다.
//  - AppBar: 기존 "◈ 내 궁합"(→ GunghapStoryScreen) 진입 버튼은 실사용
//    기능 손실을 막기 위해 그대로 유지한다. 명세(§5 S01-1)가 요구하는
//    우측 ＋(→ S08 invite)는 CTA 영역에 이미 동일 기능의 "궁합 초대장
//    보내기" 보조 버튼이 있어 AppBar에 중복 배치하지 않는다(보수적 결정
//    — 기존 기능을 깨지 않는 방향).
// ═══════════════════════════════════════════════════════════════
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../../core/router/main_bottom_nav_bar.dart';
import '../application/gunghap_provider.dart';
import '../domain/gunghap_map_models.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/destiny_map.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';
import '../widgets/intro_sheet.dart';
import '../widgets/relation_sheet.dart';
import '../widgets/slot_sheet.dart';
import '../widgets/cat_icon.dart';
import '../domain/gunghap_data.dart';
import 'gunghap_invite_screen.dart';
import 'gunghap_major_screen.dart';
import 'gunghap_result_screen.dart';
import 'gunghap_story_screen.dart';

class GunghapHomeScreen extends StatefulWidget {
  const GunghapHomeScreen({super.key});

  @override
  State<GunghapHomeScreen> createState() => _GunghapHomeScreenState();
}

class _GunghapHomeScreenState extends State<GunghapHomeScreen> {
  String? _filterMajor; // null = 전체
  bool _requestedMap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMap());
  }

  void _loadMap() {
    if (!mounted) return;
    setState(() => _requestedMap = true);
    context.read<GunghapProvider>().fetchGunghapMap();
  }

  void _openResult(String resultId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GunghapResultScreen(resultId: resultId)),
    );
  }

  void _onTapPerson(MapPerson p) {
    final provider = context.read<GunghapProvider>();
    final major = ghMajorById(p.majorId);
    showRelationSheet(
      context,
      p,
      provider: provider,
      majorName: major.name,
      majorHanja: major.hanja,
      onOpenResult: _openResult,
      onAddGunghap: () => _goMajor(context, method: 'direct'),
    );
  }

  void _onTapSlot(Slot slot) {
    final provider = context.read<GunghapProvider>();
    showSlotSheet(
      context,
      slot,
      filledCount: provider.mapPeople.length,
      onInvite: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GunghapInviteScreen(method: 'invite', majorId: slot.majorId),
        ),
      ),
      onDirect: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GunghapMajorScreen(method: 'direct', initialMajorId: slot.majorId, skipToSub: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();
    final people = _filterMajor == null
        ? provider.mapPeople
        : provider.mapPeople.where((p) => p.majorId == _filterMajor).toList();
    final headline = provider.mapPeople.isEmpty
        ? '나의 인연 지도를\n그려 볼까요'
        : provider.mapPeople.length < 8
        ? '인연지도를\n조금 더 채워 볼까요'
        : '나를 중심으로 도는\n인연의 별들';

    return GHScreen(
      // [하단바 누락 수정] 신통방통 공용 하단 네비게이션 바
      // (홈/신당부적/복주머니/마이)를 그대로 재사용한다. 궁합지도는
      // 홈 화면 "전체보기"에서 진입하므로 다른 push 화면들(정통사주/
      // 타로/귀인지도 등)과 동일하게 currentIndex: 0(홈)을 쓴다 —
      // 전용 하단바를 새로 만들지 않고 기존 [MainBottomNavBar] 그대로.
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(
        leading: Row(
          children: const [
            _GHMark(),
            SizedBox(width: 7),
            Text('궁합지도', style: TextStyle()),
          ],
        ),
        actions: [
          GHIconButton(
            glyph: '◈',
            label: '내 궁합',
            // [궁합지도 Phase 4 §3] "준비 중" 플레이스홀더를 실제
            // 궁합스토리 화면(서버 DB 실데이터)으로 교체.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GunghapStoryScreen()),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // hero badge + title
          // [00_DEV_MAPPING §5 S01-2] 우상단 100px을 비우고 68×68
          // "궁합지도" 소개 버튼을 겹쳐 올린다 → 탭 시 S07.
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 60),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: GHColors.lineSoft),
                        color: GHColors.bg2.withValues(alpha: .6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: GHColors.gold,
                              boxShadow: [
                                BoxShadow(
                                  color: GHColors.gold.withValues(alpha: .8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'DESTINY MAP · 因緣之圖',
                            style: GHText.ui(size: 12, weight: FontWeight.w600, color: GHColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(headline, textAlign: TextAlign.center, style: GHText.display(size: 28)),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: -2,
                child: _IntroButton(
                  onTap: () => showGunghapIntroSheet(
                    context,
                    onStart: () => _goMajor(context, method: 'direct'),
                  ),
                ),
              ),
            ],
          ),

          // key graphic — 인연지도(DestinyMap, 다인 궤도)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Stack(
              alignment: Alignment.center,
              children: [
                FractionallySizedBox(
                  widthFactor: .78,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            GHColors.violet.withValues(alpha: .16),
                            GHColors.gold.withValues(alpha: .06),
                            Colors.transparent,
                          ],
                          stops: const [0, .45, .7],
                        ),
                      ),
                    ),
                  ),
                ),
                // [MAP_HOME_SPEC.md §6 — 오류] 조회 자체가 실패하면
                // 궤도 대신 재시도 안내를 보여준다(스피너는 쓰지 않음 —
                // isLoadingMap 상태는 궤도+나만 그려진 빈 [DestinyMap]으로
                // 자연스럽게 표현된다).
                //
                // [버그 수정 — 로그인 직후/비로그인 "별을 불러오지 못했어요"
                // 오표시] UNAUTHORIZED(로그인 필요)는 "네트워크/서버 오류"가
                // 아니라 "아직 로그인하지 않았거나 토큰이 아직 반영되지 않은
                // 정상적인 상태"다. MAP_HOME_SPEC.md §9는 이 경우에도 지도를
                // 비워 두지 않고 "8개 빈 자리 별"로 먼저 채우도록 명시한다 —
                // 즉 UNAUTHORIZED는 아래 else 분기(DestinyMap, 빈 자리 포함)로
                // 흘러가야 하며, 진짜 네트워크/서버 오류일 때만 재시도 UI를
                // 보여준다.
                if (_requestedMap &&
                    !provider.isLoadingMap &&
                    provider.mapLoaded &&
                    provider.error != null &&
                    provider.errorCode != 'UNAUTHORIZED' &&
                    provider.mapPeople.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '별을 불러오지 못했어요',
                          style: GHText.ui(size: 13, color: GHColors.gray),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _loadMap,
                          child: Text(
                            '다시 시도',
                            style: GHText.ui(
                              size: 13,
                              weight: FontWeight.w700,
                              color: GHColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: DestinyBurst(
                      people: people,
                      slots: ghVisibleSlots(people),
                      me: provider.mapMe ?? const MapMe(stem: null, element: null),
                      focusMajor: _filterMajor,
                      onSelect: _onTapPerson,
                      onSlot: _onTapSlot,
                      onFocus: (m) => setState(() => _filterMajor = m),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 10),
            child: Text(
              '안쪽 궤도일수록 궁합 점수가 높아요 · 별을 누르면 궁합 관계가 열려요',
              textAlign: TextAlign.center,
              style: GHText.ui(size: 12, color: GHColors.gray),
            ),
          ),

          // 분야 칩 — 전체/8개 대분류 필터
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GHChip(
                    label: '전체',
                    active: _filterMajor == null,
                    onTap: () => setState(() => _filterMajor = null),
                  ),
                ),
                for (final m in ghMajors)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GHChip(
                      label: m.shortName,
                      active: _filterMajor == m.id,
                      onTap: () => setState(
                        () => _filterMajor = _filterMajor == m.id ? null : m.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // primary CTA
          // [MAP_HOME_SPEC.md §3 「CTA 빛 스침」] 3.6s, 2.4s 지연 반복 —
          // `_GhShineSweep`으로 버튼 위에 대각선 하이라이트가 주기적으로
          // 스치는 연출을 추가한다(원본 `ghm-shine` keyframe 포팅).
          _GhShineSweep(
            child: GHButton(
              label: provider.mapPeople.isEmpty ? '✦ 첫 궁합 시작하기' : '✦ 새 궁합 시작하기',
              size: GHButtonSizeT.xl,
              onPressed: () => _goMajor(context, method: 'direct'),
            ),
          ),
          const SizedBox(height: 8),
          GHButton(
            label: '궁합 초대장 보내기',
            variant: GHButtonVariant.secondary,
            size: GHButtonSizeT.md,
            leading: const Text('✉', style: TextStyle(color: GHColors.gold)),
            onPressed: () => _goMajor(context, method: 'invite'),
          ),

          const SizedBox(height: 38),
          GHSectionHead(mono: 'CATEGORY · 08', title: '어떤 인연이 궁금하세요'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
            children: [
              for (final m in ghMajors)
                _MajorTile(major: m, onTap: () => _goSub(context, m.id)),
            ],
          ),

          const SizedBox(height: 34),
          GHSectionHead(
            mono: 'RECENT',
            title: '최근 살펴본 궁합',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GunghapStoryScreen()),
              ),
              child: Text('내 궁합 관리 ›', style: GHText.ui(size: 13, color: GHColors.gray)),
            ),
          ),
          // [궁합지도 Phase 4 §3] 디자인 미리보기 전용 하드코딩
          // ghRecentHistory 더미를 제거하고, 실제 서버 결과(최대 2건
          // 미리보기)를 보여준다. 로딩/빈 상태는 이 섹션 특성상 과하지
          // 않게 처리 — 비어 있으면 섹션 자체를 숨기고, 전체 목록은
          // 위 "내 궁합 관리 ›"에서 확인하게 한다.
          const _RecentGunghapPreview(),
        ],
      ),
    );
  }

  void _goMajor(BuildContext context, {required String method}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GunghapMajorScreen(method: method)),
    );
  }

  void _goSub(BuildContext context, String majorId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GunghapMajorScreen(method: 'direct', initialMajorId: majorId, skipToSub: true),
      ),
    );
  }
}

/// [MAP_HOME_SPEC.md §3 「CTA 빛 스침」] 원본 `@keyframes ghm-shine`
/// (`transform: translateX(-120%) skewX(-18deg)` → `translateX(260%)`)을
/// Flutter로 포팅한 대각선 하이라이트 스침 애니메이션. 3.6초 주기로
/// 반복하며, 시작 시 2.4초 지연을 둔다(원본과 동일).
class _GhShineSweep extends StatefulWidget {
  const _GhShineSweep({required this.child});
  final Widget child;

  @override
  State<_GhShineSweep> createState() => _GhShineSweepState();
}

class _GhShineSweepState extends State<_GhShineSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GHRadius.button),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      // -30%w ~ +130%w 구간을 선형 이동(원본 -120%~260%의
                      // 좁은 버전 — 버튼 폭이 좁아도 자연스럽게 보이도록).
                      final x = -0.3 * w + _controller.value * 1.6 * w;
                      return Transform.translate(
                        offset: Offset(x, 0),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.skewX(-0.3),
                          child: Container(
                            width: w * 0.3,
                            height: constraints.maxHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: .45),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [00_DEV_MAPPING §5 S01-2] 우상단 「궁합지도」 소개 버튼 — 68×68
/// r18, introGrad 배경, introBtn 그림자. 미니 아이콘(점선 원 + 「나」 +
/// 별 3개) 28 + 「궁합지도」 11/800. 탭 → S07([showGunghapIntroSheet]).
class _IntroButton extends StatelessWidget {
  const _IntroButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Semantics(
      button: true,
      label: '궁합지도 소개',
      child: Container(
        width: 68,
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: GHGradients.intro,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GHColors.introBorder),
          boxShadow: GHShadow.introBtn,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(painter: _IntroGlyphPainter()),
            ),
            const SizedBox(height: 2),
            Text(
              '궁합지도',
              style: GHText.ui(size: 11, weight: FontWeight.w800, color: GHColors.introText),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IntroGlyphPainter extends CustomPainter {
  const _IntroGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // 점선 원.
    const dashCount = 16;
    final r = size.width / 2 - 2;
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = GHColors.introText.withValues(alpha: .55);
    for (var i = 0; i < dashCount; i++) {
      final a0 = i / dashCount * 2 * pi;
      final a1 = a0 + (pi / dashCount) * .65;
      canvas.drawLine(c + Offset.fromDirection(a0, r), c + Offset.fromDirection(a1, r), dashPaint);
    }
    // 중앙 「나」.
    final tp = TextPainter(
      text: TextSpan(
        text: '나',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: GHColors.introText,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    // 별 3개(지름 위 120도 간격).
    for (var i = 0; i < 3; i++) {
      final a = -pi / 2 + i * (2 * pi / 3);
      _star(canvas, c + Offset.fromDirection(a, r * .62), 2.1, GHColors.introText);
    }
  }

  void _star(Canvas canvas, Offset o, double rr, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 2;
      final rad = i.isEven ? rr * 2.2 : rr * .55;
      final pt = Offset(o.dx + cos(a) * rad, o.dy + sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GHMark extends StatelessWidget {
  const _GHMark();
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(20, 20),
    painter: _GHMarkPainter(),
  );
}

class _GHMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);
    canvas.drawCircle(
      const Offset(12, 12),
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = GHColors.gold.withValues(alpha: .6),
    );
    canvas.drawLine(
      const Offset(6.5, 15),
      const Offset(17.5, 8.5),
      Paint()
        ..strokeWidth = .9
        ..color = GHColors.gold,
    );
    canvas.drawCircle(const Offset(6.5, 15), 2.2, Paint()..color = GHColors.gold);
    canvas.drawCircle(const Offset(17.5, 8.5), 2.2, Paint()..color = GHColors.violet);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}

/// [00_DEV_MAPPING §5 S01-7] 「어떤 인연이 궁금하세요」 2열 카테고리
/// 카드 — 정사각 이미지(`sq/{id}.jpg`) + 흰 정보칸(CatIcon 18 + 축약명
/// 14.5/800 / 우측 「{n}가지」 11/700 muted). r18, imageCard 그림자.
class _MajorTile extends StatelessWidget {
  const _MajorTile({required this.major, required this.onTap});
  final GHMajor major;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GHColors.card,
        borderRadius: BorderRadius.circular(GHRadius.imageCard),
        boxShadow: GHShadow.imageCard,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.asset(
              ghArtSquare(major.id),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: GHColors.bg2.withValues(alpha: .7),
                child: Center(child: CatIcon(kind: major.icon, size: 36, active: true)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
            child: Row(
              children: [
                CatIcon(kind: major.icon, size: 18, active: true),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    major.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GHText.cardTitle(size: 14.5),
                  ),
                ),
                Text(
                  '${ghSubs[major.id]?.length ?? 0}가지',
                  style: GHText.ui(size: 11, weight: FontWeight.w700, color: GHColors.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// [궁합지도 Phase 4 §3] "최근 살펴본 궁합" — 실제 서버 데이터 전용.
//
// [절대 원칙] 더 이상 gunghap_data.dart의 하드코딩 ghRecentHistory를
// 쓰지 않는다. GunghapProvider.fetchMyResults()(GET /my-results)를
// 호출해 실제 DIRECT+INVITE 결과를 가져오고, 최신 2건만 미리보기로
// 보여준다. 전체 목록은 "내 궁합 관리 ›"에서 GunghapStoryScreen으로.
// ═══════════════════════════════════════════════════════════════
class _RecentGunghapPreview extends StatefulWidget {
  const _RecentGunghapPreview();

  @override
  State<_RecentGunghapPreview> createState() => _RecentGunghapPreviewState();
}

class _RecentGunghapPreviewState extends State<_RecentGunghapPreview> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requested = true;
      context.read<GunghapProvider>().fetchMyResults();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GunghapProvider>();

    if (!_requested || (provider.isLoadingMyResults && provider.myResults.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: GHColors.gold),
          ),
        ),
      );
    }

    if (provider.myResults.isEmpty) {
      // [빈 상태] 이 섹션 자체를 숨긴다 — 하드코딩 더미로 대체하지 않는다.
      return const SizedBox.shrink();
    }

    final recent = provider.myResults.take(2).toList();
    return Column(
      children: [
        for (final item in recent) ...[
          _HistoryRow(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  /// `GET /gunghap/my-results` 응답 items[i] (실제 서버 데이터).
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    // [상대방 이름 원칙] DIRECT는 ownerName이 항상 null이므로 resultType과
    // 무관하게 항상 guestName을 사용한다(gunghap_repository.dart 참고).
    final guestName = item['guestName'] as String? ?? '상대방';
    final relationTypeLabel = item['relationTypeLabel'] as String?;
    final grade = item['grade'] as String?;
    final resultType = item['resultType'] as String?;
    final createdAtRaw = item['createdAt'] as String?;
    final dateLabel = _formatDate(createdAtRaw);
    final resultId = item['resultId'] as String?;

    return GestureDetector(
      onTap: resultId == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GunghapResultScreen(resultId: resultId),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: GHColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GHColors.lineSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GHColors.bg2.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GHColors.divider),
              ),
              alignment: Alignment.center,
              child: const CatIcon(kind: 'heart', size: 30, active: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GHText.cardTitle(size: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (relationTypeLabel != null) ...[
                        Flexible(
                          child: Text(
                            relationTypeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GHText.ui(size: 12, color: GHColors.gold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('·', style: GHText.ui(size: 12, color: GHColors.gray)),
                        const SizedBox(width: 6),
                      ],
                      if (dateLabel != null)
                        Text(dateLabel, style: GHText.mono(size: 9.5, color: GHColors.gray)),
                    ],
                  ),
                ],
              ),
            ),
            if (resultType == 'DIRECT')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GHColors.violet.withValues(alpha: .4)),
                ),
                child: Text(
                  'DIRECT',
                  style: GHText.mono(size: 8.5, color: GHColors.violetText),
                ),
              )
            else if (grade != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: GHColors.mint.withValues(alpha: .4)),
                ),
                child: Text(
                  grade,
                  style: GHText.mono(size: 8.5, color: GHColors.mint),
                ),
              ),
            const SizedBox(width: 6),
            Text('›', style: GHText.ui(size: 18, color: GHColors.gray)),
          ],
        ),
      ),
    );
  }

  String? _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    return DateFormat('yyyy · MM · dd').format(parsed.toLocal());
  }
}
