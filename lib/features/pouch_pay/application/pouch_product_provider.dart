// [Google Play Billing 실연동 — 2026-11-26] admin_web PouchProduct 카탈로그를
// 캐시하는 얇은 Provider. 기존 화면(PouchStoreScreen/PouchCheckoutScreen)은
// 여전히 `pouch_pay_catalog.dart`의 하드코딩 상수(kPouchPacks)로 UI를 그리되,
// 체크아웃 시점에만 이 Provider로 서버 googlePlayProductId 등록 여부를
// 조회해 실결제/모의결제 분기를 결정한다(화면 UI 전면 재작성 없이 안전하게
// 실연동을 얹기 위한 점진적 설계 — 관리자가 상품 가격을 바꿔도 이 Provider만
// 다시 로드하면 반영됨).
import 'package:flutter/foundation.dart';
import '../data/pouch_product_repository.dart';

class PouchProductProvider extends ChangeNotifier {
  final PouchProductRepository _repository;
  PouchProductProvider(this._repository);

  List<PouchProductModel> _products = [];
  bool _loaded = false;

  List<PouchProductModel> get products => _products;
  bool get isLoaded => _loaded;

  /// clientId(p100 등, PouchPack.id와 동일 체계)로 서버 상품 조회.
  PouchProductModel? findByClientId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    final result = await _repository.getProducts();
    if (result.success) {
      _products = result.data!;
      _loaded = true;
      notifyListeners();
    }
  }
}
