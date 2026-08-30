import 'package:flutter/material.dart';

import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_bg_atmosphere.dart';
import '../widgets/wish_room_buttons.dart';

/// 소원방(Wish Room) — 이용안내 화면.
///
/// [배경] 과거 버전은 홈 화면 상단의 "이용안내" 버튼을 누르면 최초 1회만
/// 노출되어야 할 [WishRoomOnboardingScreen](입장 게이트)을 그대로
/// 재사용했다. 그 화면은 "소원방 들어가기" CTA만 있을 뿐 실제 기능
/// 설명이 전혀 없어 사용자가 "이용안내를 눌렀는데 아무 설명도 없다"고
/// 느끼는 원인이었다. 이 화면은 그 문제를 해결하기 위해 새로 작성한
/// **진짜 이용안내 콘텐츠**이며, 온보딩 게이트와는 완전히 분리된
/// 별도의 정적 설명 화면이다(입장 플래그를 건드리지 않는다).
class WishRoomGuideScreen extends StatelessWidget {
  const WishRoomGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: WishRoomBgAtmosphere(sigilSize: 420, sigilOpacity: 0.28),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      WishRoomIconButton(
                        icon: '←',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '소원방 이용안내',
                          style: WishRoomTextStyles.sectionTitle,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: const [
                      _GuideSection(
                        emoji: '🕯️',
                        title: '촛불 켜기',
                        body:
                            '매일 한 번, 내 소원 앞에 촛불을 켤 수 있어요.\n'
                            '촛불을 켜면 소원의 정성이 조금씩 쌓이고,\n'
                            '작은 복주머니 보상도 함께 받을 수 있어요.',
                      ),
                      _GuideSection(
                        emoji: '💛',
                        title: '응원하기',
                        body:
                            '다른 사람이 쓴 소원에 응원을 보낼 수 있어요.\n'
                            '내가 보낸 응원은 그 소원을 쓴 사람에게 전달되어\n'
                            '정성으로 쌓이고, 소원이 자라는 데 도움이 돼요.',
                      ),
                      _GuideSection(
                        emoji: '🧧',
                        title: '복주머니 주고받기',
                        body:
                            '복주머니는 소원방의 마음을 전하는 화폐예요.\n'
                            '다른 사람의 소원에 복주머니를 보내면 누가 보냈는지\n'
                            '전달되고, 내가 받은 복주머니는 "받은 선물함"에서\n'
                            '확인하고 받을 수 있어요.',
                      ),
                      _GuideSection(
                        emoji: '✨',
                        title: '소원 만들기 & 자라나는 소원',
                        body:
                            '마음속 바람을 소원으로 적어 봉인하면,\n'
                            '정성이 쌓일수록 촛불의 밝기와 상태가 자라나요.\n'
                            '시간이 지나 소원이 열리면 그 결과를 확인할 수 있어요.',
                      ),
                      _GuideSection(
                        emoji: '🙏',
                        title: '모두의 소원',
                        body:
                            '다른 사람들의 소원을 둘러보고 함께 빌어줄 수 있어요.\n'
                            '누가 이 소원을 응원했는지도 함께 확인할 수 있어요.',
                      ),
                      _GuideSection(
                        emoji: '🚫',
                        title: '신고 · 숨기기 · 차단',
                        body:
                            '불편한 소원이나 댓글은 카드의 "⋯" 버튼을 눌러\n'
                            '신고하거나, 내 화면에서만 숨기거나, 작성자를\n'
                            '차단할 수 있어요. 신고 시 사유를 직접 선택해요.',
                      ),
                      _GuideSection(
                        emoji: '🗑️',
                        title: '내 소원 삭제',
                        body:
                            '내가 쓴 소원은 "내 소원" 화면에서 언제든 삭제할\n'
                            '수 있어요. 삭제한 소원은 목록에서 사라지고\n'
                            '더 이상 다른 사람에게 보이지 않아요.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(title, style: WishRoomTextStyles.wishBodyDetail),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: WishRoomTextStyles.bodyMd),
        ],
      ),
    );
  }
}
