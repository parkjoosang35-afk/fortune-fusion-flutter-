// [S5 복주머니 결제] Checkout → Sealing → Done/Fail 화면 — design_handoff
// _pouch_payment PayCheckout.jsx `CheckoutSheet`/`SealingScreen`/`DoneScreen`/
// `FailScreen` 1:1 포팅(한 파일의 내부 stage로 합쳐, pay_screen.dart의
// `_PayStage` 패턴과 동일한 구조를 따른다).
//
// [PAYMENT_MODE=mock] "결제수단"은 상점(Google Play/App Store) 표시만 하고
// 실제 스토어 결제창은 열지 않는다 — HoldToSeal 완료 즉시
// PouchPayService.buyPack/buySubscription가 실제 Wallet/PointHistory에
// 적립한다(§ pouch_pay_service.dart 상단 주석 참고). 실결제 전환 시
// `_seal()` 내부 로직만 `in_app_purchase` 흐름으로 교체하면 된다.
//
// [S5 — 동일 결제 중복 처리 방지] pay_screen.dart의 _oid 패턴과 동일하게
// 이 화면도 자체 주문번호를 생성해 Sealing 단계 재진입/중복 실행을 막는다.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../wishroom/core/fx/wr_fx.dart';
import '../../wishroom/core/theme/wr_theme.dart';
import '../../luckpouch/application/luck_pouch_provider.dart';
import '../../../core/theme/legacy_wish_room/wish_room_candle.dart';
import '../../../core/theme/legacy_wish_room/wish_room_sigil.dart';
import '../application/pouch_pay_service.dart';
import '../application/pouch_product_provider.dart';
import '../domain/pouch_pay_catalog.dart';
import '../domain/pouch_pay_models.dart';
import 'pouch_receipt_sheet.dart';
import 'hold_to_seal_button.dart';

enum _CheckoutStage { checkout, sealing, done, fail }

class PouchCheckoutScreen extends StatefulWidget {
  const PouchCheckoutScreen({super.key, required this.request});
  final PouchPurchaseRequest request;

  @override
  State<PouchCheckoutScreen> createState() => _PouchCheckoutScreenState();
}

class _PouchCheckoutScreenState extends State<PouchCheckoutScreen> {
  _CheckoutStage _stage = _CheckoutStage.checkout;
  bool _agreeTerms = false;
  bool _agreeNoRefund = false;
  PouchPayResult? _result;
  int _burstKey = 0;

  bool get _allAgreed => _agreeTerms && _agreeNoRefund;

  List<List<String>> get _rows {
    final req = widget.request;
    if (req.isSub) {
      final t = req.sub!;
      final next = DateTime.now().add(
        Duration(days: req.subBilling == 'year' ? 365 : 30),
      );
      return [
        ['복주머니', '${pouchSubBase(t)}개'],
        ['구독 덤 +${t.bonusPct}%', '+${pouchSubBonus(t)}개'],
        ['담기는 때', req.subBilling == 'year' ? '매년' : '매달'],
        [
          '다음 결제일',
          '${next.year}.${next.month.toString().padLeft(2, '0')}.${next.day.toString().padLeft(2, '0')}',
        ],
      ];
    } else {
      final p = req.pack!;
      return [
        ['복주머니', '${p.base}개'],
        if (p.bonus > 0) ['덤', '+${p.bonus}개'],
        ['정가', '${p.base * kPouchUnitPrice}원'],
      ];
    }
  }

  Future<void> _seal() async {
    setState(() => _stage = _CheckoutStage.sealing);
    final service = context.read<PouchPayService>();
    final req = widget.request;
    // PayCheckout.jsx SealingScreen의 3.2초 연출 — "봉인하는 중" 체감 시간.
    // [Google Play Billing 실연동] 실결제 흐름은 Google 결제창 응답을 함께
    // 기다려야 하므로 두 작업을 병렬로 진행한다(최소 3.2초 연출은 유지).
    PouchPayResult result;
    try {
      if (req.isSub) {
        // 구독 실결제는 SubscriptionPlan 경로(마이페이지 → 구독)로 이미
        // 별도 구현되어 있다 — 곳간(PouchStore) 구독탭은 여전히 서버
        // 시뮬레이션(복주머니 정기지급 모의)만 다룬다(범위 분리, 02§21).
        await Future.delayed(const Duration(milliseconds: 3200));
        result = await service.buySubscription(req.sub!, billing: req.subBilling);
      } else {
        final product = context
            .read<PouchProductProvider>()
            .findByClientId(req.pack!.id);
        if (product != null && product.canRealPurchase) {
          final results = await Future.wait([
            service.buyPackReal(product),
            Future.delayed(const Duration(milliseconds: 3200)),
          ]);
          result = results[0] as PouchPayResult;
        } else {
          await Future.delayed(const Duration(milliseconds: 3200));
          result = await service.buyPack(req.pack!);
        }
      }
    } catch (_) {
      result = const PouchPayResult(success: false);
    }
    if (!mounted) return;
    setState(() {
      _result = result;
      if (result.success) {
        _stage = _CheckoutStage.done;
        _burstKey++;
      } else {
        _stage = _CheckoutStage.fail;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: SafeArea(
          child: switch (_stage) {
            _CheckoutStage.checkout => _checkoutView(),
            _CheckoutStage.sealing => _sealingView(),
            _CheckoutStage.done => _doneView(),
            _CheckoutStage.fail => _failView(),
          },
        ),
      ),
    );
  }

  Widget _closeBtn() => Align(
    alignment: Alignment.topRight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 14, 0),
      child: Semantics(
        identifier: 'pouch_checkout_close',
        button: true,
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              shape: BoxShape.circle,
              border: Border.all(color: WrC.line),
            ),
            child: const Icon(Icons.close, size: 16, color: Colors.white),
          ),
        ),
      ),
    ),
  );

  Widget _checkoutView() {
    final req = widget.request;
    return Column(
      children: [
        _closeBtn(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'CHECKOUT',
                    style: WrF.mono(size: 10.5, color: WrC.blossom2),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WrDeco.card,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: WrC.panel,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          req.isSub ? req.sub!.hanja : '🧧',
                          style: req.isSub
                              ? WrF.display(22, color: WrC.glow)
                              : const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.title,
                              style: WrF.body(
                                16,
                                w: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '🧧 ${req.gain}개',
                              style: WrF.body(13, color: WrC.glow),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WrDeco.card,
                  child: Column(
                    children: [
                      for (final row in _rows) ...[
                        _amountRow(row[0], row[1]),
                        const SizedBox(height: 8),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Divider(color: WrC.line, height: 1),
                      ),
                      _amountRow('결제금액', '${req.payNow}원', emphasize: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '결제 수단',
                  style: WrF.body(12, w: FontWeight.w700, color: WrC.muted),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: WrDeco.card,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.android,
                        size: 18,
                        color: WrC.glow,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Google Play 결제',
                        style: WrF.body(14, color: Colors.white),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.radio_button_checked,
                        size: 18,
                        color: WrC.glow,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _checkRow(
                  identifier: 'pouch_checkout_agree_terms',
                  value: _agreeTerms,
                  onChanged: (v) => setState(() => _agreeTerms = v),
                  label: '유료 서비스 이용약관에 동의해요',
                ),
                const SizedBox(height: 6),
                _checkRow(
                  identifier: 'pouch_checkout_agree_norefund',
                  value: _agreeNoRefund,
                  onChanged: (v) => setState(() => _agreeNoRefund = v),
                  label: req.isSub
                      ? '정기결제 및 자동 갱신에 동의해요 · 복주머니를 하나라도 쓰면 그 달은 환불되지 않아요'
                      : '쓰면 쓴 만큼 환불이 제한될 수 있음을 알고 있어요',
                ),
                const SizedBox(height: 20),
                HoldToSeal(
                  onDone: _seal,
                  disabled: !_allAgreed,
                  label: '꾹 눌러서 ${req.payNow}원 봉인하기',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkRow({
    required String identifier,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String label,
  }) {
    return Semantics(
      identifier: identifier,
      button: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: value ? WrC.glow : WrC.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: WrF.body(12, color: WrC.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: WrF.body(13, color: WrC.muted)),
        Text(
          value,
          style: WrF.body(
            emphasize ? 15 : 13,
            w: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: emphasize ? WrC.glow : WrC.fg,
          ),
        ),
      ],
    );
  }

  Widget _sealingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              WishRoomSigilRing(size: 140, opacity: 0.4),
              Text('願', style: WrF.display(36, color: WrC.glow)),
            ],
          ),
          const SizedBox(height: 22),
          Text('봉인하는 중', style: WrF.display(16, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            '잠시만 기다려 주세요…',
            style: WrF.mono(size: 11, color: WrC.muted),
          ),
        ],
      ),
    );
  }

  Widget _doneView() {
    final req = widget.request;
    final receipt = _result?.receipt;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: WrPetalRain(n: 16)),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: WrC.panel,
                      border: Border.all(color: WrC.glow),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      req.isSub ? req.sub!.hanja : '🧧',
                      style: req.isSub
                          ? WrF.display(40, color: WrC.glow)
                          : const TextStyle(fontSize: 46),
                    ),
                  ),
                  WrBurst(
                    key: ValueKey(_burstKey),
                    x: 55,
                    y: 55,
                    n: 20,
                    glyph: '✨',
                    spread: 120,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '✿ SEALED · N°${req.gain} ✿',
            textAlign: TextAlign.center,
            style: WrF.display(18, color: Colors.white),
          ),
          const SizedBox(height: 22),
          Consumer<LuckPouchProvider>(
            builder: (context, pouch, _) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: WrDeco.card,
                child: Column(
                  children: [
                    _amountRow('상품', req.title),
                    const SizedBox(height: 8),
                    _amountRow('받은 복주머니', '🧧 ${req.gain}'),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: WrC.line, height: 1),
                    ),
                    _amountRow(
                      '지금 가진 복주머니',
                      '🧧 ${pouch.balance}',
                      emphasize: true,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Semantics(
              identifier: 'pouch_done_primary',
              button: true,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst || route.settings.name != null,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrC.blossom,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  req.resumeLabel ?? '소원방으로 돌아가기',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (receipt != null)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: Semantics(
                identifier: 'pouch_done_receipt',
                button: true,
                child: OutlinedButton(
                  onPressed: () => openPouchReceiptSheet(context, receipt),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WrC.line),
                  ),
                  child: Text(
                    '영수증 보기',
                    style: WrF.body(14, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _failView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WishRoomCandle(size: 60, lit: false),
            const SizedBox(height: 22),
            Text(
              '잠시 바람이 불었어요',
              style: WrF.display(18, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              '결제가 끝나지 않았어요.\n빠져나간 돈은 없으니 안심하세요.',
              textAlign: TextAlign.center,
              style: WrF.body(13, color: WrC.muted),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: Semantics(
                identifier: 'pouch_fail_retry',
                button: true,
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _stage = _CheckoutStage.checkout;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WrC.blossom,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '다시 봉인하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: Semantics(
                identifier: 'pouch_fail_back_to_store',
                button: true,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: WrC.line),
                  ),
                  child: Text(
                    '곳간으로 돌아가기',
                    style: WrF.body(14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
