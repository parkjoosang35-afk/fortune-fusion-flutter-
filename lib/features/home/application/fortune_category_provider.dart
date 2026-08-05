import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/fortune_category_repository.dart';
import '../domain/fortune_category_model.dart';

/// [운세 카테고리 확장] 전체보기(all_categories_screen.dart) 화면 전역
/// Provider. 관리자(FortuneCategory/FortuneCategoryGroup)에서 설정한
/// 그룹/정렬/노출/추천 여부를 로드해 화면에 전달한다.
///
/// [중요] 이 Provider는 "어떤 카테고리를 어떤 순서로 보여줄지"만 관리하며,
/// 각 카테고리의 실제 운세 결과 생성은 여전히 기존 SajuProvider/
/// TarotProvider/CompatibilityProvider/... 가 담당한다(중복 없음).
class FortuneCategoryProvider extends ChangeNotifier {
  final FortuneCategoryRepository _repository;
  FortuneCategoryProvider(this._repository);

  LoadState<List<FortuneCategoryGroupData>> _state = const LoadState.initial();
  LoadState<List<FortuneCategoryGroupData>> get state => _state;

  List<FortuneCategoryGroupData> get groups => _state.data ?? const [];

  Future<void> load() async {
    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.getGroups();
    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '카테고리 목록을 불러오지 못했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() => load();
}
