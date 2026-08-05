import 'package:flutter/foundation.dart';

/// [소원방 Sprint 4] 5개 핵심 재미 지표(㉑ 섹션)에 대응하는 애널리틱스
/// 이벤트 전송 훅.
///
/// [설계 의도] 이 프로젝트에는 아직 Firebase Analytics 등 실제 SDK가
/// 연동되어 있지 않다(Firebase 설정 파일이 프로젝트에 없음). 그렇다고
/// 이벤트 발생 지점 자체를 나중으로 미루면, 실 SDK를 붙일 때 컨트롤러의
/// 모든 성공 경로를 다시 찾아 헤집어야 한다. 그래서 이 클래스가 "이벤트가
/// 실제로 무엇이고 언제 발생하는가"를 지금 확정하고, 전송 방식만 추상화
/// 해둔다 — 실 SDK를 붙일 때는 [_send] 메서드 본문만
/// `FirebaseAnalytics.instance.logEvent(...)` 호출로 교체하면 되고,
/// `WishRoomController`의 호출부는 전혀 손댈 필요가 없다.
///
/// 정적 메서드로 노출하는 이유: Riverpod Provider로 주입하기엔 과한
/// 무상태 유틸리티이며(순수 fire-and-forget 로깅), 테스트에서도 이
/// 클래스의 부재/존재가 어떤 상태도 좌우하지 않는다(콘솔 출력 부작용만
/// 있음 — 문서 ㉖-4 스코프: "최소 1개 이벤트씩 발생"이 완료 기준이다).
class WishRoomAnalytics {
  const WishRoomAnalytics._();

  /// [치성액션] `prayForWish` 성공 시 — daily/deep/focused 종류별 실행률과
  /// 유료 치성 전환율을 측정하기 위한 이벤트(㉑ "치성액션" 행 대응).
  static void logPrayerCompleted({
    required String prayerType,
    required int pouchCost,
    required int growthPointGain,
    required bool didLevelUp,
    required bool didUnlockNewSlot,
  }) {
    _send('wish_room_prayer_completed', {
      'prayer_type': prayerType,
      'pouch_cost': pouchCost,
      'growth_point_gain': growthPointGain,
      'did_level_up': didLevelUp,
      'did_unlock_new_slot': didUnlockNewSlot,
    });
  }

  /// [복주머니 적립/사용 + 재방문] `unlockSubSlot` 성공 시 — 무료(스트릭)
  /// 해금 vs 유료(복주머니) 해금 비율을 측정하기 위한 이벤트(㉑ "복주머니
  /// 적립/사용" 행 대응).
  static void logSlotUnlocked({required bool viaPouch}) {
    _send('wish_room_slot_unlocked', {'via_pouch': viaPouch});
  }

  /// [꾸미기] `purchaseCustomizeItem` 성공 시 — 카탈로그 아이템 보유율을
  /// 측정하기 위한 이벤트(㉑ "꾸미기" 행 대응).
  static void logCustomizeItemPurchased({
    required String itemId,
    required int pouchCost,
  }) {
    _send('wish_room_customize_item_purchased', {
      'item_id': itemId,
      'pouch_cost': pouchCost,
    });
  }

  /// [소원성장] `addWish` 성공 시 — 신규 소원 등록 자체도 성장 루프의
  /// 시작점이므로 함께 측정한다(㉑ "소원성장" 행 대응 보조 지표).
  static void logWishAdded({required String category}) {
    _send('wish_room_wish_added', {'category': category});
  }

  /// 실제 전송 지점. 지금은 SDK가 없으므로 디버그 콘솔에만 남긴다 —
  /// 릴리스 빌드(`kDebugMode == false`)에서는 아무 부작용도 없다.
  static void _send(String eventName, Map<String, Object?> params) {
    if (kDebugMode) {
      debugPrint('[WishRoomAnalytics] $eventName $params');
    }
  }
}
