import 'package:flutter/foundation.dart';
import '../data/consultation_repository.dart';
import '../domain/consultation_model.dart';

/// 07단계 §2.1 화면 단위 지역 Provider - ConsultationProvider
/// 09단계 §1.2 스트리밍 응답을 메시지 리스트의 마지막 AI 메시지에 누적 반영한다.
class ConsultationProvider extends ChangeNotifier {
  final ConsultationRepository _repository;
  ConsultationProvider(this._repository);

  String? _type;
  String get type => _type ?? 'general';

  List<ConsultationMessage> _messages = [];
  List<ConsultationMessage> get messages => _messages;

  bool _isStreaming = false;
  bool get isStreaming => _isStreaming;

  bool _isStarting = false;
  bool get isStarting => _isStarting;

  Future<void> startSession(String type) async {
    _type = type;
    _isStarting = true;
    _messages = [];
    notifyListeners();

    final result = await _repository.createSession(type: type);
    if (result.success && result.data != null) {
      _messages = List.of(result.data!.messages);
    }
    _isStarting = false;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isStreaming) return;

    final userMsg = ConsultationMessage(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      role: ConsultationRole.user,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _messages.add(userMsg);
    notifyListeners();

    _isStreaming = true;
    final aiId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    _messages.add(ConsultationMessage(id: aiId, role: ConsultationRole.ai, text: '', createdAt: DateTime.now()));
    notifyListeners();

    final buffer = StringBuffer();
    try {
      await for (final chunk in _repository.streamReply(type: type, userMessage: trimmed)) {
        buffer.write(chunk);
        final idx = _messages.indexWhere((m) => m.id == aiId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(text: buffer.toString());
          notifyListeners();
        }
      }
    } finally {
      _isStreaming = false;
      notifyListeners();
    }
  }
}
