// [미리보기 — 사용자 요청 2026-10-14] 모두의 소원방 화면의 실제 렌더를
// 골든 이미지로 남겨 사용자에게 배치(정렬칩 위치 등)를 보여주기 위한 시험.
// 갱신: flutter test --update-goldens test/explore_golden_preview_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/explore/explore_screen.dart';

/// 테스트 환경(Ahem 폰트)에서 한글이 네모로 깨지지 않도록 나눔스퀘어 폰트를
/// 앱이 쓰는 모든 패밀리명으로 로딩한다.
Future<void> _loadKoFonts() async {
  const path = '/usr/share/fonts/truetype/nanum/NanumSquareR.ttf';
  final data = File(path).readAsBytesSync().buffer.asByteData();
  for (final family in [
    'Pretendard',
    'NotoSerifKR',
    'GowunBatang',
    'IBMPlexMono',
  ]) {
    final loader = FontLoader(family)..addFont(Future.value(data));
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('모두의 소원방: 정렬칩이 이루어진 이야기 탭 옆(탭 행 우측)에 보인다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _loadKoFonts();
    await WrCatalog.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => WishRoomProvider(ApiRepository()),
          child: const ExploreScreen(),
        ),
      ),
    );
    // 네트워크 응답(비로그인 → 오류/빈 피드)이 도착해 화면이 안정될 때까지 펌프.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await expectLater(
      find.byType(ExploreScreen),
      matchesGoldenFile('goldens/explore_preview.png'),
    );
  });
}
