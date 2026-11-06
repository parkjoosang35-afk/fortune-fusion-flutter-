/// [신당부적 — 비로그인 "민세레나에게 부탁하기" 처리] 비로그인 상태로
/// 05 상세 화면에서 "민세레나에게 부탁하기"를 눌렀을 때, 지금 고른
/// 부적(talismanId)과 이미 입력해둔 소망(wish)을 잠시 보관했다가 로그인
/// 완료 직후 같은 화면으로 자동 복귀시키는 용도.
///
/// [기존 패턴과 완전히 동일] `PendingBokjuCouponStore`(복주머니 쿠폰)/
/// `PendingGuinjiMapEntryStore`(귀인지도)와 같은 "가벼운 단일 값 메모리
/// 저장소 + consume() 1회성 소비" 패턴을 그대로 재사용한다 — 앱 전역에
/// 이미 검증된 "비로그인 복귀" 아키텍처를 새로 발명하지 않는다.
class PendingShrineOrder {
  const PendingShrineOrder({required this.talismanId, required this.wish});

  final String talismanId;
  final String wish;
}

class PendingShrineOrderStore {
  PendingShrineOrderStore._();

  static PendingShrineOrder? _pending;

  static void save(String talismanId, String wish) {
    _pending = PendingShrineOrder(talismanId: talismanId, wish: wish);
  }

  /// 저장된 값을 꺼내면서 동시에 비운다(1회성 소비 — 중복 재실행 방지).
  static PendingShrineOrder? consume() {
    final p = _pending;
    _pending = null;
    return p;
  }

  static void clear() {
    _pending = null;
  }
}
