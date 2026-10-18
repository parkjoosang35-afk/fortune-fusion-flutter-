// shrine_session_provider.dart — [통합 Fix 06] 신당 스타터는 ProviderScope
// (Riverpod)로 상태를 공유했으나, 이 프로젝트는 provider 6.1.5+1 패턴으로
// 고정되어 있어(표준 불변 제약) ChangeNotifier + MultiProvider로 전환했다.
// 신당 스타터의 SessionNotifier(_k='sindang.session.v1', 변경 즉시 저장)
// 동작을 그대로 유지한다.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/shrine_session.dart';

class ShrineSessionProvider extends ChangeNotifier {
  static const _k = 'sindang.session.v1';
  SharedPreferences? _prefs;
  ShrineSession _state = ShrineSession();
  bool _loaded = false;

  ShrineSession get state => _state;
  bool get loaded => _loaded;

  ShrineSessionProvider() {
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_k);
    if (raw != null) {
      try {
        _state = ShrineSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // 저장된 값이 손상되어도 기본 세션으로 안전하게 폴백한다.
        _state = ShrineSession();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// 변경 즉시 저장(한 박자 지연 금지 — 신당 프로토타입에서 발견된 버그를
  /// 그대로 재발시키지 않기 위한 원본 설계 유지).
  void set(ShrineSession Function(ShrineSession) f) {
    _state = f(_state);
    notifyListeners();
    _prefs?.setString(_k, jsonEncode(_state.toJson()));
  }

  void reachEnding() => set((s) => s.copyWith(got: {...s.got, s.ending.k}));

  Future<void> wipe() async {
    await _prefs?.remove(_k);
    _state = ShrineSession();
    notifyListeners();
  }
}
