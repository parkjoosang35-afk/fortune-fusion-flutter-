/// [복주머니 마케팅 쿠폰 — 비로그인 진입 처리] QR 스캔/딥링크로 쿠폰
/// 토큰을 받았지만 비로그인 상태인 경우, 그 토큰을 잠시 보관했다가 로그인
/// 완료 직후 원래 등록하려던 화면([BokjuCouponResolveScreen])으로 자동
/// 복귀시키는 용도.
///
/// [귀인지도 PendingGuinjiJoinStore와 동일한 패턴] 결제/패스 소비가 전혀
/// 없는 가벼운 단일 값 저장소라는 점도 동일하다.
class PendingBokjuCouponStore {
  PendingBokjuCouponStore._();

  static String? _token;

  static void save(String token) {
    _token = token;
  }

  /// 저장된 토큰을 꺼내면서 동시에 비운다(1회성 소비 — 중복 재실행 방지).
  static String? consume() {
    final token = _token;
    _token = null;
    return token;
  }

  static void clear() {
    _token = null;
  }
}
