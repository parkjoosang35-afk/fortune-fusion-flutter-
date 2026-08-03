import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/fortune_report_model.dart';

/// [정보입력 화면 §2 동작규칙] "최초 입력값 저장 → 다음 방문 시 자동 채움"
/// 구현을 위한 로컬 저장소. 오늘의 운세뿐 아니라 사주 등 다른 운세 카테고리도
/// 같은 프로필(이름/생년월일/성별/태어난시간/양력음력)을 재사용할 수 있도록
/// 카테고리와 무관한 공용 키로 저장한다.
class FortuneProfileStore {
  FortuneProfileStore._();

  static const _key = 'fortune_profile_v1';

  static Future<FortuneInputModel?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return FortuneInputModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(FortuneInputModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(model.toJson()));
  }
}
