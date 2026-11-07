import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [결과페이지 글씨 확대 기능] 시력이 안 좋은 사용자도 결과 풀이를 편하게
/// 읽을 수 있도록, 앱 전체 글씨 크기를 사용자가 직접 조절할 수 있게 하는
/// 전역 상태. "결과페이지에서 글씨가 잘 안 보인다"는 사용자 피드백에 대한
/// 대응이며, 특정 화면 하나가 아니라 모든 화면(사주/타로/관상/손금/궁합/
/// 귀인지도 등 전체 결과페이지 포함)에 공통으로 적용되도록 앱 루트
/// (MaterialApp.builder)의 [TextScaler]를 직접 조절하는 방식을 쓴다 —
/// 화면마다 개별적으로 폰트 크기를 하드코딩해 둔 수십 개 결과 화면을 전부
/// 손대지 않고도 "전체 다"라는 요청을 한 곳에서 만족시킬 수 있다.
class TextScaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_text_scale_v1';

  /// 100%(기본) ~ 160%까지 6단계. 너무 잘게 쪼개면 버튼을 여러 번 눌러야
  /// 해서 오히려 불편하므로, 체감이 뚜렷한 간격(15%p)으로 둔다.
  static const List<double> steps = [1.0, 1.15, 1.3, 1.45, 1.6];

  double _scale = 1.0;
  double get scale => _scale;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  TextScaleProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_prefsKey);
      if (saved != null && steps.contains(saved)) {
        _scale = saved;
      }
    } catch (_) {
      // SharedPreferences 조회 실패 시 기본값(100%) 유지 — 글씨 크기 기능은
      // 부가 기능이므로 실패해도 앱 사용에 지장이 없어야 한다.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKey, _scale);
    } catch (_) {}
  }

  int get _stepIndex {
    var closest = 0;
    var minDiff = (steps[0] - _scale).abs();
    for (var i = 1; i < steps.length; i++) {
      final diff = (steps[i] - _scale).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = i;
      }
    }
    return closest;
  }

  bool get canIncrease => _stepIndex < steps.length - 1;
  bool get canDecrease => _stepIndex > 0;

  void increase() {
    final i = _stepIndex;
    if (i >= steps.length - 1) return;
    _scale = steps[i + 1];
    notifyListeners();
    _persist();
  }

  void decrease() {
    final i = _stepIndex;
    if (i <= 0) return;
    _scale = steps[i - 1];
    notifyListeners();
    _persist();
  }

  void reset() {
    if (_scale == 1.0) return;
    _scale = 1.0;
    notifyListeners();
    _persist();
  }
}
