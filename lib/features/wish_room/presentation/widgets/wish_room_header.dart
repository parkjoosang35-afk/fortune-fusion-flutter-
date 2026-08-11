import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import 'wish_room_animations.dart';

/// [소원방 Riverpod 실험판] 상단 헤더 — 타이틀 + 도움말.
///
/// [Sprint 1 QA 수정] "설정" 아이콘 버튼을 제거했다. 이전에는
/// `onSettingsTap` 콜백이 옵셔널(nullable)로 선언되어 있었는데
/// `WishRoomScreen`이 이 콜백을 어디서도 전달하지 않아 눌러도 아무 반응이
/// 없는 죽은 버튼이었다. 게다가 아이콘 색상이 `WishRoomColors.textSecondary`로
/// 고정되어 있어 비활성 상태처럼 흐려 보이지도 않고 마치 정상 동작하는
/// 버튼처럼 보였다(사용자를 오도하는 UI). ⑫-② 화면 스펙에도 설정 기능은
/// 명시되어 있지 않고 MVP 범위에도 소원방 전용 설정 화면이 없으므로,
/// 실제 기능이 뒷받침되기 전까지는 버튼 자체를 노출하지 않는 것으로 수정.
///
/// [UI 전면 개선] 타이틀에 진입 페이드인을 추가하고, 도움말 버튼에 은은한
/// 펄스 글로우를 줘 "눌러볼 수 있는 도움말이 있다"는 것을 자연스럽게
/// 인지시킨다.
class WishRoomHeader extends StatelessWidget {
  final VoidCallback onHelpTap;

  const WishRoomHeader({super.key, required this.onHelpTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WishRoomSpacing.md,
        WishRoomSpacing.md,
        WishRoomSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: FadeSlideIn(
              offsetY: -10,
              child: Text('소원방', style: WishRoomTextStyles.titleXl),
            ),
          ),
          BreathingGlow(
            glowColor: WishRoomColors.gold,
            borderRadius: WishRoomRadius.pill,
            minAlpha: 0.0,
            maxAlpha: 0.18,
            blurRadius: 12,
            child: TapBounce(
              onTap: onHelpTap,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.help_outline,
                  color: WishRoomColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
