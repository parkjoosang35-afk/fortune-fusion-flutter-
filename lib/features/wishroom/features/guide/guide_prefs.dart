// app2/guide2.jsx › localStorage('wr_hints' / 'wr_hint_seen' / 'wr_tour_done') 1:1 이식.
// 웹의 동기식 localStorage를 shared_preferences(비동기)로 옮기면서, UI가 매번
// await 없이 즉시 읽을 수 있도록 앱 시작 시 한 번 로드해 메모리 캐시로 들고 있는다.
import 'package:shared_preferences/shared_preferences.dart';

class GuidePrefs {
  GuidePrefs._();
  static final GuidePrefs I = GuidePrefs._();

  bool _hintsOn = true;
  Set<String> _seen = {};
  bool _tourDone = false;
  // [J6 Tour21] app3/tour.jsx Tour21 — "21일 미리보기 투어"를 이미 보여줬는지
  // (또는 "괜찮아요, 바로 시작할게요"로 건너뛰었는지)를 기존 wr_tour_done(6단계
  // 둘러보기)과 완전히 별개의 키로 추적한다. 생애 첫 기도 직후 1회만 떠야 하므로
  // 한 번이라도 보여주거나 건너뛰면 다시는 뜨지 않게 영구 기록한다.
  bool _tour21Done = false;
  bool _loaded = false;

  bool get hintsOn => _hintsOn;
  bool get tourDone => _tourDone;
  bool get tour21Done => _tour21Done;
  bool seen(String id) => _seen.contains(id);

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _hintsOn = (p.getString('wr_hints') ?? 'on') != 'off';
    _seen = (p.getStringList('wr_hint_seen') ?? const []).toSet();
    _tourDone = p.getBool('wr_tour_done') ?? false;
    _tour21Done = p.getBool('wr_tour21_done') ?? false;
    await _loadVisitedTabs(p);
    await _loadMenuInfoSeen(p);
    await _loadDailyCardKeys(p);
    _loaded = true;
  }

  Future<void> markSeen(String id) async {
    if (_seen.contains(id)) return;
    _seen = {..._seen, id};
    final p = await SharedPreferences.getInstance();
    await p.setStringList('wr_hint_seen', _seen.toList());
  }

  Future<void> setHintsOn(bool v) async {
    _hintsOn = v;
    final p = await SharedPreferences.getInstance();
    await p.setString('wr_hints', v ? 'on' : 'off');
    if (v) {
      _seen = {};
      await p.remove('wr_hint_seen');
    }
  }

  Future<void> setTourDone() async {
    _tourDone = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool('wr_tour_done', true);
  }

  /// [J6 Tour21] Tour21을 끝까지 봤거나("진짜 첫 기도 올리러 가기") 중간에
  /// 건너뛰었을 때("매일 알림 없이 돌아가기"/"괜찮아요, 바로 시작할게요") 둘 다
  /// 호출한다 — 원본 `previewEnd()`가 호출되는 모든 경로와 1:1.
  Future<void> setTour21Done() async {
    _tour21Done = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool('wr_tour21_done', true);
  }

  // [v5 S2] 매핑표 00-C "새로 열린 표시 — 열린 탭에 N 배지 → 그 탭을 처음 들어가면
  // 사라짐" — app3/shell.jsx `S.visited = [...new Set([...(S.visited||[]), tab])]`
  // (F.visit(id)) 1:1. 서버 unlocked[]는 "열렸는지"만 알려주고 "이 기기에서 이미 한 번
  // 들어가 봤는지"는 로컬에서만 의미가 있으므로(여러 기기 동기화 불필요 — 배지는
  // 순수 UX 장식), GuidePrefs와 동일하게 shared_preferences에 보관한다.
  Set<String> _visitedTabs = {};
  bool visitedTab(String id) => _visitedTabs.contains(id);

  Future<void> markTabVisited(String id) async {
    if (_visitedTabs.contains(id)) return;
    _visitedTabs = {..._visitedTabs, id};
    final p = await SharedPreferences.getInstance();
    await p.setStringList('wr_visited_tabs', _visitedTabs.toList());
  }

  Future<void> _loadVisitedTabs(SharedPreferences p) async {
    _visitedTabs = (p.getStringList('wr_visited_tabs') ?? const []).toSet();
  }

  // [v5 S2 — CHECKLIST.md "⋯ 소원방 돌보기 메뉴 10줄 + 안내창(menuinfo.js)"]
  // app3/menuinfo.js `seen()`/`markSeen(t)` (localStorage 'wr_menuinfo_seen') 1:1.
  // "열린 항목은 처음 1번만 안내 후 바로 가기, 재방문엔 안내 없이 바로 실행" 판정을
  // 위 _seen(안내서 전용)과 분리된 별도 Set으로 shared_preferences에 보관한다 —
  // 두 기능은 키 네임스페이스가 다른 서로 다른 "이미 봤어요" 추적이라 섞으면 안 된다.
  Set<String> _menuInfoSeen = {};
  bool menuInfoSeen(String key) => _menuInfoSeen.contains(key);

  Future<void> markMenuInfoSeen(String key) async {
    if (_menuInfoSeen.contains(key)) return;
    _menuInfoSeen = {..._menuInfoSeen, key};
    final p = await SharedPreferences.getInstance();
    await p.setStringList('wr_menuinfo_seen', _menuInfoSeen.toList());
  }

  Future<void> _loadMenuInfoSeen(SharedPreferences p) async {
    _menuInfoSeen = (p.getStringList('wr_menuinfo_seen') ?? const []).toSet();
  }

  // [A12/A13 신규 — 46개 안내 팝업 전수 대조 공백 보완] app3/shell.jsx
  // `c.log[c.day].tmrShown` / `v.log[v.day].morning` 1:1 — 원본은 서버에 저장되는
  // "방 일자(day, 0-base)"를 키로 썼지만, 이 프로젝트 서버 스키마엔 그 일자별
  // log 테이블이 없다(WishRoomPrayerLog와 마찬가지로 API 미연결, CHECKLIST.md
  // 공백 기록 참고). "오늘 하루 한 번만" 판정 자체는 기기 로컬에서만 의미가
  // 있으므로(여러 기기 동기화 불필요 — 순수 UX 장식), room.dayN(서버가 이미
  // 내려주는 "방 생성일부터 경과일")을 키로 삼아 wr_hint_seen 등과 동일하게
  // shared_preferences에 보관한다. dayN은 방마다 다시 1부터 시작하므로
  // roomId까지 합쳐 키를 만들어야 새 소원을 쓴 뒤 다시 뜨지 않는 버그를 막는다.
  String? _tmrShownKey; // 'roomId:dayN' — A12 TomorrowCard
  String? _morningShownKey; // 'roomId:dayN' — A13 MorningCard3

  Future<void> _loadDailyCardKeys(SharedPreferences p) async {
    _tmrShownKey = p.getString('wr_tmr_shown_key');
    _morningShownKey = p.getString('wr_morning_shown_key');
  }

  /// A12 TomorrowCard를 오늘(이 방의 이 dayN) 이미 보여줬는지.
  bool tomorrowCardShown(String roomId, int dayN) =>
      _tmrShownKey == '$roomId:$dayN';

  Future<void> markTomorrowCardShown(String roomId, int dayN) async {
    _tmrShownKey = '$roomId:$dayN';
    final p = await SharedPreferences.getInstance();
    await p.setString('wr_tmr_shown_key', _tmrShownKey!);
  }

  /// A13 MorningCard3를 오늘(이 방의 이 dayN) 이미 보여줬는지.
  bool morningCardShown(String roomId, int dayN) =>
      _morningShownKey == '$roomId:$dayN';

  Future<void> markMorningCardShown(String roomId, int dayN) async {
    _morningShownKey = '$roomId:$dayN';
    final p = await SharedPreferences.getInstance();
    await p.setString('wr_morning_shown_key', _morningShownKey!);
  }
}
