import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/config/env_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/share/application/share_service.dart';
import 'package:flutter_app/features/share/domain/share_result_model.dart';

/// [신통방통 앱·웹 공유 근본 정상화 — 2026-11]
///
/// 과거(2026-10-14) 계약: 앱 분기는 원본 PNG를 OS 공유 시트로 직접
/// 전송하고 서버 업로드·공유 링크 생성·동의 팝업이 전혀 없었다.
/// 지시서 §3-A("앱 공유는 반드시 그 결과로 연결되는 공유 링크를 만들어야
/// 한다")에 따라 이 계약 자체가 핵심 버그였음이 확인되어 뒤집혔다 —
/// 이제 앱도 웹과 동일하게 서버에 공유 링크(`POST /api/public/share`)를
/// 만든 뒤, 그 결과로 받은 `/r/{shareId}` 딥링크를 원본 이미지와 함께
/// OS 공유 시트로 전송한다. 이 테스트 파일은 새 계약을 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // [AuthTokenStore 의존] createShareLink()가 비로그인 상태에서도
    // authHeader() 조회를 위해 SharedPreferences를 읽는다 — 목 초기값을
    // 지정하지 않으면 MissingPluginException이 발생한다.
    SharedPreferences.setMockInitialValues({});
  });
  final png = Uint8List.fromList([1, 2, 3]);

  MockClient shareLinkClient({
    required String shareId,
    List<http.Request>? capturedRequests,
  }) {
    return MockClient((request) async {
      // [MockClient 핸들러 안에서의 expect() 금지] 여기서 바로 expect()를
      // 호출하면 그 예외가 http.post() 호출부로 전파되어
      // createShareLink()의 try/catch에 가로채져(ApiResult.fail로 변환)
      // 진짜 어서션 실패 원인이 토스트 뒤에 숨어버린다 — 요청은 캡처만
      // 해두고 실제 검증은 테스트 본문에서 수행한다.
      capturedRequests?.add(request);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'shareId': shareId,
            'shareUrl': 'https://sintong.kr/web-result/$shareId',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  Future<List<MethodCall>> pumpTapConsentAndShare(
    WidgetTester tester, {
    required http.Client client,
  }) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            calls.add(call);
            return 'success';
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp',
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ShareService.shareResult(
                context,
                resultType: ShareResultType.saju,
                title: '정통사주 결과',
                description: '요약',
                payload: {'summary': 'x'},
                preCapturedPng: png,
              ),
              child: const Text('공유'),
            ),
          ),
        ),
      ),
    );
    await http.runWithClient(() async {
      // [Zone 핵심] Dart에서 `await expr`의 연속(continuation)이 어느 Zone에서
      // 실행되는지는 그 await가 "등록되는 시점"에 Zone.current가 무엇이었는지로
      // 고정된다 — 나중에 Future를 완료(complete)시키는 쪽이 어느 Zone에
      // 있는지는 무관하다. onPressed(() => ShareService.shareResult(...))는
      // 첫 번째 탭(아래)이 디스패치되는 Zone에서 동기적으로 실행을 시작해
      // 첫 await(showDialog)에 도달하므로, 그 탭이 FakeAsync Zone(runAsync
      // 밖)에서 일어나면 이후 모든 연쇄 await(동의 다이얼로그 →
      // createShareLink HTTP → Share.shareXFiles의 실제 임시파일 IO)가
      // 전부 FakeAsync Zone에 고정돼버려, 중간에 아무리 tester.runAsync()로
      // 감싸도 "소급 이동"이 되지 않는다. 따라서 첫 번째 탭 자체를
      // tester.runAsync() 안에서 실행해 전체 연쇄가 처음부터 "진짜" 비동기
      // Zone(실제 Timer/IO가 완료되는 Zone)에서 돌게 만든다. 이 Zone은
      // Zone.current.fork()로 만들어지므로 http.runWithClient()가 심어둔
      // zoneValues(#_clientToken)는 그대로 상속되어 MockClient 조회도
      // 똑같이 동작한다(이미 MOCK_CLIENT_HIT으로 확인됨).
      await tester.runAsync(() async {
        await tester.tap(find.text('공유'));
      });
      await tester.pump();
      await tester.pumpAndSettle();
      // [신통방통 공유 근본 정상화] 앱도 웹과 동일하게 원본 공개 동의
      // 팝업을 먼저 보여준다 — 서버에 이미지를 업로드하기 전이므로.
      expect(find.text('이 결과 그대로 공개할까요?'), findsOneWidget);
      // 두 번째 탭(다이얼로그 확인)은 단지 showDialog의 Future를
      // 완료시키는 역할만 하므로 어느 Zone에서 디스패치되든 무방하다 —
      // 이미 고정된 연속 실행 Zone은 위에서 설정된 real-async Zone이다.
      await tester.tap(find.text('그대로 공유'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }, () => client);
    return calls;
  }

  testWidgets('앱 공유: 동의 후 서버에 공유 링크를 만들고 이미지+/r 딥링크를 함께 전송한다', (tester) async {
    final requests = <http.Request>[];
    final calls = await pumpTapConsentAndShare(
      tester,
      client: shareLinkClient(shareId: 'appQaShare01', capturedRequests: requests),
    );
    expect(requests.length, 1);
    expect(requests.single.url.path, '/api/public/share');
    expect(requests.single.method, 'POST');
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['resultType'], 'saju');
    expect(body['originalPngBase64'], isNotNull);
    expect(body['originalShareConsent'], true);
    expect(calls.length, 1);
    expect(calls.single.method, 'shareFiles');
    expect((calls.single.arguments as Map)['paths'], isNotEmpty);
    final textParam = calls
        .map(
          (call) =>
              '${call.arguments is Map ? (call.arguments as Map)['text'] ?? '' : ''}',
        )
        .join('\n');
    // [핵심 회귀 방지] 앱 공유 텍스트에는 반드시 /r/{shareId} 딥링크가
    // 포함돼야 한다 — 이게 없으면 받는 사람이 특정 결과로 돌아올 방법이
    // 없다(§3-A의 핵심 요구사항, 과거 버그의 직접적 증상).
    expect(textParam, contains('/r/appQaShare01'));
    expect(textParam, contains('신통방통에서 확인했어요'));
    if (EnvConfig.appDownloadUrl.isEmpty) {
      expect(textParam, isNot(contains('앱 설치:')));
    }
    expect(tester.takeException(), null);
  });

  testWidgets('앱 공유: 공유 링크 생성 서버 실패 시 이미지 전송을 시도하지 않고 명확히 실패를 알린다', (
    tester,
  ) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'success': false, 'error': '서버 오류로 공유 링크를 만들지 못했습니다.'}),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    final calls = await pumpTapConsentAndShare(tester, client: client);
    // [회귀 방지 — 침묵한 실패 금지] 링크 생성이 실패했는데 과거 계약처럼
    // "일단 이미지라도 보내자"로 조용히 폴백하면 안 된다. 사용자에게
    // 실패를 명확히 알리고, 공유 시트도 열리지 않아야 한다.
    expect(calls, isEmpty);
    expect(find.textContaining('공유 링크를 만들지 못했습니다'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('앱 이미지 공유 예외는 실패 안내하며 문구 공유와 복사로 대체하지 않는다', (tester) async {
    final attempts = <MethodCall>[];
    var copies = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => '/tmp',
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            attempts.add(call);
            throw PlatformException(code: 'unsupported');
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copies++;
            throw PlatformException(code: 'denied');
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ShareService.shareResult(
                context,
                resultType: ShareResultType.saju,
                title: '정통사주 결과',
                description: '요약',
                payload: {'summary': 'x'},
                preCapturedPng: png,
              ),
              child: const Text('공유'),
            ),
          ),
        ),
      ),
    );
    await http.runWithClient(() async {
      // [Zone 핵심 — 위 테스트와 동일 이유] 첫 번째 탭을 runAsync 안에서
      // 실행해야 onPressed의 전체 await 체인(HTTP→파일IO→MethodChannel
      // 예외)이 처음부터 real-async Zone에서 돌아간다.
      await tester.runAsync(() async {
        await tester.tap(find.text('공유'));
      });
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.text('그대로 공유'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      });
      await tester.pump();
      await tester.pumpAndSettle();
    }, () => shareLinkClient(shareId: 'appQaShare02'));
    expect(find.textContaining('결과 이미지를 공유하지 못했어요'), findsOneWidget);
    expect(attempts.length, 1);
    expect(copies, 0);
    expect(find.text('직접 복사해서 전달해주세요'), findsNothing);
    expect(tester.takeException(), null);
  });
}
