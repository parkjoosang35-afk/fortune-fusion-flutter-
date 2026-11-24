// [S5 복주머니 결제 — PAYMENT_MODE=mock] 영수증/구독상태 로컬 캐시.
// 실결제 전환 전까지는 admin_web에 orders/subscriptions 테이블이 없으므로,
// "방금 산 것"을 영수증 화면에 다시 보여주거나 곳간 화면에 구독 배지를
// 띄우기 위한 최소 표시용 정보만 기기 로컬(shared_preferences)에 둔다.
// ⚠️ 실제 잔액(진짜 돈의 가치를 가진 숫자)은 여기 저장하지 않는다 — 그건
// 전부 서버 Wallet/PointHistory(LuckPouchProvider 경유)가 단일 소스다.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/pouch_pay_models.dart';

class PouchPayLocalStore {
  PouchPayLocalStore._();
  static final PouchPayLocalStore I = PouchPayLocalStore._();

  static const _kReceipts = 'pouch_pay_receipts';
  static const _kSub = 'pouch_pay_subscription';

  List<PouchReceipt> _receipts = [];
  PouchSubscriptionState? _subscription;
  bool _loaded = false;

  List<PouchReceipt> get receipts => _receipts;
  PouchSubscriptionState? get subscription => _subscription;
  bool get hasActiveSub => _subscription != null;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_kReceipts) ?? const [];
    _receipts = raw
        .map((s) => PouchReceipt.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    final subRaw = p.getString(_kSub);
    if (subRaw != null) {
      _subscription = PouchSubscriptionState.fromJson(
        jsonDecode(subRaw) as Map<String, dynamic>,
      );
    }
    _loaded = true;
  }

  Future<void> addReceipt(PouchReceipt r) async {
    _receipts = [r, ..._receipts].take(30).toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _kReceipts,
      _receipts.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  PouchReceipt? findReceipt(String orderId) {
    for (final r in _receipts) {
      if (r.orderId == orderId) return r;
    }
    return null;
  }

  Future<void> setSubscription(PouchSubscriptionState? s) async {
    _subscription = s;
    final p = await SharedPreferences.getInstance();
    if (s == null) {
      await p.remove(_kSub);
    } else {
      await p.setString(_kSub, jsonEncode(s.toJson()));
    }
  }

  /// 로그아웃 시 계정 격리 원칙에 따라 메모리 상태를 초기화한다(파일 자체는
  /// 그대로 두되 — 재로그인 시 load()를 다시 부르면 동일 기기의 영수증이
  /// 다시 보이는 것은 모의 모드의 한계로 허용 가능, 실결제 전환 시 서버
  /// 사용자별 주문조회로 대체될 자리).
  void clearMemoryOnLogout() {
    _receipts = [];
    _subscription = null;
    _loaded = false;
  }
}
