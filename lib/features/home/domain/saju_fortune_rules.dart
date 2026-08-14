/// [정통사주 80종 · 로컬 만세력 엔진] saju_engine_v4_final.zip 의
/// 세운/월운/일운/개운아이템/대운 공통 룰(rules/*.json)을 로드하는 캐시.
///
/// [SajuRules](day_master/ten_gods/five_elements)와 완전히 동일한 패턴
/// (fire-and-forget preload + 동기 캐시 접근)을 따르되, 대상 파일만
/// 다르다. `saju_interpreter.dart`의 [SajuRules]와 별도 클래스로 둔 이유는
/// 두 클래스가 서로 다른 파이썬 모듈(saju_interpreter.py vs
/// year_fortune.py/monthly_fortune.py/daily_fortune.py/lucky_items.py/
/// compatibility.py)에서 온 룰 파일을 로드하기 때문이다(단일 책임 유지).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class SajuFortuneRules {
  const SajuFortuneRules._(
    this.yearFortune,
    this.monthlyFortune,
    this.dailyFortune,
    this.luckyItems,
    this.luckPillar,
    this.compatibility,
  );

  /// year_fortune_rules.json — { by_ten_god: { <십신>: {title, overall, wealth, career, love, health, advice} } }
  final Map<String, dynamic> yearFortune;

  /// monthly_fortune_rules.json — { by_ten_god: { <십신>: {title, overall, work, wealth, love, health, advice} } }
  final Map<String, dynamic> monthlyFortune;

  /// daily_fortune_rules.json — { by_ten_god: { <십신>: {title, mood, overall, work, wealth, love, lucky_time, avoid_time} } }
  final Map<String, dynamic> dailyFortune;

  /// lucky_items_rules.json — { by_element_lack: { <오행>: {colors, directions, numbers, items, food, activities, advice} } }
  final Map<String, dynamic> luckyItems;

  /// luck_pillar_rules.json — { gan_flavor, zhi_flavor, combo_by_ten_god, yearly_theme_by_stem }
  final Map<String, dynamic> luckPillar;

  /// compatibility_rules.json — { gan_to_gan, zhi_combos, score_bands }
  final Map<String, dynamic> compatibility;

  static SajuFortuneRules? _cached;

  static SajuFortuneRules? get cachedOrNull => _cached;

  static Future<Map<String, dynamic>> _loadJson(String name) async {
    final raw = await rootBundle.loadString('assets/jeontong/rules/$name');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<SajuFortuneRules> _load() async {
    final results = await Future.wait([
      _loadJson('year_fortune_rules.json'),
      _loadJson('monthly_fortune_rules.json'),
      _loadJson('daily_fortune_rules.json'),
      _loadJson('lucky_items_rules.json'),
      _loadJson('luck_pillar_rules.json'),
      _loadJson('compatibility_rules.json'),
    ]);
    return SajuFortuneRules._(
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
