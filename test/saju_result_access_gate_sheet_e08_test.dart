import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/result_access/application/result_access_provider.dart';
import 'package:flutter_app/features/result_access/data/result_access_repository.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_result_access_gate_sheet.dart';

/// E-08(docs/07_예외_엣지케이스.md) — "광고 로드 실패 → 06 → 기존 폴백
/// 시트, 잠금 유지 → 05."
///
/// `_handleAd()`가 `RewardedAd.load()`의 `onAdFailedToLoad` 콜백을 받으면
/// (1) 처리 상태(_processingMethod)가 풀리고 시트(06)는 그대로 유지되며(=
/// 5·9 화면 위의 바텀시트가 닫히지 않음, "잠금 유지"),
/// (2) 기존 문구("지금은 광고를 불러올 수 없어요. 잠시 후 다시
/// 시도해주세요.")로 오류 토스트가 뜨고,
/// (3) 광고 버튼이 다시 활성 상태로 복귀해 재시도할 수 있어야 한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // google_mobile_ads는 네이티브 플랫폼 채널을 직접 호출하므로, 테스트
    // 환경에서는 MethodChannel을 모킹해 실제 네이티브 SDK 호출 없이
    // `loadRewardedAd` 요청을 가로채 바로 `onAdFailedToLoad` 이벤트를
    // 돌려준다(패키지 자체 test/test_util.dart와 동일한 패턴).
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, (
          MethodCall methodCall,
        ) async {
      if (methodCall.method == 'loadRewardedAd') {
        final adId = methodCall.arguments['adId'] as int;
        // loadRewardedAd 호출 직후, 로드 실패 이벤트를 비동기로 전송한다
        // (실제 네이티브 SDK가 비동기 콜백으로 응답하는 것과 동일한 흐름).
        Future.microtask(() async {
          final args = {
            'adId': adId,
            'eventName': 'onAdFailedToLoad',
            'loadAdError': LoadAdError(
              2,
              'com.google.android.gms.ads',
              'Ad failed to load : no fill.',
              null,
            ),
          };
          final call = MethodCall('onAdEvent', args);
          final data = instanceManager.channel.codec.encodeMethodCall(call);
          await TestDefaultBinaryMessengerBinding.instance
              .defaultBinaryMessenger
              .handlePlatformMessage(
                'plugins.flutter.io/google_mobile_ads',
                data,
                (data) {},
              );
        });
        return null;
      }
      return null;
    });
  });

  void setTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  http.Response quoteResponse() {
    final body = {
      'success': true,
      'data': {
        'freePassRemaining': 2,
        'freePassHasLegacyUnlimited': false,
        'freePassAvailable': true,
        'pouchBalance': 500,
        'pouchPrice': 100,
        'pouchAvailable': true,
        'adAvailable': true,
        'coupangClaimedTodayKey': null,
        'todayClaimed': false,
      },
    };
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Widget host() {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => ResultAccessProvider(ResultAccessRepository()),
          child: const SajuResultAccessGateSheet(
            contentId: 'MONEY_001',
            contentTitle: '테스트 이야기',
            quoteText: '테스트 인용 문장입니다.',
          ),
        ),
      ),
    );
  }

  testWidgets(
    'E-08: 광고 로드가 실패하면(onAdFailedToLoad) 시트(06)가 닫히지 않고 '
    '그대로 유지되며(잠금 유지), 오류 토스트가 뜨고 광고 버튼을 다시 탭할 '
    '수 있다',
    (tester) async {
      setTallSurface(tester);
      var adSessionStartCalled = 0;

      final client = MockClient((request) async {
        if (request.url.path.contains('/result-access/quote')) {
          return quoteResponse();
        }
        if (request.url.path.contains('/result-access/ad-session/start')) {
          adSessionStartCalled++;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'sessionId': 'sess_1'},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 404);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(host());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('광고 보고 무료로 보기'), findsOneWidget);

        await tester.tap(find.text('광고 보고 무료로 보기'));
        // ad-session/start(HTTP) + loadRewardedAd(MethodChannel) +
        // onAdFailedToLoad 비동기 이벤트까지 모두 흘러갈 시간을 준다.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          adSessionStartCalled,
          1,
          reason: 'E-08 선행 조건 확인: ad-session/start가 호출되지 않음',
        );

        // (1) 시트(06)가 여전히 떠 있어야 한다 — 닫히거나 다른 화면으로
        // 전환되지 않음("잠금 유지").
        expect(
          find.byType(SajuResultAccessGateSheet),
          findsOneWidget,
          reason: 'E-08 위반: 광고 로드 실패 후 06 시트가 사라짐(잠금 유지 실패)',
        );
        expect(
          find.text('광고 보고 무료로 보기'),
          findsOneWidget,
          reason: 'E-08 위반: 광고 로드 실패 후 광고 옵션 자체가 사라짐',
        );

        // (2) 기존 문구의 오류 토스트가 노출되어야 한다.
        expect(
          find.byType(SnackBar),
          findsOneWidget,
          reason: 'E-08 위반: 광고 로드 실패 시 오류 토스트가 뜨지 않음',
        );
        expect(
          find.text('지금은 광고를 불러올 수 없어요. 잠시 후 다시 시도해주세요.'),
          findsOneWidget,
          reason: 'E-08 위반: 기존 폴백 문구가 아닌 다른 문구가 노출됨',
        );

        // (3) 광고 버튼이 다시 활성(재시도 가능) 상태여야 한다.
        final adOptionOpacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.text('광고 보고 무료로 보기'),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(
          adOptionOpacity.opacity,
          1.0,
          reason:
              'E-08 위반: 광고 로드 실패 후에도 광고 버튼이 비활성(50%)으로 남아 재시도 불가능',
        );
      }, () => client);
    },
  );
}
