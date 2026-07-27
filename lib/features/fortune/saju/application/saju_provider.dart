import 'package:flutter/foundation.dart';
import '../../../../core/utils/load_state.dart';
import '../data/saju_repository.dart';
import '../domain/saju_model.dart';

/// 07단계 §2.1 화면 단위 지역 Provider 예시 - SajuProvider
class SajuProvider extends ChangeNotifier {
  final SajuRepository _repository;
  SajuProvider(this._repository);

  LoadState<SajuResultModel> _state = const LoadState.initial();
  LoadState<SajuResultModel> get state => _state;

  List<SajuResultModel> _history = [];
  List<SajuResultModel> get history => _history;

  String? _birthDate;
  String? _birthTime;
  bool _isLunar = false;
  List<String> _topics = [];
  String? _profileId;
  String? _profileName;

  // [웹→앱 이식] "내 사주함" 프로필 목록 상태
  List<SajuProfileModel> _profiles = [];
  List<SajuProfileModel> get profiles => _profiles;
  bool _profilesLoading = false;
  bool get profilesLoading => _profilesLoading;

  Future<void> requestSaju({
    required String birthDate,
    String? birthTime,
    required bool isLunar,
    required List<String> topics,
    String? profileId,
    String? profileName,
  }) async {
    _birthDate = birthDate;
    _birthTime = birthTime;
    _isLunar = isLunar;
    _topics = topics;
    _profileId = profileId;
    _profileName = profileName;

    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.requestSaju(
      birthDate: birthDate,
      birthTime: birthTime,
      isLunar: isLunar,
      topics: topics,
      profileId: profileId,
      profileName: profileName,
    );

    if (result.success && result.data != null) {
      _state = LoadState.success(result.data!);
    } else {
      _state = LoadState.error(result.errorMessage ?? '사주 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_birthDate == null) return;
    await requestSaju(
      birthDate: _birthDate!,
      birthTime: _birthTime,
      isLunar: _isLunar,
      topics: _topics,
      profileId: _profileId,
      profileName: _profileName,
    );
  }

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = result.data!;
      notifyListeners();
    }
  }

  /// 히스토리 목록에서 특정 결과를 선택해 결과화면 상태로 반영한다.
  /// (히스토리에 없으면 아무 것도 하지 않고 현재 state를 유지 - 방금 생성한 결과를 그대로 보여주는 경우)
  void selectFromHistory(String id) {
    final found = _history.where((e) => e.id == id).toList();
    if (found.isNotEmpty) {
      _state = LoadState.success(found.first);
      notifyListeners();
    }
  }

  // ── [웹→앱 이식] "내 사주함" 프로필 관리 ────────────────────────────
  Future<void> loadProfiles() async {
    _profilesLoading = true;
    notifyListeners();
    final result = await _repository.getProfiles();
    if (result.success && result.data != null) {
      _profiles = result.data!;
    }
    _profilesLoading = false;
    notifyListeners();
  }

  Future<bool> createProfile({
    required String profileName,
    required String name,
    required String gender,
    required String birthDate,
    String? birthTime,
    bool isLunar = false,
    SajuRelationship relationship = SajuRelationship.self,
  }) async {
    final result = await _repository.createProfile(
      profileName: profileName,
      name: name,
      gender: gender,
      birthDate: birthDate,
      birthTime: birthTime,
      isLunar: isLunar,
      relationship: relationship,
    );
    if (result.success) {
      await loadProfiles();
      return true;
    }
    return false;
  }

  Future<bool> updateProfile(SajuProfileModel profile) async {
    final result = await _repository.updateProfile(profile);
    if (result.success) {
      await loadProfiles();
      return true;
    }
    return false;
  }

  Future<void> deleteProfile(String id) async {
    await _repository.deleteProfile(id);
    await loadProfiles();
  }

  Future<void> setPrimaryProfile(String id) async {
    await _repository.setPrimaryProfile(id);
    await loadProfiles();
  }

  /// "내 사주함"에서 프로필을 선택해 즉시 분석 요청
  Future<void> requestSajuFromProfile(
    SajuProfileModel profile, {
    List<String> topics = const ['종합'],
  }) {
    return requestSaju(
      birthDate: profile.birthDate,
      birthTime: profile.birthTime,
      isLunar: profile.isLunar,
      topics: topics,
      profileId: profile.id,
      profileName: profile.profileName,
    );
  }
}
