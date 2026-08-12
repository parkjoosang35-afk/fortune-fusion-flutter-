import '../../luckpouch/application/luck_pouch_provider.dart';
import '../domain/wish_wall_models.dart';

/// 복주머니(BlessingBag) 정책 어댑터.
///
/// [handoff.zip] 기획안 §4.3 `PouchPolicy` 인터페이스 + §4.6 "복주머니 정책은
/// 반드시 기존 신통방통 재화 시스템과 연결, 클라이언트 하드코딩 금지" 원칙을
/// 반영한 구현체. 이 앱에서 "기존 신통방통 재화 시스템"은 [LuckPouchProvider]
/// (→ 내부적으로 [WalletProvider]/실 Wallet 원장에 위임)이므로, 여기서는 새로운
/// 화폐를 만들지 않고 항상 [LuckPouchProvider]를 통해서만 잔액을 조회/적립/차감한다.
///
/// 일일 상한(§4.1: 하루 최대 12개 적립) 등 "정책"에 해당하는 규칙만 이 클래스가
/// 캡슐화하고, 실제 원장 기록은 전부 LuckPouchProvider.earn()/spend()로 위임한다.
class BlessingBagPolicyAdapter {
  BlessingBagPolicyAdapter(this._pouch);
  final LuckPouchProvider _pouch;

  static const int dailyEarnCap = 12;
  static const int perSendMax = 5;

  int get balance => _pouch.balance;

  /// [handoff.zip] §4.6: 서버 검증 확정만 신뢰하고 클라이언트에서 잔액을
  /// 미리 낙관적으로 차감하지 않는다. 여기서는 UI 버튼 활성화 판단용으로만
  /// 간단한 검증 결과를 미리 계산해서 반환한다(실제 차감은 spend에서).
  ({bool ok, String? reasonCode}) validateSend(int amount) {
    if (amount <= 0) return (ok: false, reasonCode: 'invalidAmount');
    if (amount > perSendMax) {
      return (ok: false, reasonCode: 'exceedsPerSendMax');
    }
    if (balance < amount) {
      return (ok: false, reasonCode: 'insufficientBalance');
    }
    return (ok: true, reasonCode: null);
  }

  /// 복주머니 보내기(=응원의 표시로 다른 사람 병에 복주머니를 매달아줌).
  Future<bool> sendPouch({
    required WishPost target,
    required int amount,
  }) async {
    final v = validateSend(amount);
    if (!v.ok) return false;
    final ok = await _pouch.spend(
      amount,
      BlessingBagSpendReason.sendPouch.label,
      sourceType: BlessingBagSpendReason.sendPouch.code,
    );
    return ok;
  }

  /// 병 밝히기(정성지수 부스트) — 소액 소비.
  Future<bool> boostBottle(WishPost target, {int amount = 2}) async {
    return _pouch.spend(
      amount,
      '병 밝히기',
      sourceType: BlessingBagSpendReason.boostBottle.code,
    );
  }

  /// 소원 담기(새 병 봉인) 완료 보너스 — 기획안 §3.3/§4.1, 정책표 §3 기준
  /// wish_created_bonus(+2, 1일 1회)를 지급한다. [정책표 §3] "1일 1회" 제한은
  /// 서버(checkPolicyEligibility)가 scope='daily'로 자동 판정한다.
  /// 반환값: 실제 지급 금액(0이면 오늘 이미 지급됨).
  Future<int> earnWishCreatedBonus() {
    return _pouch.earn(
      BlessingBagEarnReason.wishCreatedBonus.defaultAmount,
      '소원 봉인 완료',
      sourceType: BlessingBagEarnReason.wishCreatedBonus.code,
      scope: 'daily',
    );
  }

  /// 오늘의 기도 참여 보너스 — daily_prayer(+1, 최대 3회/일 정책은 서버측
  /// 일일상한 엔진이 판단하며, 여기서는 항상 적립을 요청만 한다).
  Future<int> earnDailyPrayerBonus() {
    return _pouch.earn(
      BlessingBagEarnReason.dailyPrayer.defaultAmount,
      '오늘의 기도',
      sourceType: BlessingBagEarnReason.dailyPrayer.code,
    );
  }
}
