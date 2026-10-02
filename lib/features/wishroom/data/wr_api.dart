// 신통방통 소원방 · REST 클라이언트 v2.6 — 전체 계약: docs/API_CONTRACT.md
// (원본 핸드오프는 dio 기반이었으나, 기존 신통방통 앱 컨벤션(provider+http)에
// 맞춰 http 패키지로 재작성했다. WrRepository 인터페이스 자체는 원본과 1:1 동일
// 하게 유지한다 — 화면 코드가 이 인터페이스에만 의존하도록.)
//
// 서버 Base URL: `${EnvConfig.adminApiBaseUrl}/api/public/wishroom`
// 인증: 기존 AuthTokenStore.authHeader() (Authorization: Bearer <JWT>) 그대로 재사용.
// 응답 포맷: admin_web 공개 API 공용 관례 { success: true, data: ... } /
//   { success: false, error: "...", code?: "...", retryAfter?, need?, have? }
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import 'models.dart';

abstract class WrRepository {
  // 소원방
  Future<WishRoom> createRoom({required String text, required String char, required String sealUntil, Visibility visibility, WrTheme theme, String wishColor, String paper, bool force});   // 1 POST /wish-rooms
  Future<MyRoomResponse> myRoom();                                                                              // 2 GET  /wish-rooms/me
  Future<WishRoom> room(String id);                                                                             // 3 GET  /wish-rooms/{id}
  Future<DevotionResult> devote(String id);                                                                     // 4 POST /wish-rooms/{id}/devotions
  Future<(WishRoom, Map<String, dynamic>?)> support(String id);                                                 // 5 POST /wish-rooms/{id}/supports
  Future<List<WrComment>> comments(String id);                                                                  // 6 GET  /wish-rooms/{id}/comments
  Future<WrComment> postComment(String id, String text);                                                        // 6 POST /wish-rooms/{id}/comments
  Future<(WishRoom, Me)> gift(String id, int amount);                                                           // 7 POST /wish-rooms/{id}/gifts
  Future<List<WishRoom>> explore({String? cursor});                                                             // 8 GET  /wish-rooms/explore
  Future<WishRoom> equip(String roomId, String itemId);                                                         // 9 PATCH /wish-rooms/{id}/decorations
  Future<WishRoom> complete(String id, {bool cancel});                                                          // 10 POST /wish-rooms/{id}/complete
  Future<WishRoom> seal(String id);                                                                             // 11 POST /wish-rooms/{id}/seal
  Future<List<WishRoom>> archive();                                                                             // 12 GET  /archive
  Future<List<WrItem>> items();                                                                                 // 13 GET  /items
  Future<Me> buyItem(String id);                                                                                // 14 POST /items/{id}/purchase
  Future<List<WrCharacter>> characters();                                                                       // 15 GET  /characters
  Future<Me> buyCharacter(String id);                                                                           // 16 POST /characters/{id}/purchase
  Future<Me> setCharacter(String id);                                                                           // 17 PATCH /me/character
  Future<List<WrNotification>> notifications();                                                                 // 18 GET  /notifications
  Future<int> readNotifications({String? id});                                                                  // 18 POST /notifications
  // 보조
  Future<({WishRoom before, WishRoom room})> enter(String id);                                                  // POST /wish-rooms/{id}/enter
  Future<WishRoom> rekindle(String id);                                                                         // POST /wish-rooms/{id}/rekindle
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
  Future<Me> buyOutfit(String char, WrTheme theme);                                                             // T3 POST /outfits/purchase
  Future<WishRoom> setOutfit(String id, WrTheme? theme);                                                        // T4 PATCH /wish-rooms/{id}/outfit
  Future<WishRoom> unseal(String id);                                                                           // C1 POST /wish-rooms/{id}/unseal
  Future<WishRoom> outcome(String id, Outcome o, {String? text, String? sealUntil});                            // C2 POST /wish-rooms/{id}/outcome
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
      case 'DELETE':
        res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 10));
        break;
      default:
        throw ApiError(0, 'UNKNOWN_METHOD', '지원하지 않는 요청 방식입니다');
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

  @override Future<WishRoom> createRoom({required String text, required String char, required String sealUntil, Visibility visibility = Visibility.PUBLIC, WrTheme theme = WrTheme.free, String wishColor = 'hope', String paper = 'hanji', bool force = false}) async =>
      WishRoom.fromJson(_m(await _req('POST', '/wish-rooms', {'text': text, 'char': char, 'sealUntil': sealUntil, 'visibility': visibility.name, 'theme': theme.name, 'wishColor': wishColor, 'paper': paper, 'force': force})));
  @override Future<MyRoomResponse> myRoom() async => MyRoomResponse.fromJson(_m(await _req('GET', '/wish-rooms/me')));
  @override Future<WishRoom> room(String id) async => WishRoom.fromJson(_m(await _req('GET', '/wish-rooms/$id')));
  @override Future<DevotionResult> devote(String id) async => DevotionResult.fromJson(_m(await _req('POST', '/wish-rooms/$id/devotions')));
  @override Future<(WishRoom, Map<String, dynamic>?)> support(String id) async { final d = _m(await _req('POST', '/wish-rooms/$id/supports')); return (WishRoom.fromJson(_m(d['room'])), d['reward'] == null ? null : _m(d['reward'])); }
  @override Future<List<WrComment>> comments(String id) async => _l(await _req('GET', '/wish-rooms/$id/comments'), WrComment.fromJson);
  @override Future<WrComment> postComment(String id, String text) async => WrComment.fromJson(_m(await _req('POST', '/wish-rooms/$id/comments', {'text': text})));
  @override Future<(WishRoom, Me)> gift(String id, int amount) async { final d = _m(await _req('POST', '/wish-rooms/$id/gifts', {'amount': amount})); return (WishRoom.fromJson(_m(d['room'])), Me.fromJson(_m(d['me']))); }
  @override Future<List<WishRoom>> explore({String? cursor}) async => _l(await _req('GET', '/wish-rooms/explore${cursor != null ? '?cursor=$cursor' : ''}'), WishRoom.fromJson);
  @override Future<WishRoom> equip(String roomId, String itemId) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$roomId/decorations', {'itemId': itemId})));
  @override Future<WishRoom> complete(String id, {bool cancel = false}) async => WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/complete', {'cancel': cancel})));
  @override Future<WishRoom> seal(String id) async => WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/seal')));
  @override Future<List<WishRoom>> archive() async => _l(await _req('GET', '/archive'), WishRoom.fromJson);
  @override Future<List<WrItem>> items() async => _l(await _req('GET', '/items'), WrItem.fromJson);
  @override Future<Me> buyItem(String id) async => Me.fromJson(_m(_m(await _req('POST', '/items/$id/purchase'))['me']));
  @override Future<List<WrCharacter>> characters() async => _l(await _req('GET', '/characters'), WrCharacter.fromJson);
  @override Future<Me> buyCharacter(String id) async => Me.fromJson(_m(_m(await _req('POST', '/characters/$id/purchase'))['me']));
  @override Future<Me> setCharacter(String id) async => Me.fromJson(_m(await _req('PATCH', '/me/character', {'id': id})));
  @override Future<List<WrNotification>> notifications() async => _l(await _req('GET', '/notifications'), WrNotification.fromJson);
  @override Future<int> readNotifications({String? id}) async => (_m(await _req('POST', '/notifications', {if (id != null) 'id': id}))['unread'] as num).toInt();
  @override Future<({WishRoom before, WishRoom room})> enter(String id) async { final d = _m(await _req('POST', '/wish-rooms/$id/enter')); return (before: WishRoom.fromJson(_m(d['before'])), room: WishRoom.fromJson(_m(d['room']))); }
  @override Future<WishRoom> rekindle(String id) async => WishRoom.fromJson(_m(_m(await _req('POST', '/wish-rooms/$id/rekindle'))['room']));
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
  @override Future<Me> buyOutfit(String char, WrTheme theme) async => Me.fromJson(_m(_m(await _req('POST', '/outfits/purchase', {'char': char, 'theme': theme.name}))['me']));
  @override Future<WishRoom> setOutfit(String id, WrTheme? theme) async => WishRoom.fromJson(_m(await _req('PATCH', '/wish-rooms/$id/outfit', {'theme': theme?.name})));
  @override Future<WishRoom> unseal(String id) async => WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/unseal')));
  @override Future<WishRoom> outcome(String id, Outcome o, {String? text, String? sealUntil}) async =>
      WishRoom.fromJson(_m(await _req('POST', '/wish-rooms/$id/outcome', {'outcome': o.name, if (text != null) 'text': text, if (sealUntil != null) 'sealUntil': sealUntil})));
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
}
