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

  /// [복주머니 정책표 §3] 직전 login() 성공 시 서버가 함께 내려준 첫 로그인
  /// 보상 정보(`{amount, balanceAfter}` 또는 null). login_screen.dart가 이 값으로
  /// 토스트를 띄우고 WalletProvider를 갱신한다(signup 패턴과 동일).
  Map<String, dynamic>? get lastFirstLoginReward =>
      _repository.lastFirstLoginReward;

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
  /// [6-7-4-B-4] 이용약관/개인정보처리방침 동의는 회원가입의 필수 요건이므로
  /// SignupScreen의 체크박스 상태를 그대로 전달받아 Repository로 넘긴다.
  Future<bool> signup(
    String email,
    String password,
    String nickname, {
    required bool termsAgreed,
    required bool privacyAgreed,
  }) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.emailSignup(
      email,
      password,
      nickname,
      termsAgreed: termsAgreed,
      privacyAgreed: privacyAgreed,
    );
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

  Future<bool> loginWithSocial(String provider, String accessToken) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.socialLogin(provider, accessToken);
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
    bool? isLeapMonth,
    bool? birthTimeUnknown,
    String? birthPlace,
    String? gender,
    String? nickname,
  }) async {
    final user = currentUser;
    if (user == null) return false;
    final updated = user.copyWith(
      birthDate: birthDate,
      birthTime: birthTime,
      isLunar: isLunar,
      isLeapMonth: isLeapMonth,
      birthTimeUnknown: birthTimeUnknown,
      birthPlace: birthPlace,
      gender: gender,
      nickname: nickname,
    );
    final result = await _repository.updateProfile(updated);
    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
      _lastProfileUpdateError = null;
      notifyListeners();
      return true;
    }
    // [버그 수정 — 프로필 저장 실패 방치] 이전에는 실패해도 아무 상태 변화가
    // 없어(그리고 호출부도 반환값을 확인하지 않아) 실패 원인을 사용자에게
    // 보여줄 방법이 없었다. isLoggedIn은 `_state.isSuccess` 기준이므로 여기서
    // `_state`를 error로 바꾸면 로그인 자체가 풀린 것처럼 보이는 부작용이
    // 생긴다 — 그래서 로그인 상태(`_state`)는 그대로 유지하고, 별도의
    // 경량 필드에만 실패 메시지를 보관한다.
    _lastProfileUpdateError = result.errorMessage ?? '프로필 수정에 실패했습니다.';
    notifyListeners();
    return false;
  }

  /// 직전 [updateProfile] 호출이 실패했을 때의 서버 에러 메시지(성공 시 null).
  String? _lastProfileUpdateError;
  String? get lastProfileUpdateError => _lastProfileUpdateError;

  Future<void> logout() async {
    await _repository.logout();
    _state = const LoadState.initial();
    _currentGrade = null;
    notifyListeners();
  }

  /// [Phase C - 웰컴 리워드 팝업 1회성 노출] WelcomeRewardModal CTA 탭 시 호출.
  /// 서버에 클레임을 기록하는 동시에, 현재 세션의 UserModel도 즉시 갱신해
  /// (재조회 없이) `welcomeGiftClaimed == true`가 바로 반영되도록 한다.
  Future<void> claimWelcomeGift() async {
    final user = currentUser;
    if (user == null || user.welcomeGiftClaimed) return;
    _state = LoadState.success(user.copyWith(welcomeGiftClaimed: true));
    notifyListeners();
    await _repository.claimWelcomeGift();
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
