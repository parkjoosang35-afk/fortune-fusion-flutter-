// 지갑 시트 — app2/pouch2.jsx › WalletSheet() 1:1. 어디서든(복주머니 pill 탭) 열 수
// 있는 공용 지갑 바텀시트. "짧은 영상 보기"(AdMob RewardedAd) + 5개 일일 미션 +
// 사용처 바로가기 + 전체 내역(보관함 복주머니 탭)으로 이동하는 구조.
//
// [버그수정 — 전수 감사로 발견] 상단 복주머니 pill(main_room_screen.dart › _pouchPill)이
// 탭 핸들러가 전혀 없는 정적 위젯이었다. 원본은 PouchPill({onClick: app.openWallet})로
// 탭하면 이 시트가 열려야 한다. vault_screen.dart의 _PouchTab(보관함 탭의 "복주머니
// 모으기" 전체화면)과 로직은 동일하되, 여기서는 모달 시트 레이아웃으로 축약 재구현한다
// (사용처 바로가기 3개 그리드 추가가 원본과의 차이점).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../application/wishroom_provider.dart';
import '../../data/wr_catalog.dart';
import '../../core/theme/wr_theme.dart';
import '../../core/fx/wr_fx.dart';
import '../characters/character_shop_screen.dart';
import '../../../ads_test/domain/admob_ad_ids.dart';

// 바텀탭 인덱스(wishroom_shell.dart `_tabs` 순서) 1:1 대응. VaultScreen(탭4) 내부
// TabBarView 순서(소원 기록관=0·복주머니=1·응원 보상=2)도 함께 참조한다.
const int _kTabHome = 0;
const int _kTabExplore = 1;
const int _kTabDecor = 3;
const int _kTabVault = 4;
const int _kVaultSubPouch = 1;

/// 어디서든 호출 가능한 지갑 시트 오프너. app2 `app.openWallet()` 1:1 대응.
void openWalletSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const WalletSheet(),
  );
}

const Map<String, String> _kEarnIcon = {
  'ad': '▶', 'attend': '✓', 'devo10': '🙏', 'm_visit': '☾', 'm_cheer': '❤', 'm_msg': '💬',
};
const Map<String, String> _kEarnGo = {
  'm_visit': 'explore', 'm_cheer': 'explore', 'm_msg': 'explore', 'devo10': 'home',
};

class WalletSheet extends StatefulWidget {
  const WalletSheet({super.key});
  @override
  State<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<WalletSheet> {
  bool _adLoading = false;
  int _gotKey = 0;
  int _gotAmount = 0;

  Future<void> _tap(Map<String, dynamic> src) async {
    final id = src['id'] as String;
    if (id == 'ad') {
      await _watchAd();
      return;
    }
    final go = _kEarnGo[id];
    final p = context.read<WishRoomProvider>();
    final today = p.me?.earnToday ?? const <String, int>{};
    final limit = (src['limit'] as num).toInt();
    if (go != null && (today[id] ?? 0) < limit) {
      // pop() 직후 이 시트의 context는 dispose되므로, 참조는 pop 이전에 미리 잡아둔다.
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      if (go == 'home') {
        p.requestTab(_kTabHome);
      } else {
        p.requestTab(_kTabExplore);
      }
      messenger?.showSnackBar(SnackBar(content: Text(
        id == 'devo10' ? '정성을 10번 채우면 자동으로 담겨요' : '미션을 마치면 복주머니가 담겨요')));
      return;
    }
    await _doEarn(id);
  }

  Future<void> _watchAd() async {
    if (!AdmobAdIds.isSupportedPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이 플랫폼에서는 광고 시청을 지원하지 않아요')));
      return;
    }
    if (_adLoading) return;
    setState(() => _adLoading = true);
    await RewardedAd.load(
      adUnitId: AdmobAdIds.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          bool rewarded = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) async {
              ad.dispose();
              if (mounted) setState(() => _adLoading = false);
              if (rewarded) await _doEarn('ad');
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (mounted) setState(() => _adLoading = false);
            },
          );
          ad.show(onUserEarnedReward: (ad, reward) { rewarded = true; });
        },
        onAdFailedToLoad: (_) {
          if (mounted) setState(() => _adLoading = false);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지금은 광고를 불러올 수 없어요')));
        },
      ),
    );
  }

  Future<void> _doEarn(String source) async {
    final p = context.read<WishRoomProvider>();
    final res = await p.earn(source);
    if (!mounted) return;
    if (res != null) {
      setState(() { _gotKey++; _gotAmount = res.$1; });
    } else if (p.lastError != null) {
      final msg = p.lastError!.code == 'EARN_LIMIT' ? '오늘은 모두 받았어요' : p.lastError!.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WishRoomProvider>(builder: (context, p, __) {
      final me = p.me;
      final cat = WrCatalog.I;
      final today = me?.earnToday ?? const <String, int>{};
      final earn = cat.earn;
      final adSrc = earn.firstWhere((e) => e['id'] == 'ad', orElse: () => const {'amount': 30, 'limit': 10});
      final adN = today['ad'] ?? 0;
      final adLim = (adSrc['limit'] as num).toInt();
      final adAmt = (adSrc['amount'] as num).toInt();

      return DraggableScrollableSheet(
        initialChildSize: .84, minChildSize: .5, maxChildSize: .92, expand: false,
        builder: (context, scrollCtrl) => Container(
          decoration: WrDeco.sheet,
          child: ListView(controller: scrollCtrl, padding: const EdgeInsets.fromLTRB(20, 14, 20, 32), children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            // 잔액
            Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                const _BobbingPouchIcon(),
                if (_gotKey > 0) WrBurst(key: ValueKey(_gotKey), x: 39, y: 40, n: 16, glyph: '✨', spread: 90),
              ]),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('내 복주머니', style: WrF.body(11.5, color: WrC.muted)),
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0x26F5CF6A), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x66F5CF6A))),
                    child: Text('신통방통 공용', style: WrF.body(10, color: const Color(0xFFFFE7A0)))),
                ]),
                Text('${me?.pouch ?? 0}', key: ValueKey(me?.pouch), style: WrF.display(36, color: Colors.white)),
                if (_gotKey > 0) Text('+$_gotAmount 담겼어요', key: ValueKey('got$_gotKey'), style: WrF.body(12.5, color: WrC.glow)),
              ])),
            ]),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(12), border: Border.all(color: WrC.line, style: BorderStyle.solid)),
              child: Text('신통방통 어디서 모은 복주머니든 소원방에서 그대로 쓸 수 있어요. 돈으로는 살 수 없어요.',
                style: WrF.body(11.5, color: WrC.muted, height: 1.6))),
            const SizedBox(height: 12),
            // 광고 — 가장 크게
            GestureDetector(
              onTap: adN >= adLim || _adLoading ? null : () => _tap(adSrc),
              child: Opacity(opacity: adN >= adLim ? .5 : 1, child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x47785CFF), Color(0x2EF2628F)]),
                  border: Border.all(color: const Color(0x73B496FF))),
                child: Row(children: [
                  Container(width: 46, height: 46, alignment: Alignment.center,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9A6AFF), Color(0xFF6A3AD8)])),
                    child: _adLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('▶', style: TextStyle(color: Colors.white, fontSize: 18))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('짧은 영상 보고 복주머니 받기', style: WrF.body(14, w: FontWeight.w700, color: WrC.fg)),
                    const SizedBox(height: 5),
                    Row(children: [
                      for (var i = 0; i < adLim; i++)
                        Container(width: 9, height: 4, margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: i < adN ? const Color(0xFFB89AFF) : Colors.white24)),
                      const SizedBox(width: 6),
                      Text('오늘 $adN/$adLim', style: WrF.body(10.5, color: WrC.muted)),
                    ]),
                  ])),
                  Text('+$adAmt', style: WrF.display(15, color: WrC.glow)),
                ]),
              )),
            ),
            const SizedBox(height: 18),
            Text('오늘 모을 수 있는 복', style: WrF.display(14)),
            Text('자정에 다시 채워져요', style: WrF.body(11, color: WrC.muted)),
            const SizedBox(height: 8),
            ...earn.where((e) => e['id'] != 'ad').map((src) {
              final id = src['id'] as String;
              final limit = (src['limit'] as num).toInt();
              final amount = (src['amount'] as num).toInt();
              final n = today[id] ?? 0;
              final done = n >= limit;
              return Padding(padding: const EdgeInsets.only(bottom: 6), child: GestureDetector(
                onTap: done ? null : () => _tap(src),
                child: Opacity(opacity: done ? .5 : 1, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: WrC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: WrC.cardBorder)),
                  child: Row(children: [
                    Container(width: 30, height: 30, alignment: Alignment.center,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), color: done ? Colors.white10 : const Color(0x40F2628F)),
                      child: Text(done ? '✓' : (_kEarnIcon[id] ?? '•'), style: const TextStyle(fontSize: 13))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(src['label'] as String? ?? '', style: WrF.body(13, w: FontWeight.w700, color: WrC.fg)
                      .copyWith(decoration: done ? TextDecoration.lineThrough : null))),
                    Text(done ? '받음' : '+$amount${_kEarnGo[id] != null ? ' ›' : ''}',
                      style: WrF.body(12, w: FontWeight.w700, color: done ? WrC.muted : WrC.glow)),
                  ]),
                )),
              ));
            }),
            const SizedBox(height: 18),
            Text('소원방에서 쓰는 곳', style: WrF.display(14)),
            const SizedBox(height: 8),
            Row(children: [
              _UseCard(icon: '🪷', label: '수호자', value: '300~500', onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CharacterShopScreen()));
              }),
              const SizedBox(width: 6),
              _UseCard(icon: '🏮', label: '꾸미기', value: '50~200', onTap: () {
                Navigator.of(context).pop();
                context.read<WishRoomProvider>().requestTab(_kTabDecor);
              }),
              const SizedBox(width: 6),
              _UseCard(icon: '💰', label: '선물하기', value: '자유롭게', onTap: () {
                Navigator.of(context).pop();
                context.read<WishRoomProvider>().requestTab(_kTabExplore);
              }),
            ]),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<WishRoomProvider>().requestTab(_kTabVault, vaultSubTab: _kVaultSubPouch);
              },
              child: Text('전체 내역 보기 ›', style: WrF.body(12, color: WrC.muted)),
            ),
          ]),
        ),
      );
    });
  }
}

class _BobbingPouchIcon extends StatefulWidget {
  const _BobbingPouchIcon();
  @override
  State<_BobbingPouchIcon> createState() => _BobbingPouchIconState();
}

class _BobbingPouchIconState extends State<_BobbingPouchIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      final dy = -6 * Curves.easeInOut.transform(_c.value);
      return Transform.translate(offset: Offset(0, dy), child: Image.asset('assets/wishroom/items/pouch.png', width: 78,
        errorBuilder: (_, __, ___) => const Text('💰', style: TextStyle(fontSize: 56))));
    });
  }
}

class _UseCard extends StatelessWidget {
  const _UseCard({required this.icon, required this.label, required this.value, required this.onTap});
  final String icon, label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: WrC.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: WrC.cardBorder)),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 3),
        Text(label, style: WrF.body(12, w: FontWeight.w700, color: WrC.fg)),
        Text(value, style: WrF.body(10.5, color: WrC.glow)),
      ]),
    )));
  }
}
