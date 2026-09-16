import 'package:flutter/material.dart';
import '../../../../theme/lucky_box_tokens.dart';
import 'mini_pouch_icon.dart';

/// [행운상자 - 복주머니 탭 신규 기능] dev-spec.md §3-4 Result 화면.
/// 카운트업(0→n, 900ms, easeOutCubic) + [RewardConfig.rewardMessage]
/// 카피 + "다른 상자 확인하기 (N회)" CTA. dailyLeft == 0이면 CTA가
/// "그리드로" 이동하는 대신 "close"(탭에서 나가기)를 의도하지만, 이 화면은
/// 탭 화면이라 실제로는 항상 그리드로 복귀시키고(뒤로가기 화살표 없음
/// 원칙), 그리드 쪽에서 dailyLeft==0이면 CTA가 자동으로 비활성화된다.
class PouchResultView extends StatefulWidget {
  final int balance;
  final int rewardAmount;
  final bool isJackpot;
  final int dailyLeft;
  final VoidCallback onDone;

  const PouchResultView({
    super.key,
    required this.balance,
    required this.rewardAmount,
    required this.isJackpot,
    required this.dailyLeft,
    required this.onDone,
  });

  @override
  State<PouchResultView> createState() => _PouchResultViewState();
}

class _PouchResultViewState extends State<PouchResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _count;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: LuckyBoxTokens.countUp,
    );
    _count = IntTween(begin: 0, end: widget.rewardAmount).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = RewardConfig.rewardMessage(widget.rewardAmount);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LuckyBoxTokens.sp5,
          LuckyBoxTokens.sp4,
          LuckyBoxTokens.sp5,
          LuckyBoxTokens.sp8,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '복주머니',
                  style: LuckyBoxTokens.title.copyWith(
                    color: LuckyBoxTokens.fgPrimary,
                  ),
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
                        '${widget.balance}',
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
            ),
            const Spacer(),
            Text(
              '◇ FORTUNE ◇',
              style: LuckyBoxTokens.monoLabel.copyWith(
                color: LuckyBoxTokens.accentGlowDark,
              ),
            ),
            const SizedBox(height: LuckyBoxTokens.sp6),
            AnimatedBuilder(
              animation: _count,
              builder: (context, _) {
                return ShaderMask(
                  shaderCallback: (bounds) =>
                      LuckyBoxTokens.countUpGradient.createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    '+ ${_count.value} 개',
                    style: LuckyBoxTokens.hero.copyWith(fontSize: 56),
                  ),
                );
              },
            ),
            const SizedBox(height: LuckyBoxTokens.sp5),
            Text(
              '복주머니 GET',
              style: LuckyBoxTokens.title.copyWith(
                color: LuckyBoxTokens.fgPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: LuckyBoxTokens.sp2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LuckyBoxTokens.bodyText.copyWith(
                color: LuckyBoxTokens.fgSecondary,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: LuckyBoxTokens.ctaPrimaryBg,
                  borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
                  boxShadow: LuckyBoxTokens.blackShadow,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(LuckyBoxTokens.rPill),
                    onTap: widget.onDone,
                    child: Center(
                      child: Text(
                        widget.dailyLeft > 0
                            ? '다른 상자 확인하기 (${widget.dailyLeft}회)'
                            : '내일 다시 만나요',
                        style: LuckyBoxTokens.button.copyWith(
                          color: LuckyBoxTokens.ctaPrimaryFg,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
