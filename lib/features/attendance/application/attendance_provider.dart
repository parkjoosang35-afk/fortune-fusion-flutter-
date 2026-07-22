import 'package:flutter/foundation.dart';
import '../data/attendance_repository.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;
  AttendanceProvider(this._repository);

  int _streak = 0;
  bool _checkedToday = false;
  bool _isLoading = false;

  int get streak => _streak;
  bool get checkedToday => _checkedToday;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getStatus();
    if (result.success && result.data != null) {
      _streak = result.data!['streak'] as int;
      _checkedToday = result.data!['checked_today'] as bool;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<int> checkIn() async {
    final result = await _repository.checkIn();
    if (result.success && result.data != null) {
      _checkedToday = true;
      _streak += 1;
      notifyListeners();
      return result.data!;
    }
    return 0;
  }
}
