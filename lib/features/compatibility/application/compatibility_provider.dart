import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/compatibility_repository.dart';
import '../domain/compatibility_model.dart';

/// 06단계 §4.5 `/v1/compatibility` 대응 Provider — admin_web 공개 API 실 연동.
///
/// [실API 전환 - 갭 처리] admin_web에는 "보관(save)"/"공유링크 생성"/"보관 결과 비교"에
/// 대응하는 서버 API가 없다(compatibility_results 스키마에 isSaved/shareUrl 컬럼 없음).
/// `AmuletProvider.equip()`과 동일한 원칙으로, [toggleSave]/[generateShareLink]/[compare]는
/// Repository를 호출하지 않고 클라이언트 로컬 상태([_savedIds]/[_shareUrls])로만 처리한다
/// (앱 재시작 시 초기화된다).
class CompatibilityProvider extends ChangeNotifier {
  final CompatibilityRepository _repository;
  CompatibilityProvider(this._repository);

  LoadState<CompatibilityResultModel> _state = const LoadState.initial();
  LoadState<CompatibilityResultModel> get state => _state;

  List<CompatibilityResultModel> _history = [];
  List<CompatibilityResultModel> get history => _history;

  List<CompatibilityCompareRow> _compareRows = [];
  List<CompatibilityCompareRow> get compareRows => _compareRows;

  // [갭] 서버 미지원 - 클라이언트 로컬 상태(보관 여부/공유링크). 앱 재시작 시 초기화.
  final Set<String> _savedIds = {};
  final Map<String, String> _shareUrls = {};

  String? _birthDateA;
  String? _birthDateB;
  String? _nameA;
  String? _nameB;
  CompatibilityType _type = CompatibilityType.love;

  /// 로컬 보관/공유 상태를 반영해 모델을 보강한다(서버 응답 자체는 isSaved/shareUrl 없음).
  CompatibilityResultModel _applyLocalState(CompatibilityResultModel m) {
    return m.copyWith(
      isSaved: _savedIds.contains(m.id),
      shareUrl: _shareUrls[m.id],
    );
  }

  Future<void> request({
    required String birthDateA,
    required String birthDateB,
    String? nameA,
    String? nameB,
    CompatibilityType type = CompatibilityType.love,
  }) async {
    _birthDateA = birthDateA;
    _birthDateB = birthDateB;
    _nameA = nameA;
    _nameB = nameB;
    _type = type;

    _state = const LoadState.loading();
    notifyListeners();

    final result = await _repository.requestCompatibility(
      birthDateA: birthDateA,
      birthDateB: birthDateB,
      nameA: nameA,
      nameB: nameB,
      type: type,
    );

    if (result.success && result.data != null) {
      _state = LoadState.success(_applyLocalState(result.data!));
    } else {
      _state = LoadState.error(result.errorMessage ?? '궁합 분석에 실패했습니다.');
    }
    notifyListeners();
  }

  Future<void> retry() async {
    if (_birthDateA == null || _birthDateB == null) return;
    await request(
      birthDateA: _birthDateA!,
      birthDateB: _birthDateB!,
      nameA: _nameA,
      nameB: _nameB,
      type: _type,
    );
  }

  Future<void> loadHistory() async {
    final result = await _repository.getHistory();
    if (result.success) {
      _history = (result.data ?? []).map(_applyLocalState).toList();
      notifyListeners();
    }
  }

  Future<void> loadResultById(String id) async {
    _state = const LoadState.loading();
    notifyListeners();
    final result = await _repository.getResultById(id);
    if (result.success && result.data != null) {
      _state = LoadState.success(_applyLocalState(result.data!));
    } else {
      _state = LoadState.error(result.errorMessage ?? '결과를 불러오지 못했습니다.');
    }
    notifyListeners();
  }

  /// [갭 처리] 서버 API 없음 — 클라이언트 로컬 상태로만 보관 여부를 토글한다.
  Future<bool> toggleSave(String id) async {
    if (_savedIds.contains(id)) {
      _savedIds.remove(id);
    } else {
      _savedIds.add(id);
    }
    final isSaved = _savedIds.contains(id);
    _syncCurrentAndHistory(id, isSaved: isSaved);
    notifyListeners();
    return isSaved;
  }

  /// [갭 처리] 서버 API 없음 — 클라이언트에서 결정론적 공유 URL을 생성해 로컬 보관한다.
  Future<String?> generateShareLink(String id) async {
    final url = 'https://fortunefusion.app/share/compat/$id';
    _shareUrls[id] = url;
    _syncCurrentAndHistory(id, shareUrl: url);
    notifyListeners();
    return url;
  }

  /// [갭 처리] 서버 API 없음 — 이미 로드된 [_history](+ 현재 결과)에서 보관된 항목끼리
  /// 항목별 비교표를 클라이언트에서 직접 계산한다.
  Future<bool> compare(List<String> ids) async {
    final pool = <String, CompatibilityResultModel>{};
    for (final h in _history) {
      pool[h.id] = h;
    }
    if (_state.isSuccess) {
      pool[_state.data!.id] = _state.data!;
    }
    final targets = ids
        .map((id) => pool[id])
        .whereType<CompatibilityResultModel>()
        .toList();
    if (targets.length < 2) {
      return false;
    }
    final topics = {for (final t in targets) ...t.topicResults.keys};
    final rows = topics
        .map(
          (topic) => CompatibilityCompareRow(
            topic: topic,
            valueByResultId: {
              for (final t in targets) t.id: t.topicResults[topic] ?? '-',
            },
          ),
        )
        .toList();
    rows.insert(
      0,
      CompatibilityCompareRow(
        topic: '종합점수',
        valueByResultId: {for (final t in targets) t.id: '${t.score}점'},
      ),
    );
    _compareRows = rows;
    notifyListeners();
    return true;
  }

  void _syncCurrentAndHistory(String id, {bool? isSaved, String? shareUrl}) {
    if (_state.isSuccess && _state.data!.id == id) {
      _state = LoadState.success(
        _state.data!.copyWith(isSaved: isSaved, shareUrl: shareUrl),
      );
    }
    final index = _history.indexWhere((r) => r.id == id);
    if (index != -1) {
      _history[index] = _history[index].copyWith(
        isSaved: isSaved,
        shareUrl: shareUrl,
      );
    }
  }
}
