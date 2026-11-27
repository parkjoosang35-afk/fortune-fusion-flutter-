import 'package:flutter/material.dart';
import '../../../core/theme/app_unified_style.dart';
import '../../../core/theme/dark_page_theme.dart';
import '../domain/bokju_coupon_model.dart';

/// [복주머니 마케팅 쿠폰] 등록 성공 화면 — 지급된 복주머니 수량과 등록 후
/// 잔액을 보여주는 축하 화면. "완료" 버튼으로 홈(AppShell)으로 돌아간다.
class BokjuCouponSuccessScreen extends StatelessWidget {
  const BokjuCouponSuccessScreen({super.key, required this.result});

  final BokjuCouponRedeemResult result;

  @override
  Widget build(BuildContext context) {
    return DarkPage(
      child: Scaffold(
        backgroundColor: UnifiedColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: UnifiedColors.black.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    color: UnifiedColors.black,
                    size: 52,
                  ),
                ),
                const SizedBox(height: UnifiedTokens.spaceXxl),
                Text(
                  '쿠폰 등록 완료!',
                  style: UnifiedText.titleLarge().copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: UnifiedTokens.spaceMd),
                Text(
                  '복주머니 ${_comma(result.grantedAmount)}개가 적립되었어요',
                  style: UnifiedText.body(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: UnifiedTokens.spaceXxl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
                  decoration: BoxDecoration(
                    color: UnifiedColors.cardMain,
                    borderRadius:
                        BorderRadius.circular(UnifiedTokens.radiusLg),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('적립 복주머니', style: UnifiedText.body()),
                          Text(
                            '+${_comma(result.grantedAmount)}개',
                            style: UnifiedText.bodyStrong(
                              color: UnifiedColors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: UnifiedTokens.spaceSm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('현재 잔액', style: UnifiedText.body()),
                          Text(
                            '${_comma(result.balanceAfter)}개',
                            style: UnifiedText.bodyStrong(),
                          ),
                        ],
                      ),
                      if (result.replayed) ...[
                        const SizedBox(height: UnifiedTokens.spaceSm),
                        Text(
                          '※ 이미 처리된 요청으로 중복 지급되지 않았습니다.',
                          style: UnifiedText.caption(),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UnifiedColors.black,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(UnifiedTokens.radiusPill),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/home',
                        (route) => false,
                      );
                    },
                    child: const Text(
                      '완료',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _comma(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
