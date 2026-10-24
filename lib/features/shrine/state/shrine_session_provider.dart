// 신당(THE SHRINE) v4.0 세션 상태 — [provider 6.1.5+1 고정 정책 포팅]
// 원본(신규 zip): lib/features/shrine/state/app_state.dart
// (flutter_riverpod StateNotifier/StateNotifierProvider 기반)
// ─────────────────────────────────────────────────────────────
// 본 프로젝트는 go_router/flutter_riverpod을 채택하지 않고
// provider + Navigator 1.0 으로 고정되어 있으므로(영구 정책), 원본의
// `ShrineNotifier extends StateNotifier<ShrineState>`를
// `ShrineSessionProvider extends ChangeNotifier`로 기계적으로 포팅한다.
// 데이터 모델(StoryPos/PathStep/StorySource/BoxItem/Pending/ShrineState)과
// SharedPreferences 키('shrine.v2')는 원본과 100% 동일하게 유지해,
// 추후 원본 리버팟 버전과 동작을 교차 검증할 수 있게 한다.
//
// ⚠ 원본 주석 그대로 유지: 모든 갱신은 update((s) => ...) 함수형으로 —
// 최신 상태 기준. (웹에서 발급 직후 부적함이 비던 버그 재발 방지)
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/shrine_engine.dart';

// ⚠ shrine_module.dart(kShrineBase 정의 위치)를 import하면
// state ↔ module 순환참조가 생기므로, 원본과 동일한 상수값('/shrine')을
// 이 한 곳에서만 하드코딩한다(원본 app_state.dart도 import 없이 동일한
// 패턴이었음 — shrine_module.dart와 값이 어긋나지 않도록 유지보수 시
// 반드시 함께 확인할 것).
const _kShrineBaseFallback = '/shrine';

class StoryPos {
  final String node;
  final int line;
  final Set<String> flags;
  final List<PathStep> path;
  const StoryPos(this.node, this.line, this.flags, this.path);
  Map toJson() => {
    'node': node,
    'line': line,
    'flags': flags.toList(),
    'path': path.map((e) => e.toJson()).toList(),
  };
  static StoryPos? fromJson(Map? j) => j == null
      ? null
      : StoryPos(
          j['node'],
          j['line'],
          Set<String>.from(
            j['flags'] is Map
                ? (j['flags'] as Map).keys
                : (j['flags'] ?? const []),
          ),
          (j['path'] as List? ?? []).map((e) => PathStep.fromJson(e)).toList(),
        );
}

class PathStep {
  final String label;
  final bool timeout;
  const PathStep(this.label, {this.timeout = false});
  Map toJson() => {'label': label, 'timeout': timeout};
  static PathStep fromJson(Map j) =>
      PathStep(j['label'], timeout: j['timeout'] == true);
}

/// 이야기 출처 (메인 'red-bell' 또는 추가 이야기 id) + 결말 + 선택 기록
class StorySource {
  final String story;
  final String ending;
  final Set<String> flags;
  final List<PathStep> path;
  const StorySource(
    this.story,
    this.ending, [
    this.flags = const {},
    this.path = const [],
  ]);
  Map toJson() => {
    'story': story,
    'ending': ending,
    'flags': flags.toList(),
    'path': path.map((e) => e.toJson()).toList(),
  };
  static StorySource? fromJson(Map? j) => j == null
      ? null
      : StorySource(
          j['story'],
          j['ending'],
          Set<String>.from(j['flags'] ?? const []),
          (j['path'] as List? ?? []).map((e) => PathStep.fromJson(e)).toList(),
        );
}

/// 부적함 한 장. key = 생성 조건(type|flavor|story|ending) — 같은 key 는 재열람, 다른 key 는 새 부적
/// [U5 포팅] shrine-screens-f.jsx — 수명 시스템 필드 추가:
///   at(발급 시각 ms) · tended(향 올린 횟수) · lastTend(마지막 향 올린 시각 ms) · sentAt(보낸 시각 ms)
/// ⚠ 원본 주석: "서버 저장 시 at·tended·lastTend·sentAt를 함께 저장. 날짜 계산은 서버 시간
/// 기준 권장(기기 시간 조작 방지)" — 단, 이 필드는 재발급 방지처럼 악용 방지가 필요한 영역이
/// 아니므로(수명 조작으로 인한 실질적 피해 없음) 현재는 기존 정책대로 로컬(SharedPreferences)에만
/// 저장한다. 서버 영속화가 필요해지면 이 주석을 참고해 ShrineIssueLedger 패턴을 확장할 것.
class BoxItem {
  final String key, no, date;
  final TalismanSpec spec;
  final StorySource source;
  final String mode;
  final bool saved;
  final int? at;
  final int tended;
  final int? lastTend;
  final int? sentAt;
  // [U13 포팅] 부적을 소원방(WishRoom)에 봉인한 기록 — 로컬 전용(서버 비저장,
  // U5 원칙과 동일). wishRoomId는 WishRoom.id(Flutter 쪽 공개 id 문자열),
  // wishText는 봉인 당시 소원 문구 스냅샷(소원이 나중에 바뀌어도 "그때 그
  // 소원"을 보여주기 위함), at은 봉인 시각(ms).
  final SealedTo? sealedTo;
  const BoxItem({
    required this.key,
    required this.no,
    required this.date,
    required this.spec,
    required this.source,
    this.mode = 'full',
    this.saved = false,
    this.at,
    this.tended = 0,
    this.lastTend,
    this.sentAt,
    this.sealedTo,
  });
  BoxItem copy({
    String? mode,
    bool? saved,
    int? at,
    int? tended,
    int? lastTend,
    int? sentAt,
    SealedTo? sealedTo,
  }) => BoxItem(
    key: key,
    no: no,
    date: date,
    spec: spec,
    source: source,
    mode: mode ?? this.mode,
    saved: saved ?? this.saved,
    at: at ?? this.at,
    tended: tended ?? this.tended,
    lastTend: lastTend ?? this.lastTend,
    sentAt: sentAt ?? this.sentAt,
    sealedTo: sealedTo ?? this.sealedTo,
  );
  Map toJson() => {
    'key': key,
    't': spec.type,
    'no': no,
    'date': date,
    'spec': spec.toJson(),
    'source': source.toJson(),
    'mode': mode,
    'saved': saved,
    'at': at,
    'tended': tended,
    'lastTend': lastTend,
    'sentAt': sentAt,
    'sealedTo': sealedTo?.toJson(),
  };
  static BoxItem fromJson(Map j) => BoxItem(
    key: j['key'],
    no: j['no'],
    date: j['date'],
    spec: TalismanSpec.fromJson(j['spec']),
    source: StorySource.fromJson(j['source'])!,
    mode: j['mode'] ?? 'full',
    saved: j['saved'] == true,
    at: j['at'] as int?,
    tended: j['tended'] ?? 0,
    lastTend: j['lastTend'] as int?,
    sentAt: j['sentAt'] as int?,
    sealedTo: SealedTo.fromJson(j['sealedTo'] as Map?),
  );
}

/// [U13 포팅] 부적 1장이 봉인된 소원방 정보 스냅샷. 로컬(SharedPreferences
/// 'shrine.v2')에만 저장되며 서버 WishRoom 스키마는 전혀 변경하지 않는다
/// (사용자 확정 원칙 — "소원방은 이미 있음, 봉인 연출만 포팅").
class SealedTo {
  final String wishRoomId;
  final String wishText;
  final int at;
  const SealedTo({
    required this.wishRoomId,
    required this.wishText,
    required this.at,
  });
  Map toJson() => {'wishRoomId': wishRoomId, 'wishText': wishText, 'at': at};
  static SealedTo? fromJson(Map? j) => j == null
      ? null
      : SealedTo(
          wishRoomId: j['wishRoomId'],
          wishText: j['wishText'] ?? '',
          at: j['at'] ?? 0,
        );
}

/// 의식 대기 중인 부적 — /meaning 에서 만들고 /ritual 과 /receive 가 "같은 것"을 쓴다
class Pending {
  final TalismanSpec spec;
  final StorySource source;
  final String flavor;
  final String back;
  const Pending(this.spec, this.source, this.flavor, this.back);
  Map toJson() => {
    'spec': spec.toJson(),
    'source': source.toJson(),
    'flavor': flavor,
    'back': back,
  };
  static Pending? fromJson(Map? j) => j == null
      ? null
      : Pending(
          TalismanSpec.fromJson(j['spec']),
          StorySource.fromJson(j['source'])!,
          j['flavor'],
          j['back'] ?? '$_kShrineBaseFallback/list',
        );
}

class ShrineState {
  // 회원 · 프로필
  final String? memberId;
  final List<String> memberScope;
  final String? topic, name, birth, time, season;
  final int visits;
  final SajuResult? saju; // 기기 캐시 — 원본은 신통방통. 연결 해제 시 삭제
  // 이야기
  final StoryPos? pos;
  final List<PathStep> lastPath;
  final Set<String> lastFlags;
  final Map<String, int> endings; // 메인 결말 코드 → 시각
  final Map<String, StoryPos?> talePos; // 추가 이야기 진행
  final Map<String, Map<String, int>> taleEndings;
  // 부적
  final StorySource? meaningSrc;
  final Pending? pending;
  final List<BoxItem> box;
  final int issued;
  // [U5 포팅] 신당 이야기(緣起) 열람 여부 · 들어가기 후 돌아갈 라우트 id
  final bool aboutSeen;
  final String? aboutBack;
  // pref
  final bool reduce, timer, sound, coached;
  final double ts;

  const ShrineState({
    this.memberId,
    this.memberScope = const [],
    this.topic,
    this.name,
    this.birth,
    this.time,
    this.season,
    this.visits = 0,
    this.saju,
    this.pos,
    this.lastPath = const [],
    this.lastFlags = const {},
    this.endings = const {},
    this.talePos = const {},
    this.taleEndings = const {},
    this.meaningSrc,
    this.pending,
    this.box = const [],
    this.issued = 0,
    this.aboutSeen = false,
    this.aboutBack,
    this.reduce = false,
    this.timer = true,
    this.sound = false,
    this.coached = false,
    this.ts = 1,
  });

  ShrineState copy({
    String? memberId,
    List<String>? memberScope,
    String? topic,
    String? name,
    String? birth,
    String? time,
    String? season,
    int? visits,
    SajuResult? saju,
    StoryPos? pos,
    bool clearPos = false,
    List<PathStep>? lastPath,
    Set<String>? lastFlags,
    Map<String, int>? endings,
    Map<String, StoryPos?>? talePos,
    Map<String, Map<String, int>>? taleEndings,
    StorySource? meaningSrc,
    Pending? pending,
    bool clearPending = false,
    List<BoxItem>? box,
    int? issued,
    bool? aboutSeen,
    String? aboutBack,
    bool? reduce,
    bool? timer,
    bool? sound,
    bool? coached,
    double? ts,
  }) => ShrineState(
    memberId: memberId ?? this.memberId,
    memberScope: memberScope ?? this.memberScope,
    topic: topic ?? this.topic,
    name: name ?? this.name,
    birth: birth ?? this.birth,
    time: time ?? this.time,
    season: season ?? this.season,
    visits: visits ?? this.visits,
    saju: saju ?? this.saju,
    pos: clearPos ? null : (pos ?? this.pos),
    lastPath: lastPath ?? this.lastPath,
    lastFlags: lastFlags ?? this.lastFlags,
    endings: endings ?? this.endings,
    talePos: talePos ?? this.talePos,
    taleEndings: taleEndings ?? this.taleEndings,
    meaningSrc: meaningSrc ?? this.meaningSrc,
    pending: clearPending ? null : (pending ?? this.pending),
    box: box ?? this.box,
    issued: issued ?? this.issued,
    aboutSeen: aboutSeen ?? this.aboutSeen,
    aboutBack: aboutBack ?? this.aboutBack,
    reduce: reduce ?? this.reduce,
    timer: timer ?? this.timer,
    sound: sound ?? this.sound,
    coached: coached ?? this.coached,
    ts: ts ?? this.ts,
  );

  bool get visited => visits > 1 || endings.isNotEmpty; // 실제 기록이 있을 때만 재방문 대사

  Map toJson() => {
    'data': {
      'member': memberId == null
          ? null
          : {'id': memberId, 'scope': memberScope},
      'topic': topic,
      'name': name,
      'birth': birth,
      'time': time,
      'season': season,
      'visits': visits,
      'saju': saju?.toJson(),
      'pos': pos?.toJson(),
      'lastPath': lastPath.map((e) => e.toJson()).toList(),
      'lastFlags': lastFlags.toList(),
      'endings': endings,
      'talePos': talePos.map((k, v) => MapEntry(k, v?.toJson())),
      'taleEndings': taleEndings,
      'meaningSrc': meaningSrc?.toJson(),
      'pending': pending?.toJson(),
      'box': box.map((b) => b.toJson()).toList(),
      'issued': issued,
      'aboutSeen': aboutSeen,
      'aboutBack': aboutBack,
    },
    'pref': {
      'reduce': reduce,
      'timer': timer,
      'sound': sound,
      'coached': coached,
      'ts': ts,
    },
  };
  static ShrineState fromJson(Map j) {
    final d = (j['data'] ?? {}) as Map, p = (j['pref'] ?? {}) as Map;
    final lf = d['lastFlags'];
    return ShrineState(
      memberId: d['member']?['id'],
      memberScope: List<String>.from(d['member']?['scope'] ?? const []),
      topic: d['topic'],
      name: d['name'],
      birth: d['birth'],
      time: d['time'],
      season: d['season'],
      visits: d['visits'] ?? 0,
      saju: d['saju'] == null ? null : SajuResult.fromJson(d['saju']),
      pos: StoryPos.fromJson(d['pos']),
      lastPath: (d['lastPath'] as List? ?? [])
          .map((e) => PathStep.fromJson(e))
          .toList(),
      lastFlags: Set<String>.from(lf is Map ? lf.keys : (lf ?? const [])),
      endings: Map<String, int>.from(d['endings'] ?? const {}),
      talePos: (d['talePos'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, StoryPos.fromJson(v)),
      ),
      taleEndings: (d['taleEndings'] as Map? ?? {}).map(
        (k, v) => MapEntry(k as String, Map<String, int>.from(v)),
      ),
      meaningSrc: StorySource.fromJson(d['meaningSrc']),
      pending: Pending.fromJson(d['pending']),
      box: (d['box'] as List? ?? [])
          .where((b) => b['spec'] != null)
          .map((b) => BoxItem.fromJson(b))
          .toList(),
      issued: d['issued'] ?? 0,
      aboutSeen: d['aboutSeen'] == true,
      aboutBack: d['aboutBack'],
      reduce: p['reduce'] ?? false,
      timer: p['timer'] ?? true,
      sound: p['sound'] ?? false,
      coached: p['coached'] ?? false,
      ts: (p['ts'] ?? 1).toDouble(),
    );
  }
}

String _today() {
  final d = DateTime.now();
  return '${d.year} · ${d.month.toString().padLeft(2, '0')} · ${d.day.toString().padLeft(2, '0')}';
}

/// [provider 포팅] 원본 ShrineNotifier(StateNotifier<ShrineState>)를
/// ChangeNotifier로 교체. 공개 API(update/finish/issue/updateBox/
/// unlinkMember/resetData)와 SharedPreferences 키('shrine.v2')는 원본과
/// 동일하게 유지한다.
class ShrineSessionProvider extends ChangeNotifier {
  static const _key = 'shrine.v2';
  final SharedPreferences prefs;
  ShrineState _state;

  ShrineSessionProvider(this.prefs) : _state = _read(prefs);

  ShrineState get state => _state;

  static ShrineState _read(SharedPreferences p) {
    final s = p.getString(_key);
    return s == null
        ? const ShrineState()
        : ShrineState.fromJson(jsonDecode(s));
  }

  void _save() => prefs.setString(_key, jsonEncode(_state.toJson()));

  /// ⚠ 반드시 함수형으로 최신 state를 기준으로 갱신한다(원본 app_state.dart
  /// 주석과 동일 이유 — 발급 직후 부적함이 비던 버그 재발 방지).
  void update(ShrineState Function(ShrineState) f) {
    _state = f(_state);
    _save();
    notifyListeners();
  }

  void finish(String code, List<PathStep> path, Set<String> flags) => update(
    (s) => s.copy(
      clearPos: true,
      lastPath: path,
      lastFlags: flags,
      endings: {...s.endings, code: DateTime.now().millisecondsSinceEpoch},
    ),
  );

  /// 부적 발급 — 같은 key 면 기존 항목 반환(dup), 아니면 새 일련번호. 최신 상태 기준.
  /// [U5 포팅] 보낸(sentAt != null, 灰) 부적은 중복 판정에서 제외한다 — 같은 길을
  /// 다시 걸으면 새 부적을 받을 수 있다(UPDATE_LOG_U1-U13.md U5-2 "보낸 부적은 같은
  /// 조건 부적의 중복 판정에서 제외" 참고).
  ({BoxItem item, bool dup}) issue(Pending p, String mode) {
    final ex = _state.box
        .where((b) => b.key == p.spec.key && b.sentAt == null)
        .firstOrNull;
    if (ex != null) return (item: ex, dup: true);
    late BoxItem item;
    update((s) {
      item = BoxItem(
        key: p.spec.key,
        no: 'N°${(s.issued + 1).toString().padLeft(4, '0')}',
        date: _today(),
        spec: p.spec,
        source: p.source,
        mode: mode,
        at: DateTime.now().millisecondsSinceEpoch,
      );
      return s.copy(box: [...s.box, item], issued: s.issued + 1);
    });
    return (item: item, dup: false);
  }

  void updateBox(String no, BoxItem Function(BoxItem) f) {
    final before = _state.box.where((b) => b.no == no).firstOrNull;
    debugPrint(
      '[U13-DEBUG] updateBox(no=$no) found=${before != null} boxNos=${_state.box.map((b) => b.no).toList()}',
    );
    update((s) => s.copy(box: s.box.map((b) => b.no == no ? f(b) : b).toList()));
    final after = _state.box.where((b) => b.no == no).firstOrNull;
    debugPrint('[U13-DEBUG] updateBox after sealedTo=${after?.sealedTo?.wishRoomId}');
  }

  void unlinkMember() => update(
    (s) => ShrineState(
      reduce: s.reduce,
      timer: s.timer,
      sound: s.sound,
      ts: s.ts,
      coached: s.coached,
      box: s.box,
      issued: s.issued,
      endings: s.endings,
      taleEndings: s.taleEndings,
    ),
  ); // 사주 캐시·프로필 삭제, 수집 기록은 유지

  void resetData() => update(
    (s) => ShrineState(
      reduce: s.reduce,
      timer: s.timer,
      sound: s.sound,
      ts: s.ts,
      coached: s.coached,
    ),
  );
}

String nameShown(String? name, String mode) {
  if (name == null || name.isEmpty) return '';
  if (mode == 'full') return name;
  if (mode == 'initial') {
    final chars = name.characters;
    return chars.first + '○' * (chars.length - 1).clamp(1, 3);
  }
  return '';
}
