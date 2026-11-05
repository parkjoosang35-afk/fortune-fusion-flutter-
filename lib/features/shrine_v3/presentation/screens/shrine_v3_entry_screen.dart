import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_v3_provider.dart';

/// 신당(THE SHRINE) v3 — 01 입장 화면(임시 골격).
///
/// [진행 상태] 이 파일은 app.dart/app_router.dart/app_shell.dart의
/// forward-reference를 해소하기 위한 최소 골격이다. README.md §1~§9 전체
/// 스펙(10개 화면 + 5개 오버레이, 02~10 실제 연출/로직)은 아직 이 화면
/// 안에 구현되지 않았다 — 다음 작업 세션에서 이 파일을 실제 01 입장
/// 연출로 교체하고, 02~10 화면 파일을 추가로 생성해 Navigator.push 체인으로
/// 연결해야 한다.
class ShrineV3EntryScreen extends StatefulWidget {
  const ShrineV3EntryScreen({super.key});

  @override
  State<ShrineV3EntryScreen> createState() => _ShrineV3EntryScreenState();
}

class _ShrineV3EntryScreenState extends State<ShrineV3EntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShrineV3Provider>().loadCatalog();
      context.read<ShrineV3Provider>().loadBox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineV3Provider>();
    const paper = Color(0xFFFAF3E0);
    const ink = Color(0xFF1F150C);
    const seal = Color(0xFF8B2F22);

    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: ink,
        foregroundColor: paper,
        title: const Text('신당부적'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.temple_buddhist, color: seal, size: 56),
                const SizedBox(height: 16),
                Text(
                  '신당(神堂)',
                  style: TextStyle(
                    color: paper,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.isLoading
                      ? '불러오는 중...'
                      : provider.error != null
                      ? provider.error!
                      : '부적 ${provider.catalog.length}종 · 보관 중 ${provider.boxItems.length}개',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
