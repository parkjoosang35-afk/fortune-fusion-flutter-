// app3/pay.jsx › Pay3 1:1 포팅 — 소원방 전체가 공유하는 단일 결제창.
//
// [v5 S2 — "2번 진행할 때 지킬 것" ② "구매 로직은 1벌만"] 수호자 탭(자세히 시트)과
// 상점(ShopScreen)이 반드시 이 화면 하나만 호출해야 한다. 실제 구매 API 호출
// (buyCharacter/buyOutfit/buyItem/wearNamedOutfit)은 호출부가 [PayOrder.onConfirmPay]로
// 주입하지만, confirm→paying→done 3단계 흐름과 화면 구성(금액 내역 · 부족 안내 ·
// 영수증 · after 콜백)은 전부 이 파일 하나가 전담한다 — 구매 버튼과 결제 처리를
// 두 곳에 따로 만들지 말라는 지시를 코드 구조로 강제한다.
//
// [③ 결제 서버 범위] 지금은 기존 구매 API(아이템·수호자·옷)만 쓴다. 유상/무상
// 원장·충전·환불은 S5에서 한다 — 「🧧 N개 충전하기」 버튼은 자리만 두고 토스트로
// "충전은 곧 준비돼요"만 안내한다.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/wishroom_provider.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../../core/wr_toast.dart';
import '../../core/wr_ad_earn_button.dart';
import '../wallet/wallet_sheet.dart';

/// 결제창에 전달하는 "주문" 정보 — app3/pay.jsx `order` prop 1:1.
class PayOrder {
  const PayOrder({
    required this.kind,
    required this.name,
    this.sub,
    this.img,
    this.glyph,
    required this.price,
    required this.doneTitle,
    this.afterLabel,
    this.after,
    required this.onConfirmPay,
  });

  /// app3/pay.jsx `KIND` 매핑 — char→수호자 · outfit→옷 · item→꾸미기 · dispatch→대신 기도.
  final String kind;
  final String name;
  final String? sub;
  final String? img; // asset 경로(없으면 glyph로 대체)
  final String? glyph;
  final int price;
  final String doneTitle;
  /// null이면 done 화면에 "방에 놓으러 가기" 류 버튼을 보여주지 않는다.
  final String? afterLabel;
  final VoidCallback? after;
  /// 실제 구매 API 호출 — 성공 시 true, 실패(복주머니 부족 등) 시 false를 반환해야 한다.
  /// [구매 로직 단일화] 이 콜백 "안쪽"의 provider 메서드만 호출부마다 다르고,
  /// 콜백을 "언제 · 어떻게" 호출하는지는 이 화면이 유일하게 결정한다.
  final Future<bool> Function() onConfirmPay;

  static const Map<String, String> _kindLabel = {
    'char': '수호자',
    'outfit': '옷',
    'item': '꾸미기',
    'dispatch': '대신 기도',
  };
  String get label => _kindLabel[kind] ?? kind;
}

/// 어디서든(수호자 탭 · 상점) 동일하게 호출하는 결제창 오프너.
void openPayScreen(BuildContext context, PayOrder order) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PayScreen(order: order)),
  );
}

enum _PayStage { confirm, paying, done }

class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.order});
  final PayOrder order;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  _PayStage _st = _PayStage.confirm;
  late final String _oid;
  int _paidBefore = 0;
  int _burstKey = 0;

  @override
  void initState() {
    super.initState();
    // app3/pay.jsx `'WR'+Date.now().toString(36)...` 1:1(주문번호).
    _oid =
        'WR${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  }

  Future<void> _pay(int before) async {
    setState(() => _st = _PayStage.paying);
    _paidBefore = before;
    // app3/pay.jsx `setTimeout(()=>F.pay(order,oid), 1500)` 1:1 — 결제 연출 시간.
    await Future.delayed(const Duration(milliseconds: 1500));
    bool ok;
    try {
      ok = await widget.order.onConfirmPay();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      setState(() {
        _st = _PayStage.done;
        _burstKey++;
      });
    } else {
      // app3/pay.jsx catch 분기: confirm으로 롤백 + toast.
      setState(() => _st = _PayStage.confirm);
      final err = context.read<WishRoomProvider>().lastError;
      WrToast.show(context, err?.message ?? '결제에 실패했어요. 다시 시도해 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: wrThemeData(),
      child: Scaffold(
        backgroundColor: WrC.bg2,
        body: SafeArea(
          child: Consumer<WishRoomProvider>(
            builder: (context, p, __) {
              final before = p.me?.pouch ?? 0;
              switch (_st) {
                case _PayStage.paying:
                  return _payingView();
                case _PayStage.done:
                  return _doneView(_paidBefore);
                case _PayStage.confirm:
                  return _confirmView(before);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _closeBtn() => Align(
    alignment: Alignment.topRight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 14, 0),
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
  );

  Widget _thumb(double size) {
    final order = widget.order;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: WrC.card,
        border: Border.all(color: WrC.cardBorder),
        gradient: const RadialGradient(
          colors: [Color(0x40FFDCA0), Colors.transparent],
        ),
      ),
      child: order.img != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                order.img!,
                fit: BoxFit.contain,
                width: size * .8,
                height: size * .8,
                errorBuilder: (_, __, ___) => Text(
                  order.glyph ?? '✦',
                  style: TextStyle(fontSize: size * .4),
                ),
              ),
            )
          : Text(order.glyph ?? '✦', style: TextStyle(fontSize: size * .4)),
    );
  }

  Widget _confirmView(int before) {
    final order = widget.order;
    final lack = math.max(0, order.price - before);
    final after = before - order.price;
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
                    'PAY · ${order.label}',
                    style: WrF.mono(size: 10.5, color: WrC.blossom2),
                  ),
                ),
                const SizedBox(height: 14),
                Center(child: _thumb(104)),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    order.name,
                    style: WrF.display(20, color: Colors.white),
                  ),
                ),
                if (order.sub != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      order.sub!,
                      textAlign: TextAlign.center,
                      style: WrF.body(13, color: WrC.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: WrDeco.card,
                  child: Column(
                    children: [
                      _amountRow('지금 가진 복주머니', '🧧 $before'),
                      const SizedBox(height: 8),
                      _amountRow('이번에 쓸 복주머니', '🧧 ${order.price}'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: WrC.line, height: 1),
                      ),
                      _amountRow(
                        lack > 0 ? '모자란 복주머니' : '결제 뒤 남는 복주머니',
                        '🧧 ${lack > 0 ? lack : after}',
                        emphasize: true,
                        warn: lack > 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (lack > 0) ...[
                  // ③ 결제 서버 범위 — 충전 버튼은 지금은 자리만.
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => WrToast.show(context, '충전 기능은 곧 준비돼요'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x66F5CF6A)),
                      ),
                      child: Text(
                        '🧧 $lack개 충전하기',
                        style: WrF.body(14, w: FontWeight.w700, color: const Color(0xFFFFE7A0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('활동으로 모으기', style: WrF.body(12, w: FontWeight.w700, color: WrC.muted)),
                  const SizedBox(height: 8),
                  WrAdEarnButton(onDone: () => setState(() {})),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => openWalletSheet(context),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
                      child: Text('다른 방법으로 모으기', style: WrF.body(14, color: Colors.white)),
                    ),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _pay(before),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WrC.blossom,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        '🧧 ${order.price}개로 결제하기',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountRow(String label, String value, {bool emphasize = false, bool warn = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: WrF.body(13, color: WrC.muted)),
        Text(
          value,
          style: WrF.body(
            emphasize ? 15 : 13,
            w: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: warn ? const Color(0xFFFF9CBC) : (emphasize ? WrC.glow : WrC.fg),
          ),
        ),
      ],
    );
  }

  Widget _payingView() {
    final order = widget.order;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShakingPouch(size: 86),
          const SizedBox(height: 18),
          Text('${order.label} 결제하는 중', style: WrF.display(16, color: Colors.white)),
          const SizedBox(height: 8),
          Text('주문번호 $_oid', style: WrF.mono(size: 11, color: WrC.muted)),
        ],
      ),
    );
  }

  Widget _doneView(int before) {
    final order = widget.order;
    final after = before - order.price;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _thumb(110),
              WrBurst(key: ValueKey(_burstKey), x: 55, y: 55, n: 20, glyph: '✨', spread: 120),
            ],
          ),
          const SizedBox(height: 18),
          Text(order.doneTitle, textAlign: TextAlign.center, style: WrF.display(20, color: Colors.white)),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: WrDeco.card,
            child: Column(
              children: [
                _amountRow('주문번호', _oid),
                const SizedBox(height: 8),
                _amountRow('상품', order.name),
                const SizedBox(height: 8),
                _amountRow('사용한 복주머니', '🧧 ${order.price}'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: WrC.line, height: 1),
                ),
                _amountRow('남은 복주머니', '🧧 $after', emphasize: true),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (order.afterLabel != null)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  order.after?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WrC.blossom,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  order.afterLabel!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
              child: Text(
                order.afterLabel != null ? '나중에 할게요' : '확인',
                style: WrF.body(14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShakingPouch extends StatefulWidget {
  const _ShakingPouch({required this.size});
  final double size;
  @override
  State<_ShakingPouch> createState() => _ShakingPouchState();
}

class _ShakingPouchState extends State<_ShakingPouch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final angle = (_c.value - .5) * .18;
        return Transform.rotate(
          angle: angle,
          child: Image.asset(
            'assets/wishroom/items/pouch.png',
            width: widget.size,
            errorBuilder: (_, __, ___) => Text('💰', style: TextStyle(fontSize: widget.size * .6)),
          ),
        );
      },
    );
  }
}
