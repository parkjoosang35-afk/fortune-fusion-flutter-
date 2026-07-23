import 'dart:math';
import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/giftcard_model.dart';

/// 06§4.10 `/v1/giftcards/*` 대응 Mock Repository
/// 04A 도메인J(상품권/쿠폰) J-1(products)/J-2(issues)/J-3(usages) 우선 구현.
/// J-4~J-7(취소/환불/재발급/만료로그)은 Phase14-2에서 추가.
class GiftcardRepository {
  final List<GiftcardProductModel> _products = [
    GiftcardProductModel(
      id: 'gc_001',
      name: '아메리카노 Tall',
      brand: '스타벅스',
      requiredPoint: 4500,
      stockCount: 20,
      validDays: 365,
      imageEmoji: '☕',
    ),
    GiftcardProductModel(
      id: 'gc_002',
      name: '5,000원 모바일 상품권',
      brand: 'GS25',
      requiredPoint: 5000,
      stockCount: 15,
      validDays: 180,
      imageEmoji: '🏪',
    ),
    GiftcardProductModel(
      id: 'gc_003',
      name: '문화상품권 1만원',
      brand: '문화상품권',
      requiredPoint: 10000,
      stockCount: 8,
      validDays: 365,
      imageEmoji: '🎟️',
    ),
    GiftcardProductModel(
      id: 'gc_004',
      name: '치킨 세트 교환권',
      brand: 'BBQ',
      requiredPoint: 18000,
      stockCount: 0,
      validDays: 90,
      imageEmoji: '🍗',
    ),
    GiftcardProductModel(
      id: 'gc_005',
      name: '배스킨라빈스 파인트',
      brand: '배스킨라빈스',
      requiredPoint: 9000,
      stockCount: 12,
      validDays: 180,
      imageEmoji: '🍨',
    ),
  ];

  final List<GiftcardIssueModel> _issues = [];
  final _random = Random();
  int _issueSeq = 1;

  /// GET /v1/giftcards/products
  Future<ApiResult<List<GiftcardProductModel>>> getProducts() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_products));
  }

  /// POST /v1/giftcards/orders - 교환 요청(포인트 차감은 Provider단에서
  /// WalletProvider.spend와 orchestrate, 02번§1.2 WalletService 단일 인터페이스 원칙)
  /// Mock 단계: 90% 확률로 즉시 발급 성공, 10%는 발급 실패(재고소진 등 시뮬레이션)
  Future<ApiResult<GiftcardIssueModel>> orderProduct(String productId) async {
    await mockDelay(ms: 500);
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return ApiResult.fail('존재하지 않는 상품입니다.');
    final product = _products[index];
    if (!product.inStock) return ApiResult.fail('재고가 모두 소진되었습니다.');

    final succeeded = _random.nextInt(10) < 9;
    final now = DateTime.now();
    final issue = GiftcardIssueModel(
      id: 'gci_${_issueSeq++}',
      product: product,
      pointSpent: product.requiredPoint,
      status: succeeded
          ? GiftcardIssueStatus.issued
          : GiftcardIssueStatus.failed,
      issuedCode: succeeded ? _generateCode() : null,
      issuedAt: succeeded ? now : null,
      expiresAt: succeeded ? now.add(Duration(days: product.validDays)) : null,
    );
    _issues.insert(0, issue);
    if (succeeded) {
      _products[index] = GiftcardProductModel(
        id: product.id,
        name: product.name,
        brand: product.brand,
        requiredPoint: product.requiredPoint,
        stockCount: product.stockCount - 1,
        validDays: product.validDays,
        imageEmoji: product.imageEmoji,
      );
    }
    return ApiResult.ok(issue);
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      12,
      (i) => i > 0 && i % 4 == 0
          ? '-${chars[_random.nextInt(chars.length)]}'
          : chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// GET /v1/giftcards/orders/my
  Future<ApiResult<List<GiftcardIssueModel>>> getMyOrders() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_issues));
  }

  /// POST /v1/giftcards/orders/:id/use - `giftcard_usages`(J-3) 대응 사용처리.
  /// UQ(issue_id) 제약(04A) 반영: 이미 사용된 건은 재사용 불가.
  Future<ApiResult<GiftcardIssueModel>> useIssue(String issueId) async {
    await mockDelay(ms: 300);
    final index = _issues.indexWhere((i) => i.id == issueId);
    if (index == -1) return ApiResult.fail('상품권 내역을 찾을 수 없습니다.');
    final issue = _issues[index];
    if (issue.status != GiftcardIssueStatus.issued) {
      return ApiResult.fail('사용할 수 없는 상태입니다.');
    }
    if (issue.isUsed) return ApiResult.fail('이미 사용된 상품권입니다.');
    if (issue.expiresAt != null && issue.expiresAt!.isBefore(DateTime.now())) {
      return ApiResult.fail('사용 기간이 만료되었습니다.');
    }
    final updated = issue.copyWith(usedAt: DateTime.now());
    _issues[index] = updated;
    return ApiResult.ok(updated);
  }
}
