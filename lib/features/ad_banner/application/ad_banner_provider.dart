import 'package:flutter/foundation.dart';
import '../data/ad_banner_repository.dart';
import '../domain/ad_banner_model.dart';

/// CMS 제휴광고 배너 상태관리 Provider.
///
/// position별로 결과를 캐싱해, 홈 화면의 여러 배너 슬롯(home_top/home_middle/home_bottom)이
/// 각각 독립적으로 로딩 상태를 가질 수 있게 한다.
class AdBannerProvider extends ChangeNotifier {
  final AdBannerRepository _repository;
  AdBannerProvider(this._repository);

  final Map<String, List<AdBannerModel>> _bannersByPosition = {};
  final Map<String, bool> _loadingByPosition = {};
  final Map<String, String?> _errorByPosition = {};
  // [운세 앱 개발 프롬프트-Task1] 각 position에 대해 최초 load()가
  // "완료"(성공/실패 무관)되었는지 여부. 홈 화면이 "아직 로딩 중인지"와
  // "확정적으로 광고가 없는지"를 구분해 동적 레이아웃(간격 축소 등)에 활용한다.
  final Set<String> _loadedPositions = {};

  List<AdBannerModel> bannersFor(String position) =>
      _bannersByPosition[position] ?? const [];
  bool isLoading(String position) => _loadingByPosition[position] ?? false;
  String? errorFor(String position) => _errorByPosition[position];

  /// 해당 position에 최초 load()가 (성공/실패 무관) 한 번이라도 완료되었는지.
  bool hasLoaded(String position) => _loadedPositions.contains(position);

  /// 해당 position에 현재 노출 가능한(활성/기간내) 광고 배너가 1건 이상 있는지.
  /// 홈 화면 등에서 "광고 있음/없음"에 따라 레이아웃을 동적으로 조정할 때 사용한다.
  bool hasActiveBanner(String position) => bannersFor(position).isNotEmpty;

  Future<void> load(String position) async {
    debugPrint('[AdBannerProvider] load() 호출 -> position=$position');
    _loadingByPosition[position] = true;
    _errorByPosition[position] = null;
    notifyListeners();

    final result = await _repository.getActiveBanners(position: position);

    if (result.success) {
      _bannersByPosition[position] = result.data ?? [];
      debugPrint(
        '[AdBannerProvider] load() 성공 -> position=$position, '
        '${_bannersByPosition[position]!.length}건 반영',
      );
    } else {
      _errorByPosition[position] = result.errorMessage;
      debugPrint(
        '[AdBannerProvider] load() 실패 -> position=$position, error=${result.errorMessage}',
      );
    }
    _loadingByPosition[position] = false;
    _loadedPositions.add(position);
    notifyListeners();
  }

  /// 여러 position을 한 번에 병렬 로드(홈 화면 진입 시 광고 상태를 미리 파악해
  /// 동적 레이아웃 결정에 사용할 수 있도록 함).
  Future<void> loadPositions(List<String> positions) async {
    await Future.wait(positions.map(load));
  }
}
