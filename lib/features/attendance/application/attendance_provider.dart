import 'package:flutter/foundation.dart';
import '../data/attendance_repository.dart';

/// [실API 전환] admin_web `/api/public/attendance/checkin`이 지갑 적립까지
/// 트랜잭션 내부에서 직접 처리하므로, 호출부(화면)는 반환된 reward>0일 때
/// WalletProvider.load()로 잔액만 새로고침해야 한다(WalletProvider.earn()을
/// 다시 호출하면 서버 API가 중복 적립되므로 절대 호출하지 않는다).
class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repository;
  AttendanceProvider(this._repository);

  int _streak = 0;
  bool _checkedToday = false;
  bool _isLoading = false;
  String? _lastError;

  int get streak => _streak;
  bool get checkedToday => _checkedToday;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getStatus();
    if (result.success && result.data != null) {
      _streak = result.data!['streak'] as int;
      _checkedToday = result.data!['checked_today'] as bool;
      _lastError = null;
    } else {
      _lastError = result.errorMessage;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 출석 체크인 실행. 성공(신규 지급) 시 지급된 rewardPoint(> 0)를 반환하고,
  /// 이미 오늘 체크인했거나 실패한 경우 0을 반환한다(화면단에서 lastError로 안내).
  Future<int> checkIn() async {
    final result = await _repository.checkIn();
    if (!result.success || result.data == null) {
      _lastError = result.errorMessage;
      notifyListeners();
      return 0;
    }
    final data = result.data!;
    _streak = data['streak'] as int;
    _checkedToday = true;
    _lastError = null;
    notifyListeners();

    final alreadyChecked = data['alreadyChecked'] as bool;
    if (alreadyChecked) return 0;
    return data['rewardPoint'] as int;
  }
}
