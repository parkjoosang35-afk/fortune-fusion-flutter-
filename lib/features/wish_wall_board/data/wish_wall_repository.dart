import '../domain/wish_wall_models.dart';

/// 소원벽게시판 Repository 계약.
///
/// [handoff.zip] 기획안 §7 API 계약을 이식. 현재는 인메모리 Mock 구현만
/// 제공하며(§7.3 "개발 초기 Mock 우선" 권장 원칙), 추후 실 API 연동 시
/// 이 인터페이스를 그대로 유지한 채 Repository 구현부만 교체하면 된다.
abstract class WishWallRepository {
  Future<List<WishPost>> fetchFeed({String? categoryFilter});
  Future<WishPost?> fetchDetail(String wishId);
  Future<WishPost> createWish({
    required WishCategory categoryId,
    required double glassLevel,
    required String text,
    required WishVisibility visibility,
  });
  Future<void> updateWishStatus(String wishId, {bool? isGratitude});
  Future<void> deleteWish(String wishId);
  Future<WishPost> support(String wishId);
  Future<WishPost> submitDailyPrayer(String wishId);
  Future<List<WishPost>> fetchMyWishes();
  Future<List<WishComment>> fetchComments(String wishId);
  Future<WishComment> createComment(String wishId, String text);
  Future<void> reportWish(String wishId, String reason);
  Future<void> hideWish(String wishId);
  Future<void> blockUser(String authorId);
  /// support/pouch 후 병 목의 매듭 카운트를 올리기 위한 헬퍼(=복주머니 보냄).
  Future<WishPost> incrementPouch(String wishId, int amount);
}

/// 인메모리 Mock 구현. [handoff.zip] design/wb3-data.jsx의 WISHES/COMMENTS/
/// MY_WISHES 목데이터를 참고해 유사한 톤의 초기 데이터를 시딩한다.
class MockWishWallRepository implements WishWallRepository {
  MockWishWallRepository._internal() {
    _seed();
  }
  static final MockWishWallRepository instance =
      MockWishWallRepository._internal();

  final List<WishPost> _wishes = [];
  final Map<String, List<WishComment>> _comments = {};
  final List<WishPost> _myWishes = [];
  int _seq = 1000;

  void _seed() {
    final now = DateTime.now();
    _wishes.addAll([
      WishPost(
        id: 'w0231',
        authorId: 'u_star',
        authorName: '별이지나가',
        authorAvatarEmoji: '⭐',
        isAnonymous: false,
        categoryId: WishCategory.exam,
        text: '이번 자격증 시험 꼭 붙기를. 밤새 공부한 만큼 결실이 있기를 조용히 바래봅니다.',
        createdAt: now.subtract(const Duration(minutes: 34)),
        supportCount: 128,
        prayerCount: 76,
        pouchCount: 24,
        glassLevel: 0.8,
      ),
      WishPost(
        id: 'w0230',
        authorId: 'u_wave',
        authorName: '조용한물결',
        authorAvatarEmoji: '🌊',
        isAnonymous: true,
        categoryId: WishCategory.health,
        text: '엄마 무릎 수술 잘 되고 아프지 않기를. 회복도 빠르게 되기를 함께 빌어주세요.',
        createdAt: now.subtract(const Duration(minutes: 128)),
        supportCount: 542,
        prayerCount: 289,
        pouchCount: 67,
        hasSupportedByMe: true,
        glassLevel: 0.9,
      ),
      WishPost(
        id: 'w0229',
        authorId: 'u_snow',
        authorName: '흰눈송이',
        authorAvatarEmoji: '❄️',
        isAnonymous: false,
        categoryId: WishCategory.love,
        text: '좋은 인연 만나 오래오래 함께하기를. 서로에게 따뜻한 사람이 되기를.',
        createdAt: now.subtract(const Duration(minutes: 320)),
        supportCount: 87,
        prayerCount: 41,
        pouchCount: 12,
        glassLevel: 0.6,
      ),
      WishPost(
        id: 'w0227',
        authorId: 'u_dusk',
        authorName: '해질녘',
        authorAvatarEmoji: '🌆',
        isAnonymous: true,
        categoryId: WishCategory.job,
        text: '오래 준비한 이직, 이번엔 좋은 결과가 있기를. 흔들리는 마음이 조금씩 단단해지길.',
        createdAt: now.subtract(const Duration(minutes: 512)),
        supportCount: 256,
        prayerCount: 128,
        pouchCount: 38,
        glassLevel: 0.7,
      ),
      WishPost(
        id: 'w0225',
        authorId: 'u_wind',
        authorName: '바람같이',
        authorAvatarEmoji: '🍃',
        isAnonymous: false,
        categoryId: WishCategory.money,
        text: '새로 열은 작은 가게가 오래오래 이어지기를. 찾아주는 손님들과 좋은 인연이 되기를.',
        createdAt: now.subtract(const Duration(minutes: 900)),
        supportCount: 43,
        prayerCount: 22,
        pouchCount: 5,
        glassLevel: 0.4,
      ),
      WishPost(
        id: 'w0224',
        authorId: 'u_night',
        authorName: '가만한밤',
        authorAvatarEmoji: '🌙',
        isAnonymous: true,
        categoryId: WishCategory.family,
        text: '아빠가 오래오래 곁에 있어주기를. 매일 아침 산책하시는 그 모습, 오래 보고 싶어요.',
        createdAt: now.subtract(const Duration(minutes: 1200)),
        supportCount: 1561,
        prayerCount: 802,
        pouchCount: 189,
        glassLevel: 1.0,
      ),
    ]);

    _comments['w0231'] = [
      _c('w0231', '흰눈송이', '꼭 붙으실 거예요. 같이 빌게요', 20),
      _c('w0231', '해질녘', '밤새 준비하신 만큼 좋은 결과 있으시길', 180),
      _c('w0231', '가만한밤', '응원합니다', 340),
    ];
    _comments['w0230'] = [
      _c('w0230', '별이지나가', '어머니 쾌차하시길 저도 함께 빌게요', 60),
      _c('w0230', '조용한초', '수술 잘 되실 거예요. 힘내세요', 240),
      _c('w0230', '푸른달', '가족이 아프면 마음이 많이 무겁죠. 응원합니다', 480),
      _c('w0230', '연한바람', '기도할게요', 720),
    ];
    _comments['w0229'] = [
      _c('w0229', '푸른달', '좋은 인연이 곧 찾아올 거예요', 30),
    ];

    _myWishes.addAll([
      WishPost(
        id: 'my01',
        authorId: 'me',
        authorName: '나',
        authorAvatarEmoji: '👤',
        isAnonymous: false,
        categoryId: WishCategory.exam,
        text: '올해는 꼭 합격하기를. 오래 준비한 만큼 결실이 있기를.',
        createdAt: now.subtract(const Duration(days: 3)),
        supportCount: 24,
        prayerCount: 12,
        pouchCount: 3,
        hasNewReaction: true,
        glassLevel: 0.5,
      ),
      WishPost(
        id: 'my02',
        authorId: 'me',
        authorName: '나',
        authorAvatarEmoji: '👤',
        isAnonymous: false,
        categoryId: WishCategory.health,
        text: '가족 모두 크고 작은 걱정 없이 건강한 한 해가 되기를.',
        createdAt: now.subtract(const Duration(days: 12)),
        supportCount: 8,
        prayerCount: 4,
        pouchCount: 1,
        glassLevel: 0.3,
      ),
      WishPost(
        id: 'my03',
        authorId: 'me',
        authorName: '나',
        authorAvatarEmoji: '👤',
        isAnonymous: false,
        categoryId: WishCategory.love,
        text: '오래 붙잡고 있던 마음을 조용히 내려놓을 수 있기를.',
        visibility: WishVisibility.private,
        createdAt: now.subtract(const Duration(days: 30)),
        glassLevel: 0.2,
      ),
      WishPost(
        id: 'my04',
        authorId: 'me',
        authorName: '나',
        authorAvatarEmoji: '👤',
        isAnonymous: false,
        categoryId: WishCategory.job,
        text: '오래 준비한 이직, 좋은 결과로 이어졌어요. 감사한 마음을 기록해둡니다.',
        isGratitude: true,
        createdAt: now.subtract(const Duration(days: 60)),
        supportCount: 156,
        prayerCount: 89,
        pouchCount: 24,
        glassLevel: 1.0,
      ),
    ]);
  }

  WishComment _c(String wishId, String author, String text, int minutesAgo) {
    return WishComment(
      id: 'c_${_seq++}',
      wishId: wishId,
      authorName: author,
      text: text,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
    );
  }

  @override
  Future<List<WishPost>> fetchFeed({String? categoryFilter}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (categoryFilter == null || categoryFilter == 'all') {
      return List.of(_wishes);
    }
    return _wishes
        .where((w) => w.categoryId.name == categoryFilter)
        .toList();
  }

  @override
  Future<WishPost?> fetchDetail(String wishId) async {
    await Future.delayed(const Duration(milliseconds: 120));
    try {
      return _wishes.firstWhere((w) => w.id == wishId);
    } catch (_) {
      try {
        return _myWishes.firstWhere((w) => w.id == wishId);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<WishPost> createWish({
    required WishCategory categoryId,
    required double glassLevel,
    required String text,
    required WishVisibility visibility,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final wish = WishPost(
      id: 'w_${_seq++}',
      authorId: 'me',
      authorName: '나',
      authorAvatarEmoji: '👤',
      isAnonymous: visibility == WishVisibility.anonymous,
      categoryId: categoryId,
      text: text,
      glassLevel: glassLevel,
      visibility: visibility,
      createdAt: DateTime.now(),
    );
    _myWishes.insert(0, wish);
    if (visibility != WishVisibility.private) {
      _wishes.insert(0, wish);
    }
    return wish;
  }

  @override
  Future<void> updateWishStatus(String wishId, {bool? isGratitude}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Mock: 필드가 final이라 실제 갱신은 생략(추후 실 API 연동 시 구현).
  }

  @override
  Future<void> deleteWish(String wishId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _wishes.removeWhere((w) => w.id == wishId);
    _myWishes.removeWhere((w) => w.id == wishId);
  }

  @override
  Future<WishPost> support(String wishId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final wish = await fetchDetail(wishId);
    if (wish == null) throw Exception('소원을 찾을 수 없습니다');
    if (!wish.hasSupportedByMe) {
      wish.hasSupportedByMe = true;
      wish.supportCount += 1;
    }
    return wish;
  }

  @override
  Future<WishPost> submitDailyPrayer(String wishId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final wish = await fetchDetail(wishId);
    if (wish == null) throw Exception('소원을 찾을 수 없습니다');
    if (!wish.hasPrayedToday) {
      wish.hasPrayedToday = true;
      wish.prayerCount += 1;
    }
    return wish;
  }

  @override
  Future<WishPost> incrementPouch(String wishId, int amount) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final wish = await fetchDetail(wishId);
    if (wish == null) throw Exception('소원을 찾을 수 없습니다');
    wish.pouchCount += amount;
    wish.hasNewReaction = true;
    return wish;
  }

  @override
  Future<List<WishPost>> fetchMyWishes() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.of(_myWishes);
  }

  @override
  Future<List<WishComment>> fetchComments(String wishId) async {
    await Future.delayed(const Duration(milliseconds: 120));
    return List.of(_comments[wishId] ?? const []);
  }

  @override
  Future<WishComment> createComment(String wishId, String text) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final comment = WishComment(
      id: 'c_${_seq++}',
      wishId: wishId,
      authorName: '나',
      text: text,
      createdAt: DateTime.now(),
      isMine: true,
    );
    _comments.putIfAbsent(wishId, () => []).insert(0, comment);
    return comment;
  }

  @override
  Future<void> reportWish(String wishId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> hideWish(String wishId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _wishes.removeWhere((w) => w.id == wishId);
  }

  @override
  Future<void> blockUser(String authorId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _wishes.removeWhere((w) => w.authorId == authorId);
  }
}
