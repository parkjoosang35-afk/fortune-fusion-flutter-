import 'package:flutter/foundation.dart';
import '../data/mission_repository.dart';
import '../domain/mission_model.dart';

class MissionProvider extends ChangeNotifier {
  final MissionRepository _repository;
  MissionProvider(this._repository);

  List<MissionModel> _missions = [];
  List<MissionModel> get missions => _missions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<MissionModel> get daily =>
      _missions.where((m) => m.period == MissionPeriod.daily).toList();
  List<MissionModel> get weekly =>
      _missions.where((m) => m.period == MissionPeriod.weekly).toList();

  /// [Stage2 결함수정 — 결함-A10-01] 로그아웃 시 이전 계정의 미션 진행상황이
  /// 화면에 잔존하지 않도록 초기화한다.
  void clearOnLogout() {
    _missions = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getMissions();
    if (result.success) {
      _missions = result.data!;
    }
    _isLoading = false;
    notifyListeners();
  }
}
