import 'package:flutter/material.dart';

import '../../domain/shrine_order.dart';
import '../theme/shrine_v3_theme.dart';
import 'shrine_v3_box_screen.dart';

/// 신당(THE SHRINE) v3 — 08 결과. [order]는 서버가 이미 계산한 唯一
/// 값(일련번호/사주/만료일/남은일수)을 그대로 표시만 한다.
class ShrineV3ResultScreen extends StatelessWidget {
  const ShrineV3ResultScreen({super.key, required this.order});

  final ShrineOrder order;

  @override
  Widget build(BuildContext context) {
    final t = order.talisman;
    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('成 · 부적이 완성되었어요', style: ShrineV3TextStyles.mono.copyWith(fontSize: 12)),
                const SizedBox(height: 16),
                TalismanThumbByRef(ref: t, width: 112),
                const SizedBox(height: 16),
                Text(t.name, style: ShrineV3TextStyles.title.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text('唯一 · 세상에 한 장뿐인 부적', style: ShrineV3TextStyles.ui.copyWith(fontSize: 12)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ShrineV3Colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ShrineV3Colors.line),
                  ),
                  child: Column(
                    children: [
                      _row('이름', order.ownerName),
                      _row('사주 팔자', order.sajuPillars),
                      _row('담은 소망', order.wish),
                      _row('지은 날', order.issuedDateKey),
                      _row('일련번호', order.serial),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ShrineV3Colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShrineV3Colors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('소지 기간', style: ShrineV3TextStyles.ui.copyWith(fontSize: 11)),
                          Text(
                            '${order.daysRemaining}일 · ${order.expiresDateKey}까지',
                            style: ShrineV3TextStyles.body.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                      Text('소지 중', style: ShrineV3TextStyles.body.copyWith(fontSize: 13, color: ShrineV3Colors.jade)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const ShrineV3BoxScreen()),
                      (route) => route.isFirst,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShrineV3Colors.seal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('부적함에 보관하기 ›'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(label, style: ShrineV3TextStyles.ui.copyWith(fontSize: 12))),
        Expanded(child: Text(value, style: ShrineV3TextStyles.body.copyWith(fontSize: 13))),
      ],
    ),
  );
}

/// [ShrineOrderTalismanRef]용 썸네일(카탈로그 [TalismanItem] 전체 로드 없이
/// 주문 응답에 포함된 축약 필드만으로 그릴 수 있게 하는 보조 위젯).
class TalismanThumbByRef extends StatelessWidget {
  const TalismanThumbByRef({super.key, required this.ref, required this.width});
  final ShrineOrderTalismanRef ref;
  final double width;

  @override
  Widget build(BuildContext context) {
    final path = ref.thumbPath ?? ref.imagePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/shrine_v3/$path',
        width: width,
        height: width * 2.3,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: width * 2.3,
          color: ShrineV3Colors.paperDark,
          alignment: Alignment.center,
          child: Text(ref.hanja, style: ShrineV3TextStyles.title.copyWith(fontSize: width * 0.4, color: ShrineV3Colors.seal)),
        ),
      ),
    );
  }
}
