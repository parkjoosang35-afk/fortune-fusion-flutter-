// 신통방통 - 정통사주 v3 Provider (ChangeNotifier 기반)
//
// [2차 지시서 - 옵션 2] 엔진 킷의 jeontong_v3_providers.dart(riverpod 기반)를
// 앱의 실제 상태관리 패턴(ChangeNotifier + LoadState<T>, 07단계 §2.1 표준)으로
// 재작성한 버전. 원본의 5개 provider(sajuApiBaseUrlProvider·freePassTokenProvider·
// sajuApiClientProvider·jeontong69CategoriesProvider·sajuAll69Provider)가 하던
// 역할을 이 클래스 하나에서 담당한다:
//   - baseUrl 주입은 생성자에서 [EnvConfig.adminApiBaseUrl] 계열 값을 받는다
//     (이 파일 자체에는 절대 하드코딩하지 않는다 - 2차 지시서 명시 사항).
//   - freePassToken은 상태로 보관하고 setter로 갱신한다.
//   - 카테고리 목록 / 69종 결과 / AI 해석 결과를 각각 LoadState<T>로 노출한다.
import 'package:flutter/foundation.dart';

import '../../../../core/utils/load_state.dart';
import '../data/saju_v3_api.dart';
import '../domain/birth_input.dart';
import '../domain/category_item.dart';
import '../domain/interpretation_result.dart';
import '../domain/narrative_result.dart';
import '../domain/saju_report.dart';
import '../domain/saju_result_v3.dart';

/// 카테고리 코드 그룹 메타 (69종 목록 화면 섹셔닝용)
/// — 엔진 킷 jeontong_v3_providers.dart의 kJt3Groups를 그대로 이식.
const Map<String, (String, List<String>)> kJt3Groups = {
  'A': (
    '평생운',
    [
      'A01',
      'A02',
      'A03',
      'A04',
      'A05',
      'A06',
      'A07',
      'A08',
      'A09',
      'A10',
    ],
  ),
  'B': (
    '대운',
    [
      'B01',
      'B02',
      'B03',
      'B04',
      'B05',
      'B06',
      'B07',
      'B08',
      'B09',
      'B10',
    ],
  ),
  'C': (
    '세운 · 올해',
    [
      'C01',
      'C02',
      'C03',
      'C04',
      'C05',
      'C06',
      'C07',
      'C08',
      'C09',
      'C10',
    ],
  ),
  'D': (
    '이달 · 오늘',
    [
      'D01',
      'D02',
      'D03',
      'D04',
      'D05',
      'D06',
      'D07',
      'D08',
      'D09',
      'D10',
    ],
  ),
  'E': ('궁합', ['E08', 'E09', 'E10']),
  'F': (
    '특수 주제',
    [
      'F01',
      'F02',
      'F03',
      'F04',
      'F05',
      'F06',
      'F07',
      'F08',
      'F09',
      'F10',
    ],
  ),
  'G': (
    '건강',
    ['G01', 'G02', 'G03', 'G04', 'G05', 'G06', 'G07', 'G08', 'G10'],
  ),
  'H': (
    '개운 · 풍수',
    ['H01', 'H02', 'H03', 'H04', 'H05', 'H07', 'H10'],
  ),
};

/// 정통사주 v3(69종 서버 실계산) 전용 ChangeNotifier.
///
/// [app.dart 등록 예]
/// ```dart
/// ChangeNotifierProvider(
///   create: (_) => SajuV3Provider(
///     SajuV3Api(
///       baseUrl: '${EnvConfig.adminApiBaseUrl}/saju/v3',
///       freePassProvider: () => null, // TODO: 인증 브릿지 확정 후 실 토큰 연결
///     ),
///   ),
/// ),
/// ```
class SajuV3Provider extends ChangeNotifier {
  final SajuV3Api _api;
  SajuV3Provider(this._api);

  // ── 프리패스 토큰 (임시 브릿지 - 완료 보고서에 기재된 인증 불일치 이슈) ──
  String? _freePassToken;
  String? get freePassToken => _freePassToken;
  void setFreePassToken(String? token) {
    _freePassToken = token;
    notifyListeners();
  }

  // ── 생년월일시 입력 상태 (원본 birthInputProvider 대응) ──
  BirthInput? _birthInput;
  BirthInput? get birthInput => _birthInput;
  void setBirthInput(BirthInput input) {
    _birthInput = input;
    notifyListeners();
  }

  // ── 야자시 정책 (원본 zihourPolicyProvider 대응, 승인 기본값 traditional) ──
  String _zihourPolicy = 'traditional';
  String get zihourPolicy => _zihourPolicy;
  void setZihourPolicy(String policy) {
    _zihourPolicy = policy;
    notifyListeners();
  }

  // ── 69종 카테고리 목록 (공개 엔드포인트) ──
  LoadState<List<CategoryItem>> _categoriesState = const LoadState.initial();
  LoadState<List<CategoryItem>> get categoriesState => _categoriesState;

  Future<void> loadCategories() async {
    _categoriesState = const LoadState.loading();
    notifyListeners();
    try {
      final list = await _api.getCategoriesV3();
      _categoriesState = LoadState.success(list);
    } on SajuV3ApiException catch (e) {
      _categoriesState = LoadState.error(e.message);
    } catch (e) {
      _categoriesState = LoadState.error('목록을 불러올 수 없습니다: $e');
    }
    notifyListeners();
  }

  // ── L1+L2 (팩트 + 69종 전체) ──
  LoadState<SajuAll69> _all69State = const LoadState.initial();
  LoadState<SajuAll69> get all69State => _all69State;

  Future<void> loadAll69(BirthInput birth) async {
    _birthInput = birth;
    _all69State = const LoadState.loading();
    notifyListeners();
    try {
      final result = await _api.getSajuV3Categories69(
        birth,
        zihourPolicy: _zihourPolicy,
      );
      _all69State = LoadState.success(result);
    } on SajuV3ApiException catch (e) {
      _all69State = LoadState.error(e.message);
    } catch (e) {
      _all69State = LoadState.error('사주 계산 결과를 불러올 수 없습니다: $e');
    }
    notifyListeners();
  }

  Future<void> retryAll69() async {
    if (_birthInput == null) return;
    await loadAll69(_birthInput!);
  }

  /// 이미 로드된 all69State에서 특정 카테고리 결과를 꺼낸다(재요청 없음).
  CategoryResultV3? categoryOf(String code) {
    final all = _all69State.data;
    if (all == null) return null;
    return all.items[code];
  }

  // ── AI 해석 (v3.1+, 카테고리별 캐시) ──
  final Map<String, LoadState<InterpretationResult>> _interpretStates = {};
  LoadState<InterpretationResult> interpretStateOf(String categoryCode) {
    return _interpretStates[categoryCode] ?? const LoadState.initial();
  }

  Future<void> loadInterpretation(String categoryCode) async {
    final birth = _birthInput;
    if (birth == null) {
      _interpretStates[categoryCode] = const LoadState.error('생년월일시 정보가 없습니다.');
      notifyListeners();
      return;
    }
    _interpretStates[categoryCode] = const LoadState.loading();
    notifyListeners();
    try {
      final result = await _api.getSajuV3Interpret(
        birth,
        categoryCode: categoryCode,
        zihourPolicy: _zihourPolicy,
      );
      _interpretStates[categoryCode] = LoadState.success(result);
    } on SajuV3ApiException catch (e) {
      _interpretStates[categoryCode] = LoadState.error(e.message);
    } catch (e) {
      _interpretStates[categoryCode] = LoadState.error('AI 해석을 불러올 수 없습니다: $e');
    }
    notifyListeners();
  }

  Future<void> retryInterpretation(String categoryCode) =>
      loadInterpretation(categoryCode);

  // ── [69종 AI 해석 전면 재설계] 서사형(줄글) 해석, 카테고리별 캐시 ──
  // 기존 _interpretStates(4블록 카드형)와 완전히 별개의 캐시다 — 같은
  // categoryCode라도 두 엔드포인트(/interpret, /narrative)는 다른 결과를
  // 반환하므로 절대 공유하지 않는다.
  final Map<String, LoadState<NarrativeResult>> _narrativeStates = {};
  LoadState<NarrativeResult> narrativeStateOf(String categoryCode) {
    return _narrativeStates[categoryCode] ?? const LoadState.initial();
  }

  Future<void> loadNarrative(String categoryCode, {String question = ''}) async {
    final birth = _birthInput;
    if (birth == null) {
      _narrativeStates[categoryCode] = const LoadState.error('생년월일시 정보가 없습니다.');
      notifyListeners();
      return;
    }
    _narrativeStates[categoryCode] = const LoadState.loading();
    notifyListeners();
    try {
      final result = await _api.getSajuV3Narrative(
        birth,
        categoryCode: categoryCode,
        question: question,
        zihourPolicy: _zihourPolicy,
      );
      _narrativeStates[categoryCode] = LoadState.success(result);
    } on SajuV3ApiException catch (e) {
      _narrativeStates[categoryCode] = LoadState.error(e.message);
    } catch (e) {
      _narrativeStates[categoryCode] = LoadState.error('AI 해석을 불러올 수 없습니다: $e');
    }
    notifyListeners();
  }

  Future<void> retryNarrative(String categoryCode) => loadNarrative(categoryCode);

  // ── [5차 지시서] AI 정통사주 해석 엔진 v1.0 — 9 PART 장문 리포트 ──
  // 질문 문구별로 결과가 달라질 수 있어(§5 표현 개인화), 질문 텍스트를 키로
  // 캐시한다. 동일 질문 재요청은 서버 idempotency 캐시(source=cache)로도
  // 보호되지만, 클라이언트에서도 불필요한 재조회를 막기 위해 함께 캐시한다.
  final Map<String, LoadState<SajuReportResult>> _reportStates = {};
  String _lastReportQuestion = '';
  String get lastReportQuestion => _lastReportQuestion;

  LoadState<SajuReportResult> reportStateOf(String question) {
    return _reportStates[question] ?? const LoadState.initial();
  }

  Future<void> loadReport(String question) async {
    final birth = _birthInput;
    _lastReportQuestion = question;
    if (birth == null) {
      _reportStates[question] = const LoadState.error('생년월일시 정보가 없습니다.');
      notifyListeners();
      return;
    }
    _reportStates[question] = const LoadState.loading();
    notifyListeners();
    try {
      final result = await _api.getSajuV3Report(
        birth,
        question: question,
        zihourPolicy: _zihourPolicy,
      );
      _reportStates[question] = LoadState.success(result);
    } on SajuV3ApiException catch (e) {
      // 402(프리패스 필요)·429(rate limit)·네트워크 오류를 구분해 안내할 수
      // 있도록 메시지에 상태 정보를 실어 보낸다(화면에서 e.message 그대로 노출).
      _reportStates[question] = LoadState.error(e.message);
    } catch (e) {
      _reportStates[question] = LoadState.error('리포트를 불러올 수 없습니다: $e');
    }
    notifyListeners();
  }

  Future<void> retryReport() => loadReport(_lastReportQuestion);

  /// 로그아웃 시 개인정보(생년월일시·계산 결과) 잔존 방지 — SajuProvider의
  /// clearOnLogout()과 동일한 취지.
  void clearOnLogout() {
    _birthInput = null;
    _categoriesState = const LoadState.initial();
    _all69State = const LoadState.initial();
    _interpretStates.clear();
    _narrativeStates.clear();
    _reportStates.clear();
    _lastReportQuestion = '';
    _freePassToken = null;
    notifyListeners();
  }
}
