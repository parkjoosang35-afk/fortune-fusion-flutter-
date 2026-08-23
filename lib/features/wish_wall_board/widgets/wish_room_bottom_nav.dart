import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [디자인 핸드오프 적용] `wish-screens.jsx`의 `BottomNav({active})` 공용
/// 네비게이션 바. 04 Home과 06 Feed 두 화면에서만 사용된다(디자인 원본
/// 확인 결과 그 외 화면에는 이 바가 없음).
///
/// [하단바 원칙] 앱 전역 5탭 [AppShell] 바와는 완전히 별개다. 이 위젯은
/// "소원방" 탭 안에서 push되는 화면들(홈/피드) 자체가 그리는 장식용
/// 네비게이션이다.
class WishRoomBottomNav extends StatelessWidget {
  const WishRoomBottomNav({
    super.key,
    required this.active,
    required this.onHome,
    required this.onFeed,
    required this.onRecord,
  });

  /// 'home' | 'feed' | 'me'
  final String active;
  final VoidCallback onHome;
  final VoidCallback onFeed;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final items = <(String id, String icon, String label, VoidCallback onTap)>[
      ('home', '🕯', '나의 소원', onHome),
      ('feed', '☾', '모두의 소원', onFeed),
      ('me', '◈', '기록', onRecord),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            WishRoomColors.backgroundDeep.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.4],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((it) {
          final on = it.$1 == active;
          final color = on ? WishRoomColors.glow : WishRoomColors.textSecondary;
          return InkWell(
            onTap: it.$4,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(it.$2, style: TextStyle(fontSize: 18, color: color)),
                  const SizedBox(height: 4),
                  Text(
                    it.$3,
                    style: TextStyle(
                      fontFamily: 'GowunBatangWish',
                      fontSize: 10,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
