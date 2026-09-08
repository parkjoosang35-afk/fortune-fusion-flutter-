import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_unified_style.dart';
import '../application/wallet_provider.dart';
import '../../fortune_ad/application/fortune_ad_provider.dart';
import 'wallet_content.dart';

/// 03단계 §3.3 리워드 탭 - WalletScreen(복주머니 잔액/적립·차감 내역)
///
/// [복주머니 화면 재구성] 실제 렌더링은 하단바 "복주머니" 탭(`LuckyBagScreen`)과
/// 공유하는 `WalletContent`에 위임한다(잔액 카드 + 관리자가 등록한 만큼 늘어나는
/// "무료 충전" 카드들 + 접이식 적립/사용 내역).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
      // [신통방통 복주머니 광고 적립 시스템] 지갑 화면 진입 시 노출 가능한
      // 광고 목록을 함께 로드한다(관리자 OFF/기간종료 시 목록이 비어와
      // 카드 자체가 자동으로 숨겨진다 — 재배포 없이 즉시 반영).
      context.read<FortuneAdProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(title: const Text('복주머니 지갑')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => wallet.load(),
          child: ListView(
            padding: const EdgeInsets.all(UnifiedTokens.spaceXl),
            children: const [WalletContent()],
          ),
        ),
      ),
    );
  }
}
