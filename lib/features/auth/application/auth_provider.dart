import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/auth_repository.dart';
import '../data/grade_repository.dart';
import '../domain/grade_model.dart';
import '../domain/user_model.dart';

/// 07단계 §2.1 앱 루트에 상시 등록되는 전역 Provider
/// Phase2-1: 04A §A-5 `user_grades` 연계 - 로그인/세션복원 시 등급 정보를 함께 로드한다.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  final GradeRepository _gradeRepository;
  AuthProvider(this._repository, [GradeRepository? gradeRepository])
    : _gradeRepository = gradeRepository ?? GradeRepository();

  LoadState<UserModel> _state = const LoadState.initial();
  LoadState<UserModel> get state => _state;

  GradeModel? _currentGrade;
  GradeModel? get currentGrade => _currentGrade;

  /// Wallet 적립 시 사용할 등급 배율(Phase2-1b에서 earn() 호출부에 연결 예정)
  double get pointEarnMultiplier => _currentGrade?.pointEarnMultiplier ?? 1.0;

  bool get isLoggedIn => _state.isSuccess && _state.data != null;
  UserModel? get currentUser => _state.data;

  /// [인트로 전면 개편] 직전 signup() 성공 시 서버가 함께 내려준 회원가입
  /// 보상 정보(`{amount, balanceAfter}` 또는 null). signup_screen.dart의
  /// SignupRewardHandler가 이 값으로 토스트를 띄우고 WalletProvider를 갱신한다.
  Map<String, dynamic>? get lastSignupReward => _repository.lastSignupReward;

  Future<void> _loadGrade(UserModel user) async {
    _currentGrade = await _gradeRepository.getGradeByCode(user.grade);
  }

  Future<void> restoreSession() async {
    _state = const LoadState.loading();
    notifyListeners();
    final user = await _repository.restoreSession();
    if (user != null) {
      await _loadGrade(user);
      _state = LoadState.success(user);
    } else {
      _state = const LoadState.initial();
    }
    notifyListeners();
  }

  /// Phase2-2: 이메일 회원가입(로그인과 분리된 절차)
  Future<bool> signup(String email, String password, String nickname) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.emailSignup(email, password, nickname);
    if (result.success && result.data != null) {
      await _loadGrade(result.data!);
      _state = LoadState.success(result.data!);
      notifyListeners();
      return true;
    }
    _state = LoadState.error(result.errorMessage ?? '회원가입에 실패했습니다.');
    notifyListeners();
    return false;
  }

  Future<bool> login(String email, String password) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.emailLogin(email, password);
    if (result.success && result.data != null) {
      await _loadGrade(result.data!);
      _state = LoadState.success(result.data!);
      notifyListeners();
      return true;
    }
    _state = LoadState.error(result.errorMessage ?? '로그인에 실패했습니다.');
    notifyListeners();
    return false;
  }

  Future<bool> loginWithSocial(String provider) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.socialLogin(provider);
    if (result.success && result.data != null) {
      await _loadGrade(result.data!);
      _state = LoadState.success(result.data!);
      notifyListeners();
      return true;
    }
    _state = LoadState.error(result.errorMessage ?? '로그인에 실패했습니다.');
    notifyListeners();
    return false;
  }

  Future<bool> updateProfile({
    String? birthDate,
    String? birthTime,
    bool? isLunar,
    String? gender,
    String? nickname,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    final updated = user.copyWith(
      birthDate: birthDate,
      birthTime: birthTime,
      isLunar: isLunar,
      gender: gender,
      nickname: nickname,
    );
    final result = await _repository.updateProfile(updated);
    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _repository.logout();
    _state = const LoadState.initial();
    _currentGrade = null;
    notifyListeners();
  }

  /// Phase2-3: 회원탈퇴(소프트삭제) - 02번 §1.1
  Future<bool> withdraw() async {
    final email = currentUser?.email;
    final result = await _repository.withdrawAccount(email);
    if (result.success) {
      _state = const LoadState.initial();
      _currentGrade = null;
      notifyListeners();
      return true;
    }
    return false;
  }
}
