// ═══════════════════════════════════════════════════════════════
// FILE: sintong_v2_topbar.dart
// [신통방통 홈 v2] 히어로 위에 겹쳐지는 상태바+탑바 — README §status/
// §topbar 스펙(좌측 브랜드모노 라벨 + 우측 메뉴 버튼)을 그대로 재현하되,
// 기존 화면(v1 SintongBrandAppBar)이 제공하던 지갑 잔액/알림 뱃지/
// 프로필 진입 기능을 잃지 않도록 메뉴 버튼 대신 3개의 원형 아이콘
// (코인 pill/알림 벨/프로필)을 동일한 다크 유리 스타일로 추가한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../auth/application/auth_provider.dart';
import '../../../../notification/notification_provider.dart';
import '../../../../wallet/application/wallet_provider.dart';
import '../sintong_home_v2_tokens.dart';

class SintongV2TopBar extends StatelessWidget {
  const SintongV2TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
      child: Row(
        children: [
          Text('신통방통', style: SHomeV2Text.brandMono()),
          const Spacer(),
          // 코인 pill — 지갑 잔액(기존 v1 기능 유지).
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/reward/wallet'),
            child: Consumer<WalletProvider>(
              builder: (context, wallet, _) => Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x24FFFFFF),
                  borderRadius: BorderRadius.circular(SHomeV2Radii.pill),
                  border: Border.all(
                    color: const Color(0x38FFFFFF),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '${wallet.balance}',
                      style: SHomeV2Text.brandMono().copyWith(
                        letterSpacing: 0,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 알림 벨 — 기존 v1 기능 유지.
          _CircleIconBtn(
            onTap: () => Navigator.of(context).pushNamed('/my/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  notif.unreadCount > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                if (notif.unreadCount > 0)
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: _Dot(),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 프로필/로그인 — 기존 v1 기능 유지.
          _CircleIconBtn(
            onTap: () => Navigator.of(
              context,
            ).pushNamed(auth.isLoggedIn ? '/my/settings' : '/login'),
            child: const Icon(
              Icons.person_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: const Color(0xFFE0525C),
        shape: BoxShape.circle,
        border: Border.all(color: SHomeV2Colors.sheetBg, width: 1.2),
      ),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x24FFFFFF),
          border: Border.all(color: const Color(0x38FFFFFF), width: 0.5),
        ),
        child: child,
      ),
    );
  }
}
