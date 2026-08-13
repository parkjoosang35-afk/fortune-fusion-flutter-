import 'package:flutter/foundation.dart';
import '../../../../core/telemetry/ai_call_counter.dart';
import '../../../../core/utils/load_state.dart';
import '../../../home/domain/fortune_matrix.dart';
import '../../shared/domain/fortune_report_model.dart';
import '../../generic/domain/generic_fortune_report_builder.dart';
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

  // [사주정보 이름 필드 보완] 결과/재시도(retry)에도 이름이 그대로 유지되도록
  // 요청 시 전달받은 이름을 상태로 보관한다.
  String? _name;
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
    required String name,
    required String birthDate,
    String? birthTime,
    required bool isLunar,
    required List<String> topics,
    String? profileId,
    String? profileName,
  }) async {
    _name = name;
    _birthDate = birthDate;
    _birthTime = birthTime;
    _isLunar = isLunar;
    _topics = topics;
    _profileId = profileId;
    _profileName = profileName;

    _state = const LoadState.loading();
    notifyListeners();

    // [AI 사주 호출 점진 전환] SajuRepository는 단 한 줄도 수정하지 않고,
    // 이 진입점(SajuProvider.requestSaju - 모든 호출 지점이 결국 여기를
    // 거친다)에서만 분기한다. flag가 true면 기존과 완전히 동일하게 실
    // LLM(admin_web `/api/public/fortune/saju`)을 호출하고, false면 정통사주
    // 80종과 동일한 룰 기반 생성기([GenericFortuneReportBuilder])로 우회한다.
    if (AiCallCounter.isGatePassed()) {
      final result = await _repository.requestSaju(
        name: name,
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
    } else {
      // [정통사주 룰 기반 우회 - 신규 모델 없이 기존 생성기 재사용]
      // CategoriesGridScreen(80종 전체 보기)의 공용 결과 화면이 이미 쓰고
      // 있는 [GenericFortuneReportBuilder] + [FortuneMatrix]를 그대로
      // 사용해 SajuResultModel을 채운다(신규 결과 모델 작성 없음).
      final ruleResult = _buildRuleBasedResult(
        name: name,
        topics: topics,
        profileId: profileId,
        profileName: profileName,
      );
      _state = LoadState.success(ruleResult);
    }
    notifyListeners();
  }

  /// [정통사주 룰 기반 우회 전용 헬퍼] 실 LLM 호출 없이, 이미 동시 가동
  /// 중인 [GenericFortuneReportBuilder](정통사주 80종 공용 결과 화면과 동일
  /// 생성기)로 [SajuResultModel]을 구성한다.
  ///
  /// [명식(사주 4주) 관련 주의] 이 우회 경로는 서버의 결정론적 명식 계산을
  /// 거치지 않으므로, 실제 간지를 만들어내지 않고 자리표시 값('—')만
  /// 채운다(잘못된 사주 정보를 지어내지 않기 위한 의도적 처리 — 화면
  /// 표시는 깨지지 않도록 null이 아닌 문자열만 사용한다).
  SajuResultModel _buildRuleBasedResult({
    required String name,
    required List<String> topics,
    String? profileId,
    String? profileName,
  }) {
    final now = DateTime.now();
    final effectiveTopics = topics.isEmpty ? const ['종합'] : topics;

    final topicResults = <String, String>{};
    for (final topic in effectiveTopics) {
      final entryId = _topicToSajuEntryId[topic] ?? 'S-001';
      final entry = FortuneMatrix.byId(entryId) ?? FortuneMatrix.byId('S-001');
      if (entry == null) continue;
      final report = GenericFortuneReportBuilder.build(entry, date: now);
      final overview = report.sectionsOfType<OverviewSection>();
      topicResults[topic] = overview.isNotEmpty
          ? overview.first.body
          : report.hero.headline;
    }

    final summaryEntry = FortuneMatrix.byId('S-001');
    final summaryHeadline = summaryEntry != null
        ? GenericFortuneReportBuilder.build(summaryEntry, date: now).hero.headline
        : '$name님의 사주 흐름을 정리했어요.';

    return SajuResultModel(
      id: 'rule_${now.millisecondsSinceEpoch}',
      name: name,
      pillars: const SajuPillars(year: '—', month: '—', day: '—'),
      fiveElements: const {},
      topicResults: topicResults,
      summary: summaryHeadline,
      createdAt: now,
      profileId: profileId,
      profileName: profileName,
    );
  }

  /// 사주 입력 화면의 topic 문자열('재물'/'애정'/'건강'/'월별')을 정통사주
  /// 80종 매트릭스의 S그룹 엔트리 id로 매핑한다(없으면 'S-001' 종합으로
  /// 폴백). [FortuneMatrix]는 신규 화면(categories_grid_screen)과 완전히
  /// 동일한 단일 소스를 그대로 재사용한다.
  static const Map<String, String> _topicToSajuEntryId = {
    '재물': 'S-002',
    '애정': 'S-003',
    '건강': 'S-004',
    '월별': 'S-005',
  };

  Future<void> retry() async {
    if (_birthDate == null) return;
    await requestSaju(
      name: _name ?? '게스트',
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
      name: profile.name,
      birthDate: profile.birthDate,
      birthTime: profile.birthTime,
      isLunar: profile.isLunar,
      topics: topics,
      profileId: profile.id,
      profileName: profile.profileName,
    );
  }
}
