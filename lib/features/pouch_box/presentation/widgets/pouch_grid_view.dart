import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/lucky_box_tokens.dart';
import '../../application/pouch_box_provider.dart';
import '../../../wallet/application/wallet_provider.dart';
import 'lucky_box_tile.dart';
import 'mini_pouch_icon.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-1 Grid(기본 화면).
/// 탭 진입 즉시 노출되는 3x3 상자 그리드 + 헤더 + CTA. 로딩 스피너를 두지
/// 않고(§9 QA체크리스트) [PouchBoxProvider.state]의 초기값(dailyLeft=5)으로
/// 즉시 렌더링한 뒤 실제 서버 응답이 오면 자연스럽게 갱신된다.
class PouchGridView extends StatelessWidget {
  /// "광고 보고 상자 열기" 탭 후 세션 발급(POST /start) 대기 중인지 —
  /// CTA 버튼을 잠깐 비활성 + 로딩 표시로 바꿔 중복 탭을 막는다.
  final bool starting;
  final VoidCallback onTapCta;

  const PouchGridView({
    super.key,
    required this.starting,
    required this.onTapCta,
  });

  @override
  Widget build(BuildContext context) {
    final pouchState = context.watch<PouchBoxProvider>().state;
    final balance = context.watch<WalletProvider>().balance;
    final canOpen = pouchState.watchable && pouchState.dailyLeft > 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LuckyBoxTokens.sp5,
          LuckyBoxTokens.sp4,
          LuckyBoxTokens.sp5,
          LuckyBoxTokens.sp8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(balance: balance),
            const SizedBox(height: LuckyBoxTokens.sp6),
            const Center(child: _HeaderChip()),
            const SizedBox(height: LuckyBoxTokens.sp4),
            const Center(child: _HeroTitle()),
            const SizedBox(height: LuckyBoxTokens.sp2),
            Center(
              child: Text(
                '50개 ~ 300개  ·  ${pouchState.todayOpenedCount}/${pouchState.dailyLimit}회',
                style: LuckyBoxTokens.caption,
              ),
            ),
            const SizedBox(height: LuckyBoxTokens.sp8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: LuckyBoxTokens.sp3,
              crossAxisSpacing: LuckyBoxTokens.sp3,
              children: List.generate(9, (i) => LuckyBoxTile(index: i)),
            ),
            const SizedBox(height: LuckyBoxTokens.sp8),
            if (canOpen)
              Center(
                child: Text(
                  '광고 보고 상자를 열어보세요',
                  style: LuckyBoxTokens.bodyText.copyWith(
                    color: LuckyBoxTokens.fgSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (canOpen) const SizedBox(height: LuckyBoxTokens.sp4),
            _Cta(
              canOpen: canOpen,
              loading: starting,
              reasonLabel: pouchState.reasonLabel,
              onTap: onTapCta,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int balance;
  const _Header({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '복주머니',
          style: LuckyBoxTokens.title.copyWith(color: LuckyBoxTokens.fgPrimary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LuckyBoxTokens.sp3,
            vertical: LuckyBoxTokens.sp1,
          ),
          decoration: BoxDecoration(
            color: LuckyBoxTokens.bgSoft,
            borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
            border: Border.all(color: LuckyBoxTokens.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPouchIcon(size: 18),
              const SizedBox(width: LuckyBoxTokens.sp1),
              Text(
                '$balance',
                style: const TextStyle(
                  fontFamily: LuckyBoxTokens.fontDisplay,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: LuckyBoxTokens.fgPrimary,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '개',
                style: LuckyBoxTokens.bodyText.copyWith(
                  fontSize: 13,
                  color: LuckyBoxTokens.fgSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LuckyBoxTokens.sp4,
        vertical: LuckyBoxTokens.sp2,
      ),
      decoration: BoxDecoration(
        color: LuckyBoxTokens.bgBase,
        borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
        border: Border.all(color: LuckyBoxTokens.accentGlow, width: 1.2),
        boxShadow: LuckyBoxTokens.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPouchIcon(size: 14, lit: true),
          const SizedBox(width: LuckyBoxTokens.sp2),
          Text(
            '오늘의 행운상자',
            style: LuckyBoxTokens.button.copyWith(
              fontSize: 13,
              color: LuckyBoxTokens.fgOnGlow,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          LuckyBoxTokens.heroTextGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: const Text('최대 300개', style: LuckyBoxTokens.display),
    );
  }
}

class _Cta extends StatelessWidget {
  final bool canOpen;
  final bool loading;
  final String? reasonLabel;
  final VoidCallback onTap;

  const _Cta({
    required this.canOpen,
    required this.loading,
    required this.reasonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canOpen && !loading;
    final label = canOpen ? '🎁  광고보고 상자 열기' : (reasonLabel ?? '내일 다시 만나요');

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: canOpen ? LuckyBoxTokens.lavenderGradient : null,
          color: canOpen ? null : const Color(0xFFE4E0EC),
          borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
          boxShadow: canOpen ? LuckyBoxTokens.lavenderShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
          child: InkWell(
            borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
            onTap: enabled ? onTap : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: LuckyBoxTokens.button.copyWith(
                        color: canOpen
                            ? Colors.white
                            : LuckyBoxTokens.fgMuted,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
