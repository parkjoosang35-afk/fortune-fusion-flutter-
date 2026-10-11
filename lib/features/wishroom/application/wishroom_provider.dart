// 신통방통 소원방 v2.6 · 전역 Provider
// wallet_provider.dart 패턴(ChangeNotifier + Repository 주입 + load() + clearOnLogout())을
// 그대로 따른다. 화면들은 이 Provider 하나만 참조하며, WrRepository(=wr_api.dart)를
// 통해 서버와 통신한다. 정적 카탈로그(아이템/캐릭터 그림·텍스트)는 WrCatalog.I를 직접
// 참조하고, 이 Provider는 "서버 상태"(내 방·보유 여부·레벨·알림 등)만 보관한다.
import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/wr_api.dart';
import '../data/wr_local_cache.dart';
import '../features/wallpaper/wallpaper_service.dart';
import '../features/wallpaper/wish_action_sync.dart';

class WishRoomProvider extends ChangeNotifier {
  final WrRepository repo;
  WishRoomProvider(this.repo);

  // ── 내 소원방 ──
  WishRoom? room;
  Me? me;
  IntroMode introMode = IntroMode.none;
  bool isLoading = false;
  bool loaded = false;
  ApiError? lastError;

  // ── 카탈로그(서버 보유여부 포함) ──
  List<WrItem> items = [];
  List<WrCharacter> characters = [];
  bool catalogLoaded = false;

  // ── 알림 ──
  List<WrNotification> notifications = [];

  // ── 탐색 ──
  List<WishRoom> exploreFeed = [];
  bool exploreLoading = false;

  // ── 보관함 ──
  List<WishRoom> archiveRooms = [];
  List<Map<String, dynamic>> ledger = [];

  // ── 성취후기 ──
  List<WrReview> myReviews = [];
  List<WrReview> reviewFeed = [];

  // ── 타인 소원방(탐색 상세) 캐시 ──
  WishRoom? viewedRoom;
  List<WrComment> viewedComments = [];

  // ── 안내서 한 바퀴 둘러보기 ──
  // app2/guide2.jsx › GuideBook의 "✦ 소원방 한 바퀴 둘러보기"는 app.room && 조건만으로
  // 꾸미기/보관함 등 어디서 눌러도 항상 보이고, onClose(); app.go('home');
  // setTimeout(()=>app.startTour(),400) 으로 메인 탭 이동 후 투어를 시작한다.
  // Flutter는 IndexedStack 5탭 구조라 화면 위젯이 직접 탭을 바꿀 수 없으므로,
  // 이 플래그를 WishRoomShell이 구독해 탭 전환 + 투어 시작을 대신 수행한다.
  bool tourRequested = false;

  void requestTour() {
    tourRequested = true;
    notifyListeners();
  }

  void consumeTourRequest() {
    tourRequested = false;
  }

  // ── 바텀탭 전환 요청(지갑 시트 "소원방에서 쓰는 곳"·"전체 내역 보기" 등) ──
  // IndexedStack 구조라 화면이 직접 바텀탭을 바꿀 수 없으므로, tourRequested와 같은
  // 패턴으로 WishRoomShell이 이 플래그를 구독해 대신 전환한다. vaultSubTab이 같이
  // 오면 보관함(탭4)의 내부 TabBarView(기록관/복주머니/응원보상)도 함께 전환한다.
  int? requestedTabIndex;
  int? requestedVaultSubTab;

  void requestTab(int index, {int? vaultSubTab}) {
    requestedTabIndex = index;
    requestedVaultSubTab = vaultSubTab;
    notifyListeners();
  }

  void consumeTabRequest() {
    requestedTabIndex = null;
  }

  void consumeVaultSubTabRequest() {
    requestedVaultSubTab = null;
  }

  int get unreadCount => me?.unread ?? 0;

  /// docs/WALLPAPER.md §4.3 "동기화" — room(소원/장비/테마/레벨/상태)이 서버 응답으로
  /// 바뀔 때마다(로드·정성·꾸미기·테마·레이아웃·생성 등) 호출해 네이티브 라이브
  /// 배경화면(WishRoomWallpaperService.kt)이 다음 프레임부터 최신 상태를 그리게 한다.
  /// 웹 프리뷰/iOS에서는 WallpaperService 내부에서 조용히 no-op 처리된다.
  void _syncNativeWallpaper() {
    final r = room;
    if (r == null || !catalogLoaded) return;
    WallpaperService.syncManifest(r, items);
  }

  /// [§4.1/§6 WishAction 드레인] 조작판 위젯에서 발생한 "홈에서 한 행동"을
  /// 서버로 전송한다. 앱이 "다음 실행"에 반드시 읽어야 하므로, room이 처음
  /// 로드된 직후(= 로그인 사용자의 방 id를 확정한 시점)에 호출한다 — §6
  /// "홈에서만 치성하고 앱을 한 번도 열지 않으면 기록이 사라진다"는 결과를
  /// 막기 위한 진입점이다.
  void drainPendingWishActions() {
    final r = room;
    if (r == null) return;
    WishActionSync.drainAndSync(repo: repo, fallbackRoomId: r.id);
  }

  /// [Stage2 결함수정 패턴 재사용] 로그아웃 시 이전 계정의 소원방/알림/탐색
  /// 데이터가 메모리에 남아있지 않도록 전부 초기화한다.
  void clearOnLogout() {
    room = null;
    me = null;
    introMode = IntroMode.none;
    isLoading = false;
    loaded = false;
    lastError = null;
    _cacheHydrated = false;
    // [비용 최소화 §3] 로그아웃 시 이전 계정의 "마지막 정상 방 데이터" 캐시를
    // 반드시 비운다 — 다음 계정이 로그인했을 때 콜드 스타트 1차 렌더에서
    // 타인의 방이 잠깐이라도 노출되는 것을 막는다(샘플/타인 데이터 노출 금지
    // 원칙과 동일 취지). best-effort이며 완료를 기다리지 않는다.
    WrLocalCache.clear();
    items = [];
    characters = [];
    catalogLoaded = false;
    notifications = [];
    exploreFeed = [];
    archiveRooms = [];
    ledger = [];
    myReviews = [];
    reviewFeed = [];
    viewedRoom = null;
    viewedComments = [];
    wallpaperStatus = const WallpaperStatus.empty();
    notifyListeners();
  }

  // ═══════════════════════════ 내 소원방 ═══════════════════════════

  /// [비용 최소화 §3] 콜드 스타트 시 캐시된 마지막 정상 방 데이터를 먼저
  /// 화면에 띄웠는지 여부 — true가 되면 이후 호출에서는 다시 시도하지 않는다
  /// (한 세션에 1회만 "즉시 표시"하면 충분하고, 그 뒤는 서버 응답이 진실).
  bool _cacheHydrated = false;

  /// SCR-01/03 공용 — 내 방 + 내 정보 + 인트로 모드를 한 번에 로드.
  ///
  /// [비용 최소화 §3 "홈 화면을 켤 때마다 서버를 조회하지 마세요. 마지막
  /// 정상 방 데이터를 즉시 표시하고, 동기화는 방 변경·치성 완료·필요한 앱
  /// 진입 등 정해진 시점에만 수행하세요."] 이 메서드 자체는 여전히 1회
  /// 네트워크 요청을 보낸다(main_room_screen.dart가 `room == null`일 때만
  /// 호출하도록 이미 가드하고 있어 화면 재진입마다 반복 호출되지 않음 —
  /// 즉 "정해진 시점"의 동기화다). 다만 room이 아직 비어있는 "첫 호출"
  /// 구간에서는 네트워크 응답을 기다리는 동안 빈 화면 대신, 로컬에 저장된
  /// 마지막 정상 데이터를 즉시 room/me에 채워 화면을 먼저 그리게 한다.
  Future<void> loadMyRoom() async {
    isLoading = true;
    lastError = null;
    // 아직 메모리에 room이 없고(이번 프로세스에서 처음) 캐시도 아직 안
    // 썼다면, 네트워크 왕복을 기다리지 않고 캐시를 먼저 적용한다.
    if (room == null && !_cacheHydrated) {
      _cacheHydrated = true;
      final cachedJson = await WrLocalCache.loadMyRoomJson();
      if (cachedJson != null) {
        try {
          final cached = MyRoomResponse.fromJson(cachedJson);
          room = cached.room;
          me = cached.me;
          introMode = cached.introMode;
          _syncNativeWallpaper();
          notifyListeners(); // 캐시만으로 1차 렌더 — 아래에서 실제 서버 응답으로 덮어씀.
        } catch (_) {
          // 캐시 포맷이 모델 변경 등으로 깨졌으면 조용히 무시하고 네트워크만 믿는다.
        }
      }
    }
    notifyListeners();
    try {
      final res = await repo.myRoom();
      room = res.room;
      me = res.me;
      introMode = res.introMode;
      _syncNativeWallpaper();
      // [§6 "홈에서만 치성하고 앱을 한 번도 열지 않으면 기록이 사라진다"는
      // 결과는 실패로 본다"] 내 방을 확정한 "다음 실행" 시점에 조작판
      // 위젯이 쌓아 둔 WishAction을 반드시 드레인한다.
      drainPendingWishActions();
    } on ApiError catch (e) {
      lastError = e;
    } finally {
      isLoading = false;
      loaded = true;
      notifyListeners();
    }
  }

  /// SCR-02 — 소원 작성. 성공 시 room을 갱신하고 true 반환, 실패 시 false.
  Future<bool> createRoom({
    required String text,
    required String char,
    required String sealUntil,
    Visibility visibility = Visibility.PUBLIC,
    WrTheme theme = WrTheme.free,
    String wishColor = 'hope',
    String paper = 'hanji',
    bool force = false,
  }) async {
    lastError = null;
    try {
      room = await repo.createRoom(
        text: text,
        char: char,
        sealUntil: sealUntil,
        visibility: visibility,
        theme: theme,
        wishColor: wishColor,
        paper: paper,
        force: force,
      );
      _syncNativeWallpaper();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  /// SCR-03 입장 연출(§3 introMode) — enter 응답의 before/room 두 상태를 반환한다.
  Future<({WishRoom before, WishRoom room})?> enterRoom(String id) async {
    lastError = null;
    try {
      final r = await repo.enter(id);
      room = r.room;
      _syncNativeWallpaper();
      notifyListeners();
      return r;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  /// §6.2 촛불 다시 밝히기
  Future<bool> rekindle(String id) async {
    lastError = null;
    try {
      room = await repo.rekindle(id);
      _syncNativeWallpaper();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  /// §6.1 정성들이기는 DevotionController가 repo.devote()를 직접 호출하며,
  /// 완료 콜백(onDone)에서 이 메서드를 호출해 Provider 상태(room/me)에 반영한다.
  void applyDevotionResult(DevotionResult r) {
    room = r.room;
    me = r.me;
    _syncNativeWallpaper();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> support(String id) async {
    lastError = null;
    try {
      final (r, reward) = await repo.support(id);
      room = r;
      notifyListeners();
      return reward;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  Future<bool> gift(String id, int amount) async {
    lastError = null;
    try {
      final (r, m) = await repo.gift(id, amount);
      if (room?.id == id) room = r;
      me = m;
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> complete(String id, {bool cancel = false}) async {
    lastError = null;
    try {
      room = await repo.complete(id, cancel: cancel);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> seal(String id) async {
    lastError = null;
    try {
      room = await repo.seal(id);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> unseal(String id) async {
    lastError = null;
    try {
      room = await repo.unseal(id);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> outcome(String id, Outcome o, {String? text, String? sealUntil}) async {
    lastError = null;
    try {
      room = await repo.outcome(id, o, text: text, sealUntil: sealUntil);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateVisibility(String id, Visibility v) async {
    lastError = null;
    try {
      room = await repo.updateRoom(id, visibility: v);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  // ── 꾸미기(SCR-04) ──

  Future<bool> equip(String roomId, String itemId) async {
    lastError = null;
    try {
      room = await repo.equip(roomId, itemId);
      _syncNativeWallpaper();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setLayout(String id, String itemId, {double? x, double? y, double? s, bool reset = false}) async {
    lastError = null;
    try {
      room = await repo.setLayout(id, itemId, x: x, y: y, s: s, reset: reset);
      _syncNativeWallpaper();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setPaper(String id, String paper) async {
    lastError = null;
    try {
      room = await repo.setPaper(id, paper);
      _syncNativeWallpaper();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setTheme(String id, WrTheme theme) async {
    lastError = null;
    try {
      room = await repo.setTheme(id, theme);
      _syncNativeWallpaper();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setOutfit(String id, WrTheme? theme) async {
    lastError = null;
    try {
      room = await repo.setOutfit(id, theme);
      _syncNativeWallpaper();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  List<OutfitOffer> _outfitCache = [];
  List<OutfitOffer> get outfitOffers => _outfitCache;

  Future<void> loadOutfits(String char) async {
    try {
      _outfitCache = await repo.outfits(char);
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  Future<bool> buyOutfit(String char, WrTheme theme) async {
    lastError = null;
    try {
      me = await repo.buyOutfit(char, theme);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  // ── 아이템/캐릭터 카탈로그(SCR-04/05) ──

  Future<void> loadCatalog() async {
    try {
      final results = await Future.wait([repo.items(), repo.characters()]);
      items = results[0] as List<WrItem>;
      characters = results[1] as List<WrCharacter>;
      catalogLoaded = true;
      // room이 loadMyRoom()으로 먼저 로드되고 카탈로그가 나중에 끝나는 순서도
      // 있으므로(initState에서 두 호출을 거의 동시에 발사), 카탈로그 로딩이
      // 끝나는 시점에도 한 번 더 동기화해 아이템 asset 정보 누락을 방지한다.
      _syncNativeWallpaper();
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  Future<bool> buyItem(String id) async {
    lastError = null;
    try {
      me = await repo.buyItem(id);
      await loadCatalog();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> buyCharacter(String id) async {
    lastError = null;
    try {
      me = await repo.buyCharacter(id);
      await loadCatalog();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> setCharacter(String id) async {
    lastError = null;
    try {
      me = await repo.setCharacter(id);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  // ── 알림(SCR-08) ──

  Future<void> loadNotifications() async {
    try {
      notifications = await repo.notifications();
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  Future<void> readNotifications({String? id}) async {
    try {
      final unread = await repo.readNotifications(id: id);
      if (id == null) {
        notifications = notifications.map((n) => WrNotification.fromJson({
              'id': n.id, 'text': n.text, 'type': n.type.name, 'roomId': n.roomId,
              'at': n.at.millisecondsSinceEpoch, 'read': true,
            })).toList();
      } else {
        notifications = notifications.map((n) => n.id == id
            ? WrNotification.fromJson({
                'id': n.id, 'text': n.text, 'type': n.type.name, 'roomId': n.roomId,
                'at': n.at.millisecondsSinceEpoch, 'read': true,
              })
            : n).toList();
      }
      if (me != null) {
        me = Me.fromJson({
          'id': me!.id, 'nick': me!.nick, 'repChar': me!.repChar, 'pouch': me!.pouch,
          'accountAgeDays': me!.accountAgeDays, 'giftToday': me!.giftToday, 'unread': unread,
          'ownedChars': me!.ownedChars, 'ownedItems': me!.ownedItems, 'ownedOutfits': me!.ownedOutfits,
          'settings': {'skipIntro': me!.skipIntro}, 'earnToday': me!.earnToday, 'wallpaper': me!.wallpaper,
        });
      }
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  // ── 탐색(SCR-06/07) ──

  String? _exploreCursor;
  Future<void> loadExplore({bool refresh = true}) async {
    if (exploreLoading) return;
    exploreLoading = true;
    if (refresh) {
      _exploreCursor = null;
      exploreFeed = [];
    }
    notifyListeners();
    try {
      final page = await repo.explore(cursor: _exploreCursor);
      exploreFeed = refresh ? page : [...exploreFeed, ...page];
    } on ApiError catch (e) {
      lastError = e;
    } finally {
      exploreLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadViewedRoom(String id) async {
    try {
      viewedRoom = await repo.room(id);
      viewedComments = await repo.comments(id);
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  Future<bool> postComment(String roomId, String text) async {
    try {
      final c = await repo.postComment(roomId, text);
      viewedComments = [...viewedComments, c];
      if (viewedRoom?.id == roomId) viewedRoom = await repo.room(roomId);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> report({String? roomId, String? commentId}) async {
    try {
      await repo.report(roomId: roomId, commentId: commentId);
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> block(String userId) async {
    try {
      await repo.block(userId);
      exploreFeed = exploreFeed.where((r) => r.ownerId != userId).toList();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  // ── 보관함(SCR-09) ──

  Future<void> loadArchive() async {
    try {
      archiveRooms = await repo.archive();
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  Future<void> loadLedger() async {
    try {
      ledger = await repo.ledger();
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> claimSupportReward(String id, int at) async {
    try {
      final res = await repo.claimSupportReward(id, at);
      room = await repo.room(id);
      notifyListeners();
      return res;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  // ── 성취후기(V1-V6, SCR-09) ──

  Future<Map<String, dynamic>?> postReview(String roomId, {required String text, String? photo, bool public = true}) async {
    try {
      final res = await repo.postReview(roomId, text: text, photo: photo, public: public);
      await loadMyReviews();
      return res;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadMyReviews() async {
    try {
      myReviews = await repo.reviews(mine: true);
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  Future<void> loadReviewFeed() async {
    try {
      reviewFeed = await repo.reviews(mine: false);
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  // app2/review2.jsx › ReviewWrite submit() edit 분기 `PATCH /reviews/{id}` 1:1.
  // [버그수정 — 전수감사] 기존엔 bool만 반환해 호출부가 수정된 리뷰 내용을 알 수 없었다
  // (화면에서 전혀 쓰이지 않던 죽은 코드였음) — WrReview?를 반환하도록 변경.
  Future<WrReview?> editReview(String id, {String? text, String? photo, bool? public}) async {
    try {
      final r = await repo.editReview(id, text: text, photo: photo, public: public);
      myReviews = myReviews.map((x) => x.id == id ? r : x).toList();
      reviewFeed = reviewFeed.map((x) => x.id == id ? r : x).toList();
      notifyListeners();
      return r;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteReview(String id) async {
    try {
      await repo.deleteReview(id);
      myReviews = myReviews.where((x) => x.id != id).toList();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> congrats(String id) async {
    try {
      final r = await repo.congrats(id);
      reviewFeed = reviewFeed.map((x) => x.id == id ? r : x).toList();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> reportReview(String id, String reason) async {
    try {
      await repo.reportReview(id, reason);
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  // ── 공유(SCR-07) ──

  Future<({String token, String url})?> shareLink(String id, {bool reissue = false}) async {
    try {
      return await repo.shareLink(id, reissue: reissue);
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  // ── 설정 ──

  Future<bool> setSkipIntro(bool v) async {
    try {
      me = await repo.settings(skipIntro: v);
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<(int, Me)?> earn(String source) async {
    try {
      final (amount, m) = await repo.earn(source);
      me = m;
      notifyListeners();
      return (amount, m);
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  // ── 배경화면 (app2/wallpaper2.jsx S-01~07 · docs/WALLPAPER.md W1~W5) ──

  WallpaperStatus wallpaperStatus = const WallpaperStatus.empty();

  Future<WPManifest?> loadWallpaperManifest(String roomId) async {
    try {
      return await repo.wallpaperManifest(roomId);
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadWallpaperStatus() async {
    try {
      wallpaperStatus = await repo.wallpaperStatus();
      notifyListeners();
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
    }
  }

  /// S-02 "홈 화면 + 잠금 화면에 설정" 등 — 서버에 설정 상태를 기록한다.
  /// 실제로 OS 배경화면을 바꾸는 동작은 화면(WallpaperScreen)이
  /// WallpaperService(android) 플랫폼 채널을 직접 호출해 수행하고, 이 메서드는
  /// 그 뒤에 "서버 기준 상태"만 PUT으로 동기화한다(§4 공통 흐름).
  Future<bool> setWallpaper(String roomId, {required String platform, required String target, required int version}) async {
    try {
      wallpaperStatus = await repo.setWallpaper(roomId, platform: platform, target: target, version: version);
      // [SERVER] me.wallpaper는 roomByToken 등 다른 응답에도 실려오므로 me도 최신화.
      me = await repo.me();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearWallpaper() async {
    try {
      await repo.clearWallpaper();
      wallpaperStatus = const WallpaperStatus.empty();
      notifyListeners();
      return true;
    } on ApiError catch (e) {
      lastError = e;
      notifyListeners();
      return false;
    }
  }

  /// S-07 — 레벨업 연출 안에서 배경화면 사용자에게 1회만 안내 문구를 보여준 뒤 기록.
  Future<void> wallpaperLevelNotice(int level) async {
    try {
      await repo.wallpaperLevelNotice(level);
    } catch (_) {
      // fx2.jsx 원본도 .catch(()=>{})로 무시한다 — 연출을 막을 이유가 없다.
    }
  }
}
