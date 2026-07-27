import 'package:flutter/foundation.dart';
import '../data/lucky_number_repository.dart';
import '../domain/lucky_number_model.dart';

/// "오늘의 행운숫자" 관리자 콘텐츠 상태관리 Provider.
///
/// [사용자 요청] AdBannerProvider(position별 Map 캐싱)와 달리, 이 콘텐츠는 단일 슬롯이므로
/// 단순화된 형태로 구현한다(광고 시스템과 완전히 분리).
class LuckyNumberProvider extends ChangeNotifier {
  final LuckyNumberRepository _repository;
  LuckyNumberProvider(this._repository);

  LuckyNumberModel? _content;
  bool _isLoading = false;
  String? _error;
  bool _hasLoaded = false;

  LuckyNumberModel? get content => _content;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoaded => _hasLoaded;
  bool get hasContent => _content != null;

  Future<void> load() async {
    debugPrint('[LuckyNumberProvider] load() 호출');
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.getActiveContent();

    if (result.success) {
      _content = result.data;
      debugPrint('[LuckyNumberProvider] load() 성공 -> hasContent=$hasContent');
    } else {
      _error = result.errorMessage;
      debugPrint('[LuckyNumberProvider] load() 실패 -> error=$_error');
    }
    _isLoading = false;
    _hasLoaded = true;
    notifyListeners();
  }
}
