// shrine_navigation.dart — [통합 Fix 04] 신당 스타터는 go_router(선언적
// 라우팅, `context.go('/path')`)를 썼으나, 이 프로젝트는 Navigator 1.0
// (`onGenerateRoute`) 패턴으로 고정되어 있다. 화면 전환은 신당 디자인
// 토큰이 요구하는 "1.1s 크로스페이드만"(신당_개발지시서_v1.4.pdf 변경 금지
// 값)을 유지하기 위해 PageRouteBuilder + FadeTransition으로 감싼 헬퍼를
// 제공한다. 신당 스타터의 context.go(path)/context.pop() 호출을
// ShrineNav.go(context, id)/ShrineNav.pop(context) 로 치환해 사용한다.
import 'package:flutter/widgets.dart';
import '../domain/shrine_rite_data.dart';
import 'shrine_screen_router.dart';
import '../domain/shrine_tokens.dart';

class ShrineNav {
  ShrineNav._();

  /// rite.dart(현 shrine_rite_data.dart)의 id(예: 'entry', 'door')로 이동.
  /// replace=true면 현재 화면을 교체(뒤로가기 시 신당으로 되돌아오지
  /// 않도록, 예: door→shrine 자동 전환에 사용).
  static void go(BuildContext context, String id, {bool replace = false}) {
    final route = _fadeRoute(id);
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  /// 의식 전체를 끝내고 신당 입구(entry)로 완전히 되돌아갈 때 사용 —
  /// 스택에 쌓인 모든 신당 화면을 제거한다.
  static void goAndClearStack(BuildContext context, String id) {
    Navigator.of(context).pushAndRemoveUntil(_fadeRoute(id), (route) => false);
  }

  static PageRoute<dynamic> _fadeRoute(String id) => PageRouteBuilder(
        transitionDuration: ShrineMotion.screen,
        reverseTransitionDuration: ShrineMotion.screen,
        pageBuilder: (_, __, ___) => shrineScreenFor(id),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.ease), child: c),
      );

  static bool canPop(BuildContext context) => Navigator.of(context).canPop();

  static void pop(BuildContext context) {
    if (canPop(context)) Navigator.of(context).pop();
  }

  /// [통합 Fix 05] 신당 화면 전체를 감싸는 PopScope 콜백 — 시스템
  /// 뒤로가기(Android 하드웨어 백버튼/브라우저 뒤로가기)를 신당 내부
  /// 스택으로 흡수한다(pouch_box_tab_screen.dart와 동일한 패턴).
  static bool get canPopDefault => true;
}

ShrineRouteDef shrineRouteById(String id) => shrineRoutes.firstWhere((r) => r.id == id);
