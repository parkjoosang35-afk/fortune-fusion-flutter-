// 신통방통 정통사주 v3 — 로딩 화면 (4단계 UX ③)
// 사주보기 클릭 → 팩트+69종 패치 완료 후 상세 화면으로 교체
//
// [Option 2 이식] 원본 ConsumerStatefulWidget(riverpod)을 StatefulWidget +
// provider 패키지(context.read<SajuV3Provider>())로 재작성. go_router 대신
// Navigator.pushReplacement 사용.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/saju_v3_provider.dart';
import '../domain/birth_input.dart';
import 'jeontong69_detail_screen.dart';
import 'jeontong_v3_theme.dart';

class Jeontong69LoadingScreen extends StatefulWidget {
  final BirthInput birth;
  final String targetCode;
  const Jeontong69LoadingScreen({
    super.key,
    required this.birth,
    required this.targetCode,
  });

  @override
  State<Jeontong69LoadingScreen> createState() =>
      _Jeontong69LoadingScreenState();
}

class _Jeontong69LoadingScreenState extends State<Jeontong69LoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<SajuV3Provider>();
    await provider.loadAll69(widget.birth);
    if (!mounted) return;

    final state = provider.all69State;
    if (state.isError) {
      // 오류는 build()에서 provider.all69State를 다시 구독해 표시한다
      // (별도 로컬 상태를 두지 않고 Provider 단일 소스를 그대로 사용).
      setState(() {});
      return;
    }
    final all = state.data;
    final item = all?.items[widget.targetCode];
    if (item == null) {
      setState(() {});
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => Jeontong69DetailScreen(
          all: all!,
          item: item,
          birth: widget.birth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SajuV3Provider>(
      builder: (context, provider, _) {
        final state = provider.all69State;
        String? error;
        if (state.isError) {
          error = state.errorMessage;
        } else if (state.isSuccess &&
            state.data?.items[widget.targetCode] == null) {
          error = '해당 운세를 찾을 수 없습니다 (${widget.targetCode})';
        }

        return Scaffold(
          backgroundColor: Jt3Colors.inkBlack,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (error == null) ...[
                  const CircularProgressIndicator(color: Jt3Colors.royalGold),
                  const SizedBox(height: 24),
                  const Text(
                    '사주를 불러오는 중 ✦',
                    style: TextStyle(color: Jt3Colors.softGold, fontSize: 16),
                  ),
                ] else ...[
                  const Icon(
                    Icons.error_outline,
                    color: Jt3Colors.amethyst,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Jt3Colors.moonSilver,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          '돌아가기',
                          style: TextStyle(color: Jt3Colors.moonSilver),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _load,
                        child: const Text(
                          '다시 시도',
                          style: TextStyle(color: Jt3Colors.royalGold),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
