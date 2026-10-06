import 'package:flutter/foundation.dart';
import '../../../core/utils/load_state.dart';
import '../data/saju_renewal_api.dart';
import '../data/models/topic_card.dart';
import '../data/models/interpret_result.dart';

/// [신통방통 정통사주 리뉴얼 — STEP 6.5] 화면 전환만으로 데이터를 임시
/// 전달하지 않도록(지시서 §상태관리 요구사항), 사용자 흐름 전체를 명확한
/// 상태 enum + 모델로 관리하는 전역 Provider.
///
/// 흐름: birthInput → calculating → factsReady(topics 조회 완료) →
/// firstTopic 노출 → storyPreview(summary interpret) → accessRequired
/// (Access Gate) → interpreting(detail interpret) → storyDetail →
/// moreTopics(다른 사주 이야기 후보) → (다시 storyPreview로 순환) → error.
///
/// [계정 격리 원칙] 이 Provider는 어떤 사용자 식별자도 직접 들고 있지
/// 않는다 — 모든 API 호출은 SajuRenewalApi가 AuthTokenStore의 현재
/// 로그인 사용자 기준으로만 수행하므로, 로그아웃 시 [clearOnLogout]으로
/// 메모리 상태만 지우면 사용자간 데이터가 섞일 수 없다.
enum SajuRenewalFlowStatus {
  /// 아직 아무 동작도 시작하지 않은 초기 상태(화면① 메인 "내 사주
  /// 분석하기" 버튼을 누르기 전).
  idle,

  /// 화면② 출생정보 입력 단계(서버에 아직 요청 없음, 로컬 입력폼 상태).
  birthInput,

  /// 화면③ 계산중 — AuthProvider.updateProfile() 저장 완료 후
  /// topics/select 서버 응답을 기다리는 중(실제 FACT 계산/캐시/Topic
  /// 선택이 끝날 때까지 — 단순 타이머가 아님).
  calculating,

  /// topics/select 성공 — first_topic/candidates/key_facts 확보됨
  /// (화면④ 분석 완료 단계로 바로 이어짐).
  factsReady,

  /// 화면⑤ 이야기 미리보기 — interpret(mode=summary) 응답 대기/완료.
  storyPreview,

  /// 화면⑥ Access Gate 표시/대기 중(ResultAccessGateSheet).
  accessRequired,

  /// Access Gate 통과 후 interpret(mode=detail) 호출 중.
  interpreting,

  /// 화면⑦ 상세 사주 이야기 노출 완료.
  storyDetail,

  /// 화면⑧ 다른 사주 이야기 후보 목록 노출(candidates에서 선택 대기).
  moreTopics,

  /// 서버오류/네트워크오류 등 — errorMessage 참고.
  error,
}

class SajuRenewalProvider extends ChangeNotifier {
  SajuRenewalProvider(this._api);

  final SajuRenewalApi _api;

  SajuRenewalFlowStatus _status = SajuRenewalFlowStatus.idle;
  SajuRenewalFlowStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// 네트워크 오류("재시도 버튼")와 서버 논리 오류(reason 있음)를
  /// 화면단에서 구분해 안내하기 위한 서버 reason 코드(예:
  /// BIRTH_INFO_REQUIRED, TOPIC_CONDITION_NOT_SATISFIED 등).
  String? _errorReason;
  String? get errorReason => _errorReason;

  /// topics/select 결과(화면④~⑧ 전체에서 공유).
  LoadState<TopicsSelectResult> _topicsState = const LoadState.initial();
  LoadState<TopicsSelectResult> get topicsState => _topicsState;

  /// 현재 사용자가 보고 있는 topic(처음엔 first_topic, "다른 사주
  /// 이야기"에서 교체될 수 있음).
  TopicCard? _currentTopic;
  TopicCard? get currentTopic => _currentTopic;

  /// mode=summary 결과(화면⑤).
  LoadState<InterpretSummaryResult> _previewState = const LoadState.initial();
  LoadState<InterpretSummaryResult> get previewState => _previewState;

  /// mode=detail 결과(화면⑦).
  LoadState<InterpretDetailResult> _detailState = const LoadState.initial();
  LoadState<InterpretDetailResult> get detailState => _detailState;

  /// 이번 세션에서 이미 상세보기까지 완료한 topic_id 집합 — "다른 사주
  /// 이야기" 후보 재조회 시 exclude_topic_ids로 서버에 전달해 Exposure
  /// History 정책(이미 본 이야기 재노출 방지)과 정합을 맞춘다. 서버가
  /// 최종 판단을 내리므로 이 목록은 "다음 조회에 참고로 보내는 값"일
  /// 뿐이며, Flutter가 임의로 후보를 걸러내지 않는다.
  final Set<String> _viewedTopicIds = {};

  /// [버그 수정 — C-08a(docs/08) 결함 발견] docs/03_화면명세.md §08
  /// "후보 = 받은 후보 − 이미 본 주제(세션 + 노출 이력). 표시 3장" 및
  /// docs/13_기획결정_서명지.md Q-06 최종 확정값("기본 3장, 후보 4개
  /// 이상이면 4장 허용 안 함" — "회신 없으면 권고안으로 확정"되는
  /// 최종 요약 문서이므로 이 값이 03의 "4장 허용" 초안보다 우선한다).
  /// 기존 코드는 `topicsState.data.candidates`를 필터링·개수 제한
  /// 없이 그대로 노출해, 이미 상세까지 본 주제가 08에 다시 나타나고
  /// 4개 이상이 표시될 수 있던 결함. 시기형 최대 1개 보장은 서버
  /// 책임(API 계약서 §2 "candidates: is_timing=true 최대 1개")이므로
  /// 재필터링하지 않는다(Flutter 임의 판단 금지 원칙).
  List<TopicCard> get displayableCandidates {
    final raw = _topicsState.data?.candidates ?? const <TopicCard>[];
    final remaining = raw
        .where((c) => !_viewedTopicIds.contains(c.topicId))
        .toList();
    return remaining.take(3).toList();
  }

  /// [중복 클릭 방어] summary/detail 요청이 진행 중인 동안 동일 요청이
  /// 중첩 실행되지 않도록 가드한다(§ "중복클릭" 요구사항 — 중복 LLM
  /// 호출/중복 Topic 기록 방지. 서버도 멱등 캐시로 이중 방어하지만,
  /// Flutter 쪽에서도 버튼 disable의 근거 상태를 제공한다).
  bool _isPreviewLoading = false;
  bool get isPreviewLoading => _isPreviewLoading;
  bool _isDetailLoading = false;
  bool get isDetailLoading => _isDetailLoading;
  bool _isTopicsLoading = false;
  bool get isTopicsLoading => _isTopicsLoading;

  /// [화면⑤/⑨ 다크 핸드오프 표시용] 지금까지 상세까지 완료한 이야기
  /// 수를 그대로 노출한다(0부터 시작, 화면에서는 +1하여 "N번째"로 씀).
  /// 서버 판단을 Flutter가 대체하지 않는다 — 단순 카운터 getter일 뿐,
  /// [_viewedTopicIds] 자체의 용도(Exposure History exclude 참고 목록)는
  /// 그대로 유지된다.
  int get viewedStoryCount => _viewedTopicIds.length;

  /// [버그 수정 — C-05c(docs/08) 미구현 발견] docs/03_화면명세.md §05
  /// "해제됨(05-C) | Primary [자세히 보기] → 07 직행(게이트 없음)" 및
  /// 원본 `design_files/saju/screens-b.jsx` `ScreenPreview`의
  /// `unlocked = app.unlocked.includes(app.topicId)` 분기를 그대로
  /// 재현한다. 이 세션에서 이미 상세까지 완료한 topic(=
  /// [_viewedTopicIds])이면 "해제됨" 상태로 간주해 05 화면이 게이트
  /// 없이 바로 07로 보낼 수 있게 한다(C-06e "같은 주제 재열람 시
  /// 게이트가 다시 뜨지 않는다"와 동일한 근거 데이터를 공유).
  bool isTopicUnlocked(String topicId) => _viewedTopicIds.contains(topicId);

  void _setStatus(SajuRenewalFlowStatus next) {
    _status = next;
    notifyListeners();
  }

  /// 화면② "입력완료" 버튼을 누른 뒤(=AuthProvider.updateProfile()로
  /// 서버 프로필 저장까지 완료한 뒤) 호출한다. 이 메서드 자체는 프로필
  /// 저장을 하지 않는다 — 그 책임은 AuthProvider에 있고, 호출부(화면②)가
  /// 반드시 updateProfile() 성공을 먼저 확인한 뒤 이 메서드를 호출해야
  /// 한다(§ "출생정보 입력" 요구사항 — 생년월일을 요청바디로 보내지 않고
  /// 서버 프로필에서 조회하는 API 설계와 정합).
  Future<void> startCalculating() async {
    _status = SajuRenewalFlowStatus.calculating;
    _errorMessage = null;
    _errorReason = null;
    notifyListeners();
    await _loadTopics();
  }

  /// 화면⑧ "다른 사주 이야기" — 현재까지 본 topic을 제외하고 새 후보를
  /// 다시 조회한다. 서버의 Exposure History 정책을 그대로 신뢰하며,
  /// Flutter는 "이미 상세까지 본 topic_id"만 참고로 추가 제외 요청한다.
  Future<void> loadMoreTopics() async {
    _setStatus(SajuRenewalFlowStatus.calculating);
    await _loadTopics(excludeExtra: _viewedTopicIds.toList());
  }

  Future<void> _loadTopics({List<String> excludeExtra = const []}) async {
    if (_isTopicsLoading) return;
    _isTopicsLoading = true;
    _topicsState = const LoadState.loading();
    notifyListeners();

    final result = await _api.selectTopics(
      excludeTopicIds: excludeExtra.isEmpty ? null : excludeExtra,
    );
    _isTopicsLoading = false;

    if (!result.success) {
      _topicsState = LoadState.error(
        result.errorMessage ?? '사주 이야기를 불러오지 못했습니다.',
      );
      _errorMessage = _friendlyErrorMessage(
        result.errorCode,
        result.errorMessage,
      );
      _errorReason = result.errorCode;
      _status = SajuRenewalFlowStatus.error;
      notifyListeners();
      return;
    }

    final data = result.data!;
    _topicsState = LoadState.success(data);
    _currentTopic = data.firstTopic;
    _status = SajuRenewalFlowStatus.factsReady;
    notifyListeners();

    // 화면④(분석 완료)는 제목만 보여주고, 곧바로 화면⑤ 미리보기를 위해
    // summary interpret을 이어서 호출한다(지시서 §흐름 — "분석완료→첫
    // 이야기미리보기"가 자연스럽게 이어져야 함).
    await loadPreview(data.firstTopic);
  }

  /// 화면⑤ 이야기 미리보기 — 지정된 topic으로 summary interpret을
  /// 호출한다. "다른 사주 이야기" 선택 시에도 동일하게 재사용한다.
  Future<void> loadPreview(TopicCard topic) async {
    if (_isPreviewLoading) return;
    _isPreviewLoading = true;
    _currentTopic = topic;
    _previewState = const LoadState.loading();
    notifyListeners();

    final result = await _api.interpretSummary(
      topicId: topic.topicId,
      evidenceFactKeys: topic.evidenceFactKeys,
    );
    _isPreviewLoading = false;

    if (!result.success) {
      _previewState = LoadState.error(
        result.errorMessage ?? '이야기를 불러오지 못했습니다.',
      );
      _errorMessage = _friendlyErrorMessage(
        result.errorCode,
        result.errorMessage,
      );
      _errorReason = result.errorCode;
      _status = SajuRenewalFlowStatus.error;
      notifyListeners();
      return;
    }

    _previewState = LoadState.success(result.data!);
    _status = SajuRenewalFlowStatus.storyPreview;
    notifyListeners();
  }

  /// 화면⑤ "자세히보기" 버튼 — Access Gate를 띄우기 전 상태 전환만
  /// 담당한다(실제 Gate UI는 화면 위젯이 ResultAccessGateSheet를 직접
  /// 호출 — 이 Provider는 Gate 결과를 받은 뒤 [onAccessGranted]로
  /// 이어받는다).
  void requestAccess() {
    _setStatus(SajuRenewalFlowStatus.accessRequired);
  }

  /// Access Gate 통과(beginResult 수신) 직후 화면이 호출한다. 실제
  /// detail interpret 호출까지 수행한다.
  Future<void> onAccessGranted() async {
    final topic = _currentTopic;
    if (topic == null) {
      _errorMessage = '선택된 이야기를 찾을 수 없습니다. 처음부터 다시 시도해주세요.';
      _status = SajuRenewalFlowStatus.error;
      notifyListeners();
      return;
    }
    if (_isDetailLoading) return;
    _isDetailLoading = true;
    _status = SajuRenewalFlowStatus.interpreting;
    _detailState = const LoadState.loading();
    notifyListeners();

    final result = await _api.interpretDetail(
      topicId: topic.topicId,
      evidenceFactKeys: topic.evidenceFactKeys,
    );
    _isDetailLoading = false;

    if (!result.success) {
      _detailState = LoadState.error(result.errorMessage ?? '이야기를 불러오지 못했습니다.');
      _errorMessage = _friendlyErrorMessage(
        result.errorCode,
        result.errorMessage,
      );
      _errorReason = result.errorCode;
      _status = SajuRenewalFlowStatus.error;
      notifyListeners();
      return;
    }

    _detailState = LoadState.success(result.data!);
    _viewedTopicIds.add(topic.topicId);
    _status = SajuRenewalFlowStatus.storyDetail;
    notifyListeners();
  }

  /// 화면⑦ "다른 사주 이야기" 버튼 — 화면⑧(후보 목록) 상태로 전환한다.
  /// 이미 조회된 candidates를 그대로 보여주며, 전부 이미 본 topic이면
  /// [loadMoreTopics]로 새 후보를 다시 조회해야 한다(화면이 판단).
  void showMoreTopics() {
    _setStatus(SajuRenewalFlowStatus.moreTopics);
  }

  /// 오류 화면의 "재시도" 버튼 — 직전 단계로 되돌아가 재시도한다.
  Future<void> retry() async {
    _errorMessage = null;
    _errorReason = null;
    if (_currentTopic != null && _detailState.isError) {
      await onAccessGranted();
      return;
    }
    if (_currentTopic != null && _previewState.isError) {
      await loadPreview(_currentTopic!);
      return;
    }
    await _loadTopics();
  }

  /// 서버가 내려준 사용자 안내 문구를 그대로 쓰되(§11 "내부 정보 비노출"
  /// 원칙 — 서버 메시지 자체가 이미 사용자 친화적으로 가공되어 있음),
  /// 메시지 자체를 못 받은 네트워크 예외 상황만 공통 문구로 보완한다.
  String _friendlyErrorMessage(String? code, String? serverMessage) {
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    return '일시적으로 결과를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';
  }

  /// 로그아웃 시 개인 사주 데이터 잔존 방지(§ "로그인/프로필" 요구사항 —
  /// 사용자A의 데이터가 사용자B에게 섞이면 즉시 FAIL). app.dart의
  /// `_LogoutCallbackRegistrar`에 이 메서드를 등록해야 한다.
  void clearOnLogout() {
    _status = SajuRenewalFlowStatus.idle;
    _errorMessage = null;
    _errorReason = null;
    _topicsState = const LoadState.initial();
    _currentTopic = null;
    _previewState = const LoadState.initial();
    _detailState = const LoadState.initial();
    _viewedTopicIds.clear();
    _isPreviewLoading = false;
    _isDetailLoading = false;
    _isTopicsLoading = false;
    notifyListeners();
  }

  /// 화면① 메인 "내 사주 분석하기" 버튼 — 출생정보 입력 화면으로 넘어가기
  /// 전 상태만 초기화한다(이전 분석 결과가 남아있지 않도록).
  void startNewAnalysis() {
    _status = SajuRenewalFlowStatus.birthInput;
    _errorMessage = null;
    _errorReason = null;
    _topicsState = const LoadState.initial();
    _currentTopic = null;
    _previewState = const LoadState.initial();
    _detailState = const LoadState.initial();
    _viewedTopicIds.clear();
    notifyListeners();
  }
}
