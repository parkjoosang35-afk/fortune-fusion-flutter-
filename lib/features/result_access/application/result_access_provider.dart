import 'package:flutter/foundation.dart';
import '../data/result_access_repository.dart';
import '../domain/result_access_model.dart';

/// [결과보기 통합 권한 시스템 v1.0, Phase4] §8.1 공통 서비스의 Flutter측 단일
/// 진입점. 정통사주 69종·타로 65종·운세 전체가 이 Provider 하나만 통해
/// quote/begin/ad-session API를 호출한다.
///
/// [PassProvider와의 관계] PassProvider는 여전히 프리패스 발급(쿠팡 방문→
/// 지급, claimAd)과 레거시 "카테고리 진입 게이트"(consume)를 담당한다.
/// 이 Provider는 그와 별개로 "결과보기 버튼을 눌렀을 때의 3택 결제"만
/// 전담한다 — 책임이 분리되어 있으므로 서로 대체하지 않는다.
class ResultAccessProvider extends ChangeNotifier {
  final ResultAccessRepository _repository;
  ResultAccessProvider(this._repository);

  ResultAccessQuote? _quote;
  bool _isLoadingQuote = false;
  bool _isBeginning = false;
  String? _lastError;
  String? _lastErrorReason;

  ResultAccessQuote? get quote => _quote;
  bool get isLoadingQuote => _isLoadingQuote;
  bool get isBeginning => _isBeginning;
  String? get lastError => _lastError;
  String? get lastErrorReason => _lastErrorReason;

  /// §6 3택 UI를 그리기 전 항상 최신 상태를 조회한다(§8.3 서버 재검증 —
  /// 시트를 여는 시점의 잔액을 신뢰하고 그 이후 변경은 begin()이 다시 확인).
  Future<void> loadQuote({
    required String contentType,
    String? categoryKey,
  }) async {
    _isLoadingQuote = true;
    _lastError = null;
    notifyListeners();

    final result = await _repository.getQuote(
      contentType: contentType,
      categoryKey: categoryKey,
    );
    if (result.success) {
      _quote = result.data;
    } else {
      _lastError = result.errorMessage;
    }
    _isLoadingQuote = false;
    notifyListeners();
  }

  /// §8.5 "결제 확정" — 성공하면 [ResultAccessBeginResult]를 반환하고, 호출부는
  /// 이 결과의 transactionId를 그대로 콘텐츠 API(saju/tarot/...)에 전달해야
  /// 한다. 실패하면 null을 반환하고 [lastError]/[lastErrorReason]에 사유를
  /// 남긴다(화면단에서 잔액부족/광고미완료 등 안내에 사용).
  ///
  /// [§8.4 중복 클릭 방지] 호출부가 버튼을 누른 "그 순간" 1회만 이 메서드를
  /// 호출하도록 [isBeginning] 플래그로 가드한다 — 이미 진행 중이면 즉시
  /// null을 반환해 재진입을 막는다(버튼은 화면단에서도 isBeginning으로
  /// disabled 처리해야 한다, 이중 안전장치).
  Future<ResultAccessBeginResult?> begin({
    required String transactionId,
    required String contentType,
    String? contentId,
    String? categoryKey,
    required ResultAccessPaymentMethod paymentMethod,
    String? adSessionId,
  }) async {
    if (_isBeginning) {
      debugPrint('[ResultAccessProvider] [begin] 이미 진행 중 — 중복 호출 무시');
      return null;
    }
    _isBeginning = true;
    _lastError = null;
    _lastErrorReason = null;
    notifyListeners();

    final result = await _repository.begin(
      transactionId: transactionId,
      contentType: contentType,
      contentId: contentId,
      categoryKey: categoryKey,
      paymentMethod: paymentMethod,
      adSessionId: adSessionId,
    );

    _isBeginning = false;
    if (!result.success) {
      _lastError = result.errorMessage;
      _lastErrorReason = result.errorCode;
      notifyListeners();
      return null;
    }
    notifyListeners();
    return result.data;
  }

  /// §8.3 광고 세션 시작 — AdMob 광고를 로드/표시하기 전에 호출한다.
  Future<String?> startAdSession() async {
    final result = await _repository.startAdSession();
    if (!result.success) {
      _lastError = result.errorMessage;
      notifyListeners();
      return null;
    }
    return result.data;
  }

  /// §8.3 광고 세션 완료 — AdMob의 onUserEarnedReward 콜백 이후에만 호출한다.
  Future<bool> completeAdSession(String sessionId) async {
    final result = await _repository.completeAdSession(sessionId);
    if (!result.success) {
      _lastError = result.errorMessage;
      notifyListeners();
      return false;
    }
    return true;
  }

  void clearError() {
    _lastError = null;
    _lastErrorReason = null;
    notifyListeners();
  }
}
