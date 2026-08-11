import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';

/// [디자인 핸드오프 적용 — "마법진이 소환되는 신전"] 하단 탭 네비게이션.
///
/// `wish-screens.jsx`의 `BottomNav({active})` 스펙을 그대로 재구현.
/// 3개 탭: home(🕯 "나의 소원") / feed(☾ "모두의 소원") / me(◈ "신전관리").
/// README/JSX 원본은 "기록"(◈)이었으나, 이번 대형 작업 지시("있는 기능은
/// 페이지 한칸을 더 만들어서 구현 다시 구현")에 따라 세 번째 탭을 기존
/// 성장/슬롯/치성/꾸미기 기능을 모아두는 "신전관리" 허브로 재정의했다 —
/// 아이콘(◈)과 위치는 원본 스펙을 그대로 따른다.
///
/// 스펙: position absolute bottom, padding 10px 20px 30px, 위에서
/// 아래로 옅어지는 게 아니라 transparent→bg-2 40%로 짙어지는 그라디언트
/// 페이드 배경. 활성 탭은 drop-shadow(glow-shadow) 필터.
class WishRoomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const WishRoomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (icon: '🕯', label: '나의 소원'),
    (icon: '☾', label: '모두의 소원'),
    (icon: '◈', label: '신전관리'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, WishRoomColors.backgroundDeep],
          stops: [0.0, 0.6],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isActive = index == currentIndex;
          return _NavButton(
            icon: item.icon,
            label: item.label,
            isActive: isActive,
            onTap: () => onTap(index),
          );
        }),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? WishRoomColors.glow
        : WishRoomColors.textSecondary;
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WishRoomRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WishRoomSpacing.md,
            vertical: WishRoomSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: isActive
                    ? BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: WishRoomColors.glowShadow,
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      )
                    : const BoxDecoration(),
                child: Text(icon, style: TextStyle(fontSize: 20, color: color)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: WishRoomTextStyles.pillLabel.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
