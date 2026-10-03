// 짧은 영상 보고 복주머니 받기 버튼 — app2/screens-b2.jsx › Shortage의
// `<button className="btn btn-pink" onClick={() => { onClose(); app.watchAd(); }}>
// ▶ 짧은 영상 보고 복주머니 +{AD_AMT}</button>` 1:1. AD_LIM(10회) 체크 포함(§11.2 EARN 'ad').
//
// [버그수정 — 전수감사] decor_screen.dart에만 private(_AdEarnButton)으로 구현돼 있었고,
// character_shop_screen.dart의 Shortage 시트는 이 버튼 자체가 완전히 누락돼 있었다.
// 두 화면(그리고 향후 다른 Shortage 재사용처)이 공유할 수 있도록 공개 위젯으로 추출한다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../application/wishroom_provider.dart';
import 'theme/wr_theme.dart';

class WrAdEarnButton extends StatefulWidget {
  const WrAdEarnButton({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<WrAdEarnButton> createState() => _WrAdEarnButtonState();
}

class _WrAdEarnButtonState extends State<WrAdEarnButton> {
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<WishRoomProvider>();
    final used = p.me?.earnToday['ad'] ?? 0;
    const lim = 10, amt = 30;
    final full = used >= lim;
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
      onPressed: full || _loading ? null : () async {
        setState(() => _loading = true);
        final res = await p.earn('ad');
        if (mounted) {
          setState(() => _loading = false);
          if (res != null) widget.onDone();
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: full ? WrC.darkBtn : WrC.blossom),
      child: Text(full ? '오늘 영상 보기를 모두 썼어요' : '▶ 짧은 영상 보고 복주머니 +$amt',
        style: TextStyle(color: full ? Colors.white54 : Colors.white, fontWeight: FontWeight.w700)),
    ));
  }
}
