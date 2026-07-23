import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/amulet_item_model.dart';
import '../domain/amulet_model.dart';
import '../domain/user_amulet_model.dart';

/// 06단계 §4.8 `/v1/amulets/*` 대응 Mock Repository
/// 10단계(Mock): 상점 상품/보유목록을 메모리에 고정 데이터로 유지.
/// 향후 실제 API 연동 시 이 클래스 내부 구현만 http 호출로 교체.
class AmuletRepository {
  static const _names = ['재물 부적', '애정 부적', '건강 부적', '취업운 부적'];
  static const _icons = ['🧧', '💖', '🍀', '⭐'];

  // ── GET /v1/amulets/shop 대응 Mock 상품 마스터 ──
  static final List<AmuletItemModel> _shopItems = [
    AmuletItemModel(
      id: 'am_001',
      name: '재물 부적',
      grade: AmuletGrade.byCode('common'),
      effectDescription: '금전운을 끌어당기는 기본 부적입니다.',
      iconEmoji: '🧧',
      pricePoint: 500,
    ),
    AmuletItemModel(
      id: 'am_002',
      name: '애정 부적',
      grade: AmuletGrade.byCode('rare'),
      effectDescription: '인연과 애정운을 밝혀주는 부적입니다.',
      iconEmoji: '💖',
      pricePoint: 1200,
    ),
    AmuletItemModel(
      id: 'am_003',
      name: '건강 부적',
      grade: AmuletGrade.byCode('common'),
      effectDescription: '몸과 마음의 건강을 지켜주는 부적입니다.',
      iconEmoji: '🍀',
      pricePoint: 500,
    ),
    AmuletItemModel(
      id: 'am_004',
      name: '취업운 부적',
      grade: AmuletGrade.byCode('heroic'),
      effectDescription: '새로운 기회와 취업운을 불러오는 부적입니다.',
      iconEmoji: '⭐',
      pricePoint: 2000,
    ),
    AmuletItemModel(
      id: 'am_005',
      name: '만사형통 황금부적',
      grade: AmuletGrade.byCode('legendary'),
      effectDescription: '모든 운을 상승시키는 한정판 부적입니다.',
      iconEmoji: '👑',
      pricePoint: 5000,
      isLimited: true,
    ),
    AmuletItemModel(
      id: 'am_006',
      name: 'AI 맞춤 부적',
      grade: AmuletGrade.byCode('heroic'),
      effectDescription: 'AI가 당신만을 위해 생성하는 특별한 부적입니다.',
      iconEmoji: '🎨',
      pricePoint: 3000,
      isAiGenerated: true,
    ),
  ];

  // ── GET /v1/amulets/my 대응 Mock 보유 목록(user_amulets) ──
  final List<UserAmuletModel> _myAmulets = [
    UserAmuletModel(
      id: 'ua_001',
      item: _shopItems[0],
      status: UserAmuletStatus.held,
      acquiredAt: DateTime.now().subtract(const Duration(days: 2)),
      sourceType: 'purchase',
      isEquipped: true,
    ),
    UserAmuletModel(
      id: 'ua_002',
      item: _shopItems[2],
      status: UserAmuletStatus.held,
      acquiredAt: DateTime.now().subtract(const Duration(days: 5)),
      sourceType: 'luckybag',
    ),
  ];

  /// 기존(홈 배너 요약용) - 변경 없음
  Future<ApiResult<AmuletSummary>> getActiveSummary() async {
    await mockDelay(ms: 300);
    final seed = DateTime.now().day;
    final hasActive = seed % 4 != 0;
    return ApiResult.ok(
      AmuletSummary(
        hasActive: hasActive,
        name: _names[seed % _names.length],
        iconEmoji: _icons[seed % _icons.length],
      ),
    );
  }

  /// GET /v1/amulets/shop
  Future<ApiResult<List<AmuletItemModel>>> getShopItems() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_shopItems));
  }

  /// GET /v1/amulets/my - 보유 목록(컬렉션)
  Future<ApiResult<List<UserAmuletModel>>> getMyAmulets() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_myAmulets));
  }

  /// POST /v1/amulets/purchase - 구매(Wallet spend는 Provider단에서 연동)
  Future<ApiResult<UserAmuletModel>> purchase(String itemId) async {
    await mockDelay(ms: 400);
    final item = _shopItems.where((i) => i.id == itemId).firstOrNull;
    if (item == null) {
      return ApiResult.fail('존재하지 않는 상품입니다.');
    }
    final userAmulet = UserAmuletModel(
      id: 'ua_${_myAmulets.length + 1}',
      item: item,
      status: UserAmuletStatus.held,
      acquiredAt: DateTime.now(),
      sourceType: 'purchase',
    );
    _myAmulets.insert(0, userAmulet);
    return ApiResult.ok(userAmulet);
  }

  /// POST /v1/amulets/:id/use - 사용 처리(amulet_usage_logs 기록 대응)
  Future<ApiResult<void>> use(String userAmuletId) async {
    await mockDelay(ms: 300);
    final idx = _myAmulets.indexWhere((a) => a.id == userAmuletId);
    if (idx == -1) return ApiResult.fail('보유하지 않은 부적입니다.');
    if (_myAmulets[idx].status != UserAmuletStatus.held) {
      return ApiResult.fail('이미 사용되었거나 만료된 부적입니다.');
    }
    _myAmulets[idx] = _myAmulets[idx].copyWith(
      status: UserAmuletStatus.used,
      isEquipped: false,
    );
    return ApiResult.ok(null);
  }

  /// POST /v1/amulets/:id/equip - 장착(동시 장착 제한 1개 - 정책값 Mock)
  Future<ApiResult<void>> equip(String userAmuletId) async {
    await mockDelay(ms: 300);
    final idx = _myAmulets.indexWhere((a) => a.id == userAmuletId);
    if (idx == -1) return ApiResult.fail('보유하지 않은 부적입니다.');
    if (_myAmulets[idx].status != UserAmuletStatus.held) {
      return ApiResult.fail('사용/만료된 부적은 장착할 수 없습니다.');
    }
    for (var i = 0; i < _myAmulets.length; i++) {
      _myAmulets[i] = _myAmulets[i].copyWith(isEquipped: i == idx);
    }
    return ApiResult.ok(null);
  }

  /// POST /v1/amulets/generate - AI 생성형 부적 생성 요청(ai_request_logs 대응)
  Future<ApiResult<UserAmuletModel>> generate(String baseItemId) async {
    await mockDelay(ms: 900); // AI 생성 특성상 다소 긴 대기 시뮬레이션
    final base = _shopItems.where((i) => i.id == baseItemId).firstOrNull;
    if (base == null || !base.isAiGenerated) {
      return ApiResult.fail('AI 생성 가능한 상품이 아닙니다.');
    }
    final generated = UserAmuletModel(
      id: 'ua_${_myAmulets.length + 1}',
      item: base,
      status: UserAmuletStatus.held,
      acquiredAt: DateTime.now(),
      sourceType: 'purchase',
    );
    _myAmulets.insert(0, generated);
    return ApiResult.ok(generated);
  }

  /// POST /v1/amulets/gift - 선물하기
  Future<ApiResult<void>> gift(
    String userAmuletId,
    String toUserNickname,
    String? message,
  ) async {
    await mockDelay(ms: 400);
    final idx = _myAmulets.indexWhere((a) => a.id == userAmuletId);
    if (idx == -1) return ApiResult.fail('보유하지 않은 부적입니다.');
    if (_myAmulets[idx].status != UserAmuletStatus.held) {
      return ApiResult.fail('선물할 수 없는 상태의 부적입니다.');
    }
    _myAmulets[idx] = _myAmulets[idx].copyWith(
      status: UserAmuletStatus.gifted,
      isEquipped: false,
    );
    return ApiResult.ok(null);
  }
}
