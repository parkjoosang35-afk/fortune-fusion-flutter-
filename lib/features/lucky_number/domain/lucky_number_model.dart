/// "오늘의 행운숫자" 관리자 콘텐츠 모델 - admin_web `lucky_number_contents` 테이블
/// (GET /api/public/lucky-number) 대응.
///
/// [사용자 요청] 이 기능은 광고(ad_banner/banners)가 아니므로 AdBannerModel과 구조는
/// 유사하지만 완전히 별도로 정의한다. "AD" 표기, linkUrl(제휴 링크) 개념이 없다.
/// contentType: 'image' | 'video' | 'script' 중 하나.
class LuckyNumberModel {
  final int id;
  final String title;
  final String contentType; // 'image' | 'video' | 'script'
  final String? imageUrl;
  final String? videoUrl;
  final String? script;
  final String? caption;

  const LuckyNumberModel({
    required this.id,
    required this.title,
    required this.contentType,
    this.imageUrl,
    this.videoUrl,
    this.script,
    this.caption,
  });

  bool get isImage => contentType == 'image';
  bool get isVideo => contentType == 'video';
  bool get isScript => contentType == 'script';

  factory LuckyNumberModel.fromJson(Map<String, dynamic> json) {
    return LuckyNumberModel(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      title: (json['title'] as String?) ?? '',
      contentType: (json['contentType'] as String?) ?? 'image',
      imageUrl: json['imageUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      script: json['script'] as String?,
      caption: json['caption'] as String?,
    );
  }
}
