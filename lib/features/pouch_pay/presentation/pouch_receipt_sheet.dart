// [S5 복주머니 결제] 영수증 바텀시트 — design_handoff_pouch_payment
// PayCheckout.jsx `ReceiptSheet` 1:1 포팅(한지 두루마리 스타일 생략, 기존
// WrC/WrF 팔레트의 .sheet 데코로 대체해 소원방 화면들과 통일감을 유지).
import 'package:flutter/material.dart';

import '../../wishroom/core/theme/wr_theme.dart';
import '../domain/pouch_pay_models.dart';

Future<void> openPouchReceiptSheet(BuildContext context, PouchReceipt r) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => PouchReceiptSheet(receipt: r),
  );
}

class PouchReceiptSheet extends StatelessWidget {
  const PouchReceiptSheet({super.key, required this.receipt});
  final PouchReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final r = receipt;
    final d = r.createdAt;
    final dateStr =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: WrDeco.sheet,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text('領', style: WrF.display(26, color: WrC.glow)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '영수증',
                  style: WrF.mono(size: 11, color: WrC.muted),
                ),
              ),
              const SizedBox(height: 16),
              _row('주문번호', r.orderId),
              const SizedBox(height: 8),
              _row('상품', r.title),
              const SizedBox(height: 8),
              _row('일시', dateStr),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: WrC.line, height: 1),
              ),
              for (final row in r.rows) ...[
                _row(row[0], row[1]),
                const SizedBox(height: 6),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: WrC.line, height: 1),
              ),
              _row('공급가액(추정)', '${r.payNow - r.vat}원'),
              const SizedBox(height: 6),
              _row('부가세(추정)', '${r.vat}원'),
              const SizedBox(height: 6),
              _row('결제금액', '${r.payNow}원', emphasize: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: Semantics(
                  identifier: 'pouch_receipt_close',
                  button: true,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: WrC.line),
                    ),
                    child: Text('닫기', style: WrF.body(14, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
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
}
