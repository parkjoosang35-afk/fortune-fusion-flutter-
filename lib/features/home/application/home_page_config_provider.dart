import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/home_config_cache_store.dart';
import '../data/page_config_repository.dart';
import '../domain/page_config_model.dart';
import 'section_visibility_evaluator.dart';

/// [메인화면 관리자 편집기] HomePageConfigProvider
///
/// admin_web에서 발행(publish)한 메인 홈 화면 구성을 로드해 전역으로 보관한다.
/// 1) 서버 조회 성공 -> 최신 데이터로 상태 갱신 + HomeConfigCacheStore에 백업.
/// 2) 서버 조회 실패 -> 마지막으로 저장된 캐시를 사용(있으면 usingCache=true).
/// 3) 캐시도 없음 -> state.isError, sections=[] -> 화면(home_screen_cosmic.dart)이
///    기존 정적 레이아웃으로 폴백한다.
class HomePageConfigProvider extends ChangeNotifier {
  final HomePageConfigRepository _repository;
  final HomeConfigCacheStore _cacheStore;
  final SectionVisibilityEvaluator _evaluator;

  HomePageConfigProvider(
    this._repository, {
    HomeConfigCacheStore? cacheStore,
    SectionVisibilityEvaluator? evaluator,
  }) : _cacheStore = cacheStore ?? HomeConfigCacheStore(),
       _evaluator = evaluator ?? const SectionVisibilityEvaluator();

  LoadState<PageConfigData> _state = const LoadState.initial();
  LoadState<PageConfigData> get state => _state;

  /// true면 네트워크가 아닌 로컬 캐시로 채워진 데이터라는 뜻(오프라인 배지 등에 활용 가능).
  bool _usingCache = false;
  bool get usingCache => _usingCache;

  List<PageSectionModel> get rawSections => _state.data?.sections ?? const [];

  /// 원격/캐시 데이터가 전혀 없어 화면이 정적 레이아웃으로 폴백해야 하는 상태.
  bool get shouldFallbackToStatic =>
      _state.isError && (_state.data == null || _state.data!.sections.isEmpty);

  Future<void> load() async {
    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.getHomeConfig();
    if (result.success && result.data != null) {
      _usingCache = false;
      _state = LoadState.success(result.data!);
      // 다음 실패 시를 위해 성공한 최신 구성을 그대로 백업.
      unawaited(_cacheStore.save(result.data!));
      notifyListeners();
      return;
    }

    debugPrint(
      '[HomePageConfigProvider] [load] 서버 조회 실패 -> 캐시 폴백 시도: ${result.errorMessage}',
    );
    final cached = await _cacheStore.load();
    if (cached != null && cached.sections.isNotEmpty) {
      _usingCache = true;
      _state = LoadState.success(cached);
    } else {
      _usingCache = false;
      _state = LoadState.error(
        result.errorMessage ?? '메인화면 구성을 불러오지 못했습니다.',
      );
    }
    notifyListeners();
  }

  Future<void> retry() => load();

  /// 현재 로드된 섹션 중, 주어진 사용자 상태(ctx) 기준으로 실제 노출해야 할
  /// 섹션만 걸러 정렬된 리스트로 반환한다(SectionVisibilityEvaluator 위임).
  List<PageSectionModel> visibleSections(HomeVisibilityContext ctx) {
    return _evaluator.filterVisible(rawSections, ctx);
  }
}
