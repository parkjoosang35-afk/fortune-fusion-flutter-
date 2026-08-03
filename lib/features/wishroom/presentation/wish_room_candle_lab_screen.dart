import 'package:flutter/material.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/widgets/premium_card.dart';
import 'widgets/candle/wish_room_candle_widget.dart';

/// [소원방 촛불 비주얼 재작업 지시 — 작업 방식 제안] "한 번에 최종으로
/// 고치기보다, 촛불 비주얼 시안 2~3개를 먼저 보여주는 방식"에 따라 만든
/// 임시 비교 화면. 구조/정책/토큰은 전혀 바꾸지 않고, A/B/C 촛불 오브제만
/// 나란히 놓고 상태(기본/치성 중/완료)와 완료 빛 확산을 직접 눌러볼 수
/// 있게 한다.
///
/// 최종안이 정해지면 이 화면과 [WishRoomFlameWidget](구시안)은 제거하고,
/// [WishRoomCandleWidget]의 style 하나만 소원방 전역에 적용한다.
class WishRoomCandleLabScreen extends StatelessWidget {
  const WishRoomCandleLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        foregroundColor: UnifiedColors.textPrimary,
        title: Text('촛불 시안 비교 (A/B/C)', style: UnifiedText.title()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceMd,
            UnifiedTokens.screenPadding,
            UnifiedTokens.spaceXxl,
          ),
          children: const [
            _CandleDemoCard(
              style: CandleStyle.minimal,
              title: 'A안 · 미니멀',
              description: '제단 받침 없이 초 + 불꽃만. 가장 정갈하고 심플한 인상.',
            ),
            SizedBox(height: UnifiedTokens.spaceLg),
            _CandleDemoCard(
              style: CandleStyle.altar,
              title: 'B안 · 제단 감성',
              description: '2단 받침 위에 놓인 촛불. 기도 공간 같은 몰입감 강조.',
            ),
            SizedBox(height: UnifiedTokens.spaceLg),
            _CandleDemoCard(
              style: CandleStyle.radiant,
              title: 'C안 · 풍부한 빛',
              description: '받침 + 겹겹의 빛 번짐 + 아주 은은한 빛 입자. 가장 화사함.',
            ),
            SizedBox(height: UnifiedTokens.spaceXl),
            _NoteCard(),
          ],
        ),
      ),
    );
  }
}

class _CandleDemoCard extends StatefulWidget {
  const _CandleDemoCard({
    required this.style,
    required this.title,
    required this.description,
  });

  final CandleStyle style;
  final String title;
  final String description;

  @override
  State<_CandleDemoCard> createState() => _CandleDemoCardState();
}

enum _Phase { base, ritual, done }

class _CandleDemoCardState extends State<_CandleDemoCard> {
  _Phase _phase = _Phase.base;
  int _pulseTrigger = 0;

  double get _intensity => switch (_phase) {
        _Phase.base => 0.30,
        _Phase.ritual => 0.62,
        _Phase.done => 1.0,
      };

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardMain,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.symmetric(
        vertical: UnifiedTokens.spaceXl,
        horizontal: UnifiedTokens.spaceLg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.title, style: UnifiedText.titleLarge())),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceXs),
          Row(
            children: [
              Expanded(
                child: Text(widget.description, style: UnifiedText.bodySmall()),
              ),
            ],
          ),
          const SizedBox(height: UnifiedTokens.spaceLg),
          WishRoomCandleWidget(
            style: widget.style,
            intensity: _intensity,
            size: 118,
            completionPulseTrigger: _pulseTrigger,
          ),
          const SizedBox(height: UnifiedTokens.spaceMd),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: UnifiedTokens.spaceSm,
            runSpacing: UnifiedTokens.spaceSm,
            children: [
              _PhaseChip(
                label: '기본',
                selected: _phase == _Phase.base,
                onTap: () => setState(() => _phase = _Phase.base),
              ),
              _PhaseChip(
                label: '치성 중',
                selected: _phase == _Phase.ritual,
                onTap: () => setState(() => _phase = _Phase.ritual),
              ),
              _PhaseChip(
                label: '완료',
                selected: _phase == _Phase.done,
                onTap: () => setState(() => _phase = _Phase.done),
              ),
              _PhaseChip(
                label: '빛 확산 재생',
                selected: false,
                onTap: () => setState(() => _pulseTrigger++),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: UnifiedTokens.spaceMd,
          vertical: UnifiedTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: selected ? UnifiedColors.black : UnifiedColors.chipInactiveBg,
          borderRadius: BorderRadius.circular(UnifiedTokens.radiusPill),
        ),
        child: Text(
          label,
          style: UnifiedText.chipLabel(
            color: selected ? Colors.white : UnifiedColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardBanner,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusMd),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
      child: Text(
        '이 화면은 비교용 임시 화면입니다. 구조/치성 플로우/소원의 빛 게이지/'
        '복주머니 보상/디자인 토큰은 전혀 바뀌지 않았습니다. 셋 중 하나를 '
        '고르면 소원방 메인·치성 화면의 촛불을 해당 스타일로 교체하고, 이 '
        '비교 화면과 진입 버튼은 정리(제거)합니다.',
        style: UnifiedText.caption(),
      ),
    );
  }
}
