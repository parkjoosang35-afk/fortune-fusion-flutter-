// 신통방통 소원방 · 도메인 모델 v2.6
// 기준: 프로토타입 prototype/app/api.js 의 roomView() / meView() 응답 필드 (= 서버 응답 계약)
// 실제 프로젝트에서는 freezed + json_serializable 로 전환 권장. 필드명은 그대로 유지하세요.

enum RoomStatus { DRAFT, ACTIVE, GROWING, COMPLETED, SEALED, ARCHIVED }
enum Visibility { PUBLIC, LINK, PRIVATE }
/// 꾸미기 슬롯 7종 — 최대 개수는 data/wishroom_data.json › SLOTS[].max
enum Slot { CANDLE, FLOWER, DECORATION, BACKGROUND, SPECIAL, SEAL, THEME }
enum NotiType { SUPPORT, POUCH, COMMENT, STATUS, GROWTH, COMPLETE, UNSEAL, REVIEW }
enum Behavior { idle, gaze, pray, flower, pouch, celebrate }
/// 소원방 테마 — 방 그림 · 의상 · 정성 의식이 바뀜 (docs/THEME.md)
enum WrTheme { free, god, buddha, shaman }
/// 정성 동작 — 테마별 RITUAL[theme].pose
enum Pose { pray, bow, rub }
/// 타임캡슐(봉인일) 상태
enum Capsule { LOCKED, OPENED }
enum Outcome { FULFILLED, ONGOING, REWISH }
enum WishStatus { IN_PROGRESS, ACHIEVED }

T _enum<T extends Enum>(List<T> v, String? s, T fallback) => v.firstWhere((e) => e.name == s, orElse: () => fallback);
DateTime? _ts(dynamic v) => v == null || v == 0 ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());

class Equip {
  final String candle, flower, background, special;
  final List<String> decoration; // ≤5
  final List<String> seal;       // ≤3
  final List<String> theme;      // ≤5  테마 소품
  const Equip({required this.candle, required this.flower, required this.background, required this.special,
      this.decoration = const [], this.seal = const [], this.theme = const []});
  factory Equip.fromJson(Map<String, dynamic> j) => Equip(
        candle: j['CANDLE'] ?? 'c_basic', flower: j['FLOWER'] ?? 'f_none', background: j['BACKGROUND'] ?? 'b_night', special: j['SPECIAL'] ?? 's_none',
        decoration: List<String>.from(j['DECORATION'] ?? const []), seal: List<String>.from(j['SEAL'] ?? const []), theme: List<String>.from(j['THEME'] ?? const []));
  List<String> get all => [candle, flower, background, special, ...decoration, ...seal, ...theme];
}

/// 사용자가 직접 옮긴 아이템 좌표 (PATCH /wish-rooms/{id}/layout) — 390×844 캔버스 기준
class LayoutPos { final double x, y, s; const LayoutPos(this.x, this.y, this.s);
  factory LayoutPos.fromJson(Map<String, dynamic> j) => LayoutPos((j['x'] as num).toDouble(), (j['y'] as num).toDouble(), (j['s'] as num).toDouble()); }

/// 장착 아이템 1개의 기운 상세 — wishroom-engine.ts effectsOf()의 `src[]` 1:1
/// (id, name, type, v = 궁합 적용된 최종값, match = 소원 빛깔과 아이템 aura 일치 여부)
class EffectSrc {
  final String id, name, type;
  final int v;
  final bool match;
  const EffectSrc({required this.id, required this.name, required this.type, required this.v, required this.match});
  factory EffectSrc.fromJson(Map<String, dynamic> j) => EffectSrc(
      id: j['id'] ?? '', name: j['name'] ?? '', type: j['type'] ?? '', v: (j['v'] as num?)?.toInt() ?? 0, match: j['match'] ?? false);
}

/// 장착 아이템 기운 합계 (서버 계산 · 상한 EFFECT_CAP)
class Effects {
  final int devo, support, cool, daily, pouch, decay;
  final List<EffectSrc> src;
  const Effects({this.devo = 0, this.support = 0, this.cool = 0, this.daily = 0, this.pouch = 0, this.decay = 0, this.src = const []});
  factory Effects.fromJson(Map<String, dynamic>? j) => j == null ? const Effects() : Effects(
      devo: j['devo'] ?? 0, support: j['support'] ?? 0, cool: j['cool'] ?? 0, daily: j['daily'] ?? 0, pouch: j['pouch'] ?? 0, decay: j['decay'] ?? 0,
      src: j['src'] == null ? const [] : (j['src'] as List).map((e) => EffectSrc.fromJson(Map<String, dynamic>.from(e))).toList());
}

class SupportRewardState {
  final int at; final String reward, icon; final bool reached, claimed; final String? got;
  SupportRewardState.fromJson(Map<String, dynamic> j) : at = j['at'], reward = j['reward'], icon = j['icon'], reached = j['reached'] ?? false, claimed = j['claimed'] ?? false, got = j['got'];
}

class WishRoom {
  final String id, ownerId, owner, region, text, char;
  final RoomStatus status;
  final Visibility visibility;
  final WrTheme theme;           // 방 테마
  final WrTheme? outfit;         // 사용자가 고른 의상 (null = 테마 따라감)
  final WrTheme outfitNow;       // [SERVER] 실제 표시할 의상 (그림 있고 보유했을 때만, 아니면 free)
  final String wishColor, paper; // 소원 빛깔(康財緣…) · 한지 색
  final int devotionCount, supportCount, pouchReceived, level, commentCount;
  final double points;
  final String levelName;
  final int curLevelPts;
  final int? nextLevelPts;
  final double brightness;       // §6.2  1.0 / .8 / .5 / .3 / .2 (아이템 decay 효과로 하한 상승)
  final String decayLabel;
  final bool decayBadge, isMine, supportedToday;
  final int absentDays, devotionsToday, devotionsRemaining, dailyLimit, cooldownSec, daysLit;
  final DateTime? cooldownUntil, completedAt, cancelUntil, createdAt;
  final Equip equip;
  final Map<String, LayoutPos> layout;
  final Effects effects;
  final List<SupportRewardState>? rewards;
  // 타임캡슐 봉인 (소원 작성 시 봉인일 → 그날 열림)
  final String? sealUntil, sealedOn;       // 'YYYY-MM-DD' (KST)
  final Capsule? capsule;
  final int? sealDaysLeft, sealTotalDays;
  final bool capsuleDue;
  final Outcome? outcome;
  final WishStatus? wishStatus;
  final String? shareToken;
  final Map<String, dynamic>? snapshot;    // SEALED/ARCHIVED 시 보존 (§14.2)

  WishRoom.fromJson(Map<String, dynamic> j)
      : id = j['id'], ownerId = j['ownerId'], owner = j['owner'] ?? '', region = j['region'] ?? '',
        text = j['text'], char = j['char'],
        status = _enum(RoomStatus.values, j['status'], RoomStatus.ACTIVE), visibility = _enum(Visibility.values, j['visibility'], Visibility.PUBLIC),
        theme = _enum(WrTheme.values, j['theme'], WrTheme.free),
        outfit = j['outfit'] == null ? null : _enum(WrTheme.values, j['outfit'], WrTheme.free),
        outfitNow = _enum(WrTheme.values, j['outfitNow'], WrTheme.free),
        wishColor = j['wishColor'] ?? 'hope', paper = j['paper'] ?? 'hanji',
        devotionCount = (j['devotionCount'] as num).toInt(), supportCount = (j['supportCount'] as num).toInt(),
        pouchReceived = (j['pouchReceived'] as num).toInt(), level = j['level'], commentCount = j['commentCount'] ?? 0,
        points = (j['points'] as num).toDouble(), levelName = j['levelName'], curLevelPts = j['curLevelPts'],
        nextLevelPts = j['nextLevelPts'], brightness = (j['brightness'] as num).toDouble(), decayLabel = j['decayLabel'] ?? '',
        decayBadge = j['decayBadge'] ?? false, isMine = j['isMine'] ?? false, supportedToday = j['supportedToday'] ?? false,
        absentDays = j['absentDays'] ?? 0, devotionsToday = j['devotionsToday'] ?? 0, devotionsRemaining = j['devotionsRemaining'] ?? 10,
        dailyLimit = j['dailyLimit'] ?? 10, cooldownSec = j['cooldownSec'] ?? 30, daysLit = j['daysLit'] ?? 1,
        cooldownUntil = _ts(j['cooldownUntil']), completedAt = _ts(j['completedAt']), cancelUntil = _ts(j['cancelUntil']), createdAt = _ts(j['createdAt']),
        equip = Equip.fromJson(Map<String, dynamic>.from(j['equip'] ?? const {})),
        layout = (Map<String, dynamic>.from(j['layout'] ?? const {})).map((k, v) => MapEntry(k, LayoutPos.fromJson(Map<String, dynamic>.from(v)))),
        effects = Effects.fromJson(j['effects'] == null ? null : Map<String, dynamic>.from(j['effects'])),
        rewards = j['rewards'] == null ? null : (j['rewards'] as List).map((x) => SupportRewardState.fromJson(Map<String, dynamic>.from(x))).toList(),
        sealUntil = j['sealUntil'], sealedOn = j['sealedOn'],
        capsule = j['capsule'] == null ? null : _enum(Capsule.values, j['capsule'], Capsule.LOCKED),
        sealDaysLeft = j['sealDaysLeft'], sealTotalDays = j['sealTotalDays'], capsuleDue = j['capsuleDue'] ?? false,
        outcome = j['outcome'] == null ? null : _enum(Outcome.values, j['outcome'], Outcome.ONGOING),
        wishStatus = j['wishStatus'] == null ? null : _enum(WishStatus.values, j['wishStatus'], WishStatus.IN_PROGRESS),
        shareToken = j['shareToken'], snapshot = j['snapshot'];

  double get levelProgress => nextLevelPts == null ? 1 : ((points - curLevelPts) / (nextLevelPts! - curLevelPts)).clamp(0, 1).toDouble();
  bool get readOnly => status == RoomStatus.SEALED || status == RoomStatus.ARCHIVED;
  bool get sacred => theme != WrTheme.free; // 교회·법당·신당 — 창밖 배경·Lv 해금 오브젝트·촛불 교체 숨김
}

class Me {
  final String id, nick, repChar;
  final int pouch, accountAgeDays, giftToday, unread;
  final List<String> ownedChars, ownedItems, ownedOutfits; // ownedOutfits = ['F03:god', ...]
  final bool skipIntro;
  final Map<String, int> earnToday;
  final Map<String, dynamic>? wallpaper;
  Me.fromJson(Map<String, dynamic> j)
      : id = j['id'], nick = j['nick'], repChar = j['repChar'], pouch = j['pouch'], accountAgeDays = j['accountAgeDays'] ?? 0,
        giftToday = j['giftToday'] ?? 0, unread = j['unread'] ?? 0,
        ownedChars = List<String>.from(j['ownedChars'] ?? const []), ownedItems = List<String>.from(j['ownedItems'] ?? const []),
        ownedOutfits = List<String>.from(j['ownedOutfits'] ?? const []),
        skipIntro = (j['settings'] ?? {})['skipIntro'] ?? false,
        earnToday = Map<String, int>.from(j['earnToday'] ?? {}), wallpaper = j['wallpaper'];
  bool ownsOutfit(String char, WrTheme t) => t == WrTheme.free || ownedOutfits.contains('$char:${t.name}');
}

enum IntroMode { full, short, none }

class MyRoomResponse {
  final WishRoom? room; final Me me; final IntroMode introMode;
  MyRoomResponse.fromJson(Map<String, dynamic> j)
      : room = j['room'] == null ? null : WishRoom.fromJson(j['room']), me = Me.fromJson(j['me']),
        introMode = _enum(IntroMode.values, j['introMode'], IntroMode.none);
}

class DevotionResult {
  final WishRoom room; final int prevLevel, bonus; final bool leveledUp; final Me me;
  final DevotionGain? gain;
  DevotionResult.fromJson(Map<String, dynamic> j)
      : room = WishRoom.fromJson(j['room']), prevLevel = j['prevLevel'], leveledUp = j['leveledUp'], bonus = j['bonus'] ?? 0, me = Me.fromJson(j['me']),
        gain = j['gain'] == null ? null : DevotionGain.fromJson(Map<String, dynamic>.from(j['gain']));
}

/// A-4 devote() 0.7s 단계 — "아이템 기운 보너스가 있으면 top 236 금→핑크 pill
/// `✦ 아이템 기운 +n%` + 아래 아이템별 작은 칩" 연출용. 서버 응답 `gain.bonus`(비율,
/// 예: 0.05 = 5%) · `gain.fx`(장착 아이템별 기운 목록).
class DevotionGain {
  final double bonus; // 소수(0.05 = +5%) — bonusPct = (bonus*100).round()
  final List<DevotionGainItem> fx;
  DevotionGain.fromJson(Map<String, dynamic> j)
      : bonus = (j['bonus'] as num?)?.toDouble() ?? 0,
        fx = (j['fx'] as List? ?? const []).map((e) => DevotionGainItem.fromJson(Map<String, dynamic>.from(e))).toList();
}

class DevotionGainItem {
  final String id, name, type; final int v; final bool match;
  DevotionGainItem.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String, name = j['name'] as String, type = j['type'] as String, v = (j['v'] as num).toInt(), match = j['match'] == true;
}

class ItemEffect { final String type; final int v; ItemEffect.fromJson(Map<String, dynamic> j) : type = j['type'], v = j['v']; }

class WrItem {
  final String id, name; final Slot slot; final int? price; final bool owned;
  final String? img, glyph, kind, tier, aura, desc, hanja, color, fx; // kind: stand|hang|float · tier: free|normal|special
  final WrTheme? theme;  // THEME 슬롯 전용
  final double? s;       // 기본 크기(px, 390 캔버스)
  final ItemEffect? effect;
  final int? reward;     // 응원 보상 전용 아이템 (구매 불가)
  WrItem.fromJson(Map<String, dynamic> j)
      : id = j['id'], name = j['name'], slot = _enum(Slot.values, j['slot'], Slot.DECORATION), price = j['price'], owned = j['owned'] ?? false,
        img = j['img'], glyph = j['glyph'], kind = j['kind'], tier = j['tier'], aura = j['aura'], desc = j['desc'], hanja = j['hanja'], color = j['color'], fx = j['fx'],
        theme = j['theme'] == null ? null : _enum(WrTheme.values, j['theme'], WrTheme.free),
        s = (j['s'] as num?)?.toDouble(), effect = j['effect'] == null ? null : ItemEffect.fromJson(Map<String, dynamic>.from(j['effect'])), reward = j['reward'];
  String? get asset => img == null ? null : 'assets/wishroom/items/$img.png';
}

class WrCharacter {
  final String id, name, title, grade, gender, emblem; final int? price; final bool owned; final List<Behavior> behaviors;
  final String? job, type, personality, likes, aura, line;
  WrCharacter.fromJson(Map<String, dynamic> j)
      : id = j['id'], name = j['name'], title = j['title'], grade = j['grade'], gender = j['gender'], emblem = j['emblem'] ?? '',
        price = j['price'], owned = j['owned'] ?? false,
        behaviors = (j['behaviors'] as List? ?? const []).map((b) => _enum(Behavior.values, b, Behavior.idle)).toList(),
        job = j['job'], type = j['type'], personality = j['personality'], likes = j['likes'], aura = j['aura'], line = j['line'];
}

class OutfitOffer { final WrTheme theme; final int price; final bool hasArt, owned;
  OutfitOffer.fromJson(Map<String, dynamic> j) : theme = _enum(WrTheme.values, j['theme'], WrTheme.free), price = j['price'] ?? 0, hasArt = j['hasArt'] ?? false, owned = j['owned'] ?? false; }

class WrNotification {
  final String id, text; final NotiType type; final String? roomId; final DateTime at; final bool read;
  WrNotification.fromJson(Map<String, dynamic> j)
      : id = j['id'], text = j['text'], type = _enum(NotiType.values, j['type'], NotiType.STATUS), roomId = j['roomId'], at = _ts(j['at'])!, read = j['read'] ?? false;
}

class WrComment {
  final String id, author, text; final DateTime at;
  WrComment.fromJson(Map<String, dynamic> j) : id = j['id'], author = j['author'], text = j['text'], at = _ts(j['at'])!;
}

class WrReview {
  final String id, roomId, author, wishText, text, wishColor; final String? photo; final int congrats; final bool congratsByMe, mine; final String status;
  // app2/review2.jsx › StoryCard() `v.visibility === 'PUBLIC' ? '공개' : '나만 보기'` 1:1 —
  // [버그수정 — 전수감사] 기존엔 이 필드가 아예 없어 내 글 칩(공개/나만 보기)을
  // 표시할 방법이 없었다.
  final String visibility;
  // app2/review2.jsx › StoryCard() `d(v.achievedAt)` (1행 날짜 mono 표기) 1:1.
  final DateTime? achievedAt;
  WrReview.fromJson(Map<String, dynamic> j) : id = j['id'], roomId = j['roomId'], author = j['author'] ?? '', wishText = j['wishText'] ?? '', text = j['text'] ?? '',
      wishColor = j['wishColor'] ?? 'hope', photo = j['photo'], congrats = j['congrats'] ?? 0, congratsByMe = j['congratsByMe'] ?? false, mine = j['mine'] ?? false, status = j['status'] ?? 'OK',
      visibility = j['visibility'] ?? 'PUBLIC', achievedAt = _ts(j['achievedAt']);
}

// ── 배경화면(W1~W5) — docs/WALLPAPER.md ──
// 웹 원본의 "매니페스트"는 레이어 배열(sky/room/particle/deco/candle/char/fx...)을
// 들고 있지만, 그 레이어들은 이미 RoomScene이 room+equip+level로부터 그대로
// 그려내는 것과 같은 내용이다("같은 좌표" — WALLPAPER.md §3). 그래서 이 앱에서는
// 별도 레이어 렌더러를 새로 만들지 않고, 매니페스트 응답에 담긴 WishRoom(또는
// 보존된 소원방의 snapshot으로 재구성한 WishRoom)을 그대로 RoomScene에 넘겨
// "같은 수식으로 그린다"는 원칙을 지킨다.
class WPManifest {
  final String wishRoomId;
  final int version;
  final String title;
  final WishRoom room; // RoomScene(room: .., items: ..)에 그대로 전달
  final List<String> equippedItemIds;
  final bool fulfilled; // state === 'FULFILLED' (보존된 소원방 — 금빛 리본 · confetti 1회)
  factory WPManifest.fromJson(Map<String, dynamic> j) {
    final room = WishRoom.fromJson(Map<String, dynamic>.from(j['room']));
    final state = j['state'] as String? ?? (room.status == RoomStatus.ARCHIVED ? 'FULFILLED' : 'ACTIVE');
    return WPManifest._(
      wishRoomId: j['wishRoomId'] as String? ?? room.id,
      version: (j['version'] as num?)?.toInt() ?? 1,
      title: j['title'] as String? ?? '내 소원방',
      room: room,
      equippedItemIds: j['equippedItemIds'] == null ? room.equip.all : List<String>.from(j['equippedItemIds']),
      fulfilled: state == 'FULFILLED',
    );
  }
  WPManifest._({required this.wishRoomId, required this.version, required this.title, required this.room, required this.equippedItemIds, required this.fulfilled});
  String get band {
    final lv = room.level;
    if (lv >= 7) return 'B4';
    if (lv >= 5) return 'B3';
    if (lv >= 3) return 'B2';
    return 'B1';
  }
}

/// `GET /me/wallpaper` 응답 — 현재 설정 상태.
class WallpaperStatus {
  final String? roomId, platform, target; // platform: android|ios · target: BOTH|HOME|LOCK
  final int version, latestVersion;
  final bool needsUpdate, autoSynced;
  final int seenLevelNotice;
  WallpaperStatus.fromJson(Map<String, dynamic> j)
      : roomId = j['roomId'], platform = j['platform'], target = j['target'],
        version = (j['version'] as num?)?.toInt() ?? 0, latestVersion = (j['latestVersion'] as num?)?.toInt() ?? 0,
        needsUpdate = j['needsUpdate'] ?? false, autoSynced = j['autoSynced'] ?? false,
        seenLevelNotice = (j['seenLevelNotice'] as num?)?.toInt() ?? 0;
  const WallpaperStatus.empty() : roomId = null, platform = null, target = null, version = 0, latestVersion = 0, needsUpdate = false, autoSynced = false, seenLevelNotice = 0;
  bool get isSet => roomId != null;
}

class ApiError implements Exception {
  final int status; final String code, message; final Map<String, dynamic> extra;
  ApiError(this.status, this.code, this.message, [this.extra = const {}]);
  int? get retryAfter => extra['retryAfter'];
  int? get need => extra['need'];
  int? get have => extra['have'];
  @override String toString() => '$status $code $message';
}
