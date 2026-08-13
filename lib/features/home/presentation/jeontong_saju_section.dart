import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/access/access_checker.dart';
import '../../pass/presentation/pass_gate_helper.dart';

/// [신통방통 정통사주 서브 카테고리] 홈 화면 "운세/타로" 2분할 카드에서
/// "운세" 카드를 탭했을 때 열리는 바텀시트 — 8종 정통사주 카테고리를
/// 서브 카테고리 그리드로 보여준다.
///
/// [사용자 요청 반영] "운세섹션에 8종을 서브 카테고리로 운세를 클릭시 8종이
/// 보여야 하는 구조" — 홈 본문에 항상 노출되는 고정 섹션이 아니라, 기존
/// "운세" 카드를 탭했을 때 이 8종 그리드가 뜨는 구조로 변경한다. "타로"
/// 카드/기존 운세·타로 2분할 카드 레이아웃 자체는 완전히 원상복구한다
/// (home_screen.dart의 `_FortuneTarotRow`/`_FortuneTarotMiniCard` 참고).
///
/// 참고 자료(사용자 첨부 "정통사주1.zip"):
/// - flutter_integration/design_prompts/01_home.md (레이아웃/모션/자물쇠 규칙)
/// - flutter_integration/design_system.md (컬러/타이포/컴포넌트 규격)
/// - flutter_integration/dart_models/category_item.dart (카테고리 모델)
/// - flutter_integration/flutter_templates/jeontong_saju_section.dart
///   (완성 참고 템플릿 - 8종 카드 그리드 구조를 그대로 이식)
///
/// [아키텍처 결정] 템플릿은 신규 `FreePassProvider`/`/free-pass-gate` 전용
/// 라우트를 전제로 하지만, 이 앱은 이미 동등한 프리패스 게이트 체계
/// (`AccessChecker`/`PassProvider`/`navigateWithPassGate`)가 있으므로 새
/// Provider/라우트를 추가하지 않고 기존 것을 그대로 재사용한다(회귀 없음).
/// 시트를 여는 것 자체(카테고리 탐색)는 게이트 없이 항상 가능하고, 각
/// 카테고리를 실제로 선택했을 때만 `navigateWithPassGate`로 게이트체크한다
/// (all_categories_screen 등 기존 화면들과 동일한 패턴).
///
/// 카테고리 8종(01_home.md 지정): 평생 총운/재물운/직업운/애정운/건강운/
/// 오늘의 운세/이달 운세/올해 운세. 상세 화면은 기존 SajuInputScreen(토픽
/// 딥링크) 및 daily-fortune-detail 라우트를 그대로 재사용한다(신규 화면 없음).
class _JeontongCat {
  final String code;
  final String name;
  final String hanja;
  final String route;
  final Object? arguments;

  const _JeontongCat({
    required this.code,
    required this.name,
    required this.hanja,
    required this.route,
    this.arguments,
  });
}

const _jeontongCategories = <_JeontongCat>[
  _JeontongCat(
    code: 'A01',
    name: '평생 총운',
    hanja: '命',
    route: '/ai-fortune/saju/input',
    arguments: {
      'initialTopics': ['종합'],
    },
  ),
  _JeontongCat(
    code: 'S02',
    name: '재물운',
    hanja: '財',
    route: '/ai-fortune/saju/input',
    arguments: {
      'initialTopics': ['재물'],
    },
  ),
  _JeontongCat(
    code: 'S05',
    name: '직업운',
    hanja: '官',
    route: '/ai-fortune/saju/input',
    arguments: {
      'initialTopics': ['직업'],
    },
  ),
  _JeontongCat(
    code: 'S03',
    name: '애정운',
    hanja: '緣',
    route: '/ai-fortune/saju/input',
    arguments: {
      'initialTopics': ['애정'],
    },
  ),
  _JeontongCat(
    code: 'S04',
    name: '건강운',
    hanja: '壽',
    route: '/ai-fortune/saju/input',
    arguments: {
      'initialTopics': ['건강'],
    },
  ),
  _JeontongCat(
    code: 'D02',
    name: '오늘의 운세',
    hanja: '今',
    route: '/home/daily-fortune-detail',
  ),
  _JeontongCat(
    code: 'S05',
    name: '이달 운세',
    hanja: '朔',
    route: '/ai-fortune/saju/input',
    arguments: {
      'initialTopics': ['월별'],
    },
  ),
  _JeontongCat(
    code: 'C01',
    name: '올해 운세',
    hanja: '年',
    route: '/ai-fortune/saju/input',
    arguments: {
      'initialTopics': ['월별'],
    },
  ),
];

/// design_system.md §컬러 팔레트 — 이 섹션 전용(신통방통 테마).
/// 앱 전역 UnifiedColors(화이트 베이스)와 완전히 다른 팔레트이므로
/// 별도 상수로 분리해 다른 화면에 영향이 없도록 한다.
class _JStyle {
  _JStyle._();
  static const inkBlack = Color(0xFF0A0A0F);
  static const deepNight = Color(0xFF12121A);
  static const royalGold = Color(0xFFD4AF37);
  static const amethyst = Color(0xFF6B4E9E);
  static const starWhite = Color(0xFFF8F5E6);
  static const moonSilver = Color(0xFFC0C0C8);
}

/// 홈 화면 "운세" 카드에서 호출하는 진입점 — 8종 서브 카테고리 바텀시트를 연다.
///
/// [STEP8-2 로그인 필수 UI 패턴과 동일] 시트를 닫은(pop) 뒤에는 시트 내부
/// context가 unmount되므로, 게이트체크+라우팅에는 시트를 연 "바깥쪽"(홈 화면)
/// [context]를 그대로 클로저로 캡처해 사용한다(pass_gate_helper.dart의
/// showLoginRequiredSheet와 동일한 패턴).
Future<void> showJeontongSajuCategoriesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _JeontongCategoriesSheet(homeContext: context),
  );
}

class _JeontongCategoriesSheet extends StatelessWidget {
  const _JeontongCategoriesSheet({required this.homeContext});

  /// 시트를 연 홈 화면의 context(시트가 닫혀도 계속 유효하게 살아있음).
  final BuildContext homeContext;

  Future<void> _onTap(BuildContext sheetCtx, _JeontongCat cat) async {
    // 시트(sheetCtx)를 먼저 닫고, 여전히 mounted 상태인 홈 화면 context로
    // 게이트체크 + 라우팅한다.
    Navigator.of(sheetCtx).pop();
    if (!homeContext.mounted) return;
    await navigateWithPassGate(
      homeContext,
      title: cat.name,
      route: cat.route,
      requiresPass: true,
      arguments: cat.arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPass = context.watch<AccessChecker>().isOpenPassActive();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: const BoxDecoration(
          color: _JStyle.inkBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _JStyle.royalGold.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              // Section title — design_prompts/01_home.md: gold serif 20sp
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '정통사주',
                    style: GoogleFonts.nanumMyeongjo(
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _JStyle.royalGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasPass ? '자유 이용' : '프리패스 필요',
                    style: GoogleFonts.notoSansKr(
                      textStyle: const TextStyle(
                        fontSize: 11,
                        color: _JStyle.moonSilver,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '80가지 운세 · 프리패스 하나로 무제한',
                style: GoogleFonts.notoSansKr(
                  textStyle: const TextStyle(
                    fontSize: 12,
                    color: _JStyle.moonSilver,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _jeontongCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (ctx, i) {
                  final cat = _jeontongCategories[i];
                  // design_system.md §모션: 카드 등장 fade+slide-up 400ms
                  // cubic ease-out (여기서는 stagger 40ms×idx로 순차 적용).
                  return TweenAnimationBuilder<double>(
                    key: ValueKey('${cat.code}_$i'),
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 240 + i * 40),
                    curve: Curves.easeOut,
                    builder: (ctx, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 16),
                        child: child,
                      ),
                    ),
                    child: _JeontongCard(
                      cat: cat,
                      locked: !hasPass,
                      onTap: () => _onTap(context, cat),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JeontongCard extends StatefulWidget {
  const _JeontongCard({
    required this.cat,
    required this.locked,
    required this.onTap,
  });

  final _JeontongCat cat;
  final bool locked;
  final Future<void> Function() onTap;

  @override
  State<_JeontongCard> createState() => _JeontongCardState();
}

class _JeontongCardState extends State<_JeontongCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    // design_system.md §프리패스 락 표시 규칙: shake 애니메이션(300ms).
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (widget.locked) {
          _shakeCtrl.forward(from: 0);
          // shake 모션이 보이도록 살짝 지연 후 게이트 흐름으로 진행한다.
          await Future.delayed(const Duration(milliseconds: 300));
        }
        await widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (ctx, child) => Transform.translate(
          offset: Offset(_shakeAnim.value, 0),
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _JStyle.deepNight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _JStyle.royalGold.withValues(alpha: 0.20),
              width: 1,
            ),
            boxShadow: widget.locked
                ? [
                    // design_system.md §모션: 잠금 카드 amethyst pulse.
                    BoxShadow(
                      color: _JStyle.amethyst.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: _JStyle.royalGold.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              if (widget.locked)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: _JStyle.royalGold,
                  ),
                ),
              Center(
                child: Opacity(
                  opacity: widget.locked ? 0.85 : 1.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 한자(한글) 병기 원칙 — 한자는 주변 한글보다 20% 크게.
                      Text(
                        widget.cat.hanja,
                        style: GoogleFonts.nanumMyeongjo(
                          textStyle: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: _JStyle.royalGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          widget.cat.name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansKr(
                            textStyle: const TextStyle(
                              fontSize: 14,
                              color: _JStyle.starWhite,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.locked)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _JStyle.inkBlack.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
