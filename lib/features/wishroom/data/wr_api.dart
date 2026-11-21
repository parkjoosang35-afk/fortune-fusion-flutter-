// 신통방통 소원방 · REST 클라이언트 v2.6 — 전체 계약: docs/API_CONTRACT.md
// (원본 핸드오프는 dio 기반이었으나, 기존 신통방통 앱 컨벤션(provider+http)에
// 맞춰 http 패키지로 재작성했다. WrRepository 인터페이스 자체는 원본과 1:1 동일
// 하게 유지한다 — 화면 코드가 이 인터페이스에만 의존하도록.)
//
// 서버 Base URL: `${EnvConfig.adminApiBaseUrl}/api/public/wishroom`
// 인증: 기존 AuthTokenStore.authHeader() (Authorization: Bearer <JWT>) 그대로 재사용.
// 응답 포맷: admin_web 공개 API 공용 관례 { success: true, data: ... } /
//   { success: false, error: "...", code?: "...", retryAfter?, need?, have? }
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import 'models.dart';
import 'wr_local_cache.dart';

abstract class WrRepository {
  // 소원방
  // [S1 재구축 — 소원 작성 간소화] 필수 값은 text/wishColor 두 개뿐이다.
  // char(수호자)는 생략하면 서버가 보유 중인 대표 캐릭터(기본 F00)를 쓰고,
  // sealUntil(봉인일)은 생략하면 서버가 null로 저장한다(선택 사항).
  Future<WishRoom> createRoom({required String text, String? char, String? sealUntil, Visibility visibility, WrTheme theme, required String wishColor, String paper, bool force});   // 1 POST /wish-rooms
  Future<MyRoomResponse> myRoom();                                                                              // 2 GET  /wish-rooms/me
  Future<WishRoom> room(String id);                                                                             // 3 GET  /wish-rooms/{id}
  Future<DevotionResult> devote(String id, {int? heldMs});                                                      // 4 POST /wish-rooms/{id}/devotions — v5 S1: heldMs(ms) 버튼 누르고 있던 시간, 3초 hold 검증용
  // [버그수정 — "함께 빌기" 복주머니 지급] 서버가 cheerEarned/me를 응답에 추가함에
  // 따라(POUCH.cheer 매 응원 +1 · 1일 cheerMax=5회 상한) 여기서도 Me를 함께
  // 반환해, 호출부가 WishRoomProvider.me를 갱신하고 화면의 복주머니 표시가
  // 바로 반영되도록 한다(gift()의 (WishRoom, Me) 패턴과 동일).
  Future<(WishRoom, Map<String, dynamic>?, Me)> support(String id);                                            // 5 POST /wish-rooms/{id}/supports
  Future<List<WrComment>> comments(String id);                                                                  // 6 GET  /wish-rooms/{id}/comments
  Future<WrComment> postComment(String id, String text);                                                        // 6 POST /wish-rooms/{id}/comments
  Future<(WishRoom, Me)> gift(String id, int amount);                                                           // 7 POST /wish-rooms/{id}/gifts
  Future<List<WishRoom>> explore({String? cursor});                                                             // 8 GET  /wish-rooms/explore
  Future<WishRoom> equip(String roomId, String itemId);                                                         // 9 PATCH /wish-rooms/{id}/decorations
  Future<WishRoom> complete(String id, {bool cancel, Outcome? outcome, String? note});                          // 10 POST /wish-rooms/{id}/complete
  Future<WishRoom> seal(String id);                                                                             // 11 POST /wish-rooms/{id}/seal
  Future<List<WishRoom>> archive();                                                                             // 12 GET  /archive
  Future<List<WrItem>> items();                                                                                 // 13 GET  /items
  // [S5 경제 — 동일 결제 중복 처리 방지] idempotencyKey는 pay_screen.dart의 주문번호
  // (_oid)를 그대로 재사용한다(app3/flow.js API.once(reqId,fn) 1:1) — 버튼 연타·네트워크
  // 재전송으로 같은 요청이 두 번 와도 서버가 한 번만 처리하도록. null이면 서버가 멱등
  // 체크를 건너뛰고 그냥 처리한다(PayScreen 바깥의 기존 호출부 호환).
  Future<Me> buyItem(String id, {String? idempotencyKey});                                                      // 14 POST /items/{id}/purchase
  Future<List<WrCharacter>> characters();                                                                       // 15 GET  /characters
  Future<Me> buyCharacter(String id, {String? idempotencyKey});                                                 // 16 POST /characters/{id}/purchase
  Future<Me> setCharacter(String id);                                                                           // 17 PATCH /me/character
  Future<List<WrNotification>> notifications();                                                                 // 18 GET  /notifications
  Future<int> readNotifications({String? id});                                                                  // 18 POST /notifications
  // 보조
  Future<({WishRoom before, WishRoom room})> enter(String id);                                                  // POST /wish-rooms/{id}/enter
  Future<WishRoom> rekindle(String id);                                                                         // POST /wish-rooms/{id}/rekindle
  Future<({WishRoom room, Me me})> unlockAck(String id, String key);                                            // [v5 S2] POST /wish-rooms/{id}/unlock-ack — 매핑표 00-C "열림 카드" 확인
  Future<Me> me();                                                                                              // GET  /me
  Future<List<Map<String, dynamic>>> ledger();                                                                  // GET  /me/ledger
  Future<(int, Me)> earn(String source);                                                                        // POST /me/earn
  Future<Me> settings({bool? skipIntro});                                                                       // PATCH /me/settings
  Future<WishRoom> updateRoom(String id, {Visibility? visibility});                                             // PATCH /wish-rooms/{id}
  Future<void> report({String? roomId, String? commentId});                                                     // POST /reports
  Future<void> block(String userId);                                                                            // POST /blocks
  // v2.3~2.6 추가
  Future<WishRoom> setLayout(String id, String itemId, {double? x, double? y, double? s, bool reset});          // PATCH /wish-rooms/{id}/layout
  Future<WishRoom> setPaper(String id, String paper);                                                           // PATCH /wish-rooms/{id}/paper
  Future<WishRoom> setTheme(String id, WrTheme theme);                                                          // T1 PATCH /wish-rooms/{id}/theme
  Future<List<OutfitOffer>> outfits(String char);                                                               // T2 GET /outfits?char=
  Future<Me> buyOutfit(String char, WrTheme theme, {String? idempotencyKey});                                   // T3 POST /outfits/purchase
  Future<Me> buyNamedOutfit(String char, String outfitId, {String? idempotencyKey}) => throw ApiError(409, 'NOT_READY', '신규 의상 서버 연결이 필요해요');
  Future<WishRoom> setNamedOutfit(String id, String outfitId) => throw ApiError(409, 'NOT_READY', '신규 의상 서버 연결이 필요해요');
  Future<WishRoom> setOutfit(String id, WrTheme? theme);                                                        // T4 PATCH /wish-rooms/{id}/outfit
  Future<WishRoom> unseal(String id);                                                                           // C1 POST /wish-rooms/{id}/unseal
  Future<WishRoom> outcome(String id, Outcome o, {String? text, String? sealUntil, String? note});               // C2 POST /wish-rooms/{id}/outcome
  Future<({String token, String url})> shareLink(String id, {bool reissue});                                    // S1
  Future<WishRoom> roomByToken(String token);                                                                   // S2 GET /share/{token}
  Future<Map<String, dynamic>> claimSupportReward(String id, int at);                                           // R1
  Future<Map<String, dynamic>> postReview(String roomId, {required String text, String? photo, bool public});   // V1
  Future<WrReview> editReview(String id, {String? text, String? photo, bool? public});                         // V2
  Future<void> deleteReview(String id);                                                                         // V3
  Future<List<WrReview>> reviews({bool mine});                                                                  // V4
  Future<WrReview> congrats(String id);                                                                         // V5
  Future<void> reportReview(String id, String reason);                                                         // V6
  // 배경화면 (docs/WALLPAPER.md)
  Future<WPManifest> wallpaperManifest(String roomId);                                                         // W1 GET /wish-rooms/{id}/wallpaper
  Future<WallpaperStatus> wallpaperStatus();                                                                    // W2 GET /me/wallpaper
  Future<WallpaperStatus> setWallpaper(String roomId, {required String platform, required String target, required int version}); // W3 PUT /me/wallpaper
  Future<void> clearWallpaper();                                                                                // W4 DELETE /me/wallpaper
  Future<void> wallpaperLevelNotice(int level);                                                                 // W5 POST /me/wallpaper/level-notice

  // ── [S3 신규] 수호자에게 맡기기(Entrust) ──
  Future<({WishRoom room, Me me})> entrust(String id, {required int days, bool startsToday, String? idempotencyKey});                  // POST /wish-rooms/{id}/entrust
  Future<({WishRoom room, Me me, int refund})> cancelEntrust(String id);                                       // DELETE /wish-rooms/{id}/entrust
  Future<({WishRoom room, Me me})> ackEntrust(String id);                                                      // POST /wish-rooms/{id}/entrust/ack

  // ── [S3 신규] 수호자 보내기 / 찾아온 수호자(Dispatch) ──
  Future<({WishRoom room, Me me, bool ask, String dispatchId})> dispatchGuardian(String targetRoomId, {required String guardian, bool anon, String? word, bool isReply}); // POST /wish-rooms/{id}/dispatch
  Future<List<VisitorIn>> visitors();                                                                           // GET  /me/visitors
  Future<({Me me, int rewarded})> thanksVisitor(String dispatchId);                                             // POST /me/visitors/{id}/thanks
  Future<Me> recallVisitor(String dispatchId);                                                                 // POST /me/visitors/{id}/recall
  Future<void> ackDispatch(String dispatchId);                                                                  // POST /me/dispatches/{id}/ack
}

class ApiRepository implements WrRepository {
  final String _base;
  ApiRepository({String? baseUrl}) : _base = (baseUrl ?? '${EnvConfig.adminApiBaseUrl}/api/public/wishroom');

  Future<Map<String, String>> _headers({bool json = false}) async => {
        if (json) 'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...await AuthTokenStore.authHeader(),
      };

  Uri _u(String path) => Uri.parse('$_base$path');

  Future<dynamic> _req(String method, String path, [Object? body]) async {
    final uri = _u(path);
    final headers = await _headers(json: body != null);
    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
          break;
        case 'POST':
          res = await http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 10));
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 10));
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: body == null ? null : jsonEncode(body)).timeout(const Duration(seconds: 10));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
          break;
        default:
          throw ApiError(0, 'UNKNOWN_METHOD', '지원하지 않는 요청 방식입니다');
      }
    } catch (e) {
      // [전수검수 2026-10-12 — CRITICAL] TimeoutException/SocketException 등
      // 전송 계층 예외는 ApiError가 아니라서 호출부의 `on ApiError catch`를
      // 통과했다. 그러면 await 이후 코드가 실행되지 않아 busy 플래그(치성
      // phase, 봉인/재점화/보상 수령 등)가 영구 고정됐다 — 네트워크가 느려지면
      // 소원방 핵심 기능 전체가 앱 재실행 없이 잠겼다. 전송 계층 예외를 전부
      // ApiError로 변환해 호출부가 정상 분기하도록 한다.
      if (e is ApiError) rethrow;
      throw ApiError(0, 'NETWORK', '네트워크 상태가 좋지 않아요 · 잠시 후 다시 시도해주세요');
    }
    Map<String, dynamic> decoded;
    try {
      decoded = res.body.isEmpty ? {} : Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (_) {
      throw ApiError(res.statusCode, 'PARSE_ERROR', '서버 응답을 해석할 수 없습니다');
    }
    if (res.statusCode < 200 || res.statusCode >= 300 || decoded['success'] == false) {
      throw ApiError(
        res.statusCode,
        decoded['code'] as String? ?? 'UNKNOWN',
        decoded['error'] as String? ?? decoded['message'] as String? ?? '잠시 후 다시 시도해주세요',
        decoded,
      );
    }
    return decoded['data'] ?? decoded;
  }

  Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from(v as Map);
  List<T> _l<T>(dynamic v, T Function(Map<String, dynamic>) f) => (v as List).map((x) => f(_m(x))).toList();

  @override Future<WishRoom> createRoom({required String text, String? char, String? sealUntil, Visibility visibility = Visibility.PRIVATE, WrTheme theme = WrTheme.free, required String wishColor, String paper = 'hanji', bool force = false}) async =>
      WishRoom.fromJson(_m(await _req('POST', '/wish-rooms', {
        'text': text,
        if (char != null) 'char': char,
        if (sealUntil != null) 'sealUntil': sealUntil,
        'visibility': visibility.name,
        'theme': theme.name,
        'wishColor': wishColor,
        'paper': paper,
        'force': force,
      })));
  @override Future<MyRoomResponse> myRoom() async {
    final requestUser = await AuthTokenStore.getCurrentUserId();
    final requestToken = await AuthTokenStore.getToken();
    final raw = _m(await _req('GET', '/wish-rooms/me'));
    if (requestUser != await AuthTokenStore.getCurrentUserId() || requestToken != await AuthTokenStore.getToken()) {
      throw ApiError(409, 'SESSION_CHANGED', '로그인 상태가 변경되어 이전 응답을 폐기했어요');
    }
    // [비용 최소화 §3] 성공한 원본 응답을 그대로 로컬 캐시에 남긴다 — 다음
    // 콜드 스타트/오프라인 시 Provider가 네트워크 응답을 기다리지 않고
    // 이 값을 먼저 화면에 띄울 수 있게 한다(best-effort, 실패해도 무시).
    unawaited(WrLocalCache.saveMyRoomJson(raw));
    return MyRoomResponse.fromJson(raw);
  }
  @override Future<WishRoom> room(String id) async => WishRoom.fromJson(_m(await _req('GET', '/wish-rooms/$id')));
  @override Future<DevotionResult> devote(String id, {int? heldMs}) async =>
      DevotionResult.fromJson(_m(await _req('POST', '/wish-rooms/$id/devotions', heldMs == null ? null : {'heldMs': heldMs})));
  @override Future<(WishRoom, Map<String, dynamic>?, Me)> support(String id) async { final d = _m(await _req('POST', '/wish-rooms/$id/supports')); return (WishRoom.fromJson(_m(d['room'])), d['reward'] == null ? null : _m(d['reward']), Me.fromJson(_m(d['me']))); }
  @override Future<List<WrComment>> comments(String id) async => _l(await _req('GET', '/wish-rooms/$id/comments'), WrComment.fromJson);
  @override Future<WrComment> postComment(String id, String text) async => WrComment.fromJson(_m(await _req('POST', '/wish-rooms/$id/comments', {'text': text})));
  @override Future<(WishRoom, Me)> gift(String id, int amount) async { final d = _m(await _req('POST', '/wish-rooms/$id/gifts', {'amount': amount})); return (WishRoom.fromJson(_m(d['room'])), Me.fromJson(_m(d['me']))); }
  @override Future<List<WishRoom>> explore({String? cursor}) async => _l(await _req('GET', '/wish-rooms/explore${cursor != null ? '?cursor=$cursor' : ''}'), WishRoom.fromJson);
  @override Future<WishRoom> equip(String roomId, String itemId) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$roomId/decorations', {'itemId': itemId})));
  @override Future<WishRoom> complete(String id, {bool cancel = false, Outcome? outcome, String? note}) async => WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/complete', {'cancel': cancel, if (outcome != null) 'outcome': outcome.name, if (note != null) 'note': note})));
  @override Future<WishRoom> seal(String id) async => WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/seal')));
  @override Future<List<WishRoom>> archive() async => _l(await _req('GET', '/archive'), WishRoom.fromJson);
  @override Future<List<WrItem>> items() async => _l(await _req('GET', '/items'), WrItem.fromJson);
  @override Future<Me> buyItem(String id, {String? idempotencyKey}) async => Me.fromJson(_m(_m(await _req('POST', '/items/$id/purchase', {if (idempotencyKey != null) 'idempotencyKey': idempotencyKey}))['me']));
  @override Future<List<WrCharacter>> characters() async => _l(await _req('GET', '/characters'), WrCharacter.fromJson);
  @override Future<Me> buyCharacter(String id, {String? idempotencyKey}) async => Me.fromJson(_m(_m(await _req('POST', '/characters/$id/purchase', {if (idempotencyKey != null) 'idempotencyKey': idempotencyKey}))['me']));
  @override Future<Me> setCharacter(String id) async => Me.fromJson(_m(await _req('PATCH', '/me/character', {'id': id})));
  @override Future<List<WrNotification>> notifications() async => _l(await _req('GET', '/notifications'), WrNotification.fromJson);
  @override Future<int> readNotifications({String? id}) async => (_m(await _req('POST', '/notifications', {if (id != null) 'id': id}))['unread'] as num).toInt();
  @override Future<({WishRoom before, WishRoom room})> enter(String id) async { final d = _m(await _req('POST', '/wish-rooms/$id/enter')); return (before: WishRoom.fromJson(_m(d['before'])), room: WishRoom.fromJson(_m(d['room']))); }
  @override Future<WishRoom> rekindle(String id) async => WishRoom.fromJson(_m(_m(await _req('POST', '/wish-rooms/$id/rekindle'))['room']));
  @override Future<({WishRoom room, Me me})> unlockAck(String id, String key) async { final d = _m(await _req('POST', '/wish-rooms/$id/unlock-ack', {'key': key})); return (room: WishRoom.fromJson(_m(d['room'])), me: Me.fromJson(_m(d['me']))); }
  @override Future<Me> me() async => Me.fromJson(_m(await _req('GET', '/me')));
  @override Future<List<Map<String, dynamic>>> ledger() async => (await _req('GET', '/me/ledger') as List).map(_m).toList();
  @override Future<(int, Me)> earn(String source) async { final d = _m(await _req('POST', '/me/earn', {'source': source})); return ((d['amount'] as num).toInt(), Me.fromJson(_m(d['me']))); }
  @override Future<Me> settings({bool? skipIntro}) async => Me.fromJson(_m(await _req('PATCH', '/me/settings', {if (skipIntro != null) 'skipIntro': skipIntro})));
  @override Future<WishRoom> updateRoom(String id, {Visibility? visibility}) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$id', {if (visibility != null) 'visibility': visibility.name})));
  @override Future<void> report({String? roomId, String? commentId}) async => await _req('POST', '/reports', {if (roomId != null) 'roomId': roomId, if (commentId != null) 'commentId': commentId});
  @override Future<void> block(String userId) async => await _req('POST', '/blocks', {'userId': userId});

  @override Future<WishRoom> setLayout(String id, String itemId, {double? x, double? y, double? s, bool reset = false}) async =>
      WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$id/layout', reset ? {'itemId': itemId, 'reset': true} : {'itemId': itemId, 'x': x, 'y': y, 's': s})));
  @override Future<WishRoom> setPaper(String id, String paper) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$id/paper', {'paper': paper})));
  @override Future<WishRoom> setTheme(String id, WrTheme theme) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$id/theme', {'theme': theme.name})));
  @override Future<List<OutfitOffer>> outfits(String char) async => _l(await _req('GET', '/outfits?char=$char'), OutfitOffer.fromJson);
  @override Future<Me> buyNamedOutfit(String char, String outfitId, {String? idempotencyKey}) async => Me.fromJson(_m(_m(await _req('POST', '/outfits/purchase', {'char': char, 'outfitId': outfitId, if (idempotencyKey != null) 'idempotencyKey': idempotencyKey}))['me']));
  @override Future<WishRoom> setNamedOutfit(String id, String outfitId) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$id/outfit', {'outfitId': outfitId})));
  @override Future<Me> buyOutfit(String char, WrTheme theme, {String? idempotencyKey}) async => Me.fromJson(_m(_m(await _req('POST', '/outfits/purchase', {'char': char, 'theme': theme.name, if (idempotencyKey != null) 'idempotencyKey': idempotencyKey}))['me']));
  @override Future<WishRoom> setOutfit(String id, WrTheme? theme) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$id/outfit', {'theme': theme?.name})));
  @override Future<WishRoom> unseal(String id) async => WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/unseal')));
  @override Future<WishRoom> outcome(String id, Outcome o, {String? text, String? sealUntil, String? note}) async =>
      WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/outcome', {'outcome': o.name, if (text != null) 'text': text, if (sealUntil != null) 'sealUntil': sealUntil, if (note != null) 'note': note})));
  @override Future<({String token, String url})> shareLink(String id, {bool reissue = false}) async { final d = _m(await _req('POST', '/wish-rooms/$id/share-link', {'reissue': reissue})); return (token: d['token'] as String, url: d['url'] as String); }
  @override Future<WishRoom> roomByToken(String token) async => WishRoom.fromJson(_m(await _req('GET', '/share/$token')));
  @override Future<Map<String, dynamic>> claimSupportReward(String id, int at) async => _m(await _req('POST', '/wish-rooms/$id/support-rewards/$at/claim'));
  @override Future<Map<String, dynamic>> postReview(String roomId, {required String text, String? photo, bool public = true}) async =>
      _m(await _req('POST', '/wish-rooms/$roomId/review', {'text': text, 'photo': photo, 'visibility': public ? 'PUBLIC' : 'PRIVATE'}));
  @override Future<WrReview> editReview(String id, {String? text, String? photo, bool? public}) async =>
      WrReview.fromJson(_m(await _req('PATCH', '/reviews/$id', {if (text != null) 'text': text, if (photo != null) 'photo': photo, if (public != null) 'visibility': public ? 'PUBLIC' : 'PRIVATE'})));
  @override Future<void> deleteReview(String id) async => await _req('DELETE', '/reviews/$id');
  @override Future<List<WrReview>> reviews({bool mine = false}) async => _l(await _req('GET', '/reviews${mine ? '?mine=1' : ''}'), WrReview.fromJson);
  @override Future<WrReview> congrats(String id) async => WrReview.fromJson(_m(await _req('POST', '/reviews/$id/congrats')));
  @override Future<void> reportReview(String id, String reason) async => await _req('POST', '/reviews/$id/report', {'reason': reason});

  // ── 배경화면 (W1~W5) ──
  @override Future<WPManifest> wallpaperManifest(String roomId) async => WPManifest.fromJson(_m(await _req('GET', '/wish-rooms/$roomId/wallpaper')));
  @override Future<WallpaperStatus> wallpaperStatus() async => WallpaperStatus.fromJson(_m(await _req('GET', '/me/wallpaper')));
  @override Future<WallpaperStatus> setWallpaper(String roomId, {required String platform, required String target, required int version}) async =>
      WallpaperStatus.fromJson(_m(await _req('PUT', '/me/wallpaper', {'roomId': roomId, 'platform': platform, 'target': target, 'version': version})));
  @override Future<void> clearWallpaper() async => await _req('DELETE', '/me/wallpaper');
  @override Future<void> wallpaperLevelNotice(int level) async => await _req('POST', '/me/wallpaper/level-notice', {'level': level});

  // ── [S3 신규] 수호자에게 맡기기(Entrust) — route.ts POST/DELETE/ack 응답 {room, me[, refund]} 1:1 ──
  @override Future<({WishRoom room, Me me})> entrust(String id, {required int days, bool startsToday = true, String? idempotencyKey}) async {
    final d = _m(await _req('POST', '/wish-rooms/$id/entrust', {'days': days, 'startsToday': startsToday, if (idempotencyKey != null) 'idempotencyKey': idempotencyKey}));
    return (room: WishRoom.fromJson(_m(d['room'])), me: Me.fromJson(_m(d['me'])));
  }
  @override Future<({WishRoom room, Me me, int refund})> cancelEntrust(String id) async {
    final d = _m(await _req('DELETE', '/wish-rooms/$id/entrust'));
    return (room: WishRoom.fromJson(_m(d['room'])), me: Me.fromJson(_m(d['me'])), refund: (d['refund'] as num?)?.toInt() ?? 0);
  }
  @override Future<({WishRoom room, Me me})> ackEntrust(String id) async {
    final d = _m(await _req('POST', '/wish-rooms/$id/entrust/ack'));
    return (room: WishRoom.fromJson(_m(d['room'])), me: Me.fromJson(_m(d['me'])));
  }

  // ── [S3 신규] 수호자 보내기 / 찾아온 수호자(Dispatch) ──
  @override Future<({WishRoom room, Me me, bool ask, String dispatchId})> dispatchGuardian(String targetRoomId, {required String guardian, bool anon = false, String? word, bool isReply = false}) async {
    final d = _m(await _req('POST', '/wish-rooms/$targetRoomId/dispatch', {'guardian': guardian, 'anon': anon, if (word != null) 'word': word, 'isReply': isReply}));
    return (room: WishRoom.fromJson(_m(d['room'])), me: Me.fromJson(_m(d['me'])), ask: d['ask'] == true, dispatchId: d['dispatchId'] as String);
  }
  @override Future<List<VisitorIn>> visitors() async => _l(await _req('GET', '/me/visitors'), VisitorIn.fromJson);
  @override Future<({Me me, int rewarded})> thanksVisitor(String dispatchId) async {
    final d = _m(await _req('POST', '/me/visitors/$dispatchId/thanks'));
    return (me: Me.fromJson(_m(d['me'])), rewarded: (d['rewarded'] as num?)?.toInt() ?? 0);
  }
  @override Future<Me> recallVisitor(String dispatchId) async => Me.fromJson(_m(_m(await _req('POST', '/me/visitors/$dispatchId/recall'))['me']));
  @override Future<void> ackDispatch(String dispatchId) async => await _req('POST', '/me/dispatches/$dispatchId/ack');
}
