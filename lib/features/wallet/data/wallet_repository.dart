import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/point_history_model.dart';

/// 06단계 §4.2 `/v1/wallet` 대응 Mock Repository
/// 원칙(06단계 4.2 재확인): 적립/차감 직접 API는 없다 — 각 도메인 액션이 내부적으로 earn/spend를 호출한다.
class WalletRepository {
  int _balance = 12500;
  final List<PointHistoryModel> _history = [
    PointHistoryModel(
      id: 'ph_1',
      type: PointHistoryType.earn,
      amount: 100,
      reason: '출석체크 보상',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    PointHistoryModel(
      id: 'ph_2',
      type: PointHistoryType.spend,
      amount: 500,
      reason: 'AI 타로 추가 이용',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    PointHistoryModel(
      id: 'ph_3',
      type: PointHistoryType.earn,
      amount: 300,
      reason: '일일 미션 완료',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  Future<ApiResult<int>> getBalance() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(_balance);
  }

  Future<ApiResult<List<PointHistoryModel>>> getHistory() async {
    await mockDelay(ms: 400);
    return ApiResult.ok(List.unmodifiable(_history));
  }

  /// WalletService.earn (02번 §1.2 Ledger 패턴 - 잔액은 파생값, 이력이 원본)
  Future<int> earn(int amount, String reason) async {
    _balance += amount;
    _history.insert(
      0,
      PointHistoryModel(
        id: 'ph_${_history.length + 1}',
        type: PointHistoryType.earn,
        amount: amount,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );
    return _balance;
  }

  /// WalletService.spend
  Future<bool> spend(int amount, String reason) async {
    if (_balance < amount) return false;
    _balance -= amount;
    _history.insert(
      0,
      PointHistoryModel(
        id: 'ph_${_history.length + 1}',
        type: PointHistoryType.spend,
        amount: amount,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }
}
