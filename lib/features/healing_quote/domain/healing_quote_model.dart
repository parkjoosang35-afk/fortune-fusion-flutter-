/// "힐링 문구" 관리자 콘텐츠 모델 - admin_web `healing_quotes` 테이블
/// (GET /api/public/healing-quotes) 대응.
///
/// [사용자 요청] 홈 화면의 "오늘의 운세 이야기"(운세 기능)를 완전히 삭제하고, 그 자리를
/// 좋은 글귀 / 힐링 문구 / 긍정 명언 / 응원의 한마디로 대체한다. 운세/광고와는 완전히
/// 무관한 별도 콘텐츠이며, 서버는 활성 문구 "전체 목록"을 반환하고 앱이 로컬에서
/// 1분마다 하나씩 순환 노출한다(LuckyNumberModel과 달리 단일 슬롯이 아님).
class HealingQuoteModel {
  final int id;
  final String content;
  final String? author;
  final String category;

  const HealingQuoteModel({
    required this.id,
    required this.content,
    this.author,
    this.category = 'healing',
  });

  factory HealingQuoteModel.fromJson(Map<String, dynamic> json) {
    return HealingQuoteModel(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      content: (json['content'] as String?) ?? '',
      author: json['author'] as String?,
      category: (json['category'] as String?) ?? 'healing',
    );
  }
}
