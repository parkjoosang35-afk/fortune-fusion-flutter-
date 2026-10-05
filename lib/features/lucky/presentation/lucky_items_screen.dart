import 'package:flutter/material.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_graphics.dart';

/// [신규 화면 - 개운 아이템 · 행운 색·방위] 오행(목/화/토/금/수)별 색·방위·
/// 맛·활동 정적 룰을 보여주는 화면.
///
/// [신통방통 정통사주 리뉴얼] 기존에는 [SajuProvider.state](AI LLM 사주)를
/// read-only로 참조해 "부족 오행"을 자동 하이라이트했으나, SajuProvider가
/// 완전히 제거되어 이 연동도 함께 제거한다. saju_renewal은 오행 데이터를
/// 아직 이 화면과 공유하지 않으므로, 당분간 5개 오행을 모두 평시 안내
/// 톤으로 동일하게 보여준다.
class LuckyItemsScreen extends StatelessWidget {
  const LuckyItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String? weakestElement = null;

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.spaceXl,
            UnifiedTokens.spaceMd,
            UnifiedTokens.spaceXl,
            UnifiedTokens.spaceXxl,
          ),
          children: [
            _Header(hasResult: weakestElement != null),
            const SizedBox(height: UnifiedTokens.spaceXl),
            if (weakestElement != null)
              FadeSlideIn(
                child: _WeakestElementBanner(element: weakestElement),
              ),
            if (weakestElement != null)
              const SizedBox(height: UnifiedTokens.spaceXl),
            for (var i = 0; i < _elementRules.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: UnifiedTokens.spaceMd),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 40 * i),
                  child: _ElementCard(
                    rule: _elementRules[i],
                    highlighted: _elementRules[i].name == weakestElement,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hasResult});

  final bool hasResult;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: UnifiedColors.cardAllMenu,
              borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: UnifiedTokens.iconMd,
              color: UnifiedColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: UnifiedTokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('개운 아이템 · 행운 색·방위', style: UnifiedText.titleLarge()),
              const SizedBox(height: 4),
              Text(
                hasResult
                    ? '내 사주에서 부족한 기운을 채워줄 오행 정보예요'
                    : '오행별 색·방위·맛·활동을 한눈에 확인해보세요',
                style: UnifiedText.body(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 사주 결과가 있을 때만 노출되는 "부족 오행" 요약 배너.
class _WeakestElementBanner extends StatelessWidget {
  const _WeakestElementBanner({required this.element});

  final String element;

  @override
  Widget build(BuildContext context) {
    final rule = _elementRules.firstWhere(
      (e) => e.name == element,
      orElse: () => _elementRules.first,
    );
    return PremiumCard(
      backgroundColor: UnifiedColors.passBar,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: UnifiedTokens.iconMd,
          ),
          const SizedBox(width: UnifiedTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금 가장 필요한 기운은 "${rule.name}"이에요',
                  style: UnifiedText.bodyStrong(color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  '${rule.color} · ${rule.direction} 방향을 오늘 하루 가까이 두어보세요',
                  style: UnifiedText.caption(color: UnifiedColors.neon),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 오행 1개 카드 — 색/방위/맛/추천 아이템/활동.
class _ElementCard extends StatelessWidget {
  const _ElementCard({required this.rule, required this.highlighted});

  final _ElementRule rule;
  final bool highlighted;

  // [미스터리 동양 분위기 - 기존 토큰 재사용] 오행별 스와치 색만 파일
  // 내부 상수로 유지한다(새 AppColors 클래스 신설 없음 — 단순 Color 값).
  static const Map<String, Color> _swatch = {
    '목(木)': Color(0xFF3E8E7E),
    '화(火)': Color(0xFFD1495B),
    '토(土)': Color(0xFFD9A54A),
    '금(金)': Color(0xFFB9B4C7),
    '수(水)': Color(0xFF2B2D42),
  };

  @override
  Widget build(BuildContext context) {
    final swatchColor = _swatch[rule.name] ?? UnifiedColors.textPrimary;
    return PremiumCard(
      backgroundColor: UnifiedColors.cardAllMenu,
      borderColor: highlighted ? swatchColor : Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: UnifiedTokens.iconCircleMd,
                height: UnifiedTokens.iconCircleMd,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: swatchColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  rule.name.substring(0, 1),
                  style: UnifiedText.bodyStrong(color: Colors.white),
                ),
              ),
              const SizedBox(width: UnifiedTokens.spaceSm),
              Expanded(child: Text(rule.name, style: UnifiedText.title())),
              if (highlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: UnifiedColors.cardBanner,
                    borderRadius: BorderRadius.circular(
                      UnifiedTokens.radiusPill,
                    ),
                  ),
                  child: Text('추천', style: UnifiedText.caption()),
                ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag('색', rule.color),
              _tag('방위', rule.direction),
              _tag('맛', rule.taste),
              _tag('추천', rule.item),
              _tag('활동', rule.activity),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: UnifiedColors.bg,
        borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
      ),
      child: Text(
        '$label · $value',
        style: UnifiedText.chipLabel(color: UnifiedColors.textPrimary),
      ),
    );
  }
}

/// 오행별 정적 룰 값 객체.
class _ElementRule {
  const _ElementRule({
    required this.name,
    required this.color,
    required this.direction,
    required this.taste,
    required this.item,
    required this.activity,
  });

  final String name;
  final String color;
  final String direction;
  final String taste;
  final String item;
  final String activity;
}

/// [정적 룰 폴백] 요청서에 명시된 오행별 색/방위/맛/활동 트리.
const List<_ElementRule> _elementRules = [
  _ElementRule(
    name: '목(木)',
    color: '청록',
    direction: '동쪽',
    taste: '신맛',
    item: '채소',
    activity: '산책',
  ),
  _ElementRule(
    name: '화(火)',
    color: '빨강',
    direction: '남쪽',
    taste: '쓴맛',
    item: '따뜻한 차',
    activity: '명상',
  ),
  _ElementRule(
    name: '토(土)',
    color: '노랑',
    direction: '중앙',
    taste: '단맛',
    item: '잡곡밥',
    activity: '정리습관',
  ),
  _ElementRule(
    name: '금(金)',
    color: '흰색',
    direction: '서쪽',
    taste: '매운맛',
    item: '배·도자기',
    activity: '악기연주',
  ),
  _ElementRule(
    name: '수(水)',
    color: '검정',
    direction: '북쪽',
    taste: '짠맛',
    item: '해산물',
    activity: '수영·샤워',
  ),
];
