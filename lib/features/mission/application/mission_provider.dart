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
