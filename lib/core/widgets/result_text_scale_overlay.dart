import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/text_scale_provider.dart';
import 'text_scale_fab.dart';

/// [결과페이지 글씨 확대 기능 — 배치 수정, 2026-11] 글씨 크기 조절 캡슐을
/// "앱 전체 화면"이 아니라 "결과 페이지 각각"에만 노출하고, 배율도 그
/// 결과 화면 하나에만 적용하기 위한 래퍼.
///
/// [배경 — 사용자 피드백 ①] 처음 구현(app.dart의 MaterialApp.builder에서
/// Stack으로 전역 오버레이)은 홈 화면을 포함한 모든 화면에 캡슐이 뜨는
/// 바람에 메인 하단 네비게이션 바(홈/신당부적/복주머니/마이)를 가리는
/// 문제가 있었다("메인 하단바에 이렇게 해놓으면 어떻게해 하단바가
/// 가리잔아 결과페이지에 해놔야지"). → 캡슐을 결과 화면 개별 배치로 옮김.
///
/// [배경 — 사용자 피드백 ②, 이번 수정] 캡슐은 결과 화면에만 뜨도록
/// 고쳤지만, 배율 자체(TextScaler)는 여전히 app.dart의
/// MaterialApp.builder(= 모든 라우트의 공통 조상, Navigator 바깥)에서
/// 적용하고 있었다. 그 결과 한 결과페이지에서 배율을 올리면 그 상태가
/// 전역에 남아, 결과페이지를 벗어나 홈 등 다른 화면으로 가도 계속 커진
/// 글씨로 보이는 문제가 있었다("결과페이지에서 한번 하면 다시 원복이
/// 돼야 하는데... 전체 확대된 글로 나오는것 같아"). → 배율 적용 지점을
/// app.dart(전역)에서 이 위젯(결과 화면 하나의 child 서브트리)으로
/// 옮긴다. 이제 다른 결과 화면으로 이동하면 그 화면은 자기 자신의
/// [TextScaleProvider] 값을 다시 읽어 독립적으로 반영하지만(=설정 자체는
/// 여전히 전역으로 저장/기억됨 — 다음에 아무 결과화면에 들어가도 마지막
/// 배율이 유지됨), 결과화면이 아닌 홈/하단바 화면에는 애초에 이 위젯이
/// 적용되지 않으므로 글씨가 커질 일이 없다.
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
    final scale = context.watch<TextScaleProvider>().scale;
    // [범위 제한] 이 MediaQuery는 child(이 결과 화면 하나)에만 적용된다 —
    // 캡슐(TextScaleFab) 자신은 이 MediaQuery 바깥에 둬서 "가-/100%/가+"
    // 버튼 자체 크기는 배율과 무관하게 항상 일정하게 유지한다.
    final scaledChild = scale == 1.0
        ? child
        : MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child,
          );
    return Stack(
      children: [
        scaledChild,
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
