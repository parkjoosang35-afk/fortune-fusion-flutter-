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
//
// [전수검수 2026-10-12 — MAJOR(경제)] 기존 구현은 탭 즉시 `p.earn('ad')`로 광고
// 없이 복주머니를 지급했다(버튼 문구는 "짧은 영상 보고"). WalletSheet._watchAd와
// 동일한 RewardedAd 플로우로 교체하고, 보상량/한도 하드코딩(30/10)도 카탈로그
// 값(WrCatalog.earn)으로 대체해 서버 정책 변경 시 화면이 따라가게 한다.
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../application/wishroom_provider.dart';
import '../../ads_test/domain/admob_ad_ids.dart';
import '../data/wr_catalog.dart';
import 'theme/wr_theme.dart';
import 'wr_toast.dart';

class WrAdEarnButton extends StatefulWidget {
  const WrAdEarnButton({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<WrAdEarnButton> createState() => _WrAdEarnButtonState();
}

class _WrAdEarnButtonState extends State<WrAdEarnButton> {
  bool _loading = false;

  // WalletSheet._watchAd와 동일한 리워디드 광고 플로우 — 시청 완료(rewarded)
  // 콜백에서만 earn('ad')을 호출한다.
  Future<void> _watchAd() async {
    final p = context.read<WishRoomProvider>();
    if (!AdmobAdIds.isSupportedPlatform) {
      WrToast.show(context, '이 플랫폼에서는 광고 시청을 지원하지 않아요');
      return;
    }
    if (_loading) return;
    setState(() => _loading = true);
    await RewardedAd.load(
      adUnitId: AdmobAdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          bool rewarded = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) async {
              ad.dispose();
              if (mounted) setState(() => _loading = false);
              if (rewarded) {
                final res = await p.earn('ad');
                if (mounted && res != null) widget.onDone();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (mounted) setState(() => _loading = false);
            },
          );
          ad.show(onUserEarnedReward: (ad, reward) { rewarded = true; });
        },
        onAdFailedToLoad: (_) {
          if (mounted) setState(() => _loading = false);
          if (mounted) WrToast.show(context, '지금은 광고를 불러올 수 없어요');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WishRoomProvider>();
    final used = p.me?.earnToday['ad'] ?? 0;
    final adSrc = WrCatalog.I.earn.firstWhere(
      (e) => e['id'] == 'ad',
      orElse: () => const {'amount': 30, 'limit': 10},
    );
    final lim = (adSrc['limit'] as num).toInt();
    final amt = (adSrc['amount'] as num).toInt();
    final full = used >= lim;
    if (full) return const SizedBox.shrink(); // jsx: 한도 소진 시 버튼 자체가 사라짐(&& 단락평가)
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
      onPressed: _loading ? null : _watchAd,
      style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
      child: Text('▶ 짧은 영상 보고 복주머니 +$amt',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ));
  }
}
