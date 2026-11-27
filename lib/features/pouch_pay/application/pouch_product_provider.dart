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
  // [결제 레이스 컨디션 버그 수정 — 2026-11-27] 앱 시작 직후 화면이 이
  // 비동기 로드를 기다리지 않고 바로 결제 버튼을 누르면, 체크아웃이
  // "아직 로드 중(=값이 비어 있음)"을 "관리자가 아직 등록 안 함"으로
  // 착각해 모의결제(공짜 지급) 경로로 새어버리는 실제 사고가 발생했다
  // (실기기 QA 중 재현됨 — 결제창 없이 바로 "결제 완료" 처리). 동일
  // load()가 이미 진행 중이면 그 Future를 그대로 공유해 중복 호출을
  // 막는다(ensureLoaded()가 안전하게 재사용할 수 있도록).
  Future<void>? _inFlight;

  List<PouchProductModel> get products => _products;
  bool get isLoaded => _loaded;

  /// clientId(p100 등, PouchPack.id와 동일 체계)로 서버 상품 조회.
  PouchProductModel? findByClientId(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final future = _doLoad();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _doLoad() async {
    final result = await _repository.getProducts();
    if (result.success) {
      _products = result.data!;
      _loaded = true;
      notifyListeners();
    }
  }

  /// [결제 레이스 컨디션 버그 수정 — 2026-11-27] 결제 분기를 결정하기
  /// 직전에 반드시 호출해, "서버 카탈로그 로드 완료"를 보장한 뒤에만
  /// findByClientId()의 결과를 신뢰할 수 있게 한다. 이미 로드됐으면 즉시
  /// 반환하고, 아직이면 기다리며, 네트워크 실패 등으로 실패했으면 한 번
  /// 더 재시도한다(최종 실패 시에도 [isLoaded]는 false로 남아 호출부가
  /// "모르는 상태"와 "등록 안 됨"을 구분해 안전하게 처리할 수 있다).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
    if (!_loaded) {
      await load();
    }
  }
}
