import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/healing_quote_repository.dart';
import '../domain/healing_quote_model.dart';

/// "힐링 문구" 상태관리 Provider.
///
/// [사용자 요청] "오늘의 운세 이야기"를 완전히 삭제하고, 데이터베이스에서 불러온 좋은 글귀/
/// 힐링 문구/긍정 명언/응원의 한마디를 1분마다 자동으로 새로운 문구로 변경한다. 이 기능은
/// 24시간 계속 반복되어야 하므로, 앱이 로드되어 있는 동안 내부 Timer.periodic(1분)으로
/// 인덱스를 순환시킨다(LuckyNumberProvider의 "단일 콘텐츠" 구조와 달리 리스트+순환 인덱스).
class HealingQuoteProvider extends ChangeNotifier {
  final HealingQuoteRepository _repository;
  HealingQuoteProvider(this._repository);

  static const Duration _rotationInterval = Duration(minutes: 1);

  List<HealingQuoteModel> _quotes = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  String? _error;
  bool _hasLoaded = false;
  Timer? _rotationTimer;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoaded => _hasLoaded;
  bool get hasContent => _quotes.isNotEmpty;

  /// 현재 순환 인덱스에 해당하는 문구. 데이터가 없으면 null(위젯에서 기본 문구로 대체).
  HealingQuoteModel? get current =>
      _quotes.isEmpty ? null : _quotes[_currentIndex % _quotes.length];

  Future<void> load() async {
    debugPrint('[HealingQuoteProvider] load() 호출');
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.getActiveQuotes();

    if (result.success) {
      _quotes = result.data ?? [];
      _currentIndex = _quotes.isEmpty
          ? 0
          : DateTime.now().millisecondsSinceEpoch % _quotes.length;
      debugPrint('[HealingQuoteProvider] load() 성공 -> ${_quotes.length}건');
      _startRotationTimer();
    } else {
      _error = result.errorMessage;
      debugPrint('[HealingQuoteProvider] load() 실패 -> error=$_error');
    }
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }

  void _startRotationTimer() {
    _rotationTimer?.cancel();
    if (_quotes.length <= 1) return; // 문구가 1건 이하면 순환할 필요 없음
    // [사용자 요청] "1분마다 자동으로 새로운 문구로 변경... 24시간 계속 반복"
    _rotationTimer = Timer.periodic(_rotationInterval, (_) {
      _currentIndex = (_currentIndex + 1) % _quotes.length;
      debugPrint(
        '[HealingQuoteProvider] 1분 경과 -> 다음 문구로 순환(index=$_currentIndex)',
      );
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }
}
