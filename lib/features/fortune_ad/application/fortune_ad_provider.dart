import 'package:flutter/foundation.dart';
import '../../../core/api/api_result.dart';
import '../data/fortune_ad_repository.dart';
import '../domain/fortune_ad_model.dart';

/// [신통방통 복주머니 광고 적립 시스템] 복주머니 화면의 "광고 보고 충전" 카드가
/// 참조하는 전역 상태. 광고 목록 캐시 + 시청시작/완료 API 위임을 담당한다.
/// 실제 화면 흐름(팝업 단계 전환/타이머)은 [FortuneAdWatchDialog]가 담당하고,
/// 이 Provider는 API 호출만 얇게 감싼다(§15: 상태와 통신 책임 분리).
class FortuneAdProvider extends ChangeNotifier {
  final FortuneAdRepository _repository;
  FortuneAdProvider(this._repository);

  List<FortuneAdModel> _ads = [];
  bool _isLoading = false;
  String? _error;

  List<FortuneAdModel> get ads => _ads;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 노출 우선순위(priority asc, API에서 이미 정렬됨) 중 첫 번째 광고.
  /// 관리자가 광고를 하나도 등록/노출하지 않았다면 null — 호출부는 이 경우
  /// "복주머니 무료 충전" 카드 자체를 숨겨야 한다(§관리자ON/OFF 즉시반영).
  FortuneAdModel? get primaryAd => _ads.isEmpty ? null : _ads.first;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _repository.getAds();
    if (result.success) {
      _ads = result.data!;
    } else {
      _error = result.errorMessage;
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 목록 캐시 중 [adId]에 해당하는 항목을 [updated]로 교체한다(시청 완료 후
  /// "오늘 N/M회" 표시를 즉시 갱신하기 위함 — 재조회 없이 로컬 반영).
  void replaceAd(int adId, FortuneAdModel updated) {
    final idx = _ads.indexWhere((a) => a.id == adId);
    if (idx == -1) return;
    _ads[idx] = updated;
    notifyListeners();
  }

  Future<ApiResult<FortuneAdWatchSession>> startWatch(FortuneAdModel ad) {
    return _repository.start(ad.id);
  }

  Future<ApiResult<FortuneAdRewardResult>> completeWatch({
    required int adId,
    required String sessionId,
    int? watchSeconds,
  }) {
    return _repository.complete(
      adId: adId,
      sessionId: sessionId,
      watchSeconds: watchSeconds,
    );
  }

  Future<ApiResult<FortuneAdModel>> refreshStatus(FortuneAdModel ad) async {
    final result = await _repository.getTodayStatus(ad);
    if (result.success) {
      replaceAd(ad.id, result.data!);
    }
    return result;
  }
}
