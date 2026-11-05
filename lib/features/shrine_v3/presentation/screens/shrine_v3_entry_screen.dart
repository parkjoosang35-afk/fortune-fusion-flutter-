import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/shrine_v3_provider.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/shrine_asset_path.dart';
import 'shrine_v3_gate_screen.dart';

/// 신당(THE SHRINE) v3 — 01 입장 화면.
///
/// [README §1 01 입장] 신당 외경 이미지 + 로고 + "신당으로 들어가기" CTA.
/// 비로그인 상태에서도 자유롭게 들어올 수 있다(탐색 자유 원칙) — 로그인/
/// 실명 확인은 05→07 전환(결제 게이트) 직전에만 강제한다.
class ShrineV3EntryScreen extends StatefulWidget {
  const ShrineV3EntryScreen({super.key});

  @override
  State<ShrineV3EntryScreen> createState() => _ShrineV3EntryScreenState();
}

class _ShrineV3EntryScreenState extends State<ShrineV3EntryScreen> {
  @override
  void initState() {
    super.initState();
    // 03 메인/04 직접고르기/06 추천받기가 공용으로 쓰는 카탈로그를 미리
    // 당겨둔다(비로그인에서도 호출 가능 — 인증 불필요 엔드포인트).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ShrineV3Provider>();
      if (provider.catalog.isEmpty) {
        provider.loadCatalog();
      }
    });
  }

  void _enter() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShrineV3GateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShrineV3Colors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            shrineSceneImage('entry'),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: ShrineV3Colors.ink),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.55),
                  ShrineV3Colors.ink,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(),
                Text(
                  '神堂',
                  style: ShrineV3TextStyles.title.copyWith(
                    color: ShrineV3Colors.gold,
                    fontSize: 15,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '신당',
                  style: ShrineV3TextStyles.title.copyWith(
                    color: ShrineV3Colors.paper,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '당신의 소망을 들려주세요.',
                    textAlign: TextAlign.center,
                    style: ShrineV3TextStyles.body.copyWith(
                      color: ShrineV3Colors.paper,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '민세레나가 당신만을 위한 부적을 씁니다',
                  style: ShrineV3TextStyles.ui.copyWith(
                    color: ShrineV3Colors.paper.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _enter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ShrineV3Colors.seal,
                        foregroundColor: ShrineV3Colors.paper,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        '신당으로 들어가기 ›',
                        style: ShrineV3TextStyles.body.copyWith(
                          color: ShrineV3Colors.paper,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
