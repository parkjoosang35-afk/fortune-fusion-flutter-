import 'package:flutter/foundation.dart';
import '../data/wallet_repository.dart';
import '../domain/point_history_model.dart';
import '../../../core/widgets/luck_pouch_toast.dart';

/// 07단계 §2.1 전역 Provider - WalletProvider(잔액 캐시, 최근 트랜잭션)
/// [자율 정리 - 정책 위반 무력화] 과거 등급 배율(point_earn_multiplier)을 여기서
/// 적립액에 곱해 지급하던 로직이 있었으나, 신통방통은 "프리패스(시간권) +
/// 복주머니(유일 화폐)"만 존재하는 무료 광고형 구조라 적립률/배율 개념이
/// 없어야 한다(정책: 복주머니는 항상 요청 금액 그대로 1:1 지급). 배율 관련
/// 필드/메서드를 제거해 earn()이 항상 amount 그대로 지급하도록 되돌린다.
class WalletProvider extends ChangeNotifier {
  final WalletRepository _repository;
  WalletProvider(this._repository);

  int _balance = 0;
  List<PointHistoryModel> _history = [];
  bool _isLoading = false;

  int get balance => _balance;
  List<PointHistoryModel> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final balanceResult = await _repository.getBalance();
    final historyResult = await _repository.getHistory();
    if (balanceResult.success) _balance = balanceResult.data!;
    if (historyResult.success) _history = historyResult.data!;
    _isLoading = false;
    notifyListeners();
  }

  /// 복주머니(및 그 위임체인) 적립. [sourceType]은 백엔드 PointHistory.sourceType과
  /// 동일한 값으로 전달하여 서버측 일일상한/활동점수 엔진이 올바르게 집계하도록 한다.
  /// [정책] 배율 없이 항상 [amount] 그대로 지급한다.
  Future<void> earn(
    int amount,
    String reason, {
    String sourceType = 'app',
  }) async {
    _balance = await _repository.earn(amount, reason, sourceType: sourceType);
    await load();
    LuckPouchToastController.instance.showEarn(amount, reason);
  }

  Future<bool> spend(
    int amount,
    String reason, {
    String sourceType = 'app',
  }) async {
    final ok = await _repository.spend(amount, reason, sourceType: sourceType);
    if (ok) {
      await load();
      LuckPouchToastController.instance.showSpend(amount, reason);
    } else {
      LuckPouchToastController.instance.showInsufficient(reason: reason);
    }
    return ok;
  }

  /// [Phase22 - 복주머니 경제철학 이식] "복 나누기" — 성공 시 (환급액, 오늘 남은 송금가능액)을
  /// 반환하고, 실패 시 null을 반환한다(에러 메시지는 [lastSendError]로 확인).
  String? lastSendError;

  /// [Phase22-3] 닉네임 -> userId 조회(황금률 출구버튼에서 sendBok() 호출 전 사용).
  /// 실패 시 null을 반환하고 [lastSendError]에 에러 메시지를 남긴다.
  Future<({int userId, String nickname})?> lookupUserByNickname(
    String nickname,
  ) async {
    final result = await _repository.lookupUserByNickname(nickname);
    if (!result.success) {
      lastSendError = result.errorMessage;
      return null;
    }
    lastSendError = null;
    return result.data;
  }

  Future<({int refundAmount, int dailySendRemaining})?> sendBok({
    required int toUserId,
    required int amount,
    String memo = '복 나누기',
  }) async {
    final result = await _repository.sendBok(
      toUserId: toUserId,
      amount: amount,
      memo: memo,
    );
    if (!result.success) {
      lastSendError = result.errorMessage;
      return null;
    }
    lastSendError = null;
    await load();
    return result.data;
  }
}
