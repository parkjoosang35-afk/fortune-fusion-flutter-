import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// [오늘의 운세 표준 플로우 §6 후속연결] "저장 → 마이 → 내 운세 기록에 카드 저장".
///
/// 카테고리 무관 공용 저장소로 설계해, 사주/궁합/타로/관상/손금 결과 화면도
/// 동일한 저장 로직을 그대로 재사용할 수 있게 한다(표준 플로우 확장 원칙).
class SavedFortuneRecord {
  const SavedFortuneRecord({
    required this.id,
    required this.categoryLabel,
    required this.title,
    required this.summary,
    required this.score,
    required this.date,
    required this.savedAt,
  });

  final String id;

  /// 예: '오늘의 운세', '사주', '타로' ...
  final String categoryLabel;
  final String title;
  final String summary;
  final int score;
  final DateTime date;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryLabel': categoryLabel,
    'title': title,
    'summary': summary,
    'score': score,
    'date': date.toIso8601String(),
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedFortuneRecord.fromJson(Map<String, dynamic> json) {
    return SavedFortuneRecord(
      id: json['id'] as String,
      categoryLabel: json['categoryLabel'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      score: json['score'] as int,
      date: DateTime.parse(json['date'] as String),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}

class MyFortuneRecordStore {
  MyFortuneRecordStore._();

  static const _key = 'my_fortune_records_v1';

  static Future<List<SavedFortuneRecord>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map((e) {
          try {
            return SavedFortuneRecord.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedFortuneRecord>()
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  /// 이미 같은 id가 있으면 갱신, 없으면 새로 추가.
  static Future<void> save(SavedFortuneRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final list = raw
        .map((e) {
          try {
            return SavedFortuneRecord.fromJson(
              jsonDecode(e) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedFortuneRecord>()
        .where((e) => e.id != record.id)
        .toList();
    list.insert(0, record);
    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final filtered = raw.where((e) {
      try {
        final json = jsonDecode(e) as Map<String, dynamic>;
        return json['id'] != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_key, filtered);
  }
}
