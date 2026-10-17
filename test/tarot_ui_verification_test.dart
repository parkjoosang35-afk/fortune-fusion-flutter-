// [진행] 타로 3대 요구사항(①AI리딩 문구 교체 ②포지션 카드 탭-확대 상세 ③78장
// 풀덱 진열) 코드 레벨 검증용 위젯 테스트.
//
// 배경: 실제 카드 뽑기(TarotRepository._draw)는 서버(POST
// /api/public/fortune/tarot) 왕복이 필요하고, 카테고리 상세 화면의 "시작하기"
// 버튼은 navigateWithPassGate(requiresPass: true)로 로그인 게이트가 걸려있어
// (pass_gate_helper.dart) 프로덕션 Playwright 클릭-스루로는 로그인 없이 카드
// 선택/결과 화면까지 도달할 수 없다. 이 테스트는 TarotProvider/
// TarotSessionController에 결과 데이터를 직접 주입해, 로그인·백엔드 없이도
// 위젯 트리 레벨에서 3가지 변경사항이 실제로 렌더링되는지 검증한다.
import 'dart:ui' as ui;
import 'dart:io' show Platform, File;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_app/core/util/original_result_capture.dart';
import 'package:flutter_app/features/fortune/tarot/application/tarot_audio_controller.dart';
import 'package:flutter_app/features/fortune/tarot/application/tarot_provider.dart';
import 'package:flutter_app/features/fortune/tarot/application/tarot_session_controller.dart';
import 'package:flutter_app/features/fortune/tarot/data/tarot_repository.dart';
import 'package:flutter_app/features/fortune/tarot/domain/tarot_model.dart';
import 'package:flutter_app/features/fortune/tarot/presentation/tarot_card_select_screen.dart';
import 'package:flutter_app/features/fortune/tarot/presentation/tarot_result_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// 테스트 전용 결과 3장(과거/현재/미래) 픽스처.
TarotResultModel _buildFixtureResult() {
  const cardPast = TarotCard(
    id: 'past_1',
    name: 'The Fool',
    nameKr: '바보',
    isReversed: false,
  );
  const cardPresent = TarotCard(
    id: 'present_1',
    name: 'The Sun',
    nameKr: '태양',
    isReversed: false,
  );
  const cardFuture = TarotCard(
    id: 'future_1',
    name: 'The Star',
    nameKr: '별',
    isReversed: true,
  );
  return TarotResultModel(
    id: 'fixture_result_1',
    question: '올해 나의 연애운은 어떨까요?',
    spreadType: 'three_card',
    positions: const [
      TarotSpreadPosition(
        label: '과거',
        card: cardPast,
        interpretation: '과거에는 두려움 없이 새로운 시작을 했던 흔적이 보입니다.',
      ),
      TarotSpreadPosition(
        label: '현재',
        card: cardPresent,
        interpretation: '현재는 밝고 긍정적인 에너지가 넘치는 시기입니다.',
      ),
      TarotSpreadPosition(
        label: '미래',
        card: cardFuture,
        interpretation: '미래는 희망이 잠시 흐려질 수 있으니 마음을 다잡아야 합니다.',
      ),
    ],
    summary: '전반적으로 긍정적인 흐름이 이어지는 카드 풀이입니다.',
    createdAt: DateTime(2026, 1, 1),
    topic: 'love',
  );
}

Widget _wrapWithProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => TarotProvider(TarotRepository())),
      ChangeNotifierProvider(create: (_) => TarotSessionController()),
      ChangeNotifierProvider(create: (_) => TarotAudioController()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Flutter SDK 루트를 현재 실행 중인 dart-sdk 경로에서 동적으로 유도한다.
    // 샌드박스/로컬/CI마다 SDK 설치 위치(/opt/flutter, /home/user/flutter 등)가
    // 다를 수 있으므로 절대경로를 하드코딩하지 않는다.
    // 예: .../flutter/bin/cache/dart-sdk/bin/dart -> .../flutter
    final dartExe = Platform.resolvedExecutable.replaceAll('\\', '/');
    const marker = '/bin/cache/dart-sdk/bin/dart';
    final flutterRoot = dartExe.endsWith(marker)
        ? dartExe.substring(0, dartExe.length - marker.length)
        : null;
    // 이 테스트는 find.byIcon(IconData)으로만 아이콘을 검증하며 이는 실제 글리프
    // 렌더링이 필요 없다. MaterialIcons 폰트 로드는 시각 검증 보강용 선택 사항이므로
    // 경로를 찾지 못하거나 파일이 없어도 테스트 전체를 막지 않는다.
    if (flutterRoot != null) {
      final fontFile = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (fontFile.existsSync()) {
        try {
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              fontFile.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await icons.load();
        } catch (_) {
          // 폰트 로드 실패는 치명적이지 않음(아이콘 매칭은 IconData 기반).
        }
      }
    }
    // 위젯시험 기본 Ahem 대신 앱 번들 한글 폰트를 기본 폴백에 로드. 운영 설정은 변경하지 않음.
    final fallback = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await fallback.load();
    final korean = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await korean.load();
  });
  setUp(() {
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global/events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (call) async {
            if (call.method == 'create') {
              final id = (call.arguments as Map)['playerId'];
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockMethodCallHandler(
                    MethodChannel('xyz.luan/audioplayers/events/$id'),
                    (_) async => null,
                  );
            }
            return null;
          });
    }
  });
  group('[진행] 타로 결과화면 - AI 리딩 문구 교체 + 탭-확대 상세', () {
    testWidgets('① "AI 리딩"/"AI 한마디" 문구가 화면 어디에도 남아있지 않다', (tester) async {
      final result = _buildFixtureResult();

      await tester.pumpWidget(
        _wrapWithProviders(
          Builder(
            builder: (context) {
              // 위젯 빌드 직후 provider에 결과를 직접 주입(서버 호출 없이).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<TarotProvider>().debugInjectResult(result);
              });
              return const TarotResultScreen();
            },
          ),
        ),
      );

      // 리빌 애니메이션(3600ms) + 콘텐츠 애니메이션(2600ms) 종료까지 시간을 흘려보낸다.
      // [주의] OzBackground의 별빛 반짝임(OzStarField)은 무한 Ticker로 계속
      // 리페인트되므로 pumpAndSettle()은 절대 안정화되지 않는다(타임아웃).
      // 반드시 유한한 pump(duration)만 사용한다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      // "AI 리딩"/"AI 한마디" 텍스트가 어디에도 없어야 한다.
      expect(find.textContaining('AI 리딩'), findsNothing);
      expect(find.textContaining('AI 한마디'), findsNothing);

      // 대신 새 라벨("카드 풀이")이 실제 화면(_AiReadingCard 섹션 헤더)에
      // 표시돼야 한다. (참고: "카드의 속삭임"은 TarotResultView.defaultSections
      // 정적 메타데이터에만 존재하고 화면에서 직접 순회 렌더링되지 않으므로
      // 여기서는 검증 대상에서 제외한다 - AI 한마디 카드 자체는 🌙 아이콘 +
      // aiClosing 본문만 그려지고 별도 라벨 텍스트를 그리지 않는다.)
      expect(find.textContaining('카드 풀이'), findsWidgets);
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
        final context = tester.element(find.byType(TarotResultScreen));
        for (final position in result.positions) {
          await precacheImage(
            AssetImage(position.card.thumbAssetPath),
            context,
          );
        }
      });
      await tester.pump();
      final body = tester.widget<OriginalResultBody>(
        find.byType(OriginalResultBody),
      );
      final footer = tester.widget<OriginalResultScene>(
        find.byType(OriginalResultScene),
      );
      final bodySize =
          (body.captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .size;
      final footerSize =
          (footer.captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .size;
      // Tooltip을 포함하는 기존 투명 상단 RepaintBoundary만 선택.
      final overlayFinder = find
          .ancestor(
            of: find.byTooltip('뒤로가기'),
            matching: find.byWidgetPredicate(
              (widget) => widget is RepaintBoundary && widget.key is GlobalKey,
            ),
          )
          .first;
      expect(overlayFinder, findsOneWidget);
      final overlay =
          tester.widget<RepaintBoundary>(overlayFinder).key! as GlobalKey;
      // [사용자 요청 — 외부 검수 지시 ④ hang 수정, story_detail_screen_c07_test.dart와
      // 동일 원인] captureOriginalResult 내부의
      // `Future<void>.delayed(120ms)`가 tester.runAsync() 밖(FakeAsync
      // 테스트 zone)에서 생성되면 가상 시계가 전진하기 전까지 영원히
      // 완료되지 않는다(실제 재현: 수정 전 41초+ 동일 테스트명 반복
      // 출력, hang 확정). 명시적 pump(duration)로 가상 시계를 전진시켜
      // 해소한다.
      //
      // [근본 원인 규명 및 해결 — RGBA 1~3-unit 바이트 불일치]
      // 실측 진단(동일 RenderRepaintBoundary를 같은 시점에 2회 toImage() →
      // diff=0, canvas.drawImage() 재합성 전후 비교 → diff=0)으로 배경
      // 애니메이션의 순수 래스터화와 captureOriginalResult의 재합성/PNG
      // 인코딩 단계는 완전히 결정론적임을 확인했다. 즉 화면과 캡처
      // 유틸리티 모두 결함이 아니다.
      //
      // 진짜 원인은 "두 캡처 시점의 불일치"였다. tester.pump(duration) 한
      // 번의 호출 안에서 (1) 가상 시계를 전진시켜 대기 중인 Timer(여기서는
      // captureOriginalResult 내부의 Future.delayed(120ms))를 먼저
      // 처리하고, 그 다음 (2) 전진된 시간으로 새 프레임의
      // build/layout/paint(= OzBackground의 OzStarField가 무한 Ticker
      // 콜백으로 새 _t 값에 따라 별빛 반짝임을 다시 그림)를 수행한다.
      // 따라서 captureOriginalResult 내부의 toImage() 호출은 (1) 시점,
      // 즉 그 프레임이 새로 그려지기 *직전*의 레이어를 캡처하는 반면,
      // 기존 코드는 pump(200ms)가 완전히 끝난 *이후*에야 비교용
      // toImage()를 별도로 호출했기 때문에 (2)에서 이미 _t가 전진해
      // 새로 그려진 레이어를 캡처했다 — 그 사이 별빛 하나의 opacity가
      // 미세하게 달라져 RGBA 바이트가 1~3 정도 어긋난 것이다.
      //
      // 해결(테스트 전용, 제품 코드/판정 규칙 변경 없음, 허용오차 도입
      // 없음): 비교용 toImage() 호출을 captureOriginalResult와 동일한
      // 시점에 "발급(dispatch)"한다. toImage()는 호출 시점에 이미
      // 컴포지트돼 있는 레이어를 기준으로 캡처를 시작하고 실제 완료
      // (resolve)는 나중에 비동기로 이뤄지므로, Future 생성 자체를
      // 아래 pump(duration) 호출 *이전*(즉 captureOriginalResult를 막
      // 호출한 직후, 아직 어떤 프레임도 새로 그려지기 전)으로 당기면
      // 두 캡처가 완전히 동일한 레이어를 가리키게 된다. 완료 대기(await)
      // 는 기존과 동일하게 tester.runAsync() 안에서 수행해 FakeAsync
      // 테스트 zone 밖의 실제 비동기 처리를 허용한다.
      final bodyBoundary =
          body.captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final footerBoundary =
          footer.captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final overlayBoundary =
          overlay.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final png = captureOriginalResult(
        body.captureKey,
        trailingKeys: [footer.captureKey],
        overlayKeys: [overlay],
      );
      // captureOriginalResult와 동일한 레이어 상태를 캡처하기 위해, 아래
      // pump(duration)으로 가상 시계를 전진시키기 *전에* toImage()를
      // 호출해 Future를 미리 발급받는다(완료 대기는 뒤에서 runAsync 안에서
      // 수행).
      final originalBodyFuture = bodyBoundary.toImage(pixelRatio: 1.5);
      final originalFooterFuture = footerBoundary.toImage(pixelRatio: 1.5);
      final originalOverlayFuture = overlayBoundary.toImage(pixelRatio: 1.5);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async {
        final bytes = await png;
        if (Platform.environment['EXPORT_TAROT_FIXTURE'] == '1') {
          await File(
            '/tmp/opencode/tarot-result-fixture.png',
          ).writeAsBytes(bytes);
        }
        final codec = await ui.instantiateImageCodec(bytes);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, (bodySize.width * 1.5).ceil());
        expect(
          image.height,
          (bodySize.height * 1.5).ceil() + (footerSize.height * 1.5).ceil(),
        );
        expect(image.height, greaterThan(900));
        final output = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final originalBody = await originalBodyFuture;
        final originalFooter = await originalFooterFuture;
        final originalOverlay = await originalOverlayFuture;
        try {
          final bodyPixels = (await originalBody.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final footerPixels = (await originalFooter.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final overlayPixels = (await originalOverlay.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          // 상단 겹침 영역 밖 본문과 하단은 모든 RGBA 바이트를 비교한다.
          final bodyStart = originalOverlay.height * image.width * 4;
          final bodyEnd = originalBody.height * image.width * 4;
          expect(
            output.sublist(bodyStart, bodyEnd),
            orderedEquals(bodyPixels.sublist(bodyStart)),
          );
          expect(output.sublist(bodyEnd), orderedEquals(footerPixels));
          int opaque = 0;
          for (int i = 0; i < overlayPixels.length; i += 4) {
            if (overlayPixels[i + 3] != 255) continue;
            opaque++;
            expect(
              output.sublist(i, i + 4),
              orderedEquals(overlayPixels.sublist(i, i + 4)),
            );
          }
          expect(opaque, greaterThan(0));
        } finally {
          originalBody.dispose();
          originalFooter.dispose();
          originalOverlay.dispose();
        }
        image.dispose();
        codec.dispose();
      });
      expect(tester.takeException(), null);
    });

    testWidgets('② 과거/현재/미래 포지션 카드를 탭하면 확대된 상세 시트가 열린다', (tester) async {
      final result = _buildFixtureResult();

      await tester.pumpWidget(
        _wrapWithProviders(
          Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<TarotProvider>().debugInjectResult(result);
              });
              return const TarotResultScreen();
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      // "과거" 라벨이 붙은 포지션 카드를 찾아 탭한다.
      final pastLabelFinder = find.text('과거');
      expect(pastLabelFinder, findsWidgets);

      final pastCardFinder = find
          .ancestor(of: pastLabelFinder.first, matching: find.byType(InkWell))
          .first;
      // [진행] 결과화면 콘텐츠는 ListView(가상 스크롤)로 렌더링되므로, "과거"
      // 포지션 카드가 위젯 트리에는 존재하더라도 현재 뷰포트 밖(스크롤 필요)에
      // 있으면 탭 히트테스트가 실패한다. ensureVisible()로 먼저 스크롤해
      // 화면 안으로 가져온 뒤 탭한다.
      await tester.ensureVisible(pastCardFinder);
      await tester.pump();
      await tester.tap(pastCardFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 상세 시트가 열리고, 그 안에 원래 포지션 interpretation 전문이 표시돼야
      // 한다. [_openDetail]이 PageRouteBuilder(opaque: false)를 쓰기 때문에
      // 원래 결과화면의 _PositionCard도 뒤에 그대로 남아있어(비-opaque 라우트),
      // 동일 텍스트가 "결과화면 원본 카드"+"상세 시트" 2곳에서 발견되는 것이
      // 정상 동작이다 - findsWidgets(1개 이상)로 검증한다.
      expect(
        find.textContaining('과거에는 두려움 없이 새로운 시작을 했던 흔적이 보입니다.'),
        findsWidgets,
      );
      // 심화 관점 섹션 헤더도 함께 표시돼야 한다(상세 시트에만 존재하는 신규 콘텐츠).
      expect(find.textContaining('더 깊이 들여다보면'), findsOneWidget);

      // 닫기 버튼으로 상세 시트를 닫으면 원래 결과화면으로 복귀한다.
      final closeButton = find.byIcon(Icons.close_rounded);
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        await tester.tapAt(const Offset(20, 20));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
    });
  });

  group('[진행] 타로 카드 선택화면 - 78장 풀덱 진열', () {
    testWidgets(
      '③ confirmQuestion 직후 deckSlots가 78개이고 화면에 78개의 OzFaceDownCard가 그려진다',
      (tester) async {
        late TarotSessionController session;

        await tester.pumpWidget(
          _wrapWithProviders(
            Builder(
              builder: (context) {
                session = context.read<TarotSessionController>();
                return const TarotCardSelectScreen();
              },
            ),
          ),
        );

        // 질문 확정을 직접 트리거해 78장 슬롯을 생성한다(서버 호출 없음).
        session.confirmQuestion(
          spreadType: 'three_card',
          question: '올해 나의 연애운은 어떨까요?',
          topic: 'love',
        );

        expect(session.state.deckSlots.length, 78);

        // 셔플 상태를 건너뛰고 바로 카드 선택 대기 상태로 전이시킨다.
        session.beginShuffle();
        session.shuffleFinished();

        await tester.pump();
        await tester.pump(const Duration(seconds: 2));

        // 실제로 화면에 78개의 카드 뒷면 위젯이 모두 그려졌는지 확인한다.
        // [정정] 진열 타일은 리팩터링으로 OzFaceDownCardArt(테두리 없는 순수
        // 뒷면 아트)를 렌더한다. 이전 위젯명 기대는 시험만 늦게 따라온 것으로,
        // 앱 렌더가 아니라 시험 기대가 오래된 것이었다(78개 0관측 원인).
        final faceDownFinder = find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == 'OzFaceDownCard' ||
              widget.runtimeType.toString() == 'OzFaceDownCardArt',
        );
        expect(faceDownFinder, findsNWidgets(78));
      },
    );
  });
}
