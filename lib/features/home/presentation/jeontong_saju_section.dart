import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/access/access_checker.dart';
import '../../pass/presentation/pass_gate_helper.dart';

/// [신통방통 정통사주 섹션] 힐링한마디 카드 아래, 기존 "운세/타로" 2분할
/// 카드(`_FortuneTarotRow`)를 대체하는 신규 섹션.
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
/// Provider/라우트를 추가하지 않고 기존 것을 그대로 재사용한다(회귀 없음,
/// "기존 Application/Data/Domain 레이어는 그대로 재사용" 원칙 준수).
/// 잠금 카드 탭 → shake(300ms) → 기존 `navigateWithPassGate`가 호출하는
/// 프리패스 안내 바텀시트(`showPassRequiredSheet`)로 연결된다(신규
/// `/free-pass-gate` 화면을 만들지 않는 대신, 기존 앱의 동등 기능으로 대체).
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

class JeontongSajuSection extends StatelessWidget {
  const JeontongSajuSection({super.key});

  Future<void> _onTap(BuildContext context, _JeontongCat cat) async {
    await navigateWithPassGate(
      context,
      title: cat.name,
      route: cat.route,
      requiresPass: true,
      arguments: cat.arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPass = context.watch<AccessChecker>().isOpenPassActive();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: _JStyle.inkBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _JStyle.royalGold.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  onTap: () => _onTap(ctx, cat),
                ),
              );
            },
          ),
        ],
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
