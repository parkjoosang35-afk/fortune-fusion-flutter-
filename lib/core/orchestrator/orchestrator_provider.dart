import 'package:flutter/foundation.dart';

import '../../features/auth/domain/user_model.dart';
import 'cross_check_engine.dart';
import 'fortune_orchestrator.dart';
import 'unified_fortune_profile.dart';

/// [엔진 통합 지시문 STEP 3 §3] 교차검증 화면/CTA가 구독하는 Provider.
///
/// [state management 제약 준수] 지시문이 "provider 6.1.5+1 state
/// management fixed" 라고 명시했으므로, 이 클래스는 기존 전역
/// Provider들(AuthProvider/FaceProvider 등)과 완전히 동일한 패턴
/// (ChangeNotifier + [LoadStatus] 유사 상태 열거)을 그대로 따른다 — 새
/// 상태관리 라이브러리를 도입하지 않는다.
enum OrchestratorStatus { initial, loading, loaded, error }

class OrchestratorProvider extends ChangeNotifier {
  OrchestratorProvider(this._orchestrator);

  final FortuneOrchestrator _orchestrator;

  OrchestratorStatus _status = OrchestratorStatus.initial;
  OrchestratorStatus get status => _status;

  UnifiedFortuneProfile _profile = const UnifiedFortuneProfile();
  UnifiedFortuneProfile get profile => _profile;

  List<CrossCheckResult> _judged = const [];
  List<CrossCheckResult> get judged => _judged;

  List<UnjudgedRule> _unjudged = const [];
  List<UnjudgedRule> get unjudged => _unjudged;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == OrchestratorStatus.loading;

  /// 교차검증 결과 중 conflict 판정이 1건이라도 있는지 — 결과 화면 CTA의
  /// 배지("상충 결과 있음" 등) 노출 여부 판단에 사용 가능.
  bool get hasAnyConflict =>
      _judged.any((r) => r.verdict == CrossCheckVerdict.conflict);

  /// [Stage2 결함수정 패턴 재사용] 로그아웃 시 이전 계정의 교차검증
  /// 결과(사주/타로/관상/손금/궁합 원본 데이터가 응축된 상태)가 잔존해
  /// 다음 계정에 노출되지 않도록 초기화한다.
  void clearOnLogout() {
    _status = OrchestratorStatus.initial;
    _profile = const UnifiedFortuneProfile();
    _judged = const [];
    _unjudged = const [];
    _errorMessage = null;
    notifyListeners();
  }

  /// 5개 문의 최신 결과를 모아 교차검증을 실행한다. 로그인 사용자가
  /// 없어도 호출 가능 — 이 경우 사주만 비어 있고 나머지 문(타로 등)은
  /// 각자의 Repository 이력을 그대로 사용한다(로그인 필요 여부는 각
  /// Repository/HttpAuthGuard가 이미 담당).
  Future<void> load(UserModel? user) async {
    _status = OrchestratorStatus.loading;
    notifyListeners();

    try {
      final result = await _orchestrator.run(user);
      _profile = result.profile;
      _judged = result.judged;
      _unjudged = result.unjudged;
      _status = OrchestratorStatus.loaded;
    } catch (e) {
      debugPrint('[OrchestratorProvider] [load] 예외 -> $e');
      _errorMessage = '교차검증 결과를 불러오지 못했습니다.';
      _status = OrchestratorStatus.error;
    }
    notifyListeners();
  }
}
