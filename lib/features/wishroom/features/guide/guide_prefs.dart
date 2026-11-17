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
  bool _loaded = false;

  bool get hintsOn => _hintsOn;
  bool get tourDone => _tourDone;
  bool seen(String id) => _seen.contains(id);

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _hintsOn = (p.getString('wr_hints') ?? 'on') != 'off';
    _seen = (p.getStringList('wr_hint_seen') ?? const []).toSet();
    _tourDone = p.getBool('wr_tour_done') ?? false;
    await _loadVisitedTabs(p);
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
}
