/// 결과 공유(Share Result) 기능 — 신통방통_결과공유_개발제안서(sintong-share-proposal.pdf)
/// 대응 도메인 모델.
///
/// [5개 결과 타입] 운세(fortune)/타로(tarot)/관상(face)/손금(palm)/소원성(wish).
/// admin_web `src/app/api/public/share/_shared.ts`의 `SHARE_RESULT_TYPES`와
/// 반드시 동일한 문자열 값을 사용해야 한다(서버가 화이트리스트로 검증).
enum ShareResultType {
  fortune,
  tarot,
  face,
  palm,
  wish;

  /// 서버 API에 실어 보내는 문자열 값(그대로 매칭).
  String get apiValue => name;

  static ShareResultType? fromApiValue(String? value) {
    for (final t in ShareResultType.values) {
      if (t.apiValue == value) return t;
    }
    return null;
  }
}

/// `POST /api/public/share` 성공 응답(`{shareId, shareUrl}`) 대응.
class CreatedShareLink {
  final String shareId;
  final String shareUrl;

  const CreatedShareLink({required this.shareId, required this.shareUrl});

  factory CreatedShareLink.fromJson(Map<String, dynamic> json) {
    return CreatedShareLink(
      shareId: json['shareId'] as String,
      shareUrl: json['shareUrl'] as String,
    );
  }
}

/// `GET /api/public/share/{shareId}` 성공 응답의 `data` 객체 대응.
///
/// [PII 미포함 원칙] `payload`는 서버가 그대로 통과시키는 임의 JSON이지만,
/// 이 필드에 원본 민감정보(생년월일 원본/실명/사진/전화번호 등)를 절대
/// 담지 않는다는 원칙은 **작성 시점**(ShareApiService.createShareLink 호출부)에
/// 지켜야 한다 — 이 모델 자체는 서버가 반환한 값을 그대로 읽기만 한다.
class SharedResultDto {
  final String shareId;
  final ShareResultType resultType;
  final String title;
  final String description;
  final Map<String, dynamic>? payload;
  final String? imageUrl;
  final String? ownerNickname;
  final int viewCount;
  final DateTime createdAt;

  const SharedResultDto({
    required this.shareId,
    required this.resultType,
    required this.title,
    required this.description,
    required this.payload,
    required this.imageUrl,
    required this.ownerNickname,
    required this.viewCount,
    required this.createdAt,
  });

  factory SharedResultDto.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return SharedResultDto(
      shareId: json['shareId'] as String,
      resultType:
          ShareResultType.fromApiValue(json['resultType'] as String?) ??
          ShareResultType.fortune,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      payload: rawPayload is Map<String, dynamic> ? rawPayload : null,
      imageUrl: json['imageUrl'] as String?,
      ownerNickname: json['ownerNickname'] as String?,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
