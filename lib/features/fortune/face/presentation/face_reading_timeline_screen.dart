// [v7 통합 — Option B] FaceAnalyzingScreen → (이 화면) → FaceResultScreen.
// FaceProvider의 현재 성공 상태를 ReadingArtifact로 변환해 부위별 타이핑
// 리딩 화면(ReadingTimelineScreen)에 넘기는 얇은 연결 화면. FaceProvider/
// analyze()/결과화면 라우팅은 전혀 변경하지 않는다(기존 시스템 유지 원칙).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/domain/reading_artifact_builder.dart';
import '../../shared/presentation/reading_timeline_screen.dart';
import '../../sintong/widgets/sintong_screen_bg.dart';
import '../application/face_provider.dart';

class FaceReadingTimelineScreen extends StatelessWidget {
  const FaceReadingTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FaceProvider>().state;
    final result = state.data;
    if (result == null) {
      // 방어적 안전망(이론상 analyze() 성공 직후에만 진입하므로 발생하지
      // 않음) — 결과가 없으면 결과 화면으로 바로 보낸다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(
            context,
          ).pushReplacementNamed('/ai-fortune/face/result');
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
    final artifact = ReadingArtifactBuilder.fromFace(result);
    return ReadingTimelineScreen(
      artifact: artifact,
      onFinished: () => Navigator.of(context).pushReplacementNamed(
        '/ai-fortune/face/result',
        arguments: result.id,
      ),
    );
  }
}
