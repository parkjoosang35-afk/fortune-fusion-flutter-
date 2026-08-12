import 'package:flutter/foundation.dart';

import '../data/wish_counsel_repository.dart';
import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart' show CounselCategory;

/// 상담(Midnight Comfort) 전역 상태 — ChangeNotifier 기반.
///
/// 03_FLUTTER_IMPL.md는 flutter_riverpod(StateNotifier)을 기준으로 작성돼
/// 있으나, 실제 프로젝트는 provider(6.1.5+1)를 사용하므로 이 Provider는
/// ChangeNotifier로 변환한 구현이다. `lib/app.dart`의 다른 feature
/// Provider들과 동일한 패턴(단일 ChangeNotifierProvider 등록)을 따른다.
class WishCounselProvider extends ChangeNotifier {
  WishCounselProvider(this._repository) {
    _characters = _repository.allCharacters();
  }

  final WishCounselRepository _repository;
  late List<CounselCharacter> _characters;

  List<CounselCharacter> get characters => _characters;

  List<CounselCharacter> byCategory(CounselCategory cat) =>
      _characters.where((c) => c.category == cat).toList();

  // ── 현재 세션 상태 ──
  CounselSession? _session;
  CounselSession? get session => _session;

  String _mode = 'normal';
  String get mode => _mode;

  String? _selectedEmotion;
  String? get selectedEmotion => _selectedEmotion;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  bool _crisisActive = false;
  bool get crisisActive => _crisisActive;

  void selectEmotion(String key) {
    _selectedEmotion = key;
    notifyListeners();
  }

  void selectMode(String key) {
    _mode = key;
    notifyListeners();
  }

  Future<void> startSession(CounselCharacter character) async {
    _session = await _repository.createSession(character);
    _crisisActive = false;
    final greeting = _repository.greetingFor(
      character,
      emotionKey: _selectedEmotion,
    );
    _session!.messages.add(
      CounselMessage(
        id: 'greet-${DateTime.now().microsecondsSinceEpoch}',
        role: CounselRole.ai,
        text: greeting,
        createdAt: DateTime.now(),
      ),
    );
    _session!.startEmotion = _selectedEmotion;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (_session == null || text.trim().isEmpty) return;
    final userMsg = CounselMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      role: CounselRole.user,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    _session!.messages.add(userMsg);
    notifyListeners();

    final isCrisis = _repository.detectCrisis(text);
    if (isCrisis) {
      _crisisActive = true;
    }

    _isTyping = true;
    notifyListeners();

    final buffer = StringBuffer();
    final aiMsgId = 'a-${DateTime.now().microsecondsSinceEpoch}';
    final aiMsg = CounselMessage(
      id: aiMsgId,
      role: CounselRole.ai,
      text: '',
      createdAt: DateTime.now(),
      crisis: isCrisis,
    );
    _session!.messages.add(aiMsg);

    await for (final token in _repository.streamReply(
      character: _session!.character,
      userMessage: text,
    )) {
      buffer.write(token);
      final idx = _session!.messages.indexWhere((m) => m.id == aiMsgId);
      if (idx != -1) {
        _session!.messages[idx] = _session!.messages[idx].copyWith(
          text: buffer.toString(),
        );
      }
      notifyListeners();
    }

    _isTyping = false;
    _session!.endEmotion = _selectedEmotion;
    notifyListeners();
  }

  void closeSession() {
    _session = null;
    _crisisActive = false;
    _selectedEmotion = null;
    _mode = 'normal';
    notifyListeners();
  }
}
