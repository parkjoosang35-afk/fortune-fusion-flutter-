import 'package:flutter/material.dart';
import 'text_scale_fab.dart';

/// [결과페이지 글씨 확대 기능 — 배치 수정, 2026-11] 글씨 크기 조절 캡슐을
/// "앱 전체 화면"이 아니라 "결과 페이지 각각"에만 노출하기 위한 래퍼.
///
/// [배경 — 사용자 피드백] 처음 구현(app.dart의 MaterialApp.builder에서
/// Stack으로 전역 오버레이)은 홈 화면을 포함한 모든 화면에 캡슐이 뜨는
/// 바람에 메인 하단 네비게이션 바(홈/신당부적/복주머니/마이)를 가리는
/// 문제가 있었다("메인 하단바에 이렇게 해놓으면 어떻게해 하단바가
/// 가리잔아 결과페이지에 해놔야지"). 글씨 배율 자체를 적용하는 로직
/// (TextScaleProvider + MaterialApp.builder의 TextScaler)은 올바르게
/// 전역으로 유지하되(결과 화면에서 켠 배율이 그 위에서 열리는 다이얼로그/
/// 시트에도 반영되어야 하므로), "캡슐 버튼"만 각 결과 화면이 개별적으로
/// 자신의 최상위 반환 위젯(Scaffold 등)을 이걸로 감싸는 방식으로 바꾼다.
///
/// [위치 — centerRight 고정] 결과 화면마다 하단 구조가 제각각이라
/// (하단바만 있는 화면/하단바+footer 버튼이 모두 있는 화면/하단바가 아예
/// 없는 화면 등) bottomRight처럼 화면마다 다른 여백 계산을 하는 대신,
/// 화면 높이 중앙의 오른쪽 가장자리에 고정한다 — 상단(앱바/뒤로가기
/// 버튼)과 하단(footer CTA/MainBottomNavBar)을 모두 피하면서, 스크롤
/// 가능한 본문 위에 작게 떠 있는 상태라 콘텐츠를 가리는 영역도 최소화된다.
class ResultTextScaleOverlay extends StatelessWidget {
  const ResultTextScaleOverlay({
    super.key,
    required this.child,
    this.alignment = const Alignment(1.0, 0.0),
  });

  /// 결과 화면의 최상위 위젯(보통 Scaffold).
  final Widget child;

  /// 캡슐 위치. 기본값은 화면 오른쪽 가장자리 세로 중앙(centerRight).
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: SafeArea(
              child: Align(
                alignment: alignment,
                child: TextScaleFab(alignment: alignment),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
