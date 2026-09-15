// ═══════════════════════════════════════════════════════════════
// FILE: sintong_brand_app_bar.dart
// [신통방통 메인 매핑] C-01 · BrandAppBar — Handoff.html §06
// 좌측 브랜드 로고("신통" ink + "방통" ember, Fraunces Italic 20) +
// 우측 코인 pill · 알림 벨 · 프로필 아바타(모두 30×30 원형 아이콘).
//
// [기능 보존] 기존 `_TopHeader`의 라우팅/데이터 로직(지갑 잔액 Provider,
// 알림 뱃지 카운트, 로그인 상태별 프로필/로그인 이동)을 그대로 유지하고
// 시각 스타일만 새 디자인 스펙으로 재구현한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/application/auth_provider.dart';
import '../../../../notification/notification_provider.dart';
import '../../../../wallet/application/wallet_provider.dart';
import '../sintong_home_tokens.dart';

class SintongBrandAppBar extends StatelessWidget {
  const SintongBrandAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final auth = context.watch<AuthProvider>();

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // 브랜드 로고 — "신통"(ink) + "방통"(ember), 둘 다 Fraunces Italic 500 20px.
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '신통',
                  style: SintongHomeText.brand(color: SintongHomeColors.ink),
                ),
                TextSpan(
                  text: '방통',
                  style: SintongHomeText.brand(color: SintongHomeColors.ember),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 코인 pill — 지갑 잔액. 탭 시 복주머니 지갑 상세로 이동(기존 동작 유지).
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            child: Consumer<WalletProvider>(
              builder: (context, wallet, _) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: SintongHomeColors.coinPillBg,
                  borderRadius: BorderRadius.circular(SintongHomeRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('${wallet.balance}', style: SintongHomeText.coinCount),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 알림 벨 — 30×30 원형, 미확인 알림 있으면 우상단 도트 뱃지.
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
            child: SizedBox(
              width: 30,
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    notif.unreadCount > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    size: 20,
                    color: SintongHomeColors.ink,
                  ),
                  if (notif.unreadCount > 0)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.premiumCoralAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: SintongHomeColors.background,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 프로필 아바타 — 로그인 상태면 마이페이지, 아니면 로그인 화면.
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).pushNamed(auth.isLoggedIn ? '/my/settings' : '/login'),
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: SintongHomeColors.coinPillBg,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_rounded,
                size: 16,
                color: SintongHomeColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
