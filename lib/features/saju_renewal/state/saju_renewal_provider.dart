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

  /// [버그 수정 — C-08b(docs/08) 결함 발견] 화면⑧ "[↻ 새로운 이야기]"로
  /// 교체되어 현재 화면에서 사라진(=소비된) 후보 topic_id. "이미 상세까지
  /// 본"(`_viewedTopicIds`)과는 다른 개념 — 아직 상세를 보지 않았어도
  /// 카드 교체로 한 번 노출된 적이 있으면 같은 배치에서 다시 보여주지
  /// 않기 위한 집합이다(docs/03_화면명세.md §08 "남은 후보로 교체" —
  /// 같은 카드가 바로 다시 보이면 안 됨).
  final Set<String> _shownCandidateIds = {};

  /// [버그 수정 — C-08b(docs/08) 결함 발견] [refreshCandidates] 재호출
  /// 가드용(기존 `_isTopicsLoading`과 분리 — 그 플래그는 화면⑧ 전체를
  /// 전면 스피너로 바꾸는 조건(`more_stories_screen.dart`
  /// `topicsState.isLoading || provider.isTopicsLoading`)에도 쓰이므로,
  /// 재호출 중에도 기존 카드 목록을 그대로 유지해야 하는 이번 버그
  /// 수정에서는 재사용할 수 없다).
  bool _isRefreshingCandidates = false;
  bool get isRefreshingCandidates => _isRefreshingCandidates;

  /// [버그 수정 — C-08b] docs/04_모션.md §4-5 "08: 카드 rise 600,
  /// i×80ms. [새로운 이야기] 시 **리스트 키 변경** → 재생." — jsx 원본
  /// `ScreenOthers`의 `<div key={page} ...>`와 동일한 역할. 화면이 이
  /// 값을 `AnimatedSwitcher`/`ValueKey`로 사용해 "새로운 이야기"를
  /// 누를 때마다 카드 rise 애니메이션을 다시 재생하게 한다.
  int _candidateBatch = 0;
  int get candidateBatch => _candidateBatch;

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
  ///
  /// [C-08b 연계] "새로운 이야기"로 교체되어 [_shownCandidateIds]에
  /// 들어간 후보도 제외한다 — 그래야 [refreshCandidates]가 서버를 다시
  /// 부르지 않고도 이미 받아둔 나머지 후보를 "다음 3장"으로 보여줄 수
  /// 있다(로컬 교체, 0비용).
  List<TopicCard> get displayableCandidates {
    final raw = _topicsState.data?.candidates ?? const <TopicCard>[];
    final remaining = raw
        .where(
          (c) =>
              !_viewedTopicIds.contains(c.topicId) &&
              !_shownCandidateIds.contains(c.topicId),
        )
        .toList();
    return remaining.take(3).toList();
  }

  /// [버그 수정 — C-08b(docs/08) 결함 발견] docs/03_화면명세.md §08
  /// "[새로운 이야기]: 남은 후보로 교체 ... 남은 후보 < 3 → topics/select
  /// 재호출" 조건을 판단하기 위한 getter. "남은 후보"란
  /// `raw candidates` 중 이미 본(detail 완료) 것도, 이미 교체로 소비된
  /// 것도 아닌 나머지를 뜻한다(=다음 번 [displayableCandidates] 호출이
  /// 돌려줄 수 있는 후보 수와 동일).
  int get remainingLocalCandidateCount {
    final raw = _topicsState.data?.candidates ?? const <TopicCard>[];
    return raw
        .where(
          (c) =>
              !_viewedTopicIds.contains(c.topicId) &&
              !_shownCandidateIds.contains(c.topicId),
        )
        .length;
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
  /// 수를 그대로 노출한다(0부터 시작). 서버 판단을 Flutter가 대체하지
  /// 않는다 — 단순 카운터 getter일 뿐, [_viewedTopicIds] 자체의
  /// 용도(Exposure History exclude 참고 목록)는 그대로 유지된다.
  ///
  /// [주의 — C-09a] 이 값은 "STORY · N°0X" 순번 계산에는 더 이상 쓰지
  /// 않는다(아래 [ordinalOf] 참고) — 05/07 화면이 같은 이야기에 대해
  /// 서로 다른 순번을 보여주는 결함이 있었다.
  int get viewedStoryCount => _viewedTopicIds.length;

  /// [버그 수정 — C-09a(docs/08) 결함 발견] docs/03_화면명세.md §09
  /// "SceneBg·tint·주제 태그·**순번만 교체**"(=05·07이 같은 주제를 보는
  /// 동안은 순번이 바뀌면 안 됨) 및 원본
  /// `design_files/saju/screens-b.jsx`를 정밀 대조한 결과(`pick()`,
  /// 316행): `ordinal`은 **08에서 새 주제를 선택하는 순간에만** +1되고,
  /// 05(미리보기)→07(상세)로 넘어가는 것 자체(=상세보기 **완료**)로는
  /// 전혀 바뀌지 않는다.
  ///
  /// [기존 결함] 기존 코드는 `provider.viewedStoryCount + 1`
  /// (=`_viewedTopicIds.length`, 상세보기 **완료** 횟수)을 그대로
  /// ordinal로 썼다. `onAccessGranted()`가 07 렌더링 *직전에*
  /// `_viewedTopicIds.add(topic.topicId)`를 실행하므로, 같은 이야기인데도
  /// 05에서는 "N°01", 07에서는 "N°02"로 **1 증가해 보이는** 불일치가
  /// 실제로 재현되었다(재현 테스트로 확인: 05 ordinal=1, 07 ordinal=2).
  ///
  /// [수정] "상세보기 완료 횟수"가 아니라 "이번 세션에서 미리보기를
  /// 시작한(= [loadPreview] 호출된) 고유 topic_id의 등장 순서"로
  /// 다시 계산한다 — topic_id는 05→07 전환 중에 바뀌지 않으므로 항상
  /// 동일한 순번을 돌려준다.
  int ordinalOf(String topicId) {
    final idx = _topicOrder.indexOf(topicId);
    if (idx >= 0) return idx + 1;
    // 이론상 도달하지 않음(항상 loadPreview가 먼저 기록) — 방어적으로
    // 다음 순번을 돌려준다.
    return _topicOrder.length + 1;
  }

  /// [C-09a 연계] [ordinalOf]가 참조하는 등장 순서 기록(중복 없이, 처음
  /// 본 순서 그대로). jsx 원본의 `app.ordinal`과 동일한 역할을 하되,
  /// "상세보기 완료"가 아니라 "미리보기 시작"을 기준으로 삼는다(아래
  /// [loadPreview]에서만 추가됨).
  final List<String> _topicOrder = [];

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

  /// [버그 수정 — C-08b(docs/08) 결함 발견] 화면⑧ "[↻ 새로운 이야기]"
  /// 버튼의 실제 동작. docs/03_화면명세.md §08 "[새로운 이야기]: 남은
  /// 후보로 교체(애니 rise 재생). 남은 후보 < 3 → `topics/select`
  /// 재호출(exclude=본 주제들). 재호출 중 버튼 disabled + 라벨 앞 글리프
  /// 회전."을 그대로 재현한다.
  ///
  /// [기존 결함] 과거 `loadMoreTopics()`는 버튼을 누를 때마다 **항상**
  /// `_loadTopics()`(= `topics/select` 서버 재호출)만 수행했다. 이는
  /// 두 가지 문제가 있었다:
  /// 1) docs/03 §08 "남은 후보로 교체" 로컬 스왑이 전혀 없어 후보가
  ///    아직 여럿 남아있어도 매번 서버를 다시 불렀다.
  /// 2) 더 심각하게, `_loadTopics()` 끝에서 항상
  ///    `await loadPreview(data.firstTopic)`(=summary interpret, LLM
  ///    호출)을 이어서 실행하므로, 화면⑧에서 후보를 "구경"만 해도
  ///    버튼을 누를 때마다 LLM 비용이 발생했다 — docs/03 §08 "목적:
  ///    **선택에만 LLM 비용(후보 노출은 0비용)**"을 정면 위반하는
  ///    결함이었다.
  ///
  /// 이 메서드는 그 대신: 먼저 지금 화면에 보이는 후보를
  /// [_shownCandidateIds]로 "소비 처리"하고, 그 뒤에도 로컬에 3장
  /// 이상 남아있으면 서버를 전혀 부르지 않고 끝낸다(0비용). 3장
  /// 미만일 때만 [_refreshCandidatesFromServer]로 서버를 재호출하되,
  /// `_status`/`_currentTopic`을 건드리지 않고 `loadPreview`도 호출하지
  /// 않는다 — 화면⑧은 그대로 머무르고 후보 목록만 갱신된다.
  Future<void> refreshCandidates() async {
    if (_isRefreshingCandidates) return;
    // 지금 보여주고 있던 카드들을 "소비됨"으로 표시 — 다음 번
    // displayableCandidates 계산에서 자동으로 걸러진다.
    _shownCandidateIds.addAll(displayableCandidates.map((c) => c.topicId));
    _candidateBatch++;
    if (remainingLocalCandidateCount >= 3) {
      // [로컬 교체 — 0비용] 서버를 다시 부르지 않고 남은 후보로 바로
      // 바꾼다(docs/03 §08 "남은 후보로 교체").
      notifyListeners();
      return;
    }
    await _refreshCandidatesFromServer();
  }

  /// [버그 수정 — C-08b] docs/03_화면명세.md §08 "남은 후보 < 3 →
  /// `topics/select` 재호출(exclude=본 주제들)". 전면 로딩 상태
  /// (`_topicsState`를 loading으로 바꾸는 것)는 쓰지 않는다 — 그러면
  /// `more_stories_screen.dart`가 "전체 화면 스피너"로 바뀌어 지금
  /// 보이는 카드까지 사라지는데, 명세는 "재호출 중 **버튼만**
  /// disabled"라고 못박고 있다. 대신 [_isRefreshingCandidates] 전용
  /// 플래그만 켜서 버튼만 비활성화한다.
  Future<void> _refreshCandidatesFromServer() async {
    if (_isRefreshingCandidates) return;
    _isRefreshingCandidates = true;
    notifyListeners();

    final result = await _api.selectTopics(
      excludeTopicIds: _viewedTopicIds.isEmpty
          ? null
          : _viewedTopicIds.toList(),
    );
    _isRefreshingCandidates = false;

    if (!result.success) {
      _errorMessage = _friendlyErrorMessage(
        result.errorCode,
        result.errorMessage,
      );
      _errorReason = result.errorCode;
      _status = SajuRenewalFlowStatus.error;
      notifyListeners();
      return;
    }

    // 새로 받은 후보 풀로 교체 — 이번 풀은 아직 한 번도 소비된 적이
    // 없으므로 [_shownCandidateIds]를 비워 처음부터 다시 센다.
    _topicsState = LoadState.success(result.data!);
    _shownCandidateIds.clear();
    notifyListeners();
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
    // [버그 수정 — C-08b] 완전히 새 후보 풀이므로 이전 풀의 소비 이력은
    // 무의미하다 — 비워서 처음부터 다시 3장을 셀 수 있게 한다.
    _shownCandidateIds.clear();
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
    // [버그 수정 — C-09a] 이 주제를 "이번 세션에서 처음 미리보기하는"
    // 시점에 등장 순서를 1회만 기록한다(jsx `pick()`의 `ordinal+1`과
    // 동일 시점 — 상세보기 완료가 아니라 "주제 선택/미리보기 시작").
    // 이미 기록된 topic_id(재방문)는 다시 추가하지 않아 순번이 밀리지
    // 않는다.
    if (!_topicOrder.contains(topic.topicId)) {
      _topicOrder.add(topic.topicId);
    }
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
  /// 이미 조회된 candidates를 그대로 보여주며(단, [displayableCandidates]
  /// getter가 [_viewedTopicIds]/[_shownCandidateIds]를 걸러주므로 방금
  /// 상세까지 본 topic은 자동으로 빠진다 — C-08a), 후보가 부족하면
  /// 화면 쪽에서 [remainingLocalCandidateCount] < 3을 보고 안내 문구와
  /// 함께 "새로운 이야기" 버튼으로 [refreshCandidates]를 호출하게 한다
  /// (서버 자동 선조회는 하지 않는다 — 사용자가 명시적으로 요청했을
  /// 때만 네트워크를 쓴다는 기존 원칙 유지).
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
    _shownCandidateIds.clear();
    _candidateBatch = 0;
    _topicOrder.clear();
    _isPreviewLoading = false;
    _isDetailLoading = false;
    _isTopicsLoading = false;
    _isRefreshingCandidates = false;
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
    _shownCandidateIds.clear();
    _candidateBatch = 0;
    _topicOrder.clear();
    notifyListeners();
  }
}
