// 신당(THE SHRINE) v4.0 네비게이션 — [provider+Navigator 1.0 고정 정책 포팅]
// 원본은 go_router(선언적 경로, context.go('/shrine/xxx'))를 사용하나, 이
// 프로젝트는 Navigator 1.0(`Navigator.of(context).push`) 으로 고정되어
// 있다. 과거 "통합 Fix 04~05"(A안, 커밋 4a91956)에서 확립된 선례와 동일한
// 방식으로, 1.1초 페이드(Dur.screen)만 유지하는 PageRouteBuilder 헬퍼를
// 제공하고, 원본의 `context.go('$kShrineBase/id')` 호출을 전부
// `ShrineNav.go(context, 'id', params: {...})`로 기계적으로 치환한다.
//
// ⚠ 설계 메모(포팅 결정 사항 — 다음 유지보수 시 참고):
//  · 원본 go_router의 context.go()는 "경로 전체를 교체"하는 선언적 이동이라
//    PUSH/POP 개념이 희미하지만, Navigator 1.0에서는 스택이 명시적이다.
//    화면 로직(screens/*.dart)을 고치지 않는다는 지시(③)를 지키기 위해,
//    원본이 쓴 목적지(back 콜백 포함)를 그대로 ShrineNav.go(push)로
//    옮긴다 — 즉 "뒤로가기 버튼"도 원칙적으로 push 다. 이는 네이티브
//    시스템 뒤로가기를 여러 번 눌러야 신당을 완전히 빠져나가는 결과를
//    낳지만, ShrineNav.exit()(= 「‹ 신통방통」)이 스택 깊이와 무관하게
//    항상 신당 전체를 즉시 빠져나가므로 실사용에 지장이 없다. 추후
//    스택 최적화가 필요하면 이 주석을 참고할 것.
//  · DoorScreenV32 → HallScreen 자동 전환처럼 "뒤로 가면 안 되는" 구간만
//    원본 A안 주석(door→shrine 자동 전환)과 동일하게 replace: true 를 쓴다.
//  · 모든 신당 내부 라우트는 RouteSettings(name: 'shrine:$id')로 표시해,
//    ShrineNav.exit()이 신당이 아닌 라우트(AppShell 등)를 만날 때까지
//    안전하게 pop 할 수 있게 한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import 'shrine_screen_router.dart';

class ShrineNav {
  ShrineNav._();

  /// 단계 건너뛰기 방지 가드 (웹 shrine-app.jsx / 원본 shrine_module.dart
  /// `_guard` 와 동일 로직). 이름(st.name)·주제(topic)·pending 등 선행
  /// 조건이 없으면 적절한 이전 단계로 돌려보낸다.
  static String _guard(BuildContext context, String id) {
    final st = context.read<ShrineSessionProvider>().state;
    final named = st.name != null && st.name!.isNotEmpty;
    if (id == 'talk' && !named) return 'connect';
    if ((id == 'saju' || id == 'recommend') && !named) return 'connect';
    if (id == 'story') return (!named || st.topic == null) ? (named ? 'recommend' : 'connect') : id;
    if (id == 'ritual') return (!named || st.pending == null) ? (named ? 'recommend' : 'connect') : id;
    if (id == 'receive' && st.pending == null) return 'box';
    if (id == 'meaning' && st.meaningSrc == null) return named ? 'recommend' : 'connect';
    return id;
  }

  static PageRoute<dynamic> _fadeRoute(String id, Map<String, String>? params) => PageRouteBuilder(
        settings: RouteSettings(name: 'shrine:$id'),
        transitionDuration: Dur.screen,
        reverseTransitionDuration: Dur.screen,
        pageBuilder: (_, __, ___) => shrineScreenFor(id, params),
        transitionsBuilder: (_, a, __, c) =>
            FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.ease), child: c),
      );

  /// 신당 내부 화면 id로 이동. replace=true면 현재 화면을 스택에서
  /// 교체한다(뒤로가기로 되돌아오면 안 되는 자동 전환 구간 전용).
  static void go(BuildContext context, String id, {Map<String, String>? params, bool replace = false}) {
    final target = _guard(context, id);
    final route = _fadeRoute(target, params);
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  /// 신당 진입점(AppShell의 「신당부적」 탭)에서 최초 1회 호출 — 신당 전체를
  /// 감싸는 첫 라우트를 push 한다. (원본 A안의 `ShrineNav.rootRoute(id)`를
  /// `Navigator.push(context, route)` 형태로 직접 열어주는 방식으로 변경 —
  /// _guard가 Provider state를 읽으려면 context가 필요하기 때문.)
  static void openRoot(BuildContext context, String id, {Map<String, String>? params}) {
    final target = _guard(context, id);
    Navigator.of(context).push(_fadeRoute(target, params));
  }

  /// 기록 초기화 후 신당 입구로 — 신당 내부 스택을 모두 비우고 새로
  /// 시작한다(ResultScreen의 공유뷰 「나도 신당에 들어가기」 등).
  static void goAndClearStack(BuildContext context, String id, {Map<String, String>? params}) {
    final target = _guard(context, id);
    Navigator.of(context).pushAndRemoveUntil(
      _fadeRoute(target, params),
      (route) => route.settings.name == null || !route.settings.name!.startsWith('shrine:'),
    );
  }

  static bool canPop(BuildContext context) => Navigator.of(context).canPop();

  static void pop(BuildContext context) {
    if (canPop(context)) Navigator.of(context).pop();
  }

  /// 「‹ 신통방통」 — 신당 내부 스택 깊이와 무관하게 신당을 완전히 빠져나가
  /// 신통방통(AppShell)으로 돌아간다. (원본 kShrineExit = '/home')
  static void exit(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == null || !route.settings.name!.startsWith('shrine:'),
    );
  }
}
