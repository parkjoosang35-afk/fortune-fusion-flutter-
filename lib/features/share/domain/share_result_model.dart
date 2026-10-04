/// 결과 공유(Share Result) 기능 — 신통방통_결과공유_개발제안서(sintong-share-proposal.pdf)
/// 대응 도메인 모델.
///
/// [2027-02 6개 카테고리 통일] 소원방(wish)/타로(tarot)/정통사주(saju)/
/// 귀인지도(relationship)/관상(face)/손금(palm) 6종. admin_web
/// `src/app/api/public/share/_shared.ts`의 `SHARE_RESULT_TYPES`(=중앙 설정
/// `OG_CONFIG`의 키)와 반드시 동일한 문자열 값을 사용해야 한다(서버가
/// 화이트리스트로 검증).
///
/// [하위 호환 — 절대 원칙] `fortune`은 과거(이 작업 이전) "오늘의 운세"
/// 통합 화면이 공유에 사용했던 값으로, 기존에 이미 생성된 SharedResult
/// 레코드와 `/r/{shareId}` 링크가 계속 정상 동작하도록 서버 화이트리스트에
/// 영구 보존된다. **신규 코드는 절대 이 값을 쓰지 않고 [saju]를 사용할
/// 것** — 신규 호출부에서 `ShareResultType.fortune`을 쓰면 안 된다.
enum ShareResultType {
  @Deprecated(
    '레거시 전용 — 기존에 이미 생성된 공유 데이터의 하위호환을 위해서만 '
    '유지한다. 신규 공유는 ShareResultType.saju를 사용할 것.',
  )
  fortune,
  tarot,
  face,
  palm,
  wish,
  saju,
  relationship;

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
          // ignore: deprecated_member_use_from_same_package
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
