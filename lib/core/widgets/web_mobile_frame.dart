import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// [PC 웹 미리보기 개선] 데스크톱 브라우저에서 앱을 열었을 때, 화면 전체를
/// 꽉 채우는 대신 실제 스마트폰과 비슷한 폭으로 중앙에 고정해서 보여준다.
///
/// [배경] 이 앱은 모바일 전용으로 디자인되어 있어(세로형 레이아웃), PC
/// 브라우저 창을 그대로 채우면 글자/버튼이 지나치게 커 보이고 레이아웃이
/// 어색해진다. sintong.kr/app/ 처럼 PC에서도 접속 가능한 웹 배포를 하게
/// 되면서, 실제로 이 문제가 사용자에게 체감되었다.
///
/// [적용 범위] 웹 플랫폼(kIsWeb)에서만 동작하고, 안드로이드 APK/실제 모바일
/// 브라우저 폭에서는 화면 폭이 이미 [maxWidth] 이하이므로 시각적으로 아무
/// 변화가 없다(기존 프로덕션 동작과 동일). 즉 이 위젯은 "PC에서 볼 때만"
/// 실질적으로 효과가 있다.
class WebMobileFrame extends StatelessWidget {
  const WebMobileFrame({super.key, required this.child});

  final Widget child;

  /// 일반적인 스마트폰 화면 폭(iPhone 14 Pro 기준 393, 여유를 두어 430으로
  /// 설정). 이 폭보다 브라우저 창이 넓으면 중앙에 이 폭만큼만 앱을 그리고
  /// 나머지는 배경색으로 채운다.
  static const double maxWidth = 430;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 이미 모바일 폭(모바일 브라우저로 접속)이면 그대로 통과시킨다.
        if (constraints.maxWidth <= maxWidth) return child;

        // PC처럼 넓은 화면이면 중앙에 모바일 폭만큼만 앱을 배치하고,
        // 좌우 여백은 어두운 배경색으로 채워 "폰 화면을 보는 느낌"을 준다.
        return ColoredBox(
          color: const Color(0xFF1A1A2E),
          child: Center(
            child: SizedBox(
              width: maxWidth,
              height: constraints.maxHeight,
              child: Material(child: child),
            ),
          ),
        );
      },
    );
  }
}
