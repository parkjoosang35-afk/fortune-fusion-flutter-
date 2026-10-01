// 신통방통 소원방 · 정적 카탈로그 로더
// assets/wishroom/data/wishroom_data.json (= prototype/app/data.js 를 그대로 덤프한 것)
// 레벨 · 감쇠 · 슬롯 · 아이템 82 · 캐릭터 22 · 테마 4 · 의식(RITUAL) · 의상/동작 그림 경로 · 응원 보상 · 획득처 · 소원 빛깔 · 종이 색
// 서버도 같은 JSON 을 시드 데이터로 쓰면 앱과 서버 값이 어긋나지 않습니다.
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'models.dart';

class WrCatalog {
  WrCatalog._(this.raw);
  final Map<String, dynamic> raw;
  static late WrCatalog I;

  // [버그수정 — 실제 런타임 검증으로 발견] WrCatalog.load()가 앱 어디에서도
  // 호출되지 않아 `static late WrCatalog I`가 초기화되지 않은 채 ComposeScreen/
  // MainRoomScreen/DecorScreen/CharacterShopScreen/VaultScreen 등이 WrCatalog.I를
  // 참조하는 즉시 LateInitializationError로 화면 전체가 크래시했다(회색 화면).
  // 호출부(wish_room_intro_screen.dart._boot())에서 매번 안전하게 await할 수
  // 있도록 load()를 멱등(idempotent)하게 만든다 — 이미 로드됐으면 즉시 반환.
  static bool _loaded = false;
  static bool get isLoaded => _loaded;

  static Future<void> load() async {
    if (_loaded) return;
    I = WrCatalog._(jsonDecode(await rootBundle.loadString('assets/wishroom/data/wishroom_data.json')));
    _loaded = true;
  }

  List<Map<String, dynamic>> _list(String k) => (raw[k] as List).map((e) => Map<String, dynamic>.from(e)).toList();

  List<Map<String, dynamic>> get levels => _list('LEVELS');           // {lv, name, pts, ...}
  List<Map<String, dynamic>> get decay => _list('DECAY');             // {minDays, brightness, label, badge, push?}
  Map<String, dynamic> get devotionRule => Map<String, dynamic>.from(raw['DEVOTION_RULE']); // dailyLimit 10 · cooldownSec 30 · bonusAt 10 · bonusPouch 20
  List<Map<String, dynamic>> get slots => _list('SLOTS');             // 7 슬롯 + max
  List<WrItem> get items => _list('ITEMS').map(WrItem.fromJson).toList();
  List<WrCharacter> get characters => _list('CHARACTERS').map(WrCharacter.fromJson).toList();
  List<Map<String, dynamic>> get themes => _list('THEMES');           // {id,label,glyph,hanja,sub,color,deep,light,desc,room}
  List<Map<String, dynamic>> get wishColors => _list('WISH_COLORS');  // 康 財 緣 …
  List<Map<String, dynamic>> get papers => _list('PAPERS');
  List<Map<String, dynamic>> get supportRewards => _list('SUPPORT_REWARDS');
  List<Map<String, dynamic>> get earn => _list('EARN');
  Map<String, dynamic> get effectCap => Map<String, dynamic>.from(raw['EFFECT_CAP']);
  Map<String, dynamic> get outfitPrice => Map<String, dynamic>.from(raw['OUTFIT_PRICE']);

  /// 테마별 정성 의식 — verb(기도/치성/정성) · icon · pose · done 문장 · lines(머금는 동안 3문장) · quotes(말씀 카드 [text, source])
  Map<String, dynamic> ritual(WrTheme t) => Map<String, dynamic>.from(raw['RITUAL'][t.name]);

  String roomImage(WrTheme t) => 'assets/wishroom/${(themes.firstWhere((x) => x['id'] == t.name)['room'] as String).replaceFirst('assets/', '')}';

  /// 캐릭터 이미지 (의상 반영). 웹 room2.jsx › charSrc() 와 동일 규칙
  String charImage(String code, WrTheme outfit) {
    final art = raw['OUTFIT_ART'][code];
    if (art != null && art[outfit.name] != null) return 'assets/wishroom/${(art[outfit.name] as String).replaceFirst('assets/', '')}';
    if (code == 'F01') return 'assets/wishroom/char-f-sm.png';
    if (code == 'M01') return 'assets/wishroom/char-m-sm.png';
    return 'assets/wishroom/chars/$code.png';
  }

  /// 정성 동작 그림 — 없으면 null → 기본 그림 + 기울기 모션으로 대체. 웹 data.js › poseArt() 와 동일
  String? poseImage(String code, WrTheme outfit, Pose pose) {
    final m = Map<String, dynamic>.from(raw['POSE_ART']);
    final k = '${code}_${outfit.name}_';
    final p = m['$k${pose.name}'] ?? m['${k}pray'] ?? m.entries.where((e) => e.key.startsWith(k)).map((e) => e.value).cast<String?>().firstWhere((_) => true, orElse: () => null);
    return p == null ? null : 'assets/wishroom/${(p as String).replaceFirst('assets/', '')}';
  }

  Map<String, dynamic> levelOf(int lv) => levels.firstWhere((l) => l['lv'] == lv);
}
