// ═══════════════════════════════════════════════════════════════
// FILE: gunghap_coming_soon_screen.dart
// [궁합지도 Star Map 디자인 적용] 이번 턴 구현 범위 경계 화면.
//
// 정식 개발 지시서(15섹션)의 04(나의 정보 입력)부터는 실제 회원
// 사주 조회, 초대장 토큰 발급, 사주 FACT 궁합 계산, 복주머니 결제
// 연동 등 백엔드가 필요하다 — 이번 턴은 "궁합지도 클릭시 지금 디자인
// 나오게"라는 축소된 요청 범위이므로 01~03(메인 홈 → 대분류 →
// 세부 카테고리)까지만 실제 클릭 흐름으로 구현하고, 그 다음은 같은
// Star Map 테마를 유지한 안내 화면으로 자연스럽게 멈춘다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../../../core/router/main_bottom_nav_bar.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import '../widgets/gh_button.dart';
import '../widgets/gh_screen.dart';

class GunghapComingSoonScreen extends StatelessWidget {
  const GunghapComingSoonScreen({super.key, required this.title, this.stepLabel});
  final String title;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    return GHScreen(
      // [하단바 누락 수정] 기존 공용 하단바 재사용(currentIndex: 0=홈).
      bottomNav: const MainBottomNavBar(currentIndex: 0),
      appBar: GHAppBar(title: title, onBack: () => Navigator.of(context).pop()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.auto_awesome, color: GHColors.gold, size: 40),
          const SizedBox(height: 20),
          if (stepLabel != null) ...[
            Center(child: GHMono(stepLabel!, color: GHColors.gold)),
            const SizedBox(height: 10),
          ],
          Text(
            '이 화면은 준비 중이에요',
            textAlign: TextAlign.center,
            style: GHText.title(size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            '실제 사주 정보 입력과 궁합 분석은\n정식 서비스 업데이트에서 만나볼 수 있어요.',
            textAlign: TextAlign.center,
            style: GHText.ui(size: 14, height: 1.6, color: GHColors.gray),
          ),
          const SizedBox(height: 32),
          GHButton(
            label: '처음으로 돌아가기',
            variant: GHButtonVariant.secondary,
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      ),
    );
  }
}
