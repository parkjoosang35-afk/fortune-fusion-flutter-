// 짧은 영상 보고 복주머니 받기 버튼 — app2/screens-b2.jsx › Shortage의
// `{((app.me.earnToday||{}).ad||0) < AD_LIM && <button className="btn btn-pink"
// onClick={() => { onClose(); app.watchAd(); }}>▶ 짧은 영상 보고 복주머니 +{AD_AMT}
// </button>}` 1:1. AD_LIM(10회) 체크 포함(§11.2 EARN 'ad').
//
// [버그수정 — 전수감사] decor_screen.dart에만 private(_AdEarnButton)으로 구현돼 있었고,
// character_shop_screen.dart의 Shortage 시트는 이 버튼 자체가 완전히 누락돼 있었다.
// 두 화면(그리고 향후 다른 Shortage 재사용처)이 공유할 수 있도록 공개 위젯으로 추출한다.
//
// [버그수정 2 — "나머지 빨리 진행해" 전수재검증] jsx 원본은 `&&` 단락 평가로 한도(10회)
// 소진 시 버튼 자체를 DOM에서 완전히 제거(숨김)한다. 기존 Flutter 구현은 버튼을 항상
// 렌더링하고 disabled+문구만 바꿔 보여주고 있었다 — CHECKLIST.md 항목명 "한도 소진 시
// 진입점 숨김"과 불일치. full이면 SizedBox.shrink()로 완전히 숨겨 1:1 재현한다.
// (참고: WalletSheet의 광고 카드는 jsx pouch2.jsx도 숨기지 않고 opacity+disabled만
// 적용하므로 그쪽은 기존 구현이 이미 올바르다 — 여기 Shortage 전용 수정임.)
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
    if (full) return const SizedBox.shrink(); // jsx: 한도 소진 시 버튼 자체가 사라짐(&& 단락평가)
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
      onPressed: _loading ? null : () async {
        setState(() => _loading = true);
        final res = await p.earn('ad');
        if (mounted) {
          setState(() => _loading = false);
          if (res != null) widget.onDone();
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
      child: Text('▶ 짧은 영상 보고 복주머니 +$amt',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ));
  }
}
