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

  /// [소원방 마무리 - Phase A] 서버가 이미 트랜잭션 안에서 지급을 확정한
  /// 뒤(예: 댓글 작성, 소원 성취), 잔액 표시만 최신화하고 싶을 때 사용한다.
  /// gratitude_provider.seal()과 동일한 "서버 확정만 신뢰" 패턴.
  Future<void> refreshBalance() => _pouch.load();

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

  // ── [소원방 리스킨 — "받기" 확장 채널] ──────────────────────────
  // 아래 3개는 새 소원방 홈(제단)/팝업 "받기" 탭을 위해 추가된 적립 채널.
  // 전부 scope='daily' 또는 'weekly'로 서버측 일일/주간 상한 판정에 맞춰
  // 요청하며, 실제 지급 여부(중복 방지)는 서버가 결정한다(반환값 0=이미 지급).

  /// 제단 참배 보너스 — 오늘 소원방(제단 홈)에 처음 들어오면 1일 1회 지급.
  Future<int> earnAltarVisitBonus() {
    return _pouch.earn(
      BlessingBagEarnReason.altarVisit.defaultAmount,
      BlessingBagEarnReason.altarVisit.label,
      sourceType: BlessingBagEarnReason.altarVisit.code,
      scope: 'daily',
    );
  }

  /// 주간 소원함 개봉 보너스 — 이번 주 소원함(box-opening)을 열면 7일 1회 지급.
  Future<int> earnWeeklyBoxOpeningBonus() {
    return _pouch.earn(
      BlessingBagEarnReason.weeklyBoxOpening.defaultAmount,
      BlessingBagEarnReason.weeklyBoxOpening.label,
      sourceType: BlessingBagEarnReason.weeklyBoxOpening.code,
      scope: 'weekly',
    );
  }

  /// 소원 성취(축하) 보너스 — 내 소원을 "이뤄졌어요"로 표시할 때 지급.
  /// [sourceId]에 해당 소원의 고유 번호를 넘기면 서버가 소원 1건당 1회로
  /// 제한할 수 있다(건당 1회 정책 판정용, 옵션).
  Future<int> earnWishFulfilledBonus({int? wishSourceId}) {
    return _pouch.earn(
      BlessingBagEarnReason.wishFulfilled.defaultAmount,
      BlessingBagEarnReason.wishFulfilled.label,
      sourceType: BlessingBagEarnReason.wishFulfilled.code,
      sourceId: wishSourceId,
    );
  }

  /// [소원방 마무리 - Phase A] 응원 한 마디(wish_comment, +2)는 소원 성취
  /// (wishFulfilled)와 마찬가지로 서버가 POST /wishes/:id/comments 트랜잭션
  /// 안에서 이미 지급을 완료한다(comments/route.ts 참고). 클라이언트가 여기서
  /// 다시 [_pouch.earn]을 호출하면 이중 지급 요청이 되므로, 그런 메서드는
  /// 만들지 않는다 — 서버 응답의 grantedAmount만 신뢰하고, 잔액은
  /// [LuckPouchProvider.load]로 재조회한다(호출부: 신규 응원 목록 화면).

  /// 오늘의 촛불 보너스 — bokjumeoni-plan §02 EARN "매일의 발자국" 4종 중
  /// 하나(daily_candle, +1, 1일 1회). PointPolicy는 이미 Phase02 시딩으로
  /// 등록되어 있으므로(서버 신규 라우트 불필요) 기존 altarVisit 등과 동일한
  /// scope='daily' earn 패턴을 그대로 사용한다.
  Future<int> earnDailyCandleBonus() {
    return _pouch.earn(
      BlessingBagEarnReason.dailyCandle.defaultAmount,
      BlessingBagEarnReason.dailyCandle.label,
      sourceType: BlessingBagEarnReason.dailyCandle.code,
      scope: 'daily',
    );
  }

  /// 60초 명상 보너스 — bokjumeoni-plan §02 EARN "매일의 발자국" 4종 중
  /// 하나(daily_meditation, +2, 1일 1회). 실제 60초 타이머를 끝까지 마쳐야
  /// 호출되는 채널이며(UI가 트리거 시점을 통제), 서버는 여전히 최종 판단
  /// (scope='daily' 1일 1회)만 담당한다.
  Future<int> earnDailyMeditationBonus() {
    return _pouch.earn(
      BlessingBagEarnReason.dailyMeditation.defaultAmount,
      BlessingBagEarnReason.dailyMeditation.label,
      sourceType: BlessingBagEarnReason.dailyMeditation.code,
      scope: 'daily',
    );
  }

  // ── [소원방 리스킨 — "보내기" 확장 채널] ──────────────────────────

  /// 감사 도장(Seal) 보내기 — sendPouch보다 가벼운 소액 소비로, 감사의
  /// 마음을 도장 하나로 표현할 때 사용(기본 1개).
  Future<bool> giftSeal({int amount = 1}) {
    return _pouch.spend(
      amount,
      BlessingBagSpendReason.giftSeal.label,
      sourceType: BlessingBagSpendReason.giftSeal.code,
    );
  }
}
