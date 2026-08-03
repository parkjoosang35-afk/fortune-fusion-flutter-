import 'package:flutter/foundation.dart';
import '../../wallet/application/wallet_provider.dart';
import '../../wallet/domain/point_history_model.dart';
import '../domain/luck_pouch_model.dart';

/// [재화 구조 정리 및 재연결] 복주머니 전역 Provider.
///
/// ⚠️ 구조 변경(2025 정리 작업): 복주머니는 더 이상 별도의 로컬(SharedPreferences)
/// 자산이 아니다. 실제 원장은 백엔드 Wallet/PointHistory(=[WalletProvider])가
/// 단일 소스이며, 이 클래스는 그 위에 얹힌 "얇은 위임(delegating) 래퍼"다.
/// - 화면단(마이페이지/커뮤니티/부적/상담 등)이 참조하는 타입/메서드 이름은
///   기존과 동일(balance/history/load/earn/spend/canSpend)하게 유지하여
///   기존 코드를 최소한으로만 건드린다.
/// - 실제 잔액/이력/네트워크 호출은 전부 [WalletProvider]로 위임한다.
/// - app.dart의 `ChangeNotifierProxyProvider<WalletProvider, LuckPouchProvider>`가
/// WalletProvider가 갱신될 때마다 [updateWallet]을 호출해 내부 참조를 최신
/// 인스턴스로 교체한다(단, LuckPouchProvider 자기 자신의 identity는 유지되어야
/// 하므로 새 인스턴스를 만들지 않고 in-place로 갱신한다 — WishRoomProvider 등이
/// 생성 시점에 한 번만 `context.read<LuckPouchProvider>()`로 참조를 들고 있기 때문).
class LuckPouchProvider extends ChangeNotifier {
  WalletProvider _wallet;
  LuckPouchProvider(this._wallet) {
    _wallet.addListener(_onWalletChanged);
  }

  void _onWalletChanged() {
    notifyListeners();
  }

  /// app.dart의 ChangeNotifierProxyProvider.update에서 호출된다.
  /// WalletProvider 인스턴스 자체는 app 전체에서 하나만 존재하므로 보통은
  /// 동일 인스턴스가 다시 전달되지만, 방어적으로 리스너를 갈아끼운다.
  void updateWallet(WalletProvider wallet) {
    if (identical(_wallet, wallet)) {
      // 동일 인스턴스가 notifyListeners()로 갱신된 경우 - 위 리스너가 이미 처리.
      return;
    }
    _wallet.removeListener(_onWalletChanged);
    _wallet = wallet;
    _wallet.addListener(_onWalletChanged);
    notifyListeners();
  }

  int get balance => _wallet.balance;
  bool get isLoading => _wallet.isLoading;

  List<LuckPouchHistoryModel> get history =>
      _wallet.history.map(_convert).toList();

  LuckPouchHistoryModel _convert(PointHistoryModel h) {
    return LuckPouchHistoryModel(
      id: h.id,
      type: h.type == PointHistoryType.earn
          ? LuckPouchHistoryType.earn
          : LuckPouchHistoryType.spend,
      amount: h.amount,
      reason: h.reason,
      createdAt: h.createdAt,
    );
  }

  Future<void> load() => _wallet.load();

  /// 복주머니 적립. [sourceType]은 백엔드 PointHistory.sourceType 값과 맞춰
  /// 전달해야 서버측 일일상한/활동점수 엔진(luck-pouch-engine.ts)이 올바르게
  /// 동작한다(기본값 'app'은 분류 미지정 적립).
  Future<void> earn(int amount, String reason, {String sourceType = 'app'}) {
    return _wallet.earn(amount, reason, sourceType: sourceType);
  }

  /// 복주머니 소비(응원/강조/부적/상담 등). 잔액 부족 시 false.
  Future<bool> spend(
    int amount,
    String reason, {
    String sourceType = 'app',
  }) {
    return _wallet.spend(amount, reason, sourceType: sourceType);
  }

  bool canSpend(int amount) => balance >= amount;

  @override
  void dispose() {
    _wallet.removeListener(_onWalletChanged);
    super.dispose();
  }
}
