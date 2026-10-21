import 'package:flutter/widgets.dart';

import 'sintong_sound_service.dart';

/// [신통방통 사운드 배치 개발 기획서 §8.1 공통 이벤트 nav.push/nav.pop]
/// "스택에 새 화면 push 완료" → `07_page_in`, "뒤로가기·모달 닫기" →
/// `08_page_back`을 앱 전체 단일 지점에서 재생한다.
///
/// [기존 WebNavBridgeObserver와 동일한 패턴] `app.dart`의
/// `navigatorObservers: [WebNavBridgeObserver(), ...]` 목록에 추가하는
/// 방식으로, 화면 각각에 재생 코드를 심지 않고 네비게이션 레이어
/// 한 곳에서 모든 push/pop을 포착한다.
///
/// [과도한 트리거 방지] 다이얼로그/바텀시트(`showDialog`,
/// `showModalBottomSheet`)도 내부적으로 push를 호출하므로 이 Observer를
/// 거친다. 기획서 §5.2가 "모달·바텀시트"를 별도로 다루고 있어 07/08과
/// 혼동될 수 있으나, §8.1 정의상 nav.push/pop은 "스택에 새 화면 push"
/// 전반을 가리키므로 다이얼로그도 포함해 재생한다 — 과도하다고 판단되면
/// route.settings.name이 null인 경우(대부분 다이얼로그/바텀시트)만 걸러
/// 별도 처리할 수 있도록 route 정보를 유지해 둔다.
class SoundNavigatorObserver extends NavigatorObserver {
  SoundNavigatorObserver(this._sound);

  final SintongSoundService _sound;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sound.playEvent('nav.push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sound.playEvent('nav.pop');
  }
}
