import 'package:flutter/foundation.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../data/wish_room_repository.dart';
import '../domain/wish_room_model.dart';

/// [소원방 MVP] 소원방 전역 상태 Provider.
///
/// [통합정책 §17] "복주머니 적립은 transaction 형태로 남길 수 있게 설계",
/// "치성 완료 여부는 일 단위로 관리", "화면마다 임시 판정하지 말고 공통
/// 상태/정책 함수로 연결" 3원칙을 이 클래스 하나로 모은다. 화면(Screen)은
/// 절대 SharedPreferences나 날짜 계산을 직접 하지 않고, 이 Provider의
/// 체크 함수([getTodayRitualStatus]/[canPerformTodayRitual]/
/// [getWishLightProgress])만 호출한다.
///
/// [권장 상태값 매핑 노트] 통합정책 §17이 제시한 7개 권장 상태
/// (wishRoomState/dailyRitualState/ritualProgressState/streakState/
/// lightGaugeState/luckPouchBalanceState/luckPouchTransactionState) 중
/// 뒤 2개(복주머니 잔액/거래내역)는 이미 [LuckPouchProvider]가 전역으로
/// 들고 있는 상태라, 여기서 별도 필드로 중복 보관하지 않고 그대로
/// 위임한다(중복 상태를 두 곳에 만들면 동기화 버그의 원인이 되고, 지난
/// 세션에서 발견한 "WalletProvider 자산 혼용" 문제와 같은 종류의 실수를
/// 반복하게 된다). streak/lightGauge는 [room]의 필드로, dailyRitual은
/// [getTodayRitualStatus]로 파생 계산하며, ritualProgress(터치 진행률)는
/// 오늘의 치성 화면 안에서만 의미 있는 화면 전용 임시 상태이므로
/// [WishRoomRitualScreen]의 로컬 State로 둔다(전역 상태로 승격할 필요가
/// 없는 값을 억지로 Provider에 넣지 않는다).
class WishRoomProvider extends ChangeNotifier {
  WishRoomProvider(this._repository, this._luckPouch);

  final WishRoomRepository _repository;
  final LuckPouchProvider _luckPouch;

  WishRoomModel? _room;
  bool _isLoading = false;
  bool _introSeen = false;

  WishRoomModel get room => _room ?? WishRoomModel.initial(userId: 'local_user');
  bool get isLoading => _isLoading;

  /// 소원방 첫 진입 안내를 이미 본 적이 있는가(§6 "첫 진입 시 1회만").
  bool get introSeen => _introSeen;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _room = await _repository.getRoom();
    _introSeen = await _repository.getIntroSeen();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markIntroSeen() async {
    if (_introSeen) return;
    _introSeen = true;
    await _repository.setIntroSeen(true);
    notifyListeners();
  }

  // ── 치성 상태 판정(§16 상태별 화면 설계 — 공통 체크 함수) ──

  /// 오늘 이미 치성을 드렸는가. [room.todayRitualDone] 스냅샷을 그대로
  /// 믿지 않고, [room.lastRitualAt]과 "지금"을 매번 비교해 판정한다(자정을
  /// 넘겨도 항상 정확한 값을 반환하기 위함).
  bool getTodayRitualStatus() {
    final last = room.lastRitualAt;
    if (last == null) return false;
    return _isSameDay(last, DateTime.now());
  }

  /// 오늘의 치성을 지금 수행할 수 있는가(= 아직 안 했는가).
  bool canPerformTodayRitual() => !getTodayRitualStatus();

  /// 소원의 빛 진행률(0.0~1.0, 게이지 위젯에 그대로 꽂아 쓸 수 있는 형태).
  double getWishLightProgress() => room.wishLightPercent.clamp(0, 100) / 100.0;

  // ── 치성 완료 처리 ──

  /// 오늘의 치성을 완료 처리한다. 연속 치성/소원의 빛을 갱신하고, 복주머니
  /// 보상을 실제로 지급한 뒤(§13, [LuckPouchProvider.earn] 트랜잭션으로
  /// 남음) 결과를 반환한다. 이미 오늘 치성을 완료한 상태에서 호출되는
  /// 실수를 방지하기 위해 [canPerformTodayRitual]을 다시 한 번 확인한다.
  Future<RitualRewardResult> applyRitualReward({required int tapCount}) async {
    if (!canPerformTodayRitual()) {
      // 방어적 가드: 화면에서 canPerformTodayRitual()로 이미 막았어야 하는
      // 경로다. 그래도 호출되면 보상 없이 현재 상태를 그대로 반환한다.
      return RitualRewardResult(
        luckPouch: 0,
        exp: 0,
        lightIncrease: 0,
        streakAfter: room.streakDays,
        wishLightPercent: room.wishLightPercent,
      );
    }

    final now = DateTime.now();
    final newStreak = updateWishRoomStreak(now);

    int luckPouchReward = WishRoomRewardConfig.baseRitualLuckPouch;
    double lightIncrease = WishRoomRewardConfig.baseLightIncrease;
    if (newStreak % 7 == 0) {
      // 연속 치성 7일 단위 마일스톤 — §11 "추후 확장 보상" 이전 단계의
      // MVP 보상(추가 복주머니 + 게이지 추가 상승)만 적용한다.
      luckPouchReward += WishRoomRewardConfig.weeklyBonusLuckPouch;
      lightIncrease += WishRoomRewardConfig.weeklyBonusLight;
    } else if (newStreak >= 3) {
      luckPouchReward += WishRoomRewardConfig.streakBonusLuckPouch;
    }

    final newLightPercent = (room.wishLightPercent + lightIncrease).clamp(
      0,
      100,
    ).toDouble();

    final updatedRoom = room.copyWith(
      todayRitualDone: true,
      lastRitualAt: now,
      streakDays: newStreak,
      wishLightPercent: newLightPercent,
      updatedAt: now,
    );
    await _repository.saveRoom(updatedRoom);

    await _repository.appendRitualHistory(
      RitualRecordModel(
        ritualId: now.microsecondsSinceEpoch.toString(),
        userId: updatedRoom.userId,
        ritualDate: now,
        tapCount: tapCount,
        rewardLuckPouch: luckPouchReward,
        rewardExp: WishRoomRewardConfig.baseRitualExp,
        lightIncrease: lightIncrease,
        streakAfter: newStreak,
        createdAt: now,
      ),
    );

    // [자산 정책] 복주머니 지급은 반드시 LuckPouchProvider를 통해서만
    // 이루어진다 — 소원방이 자체 잔액을 따로 들고 있지 않는다(§8 금지
    // 원칙: 하나의 기능이 세 자산에 동시에 걸리는 구조를 만들지 않는다 +
    // 자산별 단일 진실 공급원 유지).
    // [재화 구조 정리 - 재연결] sourceType 미지정 시 서버 기본값 'app'으로 기록되어
    // 어떤 활동으로 적립됐는지 PointHistory에서 구분이 불가능했다(관리자 내역
    // 확인·통계 집계 시 "치성 드리기"만 따로 볼 수 없는 문제). luck_pouch_rules
    // 시드의 actionType="wish_room_ritual"과 이름을 맞춰 'wish_room_ritual'로 명시.
    await _luckPouch.earn(
      luckPouchReward,
      '오늘의 치성 보상',
      sourceType: 'wish_room_ritual',
    );

    _room = updatedRoom;
    notifyListeners();

    return RitualRewardResult(
      luckPouch: luckPouchReward,
      exp: WishRoomRewardConfig.baseRitualExp,
      lightIncrease: lightIncrease,
      streakAfter: newStreak,
      wishLightPercent: newLightPercent,
    );
  }

  /// 연속 치성 일수 계산(§11). 마지막 치성이 "어제"였다면 +1, "오늘"이면
  /// 그대로(가드 경로), 그 이전이거나 기록이 없다면 1로 리셋/시작한다.
  @visibleForTesting
  int updateWishRoomStreak(DateTime now) {
    final last = room.lastRitualAt;
    if (last == null) return 1;
    if (_isSameDay(last, now)) return room.streakDays;
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(last, yesterday)) return room.streakDays + 1;
    return 1;
  }

  Future<void> updateWishText(String text) async {
    final updated = room.copyWith(
      wishText: text.trim(),
      updatedAt: DateTime.now(),
    );
    await _repository.saveRoom(updated);
    _room = updated;
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
