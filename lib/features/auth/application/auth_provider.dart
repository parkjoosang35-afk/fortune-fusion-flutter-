import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

/// 07단계 §2.1 앱 루트에 상시 등록되는 전역 Provider
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;
  AuthProvider(this._repository);

  LoadState<UserModel> _state = const LoadState.initial();
  LoadState<UserModel> get state => _state;

  bool get isLoggedIn => _state.isSuccess && _state.data != null;
  UserModel? get currentUser => _state.data;

  Future<void> restoreSession() async {
    _state = const LoadState.loading();
    notifyListeners();
    final user = await _repository.restoreSession();
    if (user != null) {
      _state = LoadState.success(user);
    } else {
      _state = const LoadState.initial();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.emailLogin(email, password);
    if (result.success && result.data != null) {
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
    notifyListeners();
  }
}
