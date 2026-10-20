// assets/shrine/data/shrine.json 을 읽는 모델. CMS가 생기면 같은 JSON을 서버에서 받는다.
import 'dart:convert';
import 'package:flutter/services.dart';
import '../engine/shrine_engine.dart';

class Topic {
  final String id, sig, label, obj, d, hook, glyph, reveal;
  Topic.fromJson(Map j)
      : id = j['id'], sig = j['sig'], label = j['label'], obj = j['obj'] ?? j['label'],
        d = j['d'], hook = j['hook'], glyph = j['glyph'], reveal = j['reveal'];
}

class Line {
  final String who; // wolhwa | narr | voice
  final String text;
  final String? art; // 대사 단위 배경 (없으면 node.art)
  Line.fromJson(Map j) : who = j['who'], text = j['text'], art = j['art'];
}

class Choice {
  final String label;
  final String? next, flag, card;
  Choice.fromJson(Map j) : label = j['label'], next = j['next'], flag = j['flag'], card = j['card'];
}

class StoryNode {
  final String id, art;
  final int step;
  final String? chapter, quote, timeoutLabel, timeoutFlag;
  final bool cards, climax;
  final int? timer;
  final List<String> set;
  final List<Line> lines;
  final List<Choice> choices;
  StoryNode.fromJson(this.id, Map j)
      : art = j['art'], step = j['step'], chapter = j['chapter'], quote = j['quote'],
        cards = j['cards'] == true, climax = j['climax'] == true, timer = j['timer'],
        timeoutLabel = j['timeoutLabel'], timeoutFlag = j['timeoutFlag'],
        set = List<String>.from(j['set'] ?? const []),
        lines = (j['lines'] as List).map((e) => Line.fromJson(e)).toList(),
        choices = (j['choices'] as List).map((e) => Choice.fromJson(e)).toList();
}

/// 결말 판정 규칙: 위에서부터 첫 번째로 맞는 규칙의 ending.
/// all = 모두 있어야 함, any = 하나 이상 있어야 함, 둘 다 없으면 기본값.
class RouteRule {
  final List<String> all, any;
  final String ending;
  RouteRule.fromJson(Map j)
      : all = List<String>.from(j['all'] ?? const []), any = List<String>.from(j['any'] ?? const []), ending = j['ending'];
  bool match(Set<String> f) => all.every(f.contains) && (any.isEmpty || any.any(f.contains));
}

class Ending {
  final String code, name, art, thumb, line;
  final List<String> body;
  Ending.fromJson(this.code, Map j)
      : name = j['name'], art = j['art'], thumb = j['thumb'], line = j['line'], body = List<String>.from(j['body']);
}

/// 추가 이야기 (room · night · other · secret) — 메인과 같은 노드 구조
class Tale {
  final String id, title, en, intro, cover, talis, start; final int minutes, fear;
  final Map<String, StoryNode> nodes; final List<RouteRule> route; final Map<String, Ending> endings;
  Tale.fromJson(this.id, Map j)
      : title = j['title'], en = j['en'], intro = j['intro'], cover = j['cover'], talis = j['talis'], start = j['start'],
        minutes = j['min'], fear = j['fear'],
        nodes = (j['nodes'] as Map).map((k, v) => MapEntry(k as String, StoryNode.fromJson(k, v))),
        route = (j['route'] as List).map((e) => RouteRule.fromJson(e)).toList(),
        endings = (j['endings'] as Map).map((k, v) => MapEntry(k as String, Ending.fromJson(k, {...v, 'thumb': v['art']})));
  String judge(Set<String> f) => route.firstWhere((r) => r.match(f), orElse: () => route.last).ending;
}

class Shrine {
  final List<Topic> topics;
  final List<Map> ritual;
  final List<String> analysis;
  final Map<String, StoryNode> nodes;
  final String start, title, en, intro;
  final int minutes, fear;
  final List<RouteRule> route;
  final Map<String, Ending> endings;
  final Map<String, String> readings;
  final Map<String, Tale> tales;
  final TalismanEngine talismans;

  Shrine._(Map j)
      : topics = (j['topics'] as List).map((e) => Topic.fromJson(e)).toList(),
        ritual = List<Map>.from(j['ritual']),
        analysis = List<String>.from(j['analysis']),
        nodes = (j['story']['nodes'] as Map).map((k, v) => MapEntry(k as String, StoryNode.fromJson(k, v))),
        start = j['story']['start'], title = j['story']['title'], en = j['story']['en'], intro = j['story']['intro'],
        minutes = j['story']['min'], fear = j['story']['fear'],
        route = (j['story']['route'] as List).map((e) => RouteRule.fromJson(e)).toList(),
        endings = (j['endings'] as Map).map((k, v) => MapEntry(k as String, Ending.fromJson(k, v))),
        readings = Map<String, String>.from(j['readings']),
        tales = (j['tales'] as Map).map((k, v) => MapEntry(k as String, Tale.fromJson(k, v))),
        talismans = TalismanEngine.fromShrineJson(j);

  static Future<Shrine> load() async => Shrine._(jsonDecode(await rootBundle.loadString('assets/shrine/data/shrine.json')));

  String judge(Set<String> flags) => route.firstWhere((r) => r.match(flags), orElse: () => route.last).ending;

  Topic topic(String? id) => topics.firstWhere((t) => t.id == id, orElse: () => topics.first);

  /// {name} {season} {topic} {hook} 치환
  String fill(String s, {String? name, String? season, String? topicId}) {
    final t = topic(topicId);
    return s
        .replaceAll('{hook}', t.hook)
        .replaceAll('{name}', (name == null || name.isEmpty) ? '당신' : name)
        .replaceAll('{season}', season ?? '여름')
        .replaceAll('{topic}', t.label);
  }
}

/// 생월 → 계절 (3–5 봄, 6–8 여름, 9–11 가을, 나머지 겨울)
String seasonOf(int month) => month >= 3 && month <= 5 ? '봄' : month <= 8 && month >= 6 ? '여름' : month >= 9 && month <= 11 ? '가을' : '겨울';

/// 1995.08.14 → 一九九五年 8月 14日
String hanjaDate(String b) {
  const h = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
  final p = b.split('.');
  if (p.length != 3) return '';
  return '${p[0].split('').map((c) => h[int.parse(c)]).join()}年 ${int.parse(p[1])}月 ${int.parse(p[2])}日';
}
