/// [소원방 가이드] 관리자 CMS가 편집한 "이용 방법" 슬라이드 1장.
///
/// 서버 원천: `GET /api/wish-room/guide`(admin_web이 관리하는 가이드
/// 슬라이드 목록 — 문구/이미지/노출순서를 관리자가 CMS에서 직접
/// 편집한다). § "관리자 설정값 하드코딩 금지" 원칙에 따라 클라이언트는
/// 이 문구를 절대 하드코딩하지 않고 항상 [WishRoomRepository.
/// fetchGuideSlides]를 통해 받아온다. 다만 네트워크 오류 등으로 서버
/// 응답을 받지 못했을 때를 대비해 [WishGuideDialog]가 자체적으로 최소
/// 안내를 보여줄 수 있도록 Mock 구현체는 합리적인 기본 슬라이드를
/// 반환한다(§ "placeholder/coming soon 없이 완전 동작" 원칙).
class GuideSlide {
  final String title;
  final String body;
  final String? imageUrl;

  const GuideSlide({required this.title, required this.body, this.imageUrl});
}
