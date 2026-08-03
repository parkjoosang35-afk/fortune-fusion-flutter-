import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/wish_post_repository.dart';
import '../domain/wish_post_model.dart';

/// [웹→앱 이식] 신통방통 wish.html "오늘의 행운 룰렷" 결과 명언 풀
/// (js/wish-engine.js ROULETTE_QUOTES 그대로 이식)
const _rouletteQuotes = [
  '느리더라도 멈추지 않으면 반드시 도착한다.',
  '오늘의 작은 용기가 내일의 큰 행운이 된다.',
  '기다림도 준비의 한 과정이다.',
  '당신의 진심은 언젠가 반드시 통한다.',
  '지금의 이 순간도 결국 지나간 뒤엔 그리운 날이 된다.',
  '마음을 다잡으면 길이 보인다.',
  '행운은 준비된 자에게 우연을 가장해 찾아온다.',
];

class WishPostProvider extends ChangeNotifier {
  final WishPostRepository _repository;
  WishPostProvider(this._repository);

  static const _rouletteLastKey = 'wish_roulette_last_date';

  List<WishPostModel> _posts = [];
  bool _isLoading = false;
  WishFeedTab _currentTab = WishFeedTab.all;

  final Map<String, List<WishCommentModel>> _commentsByWishId = {};
  final Set<String> _loadingCommentsFor = {};

  String? _rouletteResult;
  bool _canSpinRoulette = true;

  // [소원성(Wish Castle) 확장] 명예의 전당(서버 집계 버전) 상태.
  // 기존 hallOfFame(클라이언트 파생 집계) getter와는 별개로 유지한다(하위호환).
  List<Map<String, dynamic>> _featuredReviews = [];
  List<Map<String, dynamic>> _hallOfFameRanking = [];
  bool _isLoadingHallOfFame = false;

  List<WishPostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  WishFeedTab get currentTab => _currentTab;
  String? get rouletteResult => _rouletteResult;
  bool get canSpinRoulette => _canSpinRoulette;

  /// [소원성(Wish Castle) 확장] 관리자가 수동 선정한 성취 후기 목록(서버 집계).
  List<Map<String, dynamic>> get featuredReviews => _featuredReviews;

  /// [소원성(Wish Castle) 확장] 응원 누적 상위 랭킹(서버 집계, top 10).
  List<Map<String, dynamic>> get hallOfFameRanking => _hallOfFameRanking;

  bool get isLoadingHallOfFame => _isLoadingHallOfFame;

  /// [웹→앱 이식] 신통방통 wish.html "오늘의 인기 소원" - 응원수 상위 5개(파생 데이터)
  List<WishPostModel> get hotWishes {
    final list = List<WishPostModel>.from(_posts)
      ..sort((a, b) => b.supportCount.compareTo(a.supportCount));
    return list.take(5).toList();
  }

  /// [웹→앱 이식] 신통방통 wish.html "🏆 소원성 명예의 전당" - 작성자별 응원 합산 상위 5명
  List<WishHallOfFameEntry> get hallOfFame {
    final byAuthor = <String, List<WishPostModel>>{};
    for (final p in _posts) {
      if (p.isAnonymous) continue;
      byAuthor.putIfAbsent(p.authorNickname, () => []).add(p);
    }
    final entries = byAuthor.entries.map((e) {
      final total = e.value.fold<int>(0, (sum, p) => sum + p.supportCount);
      return WishHallOfFameEntry(
        nickname: e.key,
        totalSupport: total,
        wishCount: e.value.length,
      );
    }).toList();
    entries.sort((a, b) => b.totalSupport.compareTo(a.totalSupport));
    return entries.take(5).toList();
  }

  /// [웹→앱 이식] 신통방통 wish.html "오늘 등록된 소원" 카운트
  int get todayCount {
    final now = DateTime.now();
    return _posts
        .where(
          (p) =>
              p.createdAt.year == now.year &&
              p.createdAt.month == now.month &&
              p.createdAt.day == now.day,
        )
        .length;
  }

  Future<void> checkRouletteAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_rouletteLastKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _canSpinRoulette = last != today;
    notifyListeners();
  }

  /// [웹→앱 이식] 신통방통 wish.html "행운 룰렷 돌리기 (하루 1회)"
  Future<String?> spinRoulette() async {
    if (!_canSpinRoulette) return null;
    final quote = _rouletteQuotes[Random().nextInt(_rouletteQuotes.length)];
    _rouletteResult = quote;
    _canSpinRoulette = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _rouletteLastKey,
      DateTime.now().toIso8601String().substring(0, 10),
    );
    return quote;
  }

  List<WishCommentModel> commentsOf(String wishId) =>
      _commentsByWishId[wishId] ?? const [];
  bool isLoadingCommentsOf(String wishId) =>
      _loadingCommentsFor.contains(wishId);

  Future<void> loadFeed({WishFeedTab? tab}) async {
    _currentTab = tab ?? _currentTab;
    _isLoading = true;
    notifyListeners();
    final result = await _repository.getFeed(tab: _currentTab);
    if (result.success) _posts = result.data!;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> changeTab(WishFeedTab tab) async {
    if (_currentTab == tab) return;
    await loadFeed(tab: tab);
  }

  /// [3단계 - 복주머니 커뮤니티 적립 연동] 성공 시 서버가 지급한 rewardPoint를
  /// 반환한다(호출부 UI가 "+N P 획득" 토스트를 표시할 수 있도록). 실패 시 null.
  Future<int?> createPost(
    String content, {
    String category = '기타',
    bool isAnonymous = false,
    String? goalTag,
  }) async {
    final result = await _repository.createPost(
      content,
      category: category,
      isAnonymous: isAnonymous,
      goalTag: goalTag,
    );
    if (result.success) {
      final rewardPoint = result.data!.rewardPoint;
      await loadFeed();
      return rewardPoint;
    }
    return null;
  }

  /// "행운 보내기" - Mock 단계 임시정책: 복주머니 이동 없는 단순 응원 토글
  /// (03§10.3/§18/§570 정책 미확정 - 향후 복주머니전송형 확정 시 WalletProvider.spend/earn
  /// orchestrate를 이 메서드에 추가하는 정도로 영향도 최소화되도록 설계)
  Future<void> toggleSupport(String wishId) async {
    final result = await _repository.toggleSupport(wishId);
    if (!result.success) return;
    final updated = result.data!;
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index != -1) {
      _posts[index] = updated;
      notifyListeners();
    }
  }

  Future<void> loadComments(String wishId) async {
    _loadingCommentsFor.add(wishId);
    notifyListeners();
    final result = await _repository.getComments(wishId);
    if (result.success) _commentsByWishId[wishId] = result.data!;
    _loadingCommentsFor.remove(wishId);
    notifyListeners();
  }

  /// [3단계 - 복주머니 커뮤니티 적립 연동] 성공 시 서버가 지급한 복주머니(bokjuAwarded)를
  /// 반환한다(호출부 UI가 "+N 복주머니" 피드백을 표시할 수 있도록). 실패 시 null.
  Future<int?> addComment(String wishId, String content) async {
    final result = await _repository.addComment(wishId, content);
    if (!result.success) return null;
    await loadComments(wishId);
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(
        commentCount: _posts[index].commentCount + 1,
      );
      notifyListeners();
    }
    return result.data!.bokjuAwarded;
  }

  Future<bool> report(
    ReportTargetType targetType,
    String targetId,
    String reason,
  ) async {
    final result = await _repository.report(targetType, targetId, reason);
    return result.success;
  }

  /// [재화 구조 정리] 복주머니 보내기 실패 시(주로 잔액 부족) UI에 보여줄 에러 메시지.
  String? lastBokjuError;

  /// [소원성(Wish Castle) 확장] 복주머니 보내기 - [재화 구조 정리]에 따라 선택한
  /// amount만큼 실제 지갑(Wallet)에서 차감된다(서버가 원자적으로 처리, 잔액 부족
  /// 시 409). 성공 시 posts 캐시를 서버 응답값으로 즉시 갱신하고, 레벨업 여부/
  /// 이전 레벨/최종레벨 최초 도달 여부를 [WishBokjuSendResult]로 반환해 호출부(UI)가
  /// 성장 연출/레벨업 연출/최종단계 특별연출을 분기할 수 있게 한다.
  Future<WishBokjuSendResult?> sendBokju(String wishId, int amount) async {
    final result = await _repository.sendBokju(wishId, amount);
    if (!result.success || result.data == null) {
      lastBokjuError = result.errorMessage ?? '복주머니 보내기에 실패했습니다.';
      return null;
    }
    lastBokjuError = null;
    final data = result.data!;
    final index = _posts.indexWhere((p) => p.id == wishId);
    final newCandleLevel = (data['candleLevel'] as num).toInt();
    final newBokjuCount = (data['bokjuCount'] as num).toInt();
    final previousLevel = (data['previousLevel'] as num).toInt();
    final leveledUp = data['leveledUp'] as bool? ?? false;
    final isMilestoneShown = data['isMilestoneShown'] as bool? ?? false;
    final achievedAt = data['achievedAt'] != null
        ? DateTime.parse(data['achievedAt'] as String)
        : null;
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(
        candleLevel: newCandleLevel,
        bokjuCount: newBokjuCount,
        achievedAt: achievedAt,
        isMilestoneShown: isMilestoneShown,
      );
      notifyListeners();
    }
    return WishBokjuSendResult(
      candleLevel: newCandleLevel,
      bokjuCount: newBokjuCount,
      previousLevel: previousLevel,
      leveledUp: leveledUp,
      reachedMaxLevel:
          leveledUp && newCandleLevel >= WishPostModel.maxCandleLevel,
    );
  }

  /// [소원성(Wish Castle) 확장] 최종단계(레벨4) 특별 연출을 1회만 노출하기 위한
  /// "이미 봤음" 표시. 로컬 캐시도 함께 갱신해 같은 화면에서 재진입 시 재생되지 않게 한다.
  Future<void> markMilestoneShown(String wishId) async {
    await _repository.markMilestoneShown(wishId);
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(isMilestoneShown: true);
      notifyListeners();
    }
  }

  /// [소원성(Wish Castle) 확장] 명예의 전당(서버 집계 버전) 로드.
  /// - featuredReviews: 관리자가 CMS에서 수동 선정한 성취 후기
  /// - ranking: 응원 누적 상위 랭킹(top 10)
  Future<void> loadHallOfFame() async {
    _isLoadingHallOfFame = true;
    notifyListeners();
    final result = await _repository.getHallOfFame();
    if (result.success && result.data != null) {
      final data = result.data!;
      _featuredReviews = (data['featuredReviews'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _hallOfFameRanking = (data['ranking'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    _isLoadingHallOfFame = false;
    notifyListeners();
  }

  /// [소원성(Wish Castle) 확장] 성취 후기 작성 - 최종레벨(레벨4) 도달 소원만 작성 가능.
  /// (서버 측에서도 candleLevel<4면 400을 반환하므로 UI는 isMaxLevel일 때만 진입점을 노출한다.)
  Future<bool> submitReview(String wishId, String content) async {
    final result = await _repository.submitReview(wishId, content);
    return result.success;
  }

  /// [재화 구조 정리 - 재연결] cheer/empathize/highlight/expose_boost 4개 유료
  /// 액션 실패 시(주로 잔액부족/본인글아님) UI에 보여줄 에러 메시지.
  String? lastWishActionError;

  /// [재화 구조 정리 - 재연결] 댓글 응원(cheer) - 성공 시 결과(차감액/잔액/최신
  /// cheerCount)를 반환한다. 실패 시 null(lastWishActionError 확인).
  Future<WishSpendActionResult?> cheerComment(
    String wishId,
    String commentId,
  ) async {
    final result = await _repository.cheerComment(wishId, commentId);
    if (!result.success || result.data == null) {
      lastWishActionError = result.errorMessage ?? '응원 처리에 실패했습니다.';
      return null;
    }
    lastWishActionError = null;
    final data = result.data!;
    final newCheerCount = (data['cheerCount'] as num).toInt();
    final comments = _commentsByWishId[wishId];
    if (comments != null) {
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        comments[index] = comments[index].copyWith(cheerCount: newCheerCount);
        notifyListeners();
      }
    }
    return WishSpendActionResult(
      amountSpent: (data['amountSpent'] as num).toInt(),
      balanceAfter: (data['balanceAfter'] as num?)?.toInt(),
    );
  }

  /// [재화 구조 정리 - 재연결] 댓글 공감(empathize) - cheerComment와 동일 구조.
  Future<WishSpendActionResult?> empathizeComment(
    String wishId,
    String commentId,
  ) async {
    final result = await _repository.empathizeComment(wishId, commentId);
    if (!result.success || result.data == null) {
      lastWishActionError = result.errorMessage ?? '공감 처리에 실패했습니다.';
      return null;
    }
    lastWishActionError = null;
    final data = result.data!;
    final newEmpathizeCount = (data['empathizeCount'] as num).toInt();
    final comments = _commentsByWishId[wishId];
    if (comments != null) {
      final index = comments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        comments[index] = comments[index].copyWith(
          empathizeCount: newEmpathizeCount,
        );
        notifyListeners();
      }
    }
    return WishSpendActionResult(
      amountSpent: (data['amountSpent'] as num).toInt(),
      balanceAfter: (data['balanceAfter'] as num?)?.toInt(),
    );
  }

  /// [재화 구조 정리 - 재연결] 글 강조(highlight) - 본인 소원에만 적용 가능(서버가
  /// 403 가드). 성공 시 posts 캐시의 isHighlighted/highlightedUntil을 갱신한다.
  Future<WishSpendActionResult?> highlightWish(String wishId) async {
    final result = await _repository.highlightWish(wishId);
    if (!result.success || result.data == null) {
      lastWishActionError = result.errorMessage ?? '글 강조 처리에 실패했습니다.';
      return null;
    }
    lastWishActionError = null;
    final data = result.data!;
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(
        isHighlighted: true,
        highlightedUntil: data['highlightedUntil'] != null
            ? DateTime.parse(data['highlightedUntil'] as String)
            : null,
      );
      notifyListeners();
    }
    return WishSpendActionResult(
      amountSpent: (data['amountSpent'] as num).toInt(),
      balanceAfter: (data['balanceAfter'] as num?)?.toInt(),
    );
  }

  /// [재화 구조 정리 - 재연결] 노출 강화(expose_boost) - 성공 시 posts 캐시의
  /// isBoosted를 즉시 true로 갱신한다(피드 상단 재배치는 다음 loadFeed()부터 반영).
  Future<WishSpendActionResult?> exposeBoostWish(String wishId) async {
    final result = await _repository.exposeBoostWish(wishId);
    if (!result.success || result.data == null) {
      lastWishActionError = result.errorMessage ?? '노출 강화 처리에 실패했습니다.';
      return null;
    }
    lastWishActionError = null;
    final data = result.data!;
    final index = _posts.indexWhere((p) => p.id == wishId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(isBoosted: true);
      notifyListeners();
    }
    return WishSpendActionResult(
      amountSpent: (data['amountSpent'] as num).toInt(),
      balanceAfter: (data['balanceAfter'] as num?)?.toInt(),
    );
  }
}

/// [재화 구조 정리 - 재연결] cheer/empathize/highlight/expose_boost 공통 응답
/// 결과 - 실제 차감액과 처리 후 잔액을 담아 UI가 공용 차감 토스트를 띄울 수
/// 있게 한다(신규 원자단위 신설 없이 순수 데이터 클래스).
class WishSpendActionResult {
  final int amountSpent;
  final int? balanceAfter;
  const WishSpendActionResult({required this.amountSpent, this.balanceAfter});
}

/// [소원성(Wish Castle) 확장] sendBokju() 결과 - UI가 성장/레벨업/최종연출을
/// 분기하기 위한 최소 정보만 담는다(신규 원자단위 신설 없이 순수 데이터 클래스).
class WishBokjuSendResult {
  final int candleLevel;
  final int bokjuCount;
  final int previousLevel;
  final bool leveledUp;
  final bool reachedMaxLevel;

  const WishBokjuSendResult({
    required this.candleLevel,
    required this.bokjuCount,
    required this.previousLevel,
    required this.leveledUp,
    required this.reachedMaxLevel,
  });
}
