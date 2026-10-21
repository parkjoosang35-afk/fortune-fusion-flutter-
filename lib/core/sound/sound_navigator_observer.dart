import 'package:flutter/widgets.dart';

import 'sintong_sound_service.dart';

/// [신통방통 사운드 배치 개발 기획서 §8.1 공통 이벤트 nav.push/nav.pop]
/// "스택에 새 화면 push 완료" → `07_page_in`, "뒤로가기·모달 닫기" →
/// `08_page_back`을 앱 전체 단일 지점에서 재생한다.
///
/// [2026-11 — 대표님 피드백 "다른데로 클릭시 음향전환이 돼는것도 잇고
/// 안돼는것도잇고" 대응] 기존에는 화면 8개의 "진입 위젯" 각각에
/// `SoundRouteTrigger`를 수동으로 심는 방식이었다. 이 방식의 실패 사례가
/// 실제로 발견됐다 — 예를 들어 `/tarot/home` named route의 실제 위젯은
/// `OzTarotHomeScreen`인데 `SoundRouteTrigger`는 더 이상 쓰이지 않는 구
/// `TarotHomeScreen`에만 걸려 있어, 타로 메뉴는 BGM이 "전혀" 전환되지
/// 않고 있었다. 이런 화면별 실수를 구조적으로 방지하기 위해, 이제부터는
/// **화면 위젯이 무엇이든 상관없이 Navigator 레벨의 route.settings.name
/// 하나만 보고 BGM을 결정**한다 — 새 화면을 추가해도 라우트 이름만
/// `app_router.dart`에 등록하면 사운드가 자동으로 따라온다.
///
/// [전제 조건] `route.settings.name`이 채워져 있으려면 그 라우트를 만든
/// 헬�어(`AppRouter._page`/`_pageNamed`/`_guinjiPage`/
/// `sajuDimensionEnterRoute` 등)가 `RouteSettings(name: ...)`를 실제로
/// 전달해야 한다. 과거엔 `_page()`가 이를 누락하고 있어
/// `route.settings.name`이 항상 null이었다 — 이번에 해당 헬퍼들을 함께
/// 수정했다(app_router.dart, guinji_page_route.dart,
/// saju_dimension_transition.dart 참고).
///
/// [didPush/didPop/didReplace 3곳 모두 처리하는 이유] 이 앱은
/// `pushNamed`(push) 뿐 아니라 `pushReplacementNamed`(화면 교체,
/// didReplace 호출)와 뒤로가기(pop, 이전 화면이 다시 보임)도 광범위하게
/// 쓴다(예: 스플래시→홈, 타로 인트로→타로 홈, AI 결과→히스토리 redirect
/// 전부 pushReplacementNamed). 셋 중 하나만 처리하면 그 경로로 들어온
/// 전환은 BGM이 멈춘 것처럼 보이므로 셋 모두 동일한 매핑 로직을 탄다.
///
/// [과도한 트리거 방지] 다이얼로그/바텀시트도 내부적으로 push를 호출해
/// 이 Observer를 거치지만, `playRoute()`가 "동일 라우트 재호출 시
/// no-op"이고 또 그 라우트들은 보통 이름이 없거나(`settings.name==null`)
/// 매핑 테이블에 없는 이름이라 BGM에는 영향을 주지 않는다(SFX 07/08만
/// 재생).
class SoundNavigatorObserver extends NavigatorObserver {
  SoundNavigatorObserver(this._sound);

  final SintongSoundService _sound;

  /// `sound_routes.json`의 8개 메뉴 키(main/saju/guide/tarot/wish/face/
  /// palm/shrine) 각각에 대응하는 named route 접두사 목록. `startsWith`로
  /// 매칭하므로 그 메뉴의 "하위 화면"(질문입력/로딩/결과/히스토리 등)까지
  /// 전부 자동으로 커버된다 — 과거 "진입 화면 1개에만 트리거"의 한계를
  /// 구조적으로 없앤다.
  static const Map<String, List<String>> _routePrefixes = {
    'main': ['/home'],
    'saju': [
      '/saju-renewal',
      '/saju/v3',
      '/jeontong',
      '/ai-fortune/saju',
    ],
    'guide': ['/guinji', '/g'],
    'tarot': ['/tarot/', '/ai-fortune/tarot'],
    'wish': ['/wish-room', '/wish-wall', '/onboarding', '/w/'],
    'face': ['/ai-fortune/face'],
    'palm': ['/ai-fortune/palm'],
    // 신당 내부 네비게이션(ShrineNav._fadeRoute/openRoot)은
    // `RouteSettings(name: 'shrine:$id')` 형태라 '/'로 시작하지 않는다.
    'shrine': ['/shrine', 'shrine:'],
  };

  /// [REQ — 사용자 "전체보기/운세 하위 상세 화면에서는 전환이 안된다"
  /// 문제 방지] 라우트 이름 하나로 8개 메뉴 중 어디에도 속하지 않으면
  /// null을 반환한다 — 이 경우 playRoute를 아예 호출하지 않고 현재 BGM을
  /// 그대로 유지한다(예: 리워드/상점/쿠폰/마이 화면은 전용 BGM이 설계에
  /// 없으므로 직전 메뉴의 BGM이 자연스럽게 이어진다).
  static String? _resolveRouteKey(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final entry in _routePrefixes.entries) {
      for (final prefix in entry.value) {
        if (name == prefix || name.startsWith(prefix)) return entry.key;
      }
    }
    return null;
  }

  void _applyForRoute(Route<dynamic>? route) {
    final key = _resolveRouteKey(route?.settings.name);
    if (key == null) return;
    try {
      _sound.playRoute(key);
    } catch (_) {
      // [저사양 degrade] 사운드 서비스 미등록/초기화 실패가 네비게이션
      // 자체를 막아서는 절대 안 된다.
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sound.playEvent('nav.push');
    _applyForRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sound.playEvent('nav.pop');
    // pop 이후 실제로 "다시 보이는" 화면은 route가 아니라 previousRoute다
    // — 예: 타로 하위 화면에서 뒤로가기를 눌러 홈으로 돌아오면
    // previousRoute.settings.name이 '/home'이므로 여기서 'main' BGM으로
    // 정확히 복귀한다(기존 IndexedStack 탭 복귀 미반영 문제의 핵심 수정).
    _applyForRoute(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    // pushReplacementNamed 경로(스플래시→홈, 타로 인트로→타로 홈,
    // AI사주 구 라우트→정통사주 리뉴얼 redirect 등)가 전부 이 콜백을
    // 탄다 — didPush만 보면 이 전환들의 BGM 전환이 누락된다.
    _applyForRoute(newRoute);
  }
}
