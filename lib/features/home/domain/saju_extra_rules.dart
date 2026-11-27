/// [정통사주 80종 · 추가 룰 DB 로더] saju_interpreter.dart 의 [SajuRules] 가
/// 이미 로드하는 3종(day_master/ten_gods/five_elements) 외에, 80종 카테고리
/// 계산(세운/월운/일운/개운 아이템/궁합)에 필요한 나머지 6종 룰 JSON을
/// 별도로 로드/캐시하는 싱글톤.
///
/// 기존 [SajuRules] 클래스를 건드리지 않고(회귀 위험 방지) 완전히 독립된
/// 클래스로 둔다 — 동일한 fire-and-forget preload 패턴을 그대로 따른다.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class SajuExtraRules {
  const SajuExtraRules._(
    this.yearFortune,
    this.monthlyFortune,
    this.dailyFortune,
    this.luckyItems,
    this.luckPillar,
    this.compatibility,
  );

  final Map<String, dynamic> yearFortune;
  final Map<String, dynamic> monthlyFortune;
  final Map<String, dynamic> dailyFortune;
  final Map<String, dynamic> luckyItems;
  final Map<String, dynamic> luckPillar;
  final Map<String, dynamic> compatibility;

  static SajuExtraRules? _cached;

  static SajuExtraRules? get cachedOrNull => _cached;

  static Future<SajuExtraRules> _load() async {
    Future<Map<String, dynamic>> loadJson(String name) async {
      final raw = await rootBundle.loadString('assets/jeontong/rules/$name');
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final results = await Future.wait([
      loadJson('year_fortune_rules.json'),
      loadJson('monthly_fortune_rules.json'),
      loadJson('daily_fortune_rules.json'),
      loadJson('lucky_items_rules.json'),
      loadJson('luck_pillar_rules.json'),
      loadJson('compatibility_rules.json'),
    ]);
    return SajuExtraRules._(
      results[0],
      results[1],
      results[2],
      results[3],
      results[4],
      results[5],
    );
  }

  /// fire-and-forget 프리로드. 이미 로드돼 있으면 즉시 반환한다.
  static Future<void> preload() async {
    if (_cached != null) return;
    _cached = await _load();
  }

  /// 테스트 전용 — 캐시 초기화.
  static void resetForTest() => _cached = null;
}
