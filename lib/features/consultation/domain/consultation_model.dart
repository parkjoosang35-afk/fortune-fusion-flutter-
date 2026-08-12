/// 04A E-7 `consultation_sessions`/`consultation_messages` 대응 모델.
///
/// [AI 상담 채팅 실연동] admin_web `/api/public/consultation/session`,
/// `/api/public/consultation/message` 공개 API 응답을 그대로 반영한다.
/// 과거 Mock 단계에서는 세션 id가 클라이언트가 임의로 만든 문자열이었지만,
/// 실연동 이후에는 서버가 발급한 정수 sessionId(ConsultationSession.id)를
/// 그대로 써야 한다(다음 턴 전송 시 이 값을 그대로 되돌려줘야 함).
enum ConsultationRole { user, ai }

/// 상담 세션당 정책 상수(서버 `open-consultation-service.ts`와 동일한 값을
/// 클라이언트에서도 즉시 검증/안내할 수 있도록 미러링한다. 최종 판정은
/// 항상 서버가 내리며, 이 값들은 UX용 사전 체크 목적일 뿐이다).
class ConsultationLimits {
  const ConsultationLimits._();

  /// 유저 1회 발화(메시지) 최대 글자수.
  static const int maxMessageLength = 500;

  /// 세션당 허용되는 유저 발화(턴) 최대 횟수. 서버가 실제 값을 응답으로
  /// 내려주지만, 세션이 아직 시작되지 않은 시점의 기본 안내용으로 사용한다.
  static const int defaultMaxTurns = 20;
}

class ConsultationMessage {
  final String id;
  final ConsultationRole role;
  final String text;
  final DateTime createdAt;

  const ConsultationMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
  });

  ConsultationMessage copyWith({String? text}) => ConsultationMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
  );

  factory ConsultationMessage.fromJson(Map<String, dynamic> json) {
    return ConsultationMessage(
      id: json['id'] as String,
      role: json['role'] == 'user'
          ? ConsultationRole.user
          : ConsultationRole.ai,
      text: json['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// 상담 유형: saju(사주상담) / tarot(타로상담) / general(일반상담)
///
/// [AI 상담 채팅 실연동] `sessionId`(서버 발급 정수)와 `turnCount`/`maxTurns`
/// (20턴 한도 UI 안내용)를 추가했다. `isNew`는 오늘 처음 생성된 세션인지
/// (true) 기존 세션을 그대로 재사용한 것인지(false, idempotent 재사용)를
/// 구분한다 — 광고 게이트를 다시 통과하지 않고도 안전하게 재진입했다는 신호.
class ConsultationSessionModel {
  final int sessionId;
  final String type;
  final int turnCount;
  final int maxTurns;
  final String status;
  final List<ConsultationMessage> messages;
  final bool isNew;

  const ConsultationSessionModel({
    required this.sessionId,
    required this.type,
    required this.turnCount,
    required this.maxTurns,
    required this.status,
    required this.messages,
    required this.isNew,
  });

  factory ConsultationSessionModel.fromJson(Map<String, dynamic> json) {
    return ConsultationSessionModel(
      sessionId: json['sessionId'] as int,
      type: json['type'] as String? ?? 'general',
      turnCount: json['turnCount'] as int? ?? 0,
      maxTurns: json['maxTurns'] as int? ?? ConsultationLimits.defaultMaxTurns,
      status: json['status'] as String? ?? 'active',
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConsultationMessage.fromJson)
          .toList(),
      isNew: json['isNew'] as bool? ?? false,
    );
  }
}

/// POST /api/public/consultation/message 성공 응답(스트리밍 재현에 필요한
/// reply 텍스트 + 갱신된 턴 카운트).
class ConsultationTurnResult {
  final String reply;
  final int turnCount;
  final int maxTurns;
  final int remainingTurns;

  const ConsultationTurnResult({
    required this.reply,
    required this.turnCount,
    required this.maxTurns,
    required this.remainingTurns,
  });

  factory ConsultationTurnResult.fromJson(Map<String, dynamic> json) {
    return ConsultationTurnResult(
      reply: json['reply'] as String? ?? '',
      turnCount: json['turnCount'] as int? ?? 0,
      maxTurns: json['maxTurns'] as int? ?? ConsultationLimits.defaultMaxTurns,
      remainingTurns: json['remainingTurns'] as int? ?? 0,
    );
  }
}

/// [AI 상담 채팅 실연동] 상담 메시지 전송 실패(턴 한도 초과/500자 초과/
/// 세션 종료 등)를 화면단에 알리기 위한 예외. `code`는 서버가 내려주는
/// `reason`(또는 `OpenConsultationServiceError.code`) 값을 그대로 담아
/// UI가 사유별로 다르게 반응할 수 있게 한다(예: TURN_LIMIT_REACHED이면
/// "내일 다시" 안내, SESSION_ENDED면 재시작 유도).
class ConsultationRequestException implements Exception {
  final String message;
  final String? code;
  final int? turnCount;
  final int? maxTurns;

  const ConsultationRequestException(
    this.message, {
    this.code,
    this.turnCount,
    this.maxTurns,
  });

  @override
  String toString() => message;
}
