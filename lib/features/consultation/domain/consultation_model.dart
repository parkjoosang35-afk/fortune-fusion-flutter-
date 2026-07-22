/// 04A E-7 `consultation_sessions`/`consultation_messages` 대응 모델
/// 09단계 §1.2 AI Gateway `generateStream()` 스트리밍 인터페이스를 Mock으로 재현하기 위한 도메인 모델
enum ConsultationRole { user, ai }

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
}

/// 상담 유형: saju(사주상담) / tarot(타로상담) / general(일반상담)
class ConsultationSessionModel {
  final String id;
  final String type;
  final List<ConsultationMessage> messages;
  final DateTime createdAt;

  const ConsultationSessionModel({
    required this.id,
    required this.type,
    required this.messages,
    required this.createdAt,
  });
}
