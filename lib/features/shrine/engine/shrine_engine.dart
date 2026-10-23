// 신당 v3 — 엔진 경계 (웹 shrine-engine.js 와 1:1)
// ─────────────────────────────────────────────────────────────
// ⚠ 신당은 사주를 계산하지 않는다.
//   SajuRepository / MemberRepository 는 "인터페이스"이고,
//   Sample* 구현은 신통방통 API 연동 전 시연용이다. 실제 구현은
//   신통방통 API 응답을 SajuResult 로 "변환"만 한다(어댑터).
//   엔진이 주지 않는 값은 null → 화면에서 생략. 지어내지 않는다.
// ─────────────────────────────────────────────────────────────
import 'dart:convert';

// ═══════════ 회원 ═══════════
class MemberProfile {
  final String memberId; final String? name, birth, time; final String calendar;
  const MemberProfile({required this.memberId, this.name, this.birth, this.time, this.calendar = '양력'});
}

/// 실제 구현: 신통방통 인증(OAuth 류) → 사용자가 동의한 scope 만 수신.
/// 토큰·비밀번호를 신당 저장소에 복사하지 않는다.
abstract class MemberRepository {
  Future<MemberProfile> link({required Set<String> scope}); // scope: name / birth / time
  Future<void> unlink();
}

class SampleMemberRepository implements MemberRepository {
  @override
  Future<MemberProfile> link({required Set<String> scope}) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return MemberProfile(memberId: 'stb_sample_0001',
      name: scope.contains('name') ? '박서연' : null,
      birth: scope.contains('birth') ? '1995.08.14' : null,
      time: scope.contains('time') ? '14:20' : null);
  }
  @override
  Future<void> unlink() async {}
}

// ═══════════ 정통사주 ═══════════
class TopicReading { final double score; final String? note; const TopicReading(this.score, this.note);
  Map toJson() => {'score': score, 'note': note};
  static TopicReading fromJson(Map j) => TopicReading((j['score'] as num).toDouble(), j['note']); }

class SajuResult {
  final Map<String, String?> pillars;           // year · month · day · hour(null 가능)
  final String dayStem, dayElement, dayLabel;
  final Map<String, int> elements;              // 木 火 土 金 水
  final String? temperament;
  final List<String> strengths, cautions;
  final Map<String, TopicReading> topics;       // fate · love · money · flow
  final bool hourUnknown;
  final String source;                          // 'SAMPLE' | 'STB_SAJU_ENGINE'
  const SajuResult({required this.pillars, required this.dayStem, required this.dayElement, required this.dayLabel,
    required this.elements, this.temperament, this.strengths = const [], this.cautions = const [], this.topics = const {},
    this.hourUnknown = false, this.source = 'SAMPLE'});

  Map toJson() => {'pillars': pillars, 'dayMaster': {'stem': dayStem, 'element': dayElement, 'label': dayLabel}, 'elements': elements,
    'temperament': temperament, 'strengths': strengths, 'cautions': cautions, 'topics': topics.map((k, v) => MapEntry(k, v.toJson())),
    'hourUnknown': hourUnknown, 'source': source};
  static SajuResult fromJson(Map j) => SajuResult(
    pillars: Map<String, String?>.from(j['pillars']), dayStem: j['dayMaster']['stem'], dayElement: j['dayMaster']['element'], dayLabel: j['dayMaster']['label'],
    elements: Map<String, int>.from(j['elements']), temperament: j['temperament'],
    strengths: List<String>.from(j['strengths'] ?? const []), cautions: List<String>.from(j['cautions'] ?? const []),
    topics: (j['topics'] as Map? ?? {}).map((k, v) => MapEntry(k as String, TopicReading.fromJson(v))),
    hourUnknown: j['hourUnknown'] == true, source: j['source'] ?? 'SAMPLE');
}

/// 실제 구현: 신통방통 정통사주 API 호출 → SajuResult 로 매핑.
/// 매핑표(실제 응답 필드 → 이 스키마)는 착수 전 제출물 ④에 포함한다.
abstract class SajuRepository { Future<SajuResult?> fetch({required String birth, String? time, String calendar = '양력'}); }

int fnv(String s) { var h = 2166136261; for (final c in s.codeUnits) { h ^= c; h = (h * 16777619) & 0xFFFFFFFF; } return h; }

class SampleSajuRepository implements SajuRepository {
  // 웹 shrine-engine.js SAMPLES 와 같은 3종. 숫자는 예시일 뿐.
  static final _samples = [
    {'pillars': {'year': '乙亥', 'month': '甲申', 'day': '丁卯', 'hour': '丁未'}, 'dayMaster': {'stem': '丁', 'element': '火', 'label': '정화(丁火) · 촛불의 불'},
     'elements': {'木': 3, '火': 3, '土': 1, '金': 1, '水': 2},
     'temperament': '작은 불처럼 주변을 오래 밝히는 기질로 풀이됩니다. 겉으로는 조용하지만 한번 마음을 두면 쉽게 꺼지지 않습니다.',
     'strengths': ['사람을 살피는 섬세함', '한번 정한 일을 오래 지키는 끈기'], 'cautions': ['마음을 먼저 다 내어주고 지치기 쉬움', '토(土) 기운이 적어 결정을 미루는 경향'],
     'topics': {'love': {'score': .86, 'note': '인연을 뜻하는 기운이 두드러지게 나타납니다.'}, 'fate': {'score': .62, 'note': '스스로를 밝히는 불의 기운이 뚜렷합니다.'},
       'money': {'score': .41, 'note': '재물 기운은 고르게 흐르는 편입니다.'}, 'flow': {'score': .55, 'note': '올해는 변화의 기운이 조금 들어옵니다.'}}},
    {'pillars': {'year': '壬申', 'month': '辛亥', 'day': '庚辰', 'hour': null}, 'dayMaster': {'stem': '庚', 'element': '金', 'label': '경금(庚金) · 다듬지 않은 쇠'},
     'elements': {'木': 0, '火': 1, '土': 2, '金': 3, '水': 3},
     'temperament': '단단하고 곧은 쇠의 기질로 풀이됩니다. 옳다고 여기는 일 앞에서는 물러서지 않습니다.',
     'strengths': ['결단력', '맡은 것을 끝까지 책임지는 태도'], 'cautions': ['목(木) 기운이 없어 융통성이 부족해 보일 수 있음'],
     'topics': {'money': {'score': .81, 'note': '재물과 일의 흐름을 뜻하는 기운이 강하게 나타납니다.'}, 'fate': {'score': .58, 'note': '자기 길을 스스로 정하는 기운이 있습니다.'},
       'love': {'score': .37, 'note': null}, 'flow': {'score': .49, 'note': null}}},
    {'pillars': {'year': '己卯', 'month': '丙子', 'day': '癸酉', 'hour': '壬子'}, 'dayMaster': {'stem': '癸', 'element': '水', 'label': '계수(癸水) · 이슬과 빗물'},
     'elements': {'木': 1, '火': 1, '土': 1, '金': 2, '水': 3},
     'temperament': '스며드는 물의 기질로 풀이됩니다. 상황을 오래 보고 조용히 길을 찾습니다.',
     'strengths': ['관찰력', '흐름을 읽는 감각'], 'cautions': ['생각이 깊어 행동이 늦어질 수 있음'],
     'topics': {'flow': {'score': .79, 'note': '흐름과 변화를 뜻하는 기운이 두드러집니다.'}, 'fate': {'score': .53, 'note': null},
       'love': {'score': .5, 'note': '인연 기운이 고르게 있습니다.'}, 'money': {'score': .44, 'note': null}}},
  ];
  @override
  Future<SajuResult?> fetch({required String birth, String? time, String calendar = '양력'}) async {
    if (birth.isEmpty) return null;
    final m = jsonDecode(jsonEncode(_samples[fnv(birth) % _samples.length])) as Map;
    final unknown = time == null || time == '모름';
    if (unknown) (m['pillars'] as Map)['hour'] = null;
    m['hourUnknown'] = unknown; m['source'] = 'SAMPLE';
    return SajuResult.fromJson(m);
  }
}

// ═══════════ U12 · 어뷰징 방지 · 사주 기반 개인화 ═══════════
// [포팅 원본] /tmp/shrine_v3/merged/prototype/shrine-engine.js의
// fingerprint()/topicsAllowed()를 Dart로 1:1 포팅한다(순수 함수,
// 네트워크 없음). 발급 가능 여부(canIssue)/발급 기록(recordIssue)/
// 서명(sign)은 서버(admin_web)가 정본이므로 ShrineServerRepository에서
// HTTP로 호출한다 — 원본 JS 주석 그대로: "SECRET·원장·서명은 반드시 서버".
//
// 원칙 ③ 부적 = 사주 지문 × 주제 × 이야기 × 선택의 길 × 결말 조합.
// 같은 사람 = 같은 부적, 다른 사람 = 다른 부적 — 지문은 사주 네 기둥
// (년/월/일/시)만으로 계산하고, 로그인 사용자 식별은 별개로
// RealMemberRepository.memberId(실제 userId)가 담당한다.
String? sajuFingerprint(SajuResult? saju) {
  if (saju == null) return null;
  final p = saju.pillars;
  final year = p['year'], month = p['month'], day = p['day'];
  if (year == null || month == null || day == null) return null;
  final key = [year, month, day, p['hour'] ?? '-'].join('|');
  final h = fnv(key) % 1679616; // 36^4
  return h.toRadixString(36).toUpperCase().padLeft(4, '0');
}

/// 사주가 근거(note)를 준 주제만 허용한다 — 근거 없는 주제는 잠금.
/// [엔진 경계 원칙] 지어내지 않는다: note가 없는 주제는 추천 후보에서도 제외.
({List<String> allowed, String? today}) topicsAllowed(SajuResult? saju) {
  if (saju == null || saju.topics.isEmpty) return (allowed: const [], today: null);
  final r = saju.topics.entries.where((e) => e.value.note != null).toList()
    ..sort((a, b) => b.value.score.compareTo(a.value.score));
  final allowed = r.map((e) => e.key).toList();
  return (allowed: allowed, today: allowed.isEmpty ? null : allowed.first);
}

// ═══════════ 주제 추천 — 근거가 있는 주제만 ═══════════
class Recommendation { final String? pick; final String? reason; final List<MapEntry<String, TopicReading>> ranked;
  const Recommendation(this.pick, this.reason, this.ranked); }

Recommendation recommend(SajuResult? s) {
  if (s == null || s.topics.isEmpty) return const Recommendation(null, null, []);
  final ranked = s.topics.entries.toList()..sort((a, b) => b.value.score.compareTo(a.value.score));
  final top = ranked.first.value;
  if (top.score < .6 || top.note == null) return Recommendation(null, null, ranked); // 근거 불충분 → 일반 목록
  return Recommendation(ranked.first.key, top.note, ranked);
}

// ═══════════ 선택 해석 · 부적 구성 (데이터는 shrine.json talismans) ═══════════
class Flavor { final String id, k, label, said, story, motif; const Flavor(this.id, this.k, this.label, this.said, this.story, this.motif); }

class TalismanSpec {
  final String key, type, flavor, sig, name, head, base, paper, phrase, phraseMeaning, motif, border, seal, designId;
  final String? story, ending, element;
  const TalismanSpec({required this.key, required this.type, required this.flavor, required this.sig, required this.name, required this.head,
    required this.base, required this.paper, required this.phrase, required this.phraseMeaning, required this.motif,
    required this.border, required this.seal, required this.designId, this.story, this.ending, this.element});
  Map toJson() => {'key': key, 'type': type, 'flavor': flavor, 'sig': sig, 'name': name, 'head': head, 'base': base, 'paper': paper,
    'phrase': phrase, 'phraseMeaning': phraseMeaning, 'motif': motif, 'border': border, 'seal': seal, 'designId': designId,
    'story': story, 'ending': ending, 'element': element};
  static TalismanSpec fromJson(Map j) => TalismanSpec(key: j['key'], type: j['type'], flavor: j['flavor'], sig: j['sig'], name: j['name'], head: j['head'],
    base: j['base'], paper: j['paper'], phrase: j['phrase'], phraseMeaning: j['phraseMeaning'], motif: j['motif'], border: j['border'], seal: j['seal'],
    designId: j['designId'], story: j['story'], ending: j['ending'], element: j['element']);
}

class TalismanEngine {
  final Map types, phrases, flavors, motifs, copy; final List borders, seals; final Map<String, String> flagFlavor; final List<String> order;
  TalismanEngine.fromShrineJson(Map j)
      : types = j['talismans']['types'], phrases = j['talismans']['phrases'], flavors = j['talismans']['flavors'],
        motifs = j['talismans']['motifs'], copy = j['talismans']['copy'],
        borders = j['talismans']['borders'], seals = j['talismans']['seals'],
        flagFlavor = Map<String, String>.from(j['flagFlavor']), order = List<String>.from(j['flavorOrder']);

  /// 선택 플래그 → 6성향 중 최다. 동점은 order 순.
  Flavor interpret(Iterable<String> flags) {
    final cnt = <String, int>{};
    for (final f in flags) { final v = flagFlavor[f]; if (v != null) cnt[v] = (cnt[v] ?? 0) + 1; }
    var best = 'observe', bv = -1;
    for (final k in order) { final c = cnt[k] ?? 0; if (c > bv) { bv = c; best = k; } }
    final F = flavors[best];
    return Flavor(best, F['k'], F['label'], F['said'], F['story'], F['motif']);
  }

  /// 유형 × 성향 × 이야기 × 결말 → 부적. 문구는 검증 사전(phrases[type][flavor])에서만.
  TalismanSpec compose({required String type, required String flavor, String? story, String? ending, String? element}) {
    final T = types[type] ?? types['love']; final F = flavors[flavor] ?? flavors['observe'];
    final ph = ((phrases[type] ?? phrases['love'])[flavor] ?? (phrases[type] ?? phrases['love'])['observe']) as List;
    final key = [type, flavor, story ?? '-', ending ?? '-'].join('|');
    final h = fnv(key);
    return TalismanSpec(key: key, type: type, flavor: flavor, story: story, ending: ending, element: element,
      sig: T['sig'], name: T['name'], head: T['head'], base: T['base'], paper: T['paper'],
      phrase: ph[0], phraseMeaning: ph[1], motif: motifs[F['motif']],
      border: borders[h % borders.length], seal: seals[(h >> 3) % seals.length],
      designId: 'BJ-${type.toUpperCase()}-${F['k']}-${(h % 9973).toRadixString(36).toUpperCase()}');
  }
}
