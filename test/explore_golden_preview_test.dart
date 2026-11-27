// [미리보기 — 사용자 요청 2026-10-14] 모두의 소원방 실렌더 골든.
// 네트워크 없이 빈 목록을 반환하는 타입 지정 스텁으로 헤더·탭 행·
// 정렬칩·빛깔 칩의 실제 배치를 검증한다.
// 갱신: flutter test --update-goldens test/explore_golden_preview_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/explore/explore_screen.dart';

/// 모든 메서드가 절대 끝나지 않는 Future — 실네트워크가 FakeAsync를 막는 문제 차단.
class _NeverRepo implements WrRepository {
  @override
  Future<List<WishRoom>> explore({String? cursor}) async => [];

  @override
  Future<List<WrReview>> reviews({bool mine = false}) async => [];

  @override
  dynamic noSuchMethod(Invocation i) => throw UnsupportedError(i.memberName.toString());
}

Future<ByteData> _fontData() async {
  final f = File('/usr/share/fonts/truetype/nanum/NanumSquareR.ttf');
  return ByteData.view(f.readAsBytesSync().buffer);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('모두의 소원방: 탭 행 우측 정렬칩 배치 미리보기', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // [핵심 수정] 실(Real-time) 비동기가 필요한 폰트·카탈로그 로딩은 runAsync로
    // FakeAsync 밖에서 실행해야 시험이 멈추지 않는다.
    await tester.runAsync(() async {
      final data = await _fontData();
      for (final family in [
        'Pretendard',
        'NotoSerifKR',
        'GowunBatang',
        'IBMPlexMono',
      ]) {
        final loader = FontLoader(family)..addFont(Future.value(data));
        await loader.load();
      }
      await WrCatalog.load();
    });
    print('PREVIEW: 폰트·카탈로그 로드 완료');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => WishRoomProvider(_NeverRepo()),
          child: const ExploreScreen(),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    print('PREVIEW: 펌프 완료 — 골든 캡처 시작');
    await expectLater(
      find.byType(ExploreScreen),
      matchesGoldenFile('goldens/explore_preview.png'),
    );
    print('PREVIEW: 골든 저장 완료');
  }, timeout: Timeout(Duration(minutes: 3)));
}
