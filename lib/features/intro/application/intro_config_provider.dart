import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/intro_config_repository.dart';
import '../domain/intro_config_model.dart';

/// [인트로 전면 개편] admin_web에서 발행한 인트로(첫 진입) 설정을 로드해
/// 전역으로 보관한다. HomePageConfigProvider와 동일한 폴백 철학을 따르되,
/// 로컬 캐시 저장소까지는 필요 없다고 판단해 생략했다(실패 시 하드코딩
/// [IntroConfigModel.fallback]로 즉시 대체 — 인트로는 앱 진입 첫 화면이라
/// 네트워크 지연/실패로 빈 화면을 보여줄 수 없기 때문에 캐시 단계 없이
/// 바로 fallback 상수를 쓰는 편이 더 안전하다).
class IntroConfigProvider extends ChangeNotifier {
  final IntroConfigRepository _repository;

  IntroConfigProvider(this._repository);

  LoadState<IntroConfigModel> _state = const LoadState.initial();
  LoadState<IntroConfigModel> get state => _state;

  /// 서버 설정이 아직 로드되지 않았거나 실패했을 때도 항상 사용 가능한 값을
  /// 반환한다(fallback 포함) — 화면 쪽에서 null 체크 없이 바로 쓸 수 있도록.
  IntroConfigModel get config => _state.data ?? IntroConfigModel.fallback();

  Future<void> load() async {
    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.getIntroConfig();
    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      debugPrint(
        '[IntroConfigProvider] [load] 서버 조회 실패 -> fallback 상수 사용: ${result.errorMessage}',
      );
      _state = LoadState.success(IntroConfigModel.fallback());
    }
    notifyListeners();
  }
}
