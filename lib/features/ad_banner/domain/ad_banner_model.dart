/// CMS 제휴광고 배너 모델 - admin_web `banners` 테이블(GET /api/public/banners) 대응.
///
/// 필드는 API 응답 JSON의 camelCase 키와 1:1 매핑되며, DB 원본 컬럼명은 주석으로 병기한다.
///
/// [광고소스 지원] adType에 따라 두 가지 형태를 지원한다.
///  - 'image'  : 기존 방식. imageUrl(썸네일) + linkUrl(탭 시 이동할 제휴 링크)
///  - 'script' : 제휴사(쿠팡파트너스 등)가 발급한 원본 광고 태그(<iframe>/<script>)를
///               그대로 저장한 adScript를 WebView로 렌더링한다. 이 경우 imageUrl/linkUrl은
///               사용하지 않는다(광고 자체가 클릭/이동까지 처리).
class AdBannerModel {
  final int id; // banners.id
  final String title; // banners.title
  final String adType; // banners.ad_type ('image' | 'script')
  final String? imageUrl; // banners.image_url (adType='image' 전용, nullable)
  final String? linkUrl; // banners.link_url (제휴 어필리에이트 링크, adType='image' 전용)
  final String? adScript; // banners.ad_script (adType='script' 전용, 원본 광고 태그)
  final String positionCode; // banners.position_code (home_top/home_middle/home_bottom)
  final int sortOrder; // banners.sort_order

  const AdBannerModel({
    required this.id,
    required this.title,
    required this.positionCode,
    required this.sortOrder,
    this.adType = 'image',
    this.imageUrl,
    this.linkUrl,
    this.adScript,
  });

  bool get isScriptAd => adType == 'script';

  factory AdBannerModel.fromJson(Map<String, dynamic> json) {
    // 서버 응답 타입이 예상과 다를 경우를 대비해 안전 캐스팅으로 방어한다.
    return AdBannerModel(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      title: (json['title'] as String?) ?? '',
      adType: (json['adType'] as String?) ?? 'image',
      imageUrl: json['imageUrl'] as String?,
      linkUrl: json['linkUrl'] as String?,
      adScript: json['adScript'] as String?,
      positionCode: (json['positionCode'] as String?) ?? '',
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse('${json['sortOrder']}') ?? 0,
    );
  }
}
