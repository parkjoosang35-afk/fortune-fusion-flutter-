import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/util/original_result_capture.dart';
import 'package:flutter_app/core/widgets/result_card_stack.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';
import 'package:flutter_app/features/wishroom/data/wr_catalog.dart';
import 'package:flutter_app/features/wishroom/features/complete/complete_screen.dart';

import 'package:flutter_app/core/utils/load_state.dart';
import 'package:flutter_app/features/fortune/face/application/face_provider.dart';
import 'package:flutter_app/features/fortune/face/data/face_repository.dart';
import 'package:flutter_app/features/fortune/face/domain/face_model.dart';
import 'package:flutter_app/features/fortune/face/presentation/face_result_screen.dart';
import 'package:flutter_app/features/fortune/palm/application/palm_provider.dart';
import 'package:flutter_app/features/fortune/palm/data/palm_repository.dart';
import 'package:flutter_app/features/fortune/palm/domain/palm_model.dart';
import 'package:flutter_app/features/fortune/palm/presentation/palm_result_screen.dart';
import 'package:flutter_app/features/fortune/tarot/presentation/oz/widgets/oz_background.dart';

class _FaceFixture extends FaceProvider {
  _FaceFixture() : super(FaceRepository());
  @override
  LoadState<FaceResultModel> get state => LoadState.success(
    FaceResultModel(
      id: 'face-fixture',
      features: {'이마': List.filled(180, '원래 해석 ').join(), '끝부위': '마지막 본문'},
      topicResults: {},
      summary: '관상 원본',
      createdAt: DateTime(2026, 10, 13),
    ),
  );
}

class _PalmFixture extends PalmProvider {
  _PalmFixture() : super(PalmRepository());
  @override
  LoadState<PalmResultModel> get state => LoadState.success(
    PalmResultModel(
      id: 'palm-fixture',
      lines: {'생명선': List.filled(180, '원래 해석 ').join(), '끝선': '마지막 본문'},
      topicResults: {},
      summary: '손금 원본',
      createdAt: DateTime(2026, 10, 13),
    ),
  );
}

class _UnusedWishRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('시험 중 서버 변경 금지: ${invocation.memberName}');
}

void main() {
  testWidgets('부가 캡처 키가 없어도 준비된 본문은 저장한다', (tester) async {
    final body = GlobalKey();
    final missing = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: RepaintBoundary(
      key: body, child: const SizedBox(width: 200, height: 300, child: ColoredBox(color: Colors.blue)),
    )));
    await tester.pump();
    // [행잉 버그 수정 — 외부 검수 지시 ④] captureOriginalResult 내부에
    // Future.delayed(120ms)(커밋 6bf2f13)가 추가된 뒤로는, runAsync() 밖에서
    // 호출부터 만들고 결과만 안에서 await하는 과거 패턴이 FakeAsync 타임존에
    // 타이머를 등록해버려 해당 타이머가 영원히 발동하지 않아 테스트가
    // 무한 행(hang)된다. 반드시 호출 자체를 runAsync() 콜백 안으로 옮겨야 한다.
    final bytes = await tester.runAsync(
      () => captureOriginalResult(body, leadingKeys: [missing], overlayKeys: [missing]),
    );
    expect(bytes, isNotNull);
    expect(bytes!.isNotEmpty, isTrue);
  });

  testWidgets('투명 상단 버튼 캡처는 본문 위에 겹치고 전체 높이를 늘리지 않는다', (tester) async {
    final body = GlobalKey();
    final overlay = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              OriginalResultBody(
                captureKey: body,
                background: Colors.blue,
                child: const SizedBox(width: 300, height: 1200),
              ),
              RepaintBoundary(
                key: overlay,
                child: const SizedBox(
                  width: 300,
                  height: 40,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: ColoredBox(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // [행잉 버그 수정 — 외부 검수 지시 ④] 아래 §1 설명과 동일한 이유로
    // captureOriginalResult() 호출을 runAsync() 콜백 안으로 이동.
    await tester.runAsync(() async {
      final capture = captureOriginalResult(body, overlayKeys: [overlay]);
      final codec = await ui.instantiateImageCodec(await capture);
      final image = (await codec.getNextFrame()).image;
      expect(image.height, 1800);
      expect(image.width, 450);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(
        pixels.getUint8((10 * 450 + 10) * 4),
        (Colors.red.toARGB32() >> 16) & 255,
      );
      expect(
        pixels.getUint8((10 * 450 + 150) * 4 + 2),
        Colors.blue.toARGB32() & 255,
      );
      image.dispose();
      codec.dispose();
    });
    expect(tester.takeException(), null);
  });
  testWidgets('타로 기존 그라디언트 별빛 배경을 전체본문 캡처 내부에 포함', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginalResultBody(
            captureKey: key,
            background: Colors.transparent,
            frame: (child) =>
                Stack(children: [const OzBackground(twinkle: false), child]),
            child: const SizedBox(width: 390, height: 1400),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(key), matching: find.byType(OzStarField)),
      findsOneWidget,
    );
    // [행잉 버그 수정 — 외부 검수 지시 ④] captureOriginalResult() 호출을
    // runAsync() 콜백 안으로 이동(상단 §1 설명 참고).
    await tester.runAsync(() async {
      final capture = captureOriginalResult(key);
      final codec = await ui.instantiateImageCodec(await capture);
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final x = image.width ~/ 2;
      int channel(int y, int c) =>
          pixels.getUint8((y * image.width + x) * 4 + c);
      expect(channel(50, 3), 255);
      expect(channel(image.height - 50, 3), 255);
      expect(
        [channel(50, 0), channel(50, 1), channel(50, 2)],
        isNot(
          equals([
            channel(image.height - 50, 0),
            channel(image.height - 50, 1),
            channel(image.height - 50, 2),
          ]),
        ),
      );
      expect(image.height, 2100);
      image.dispose();
      codec.dispose();
    });
    expect(tester.takeException(), null);
  });
  testWidgets('전체 본문 뒤 실제 하단 액션 영역 픽셀과 높이 보존', (tester) async {
    final body = GlobalKey();
    final footer = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: OriginalResultBody(
                  captureKey: body,
                  background: Colors.blue,
                  child: const SizedBox(width: 300, height: 1200),
                ),
              ),
              OriginalResultScene(
                captureKey: footer,
                background: Colors.green,
                child: const SizedBox(width: 300, height: 60),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // [행잉 버그 수정 — 외부 검수 지시 ④] captureOriginalResult() 호출을
    // runAsync() 콜백 안으로 이동(상단 §1 설명 참고).
    await tester.runAsync(() async {
      final capture = captureOriginalResult(body, trailingKeys: [footer]);
      final codec = await ui.instantiateImageCodec(await capture);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 450);
      expect(image.height, 1890);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(
        pixels.getUint8((1850 * 450 + 150) * 4 + 1),
        (Colors.green.toARGB32() >> 8) & 255,
      );
      image.dispose();
      codec.dispose();
    });
    expect(tester.takeException(), null);
  });
  for (final face in [true, false]) {
    testWidgets('${face ? '관상' : '손금'} 실제 화면 상단바·전체 프레임 캡처 연결', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = face ? _FaceFixture() : _PalmFixture();
      await tester.pumpWidget(
        face
            ? ChangeNotifierProvider<FaceProvider>.value(
                value: provider as FaceProvider,
                child: const MaterialApp(home: FaceResultScreen()),
              )
            : ChangeNotifierProvider<PalmProvider>.value(
                value: provider as PalmProvider,
                child: const MaterialApp(home: PalmResultScreen()),
              ),
      );
      await tester.pumpAndSettle();
      final scene = tester.widget<OriginalResultScene>(
        find.byType(OriginalResultScene),
      );
      final stack = tester.widget<ResultCardStack>(
        find.byType(ResultCardStack),
      );
      expect(stack.captureFrame, isNotNull);
      // 비공개 프레임의 이름에 의존하지 않고 두 개의 실제 ClipRRect 중첩 방지.
      final bodyBoundary = find.byKey(stack.captureKey!);
      expect(
        find.descendant(of: bodyBoundary, matching: find.byType(ClipRRect)),
        findsNothing,
      );
      final paperContainers = find.descendant(
        of: bodyBoundary,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.clipBehavior == Clip.antiAlias &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).borderRadius ==
                  const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
        ),
      );
      expect(paperContainers, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(OriginalResultScene),
          matching: find.text(face ? '觀相 · REPORT' : '手紋 · REPORT'),
        ),
        findsOneWidget,
      );
      final headerSize =
          (scene.captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .size;
      final bodySize =
          (stack.captureKey!.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .size;
      expect(headerSize.width, bodySize.width);
      expect(bodySize.height, greaterThan(844));
      // [행잉 버그 수정 — 외부 검수 지시 ④] captureOriginalResult() 호출을
      // runAsync() 콜백 안으로 이동(상단 §1 설명 참고).
      await tester.runAsync(() async {
        final capture = captureOriginalResult(
          stack.captureKey!,
          leadingKeys: [scene.captureKey],
        );
        final codec = await ui.instantiateImageCodec(await capture);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 585);
        expect(
          image.height,
          (headerSize.height * 1.5).ceil() + (bodySize.height * 1.5).ceil(),
        );
        image.dispose();
        codec.dispose();
      });
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  }
  testWidgets('고정 상단과 전체본문 원래 픽셀을 확대 왜곡 없이 한 PNG로 연결', (tester) async {
    final header = GlobalKey();
    final body = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              OriginalResultScene(
                captureKey: header,
                background: Colors.red,
                child: const SizedBox(width: 300, height: 40),
              ),
              Expanded(
                child: OriginalResultBody(
                  captureKey: body,
                  background: Colors.blue,
                  child: const SizedBox(width: 300, height: 1200),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // [행잉 버그 수정 — 외부 검수 지시 ④] captureOriginalResult() 호출을
    // runAsync() 콜백 안으로 이동(상단 §1 설명 참고).
    await tester.runAsync(() async {
      final capture = captureOriginalResult(body, leadingKeys: [header]);
      final bytes = await capture;
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 450);
      expect(image.height, 1860);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(
        pixels.getUint8((10 * 450 + 150) * 4),
        (Colors.red.toARGB32() >> 16) & 255,
      );
      expect(
        pixels.getUint8((1800 * 450 + 150) * 4 + 2),
        Colors.blue.toARGB32() & 255,
      );
      image.dispose();
      codec.dispose();
    });
    expect(tester.takeException(), null);
  });
  testWidgets('이미 봉인된 소원 재진입: 봉인 장면 원본 저장 공유 유지', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => WrCatalog.load());
    final provider = WishRoomProvider(_UnusedWishRepository())
      ..room = WishRoom.fromJson({
        'id': 'local-sealed',
        'ownerId': 'local-owner',
        'owner': '검증자',
        'text': '봉인 원문 표식',
        'char': 'F01',
        'status': 'SEALED',
        'devotionCount': 12,
        'supportCount': 3,
        'pouchReceived': 2,
        'level': 10,
        'points': 10000,
        'levelName': '완성',
        'curLevelPts': 10000,
        'brightness': 1,
        'daysLit': 7,
      });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: CompleteScreen(roomId: 'local-sealed', already: true),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final sceneFinder = find.byType(OriginalResultScene);
    expect(sceneFinder, findsOneWidget);
    expect(find.text('축하합니다'), findsNothing);
    expect(
      find.descendant(
        of: sceneFinder,
        matching: find.text('소원 기록관에\n영원히 머뭅니다'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sceneFinder, matching: find.text('결과 그대로 저장')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sceneFinder, matching: find.text('기념 이미지 공유하기')),
      findsOneWidget,
    );
    final scene = tester.widget<OriginalResultScene>(sceneFinder);
    final boundary =
        scene.captureKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    expect(boundary.size, const Size(390, 844));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      expect(
        (await image.toByteData(format: ui.ImageByteFormat.png))!.lengthInBytes,
        greaterThan(1000),
      );
      image.dispose();
    });
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets('소원 완료 실제 장면: 배경·축하문구·원문카드·저장공유가 같은 캡처 경계', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => WrCatalog.load());
    final provider = WishRoomProvider(_UnusedWishRepository())
      ..room = WishRoom.fromJson({
        'id': 'local-wish',
        'ownerId': 'local-owner',
        'owner': '검증자',
        'text': '완료 원문 표식',
        'char': 'F01',
        'status': 'COMPLETED',
        'devotionCount': 12,
        'supportCount': 3,
        'pouchReceived': 2,
        'level': 10,
        'points': 10000,
        'levelName': '완성',
        'curLevelPts': 10000,
        'brightness': 1,
        'daysLit': 7,
      });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: CompleteScreen(roomId: 'local-wish', already: true),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final sceneFinder = find.byType(OriginalResultScene);
    expect(sceneFinder, findsOneWidget);
    for (final text in ['축하합니다', '완료 원문 표식', '결과 그대로 저장', '기념 이미지 공유하기']) {
      expect(
        find.descendant(of: sceneFinder, matching: find.text(text)),
        findsOneWidget,
      );
    }
    final scene = tester.widget<OriginalResultScene>(sceneFinder);
    final boundary =
        scene.captureKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    expect(boundary.size, const Size(390, 844));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes!.lengthInBytes, greaterThan(1000));
      expect(image.width, 390);
      expect(image.height, 844);
      image.dispose();
    });
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
  testWidgets('원래 카드 위젯 전체 높이 배치와 위·아래 픽셀 색 보존', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OriginalResultBody(
            captureKey: key,
            background: Colors.black,
            child: Column(
              children: const [
                SizedBox(
                  width: 300,
                  height: 400,
                  child: ColoredBox(color: Colors.red),
                ),
                SizedBox(
                  width: 300,
                  height: 400,
                  child: ColoredBox(color: Colors.blue),
                ),
                SizedBox(
                  width: 300,
                  height: 400,
                  child: ColoredBox(color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    expect(boundary.size.height, 1200);
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int channel(int y, int c) =>
          pixels.getUint8((y * image.width + 150) * 4 + c);
      expect(channel(10, 0), (Colors.red.toARGB32() >> 16) & 255);
      expect(channel(500, 2), Colors.blue.toARGB32() & 255);
      expect(channel(1100, 1), (Colors.green.toARGB32() >> 8) & 255);
      expect(image.height, 1200);
      image.dispose();
    });
  });
  testWidgets('실제 ResultCardStack 마지막 원래 섹션까지 캡처 높이에 포함', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultCardStack(
            captureKey: key,
            heroCaption: '종합 관상',
            heroSummary: '원래 요약',
            sections: List.generate(
              12,
              (i) => ResultSection(
                title: '부위$i',
                body: List.filled(80, '전체 해석 ').join(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
          .size
          .height,
      greaterThan(2000),
    );
    await tester.scrollUntilVisible(
      find.text('부위11'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('부위11'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
