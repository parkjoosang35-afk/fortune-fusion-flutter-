// [v7 통합 — Option B] PalmAnalyzingScreen → (이 화면) → PalmResultScreen.
// PalmProvider의 현재 성공 상태를 ReadingArtifact로 변환해 부위별 타이핑
// 리딩 화면(ReadingTimelineScreen)에 넘기는 얇은 연결 화면. PalmProvider/
// analyze()/결과화면 라우팅은 전혀 변경하지 않는다(기존 시스템 유지 원칙).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/domain/reading_artifact_builder.dart';
import '../../shared/presentation/reading_timeline_screen.dart';
import '../../sintong/widgets/sintong_screen_bg.dart';
import '../application/palm_provider.dart';

class PalmReadingTimelineScreen extends StatelessWidget {
  const PalmReadingTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PalmProvider>().state;
    final result = state.data;
    if (result == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(
            context,
          ).pushReplacementNamed('/ai-fortune/palm/result');
        }
      });
      return const Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: SintongScreenBg()),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    final artifact = ReadingArtifactBuilder.fromPalm(result);
    return ReadingTimelineScreen(
      artifact: artifact,
      onFinished: () => Navigator.of(context).pushReplacementNamed(
        '/ai-fortune/palm/result',
        arguments: result.id,
      ),
    );
  }
}
