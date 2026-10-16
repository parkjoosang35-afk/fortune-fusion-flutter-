// [사용자 요청 — 외부 검수 지시 ③ Task 5] 사주·타로·관상·손금·궁합 5개 결과
// 화면에서 "다른 운세와 비교해보기"/"운세비교" CTA를 실제로 탭해 교차검증
// 화면([CrossCheckResultScreen])으로 정상 이동하는지, 그리고 그 화면이
// [OrchestratorProvider]를 통해 실제로 엔진 결과를 받아 렌더링하는지를
// 코드 추론이 아니라 실제 위젯 실행으로 검증한다.
//
// [설계 핵심 — cross_check_rules.dart 조사로 확인된 제약] 현재 등록된 4개
// 규칙은 전부 "사주 ↔ 다른 한 문"쌍만 정의되어 있다(사주↔관상/사주↔손금/
// 사주↔궁합/타로↔사주). 즉 로그인 사용자가 유효한 생년월일을 가지고
// 있어야만 "판정(judged)" 결과가 나올 수 있고, 그렇지 않으면 교차검증
// 화면은 "아직 비교할 수 없는 조합"만 보여준다 - 이 역시 올바른 동작이다
// (허위로 판정을 만들어내지 않는 것이 설계 원칙이므로). 이 테스트는 실제로
// "판정(judged)"까지 나오는 것을 증명하기 위해, [AuthProvider.
// restoreSession]을 `/api/public/auth/me` Mock으로 서빙해 생년월일을 가진
// 로그인 사용자를 세팅하고, [DoorEngineGateway]가 호출하는 각 Repository.
// getHistory()도 동일 MockClient로 서빙한다.
//
// [AuthProvider에 debugInject가 없는 이유] 다른 4개 Provider와 달리
// AuthProvider는 테스트 전용 직접 주입 메서드가 없다 - 유일한 경로는
// restoreSession()을 통해 실제 로그인 플로우(토큰 저장 -> `/me` 호출 ->
// UserModel 파싱)를 그대로 타는 것이다(AuthTokenStore 구조를 바꾸지 않는다는
// 제약 준수).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nested/nested.dart' show SingleChildWidget;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/core/auth/auth_token_store.dart';
import 'package:flutter_app/core/orchestrator/door_engine_gateway.dart';
import 'package:flutter_app/core/orchestrator/fortune_orchestrator.dart';
import 'package:flutter_app/core/orchestrator/orchestrator_provider.dart';
import 'package:flutter_app/core/orchestrator/presentation/cross_check_result_screen.dart';
import 'package:flutter_app/core/router/app_router.dart';

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';

import 'package:flutter_app/features/compatibility/application/compatibility_provider.dart';
import 'package:flutter_app/features/compatibility/data/compatibility_repository.dart';
import 'package:flutter_app/features/compatibility/domain/compatibility_model.dart';
import 'package:flutter_app/features/compatibility/presentation/compatibility_result_screen.dart';

import 'package:flutter_app/features/fortune/face/application/face_provider.dart';
import 'package:flutter_app/features/fortune/face/data/face_repository.dart';
import 'package:flutter_app/features/fortune/face/domain/face_model.dart';
import 'package:flutter_app/features/fortune/face/presentation/face_result_screen.dart';

import 'package:flutter_app/features/fortune/palm/application/palm_provider.dart';
import 'package:flutter_app/features/fortune/palm/data/palm_repository.dart';
import 'package:flutter_app/features/fortune/palm/domain/palm_model.dart';
import 'package:flutter_app/features/fortune/palm/presentation/palm_result_screen.dart';

import 'package:flutter_app/features/fortune/tarot/application/tarot_audio_controller.dart';
import 'package:flutter_app/features/fortune/tarot/application/tarot_provider.dart';
import 'package:flutter_app/features/fortune/tarot/application/tarot_session_controller.dart';
import 'package:flutter_app/features/fortune/tarot/data/tarot_repository.dart';
import 'package:flutter_app/features/fortune/tarot/domain/tarot_model.dart';
import 'package:flutter_app/features/fortune/tarot/presentation/tarot_result_screen.dart';

import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/story_detail_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// 사주 계산에 쓰일 생년월일을 가진 로그인 사용자. 1990-03-15 08:30 남성 —
/// [DefaultDoorEngineGateway.getSajuProfile]이 이 값을 실제 PHASE1~4
/// 로컬 엔진([JeontongReportBuilder])에 그대로 투입해 오행/합충형파해/
/// 용신/세운을 전부 계산한다(교차검증 규칙이 요구하는 비-null
/// sajuProfile/sajuResult를 만들기 위한 최소 조건).
Map<String, dynamic> _sajuCapableUserJson() => {
  'id': 'user_cross_check_1',
  'nickname': '검수유저',
  'email': 'crosscheck@example.com',
  'birth_date': '1990-03-15',
  'birth_time': '08:30',
  'is_lunar': false,
  'is_leap_month': false,
  'birth_time_unknown': false,
  'birth_place': null,
  'gender': 'M',
  'grade': 'bronze',
  'welcome_gift_claimed': true,
};

http.Response _authMeResponse() => http.Response(
  jsonEncode({
    'success': true,
    'data': {'user': _sajuCapableUserJson()},
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _notFound() => http.Response('not found', 404);

/// 각 door의 history 엔드포인트를 서빙하는 공용 MockClient. [extra]로
/// 호출부가 필요한 door만 선택적으로 채울 수 있다 - 채우지 않은 door는
/// 404(->Repository가 빈 로컬 _history로 폴백, 즉 "아직 이용 안 함"과
/// 동일한 정직한 상태)로 응답한다.
MockClient _buildMockClient({
  bool withAuthMe = true,
  http.Response Function()? faceHistory,
  http.Response Function()? palmHistory,
  http.Response Function()? tarotHistory,
  http.Response Function()? compatibilityHistory,
  http.Response Function()? sajuTopicsSelect,
  http.Response Function(Map<String, dynamic> body)? sajuInterpret,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (withAuthMe && path.contains('/auth/me')) {
      return _authMeResponse();
    }
    if (path.contains('/fortune/face/history')) {
      return faceHistory?.call() ?? _notFound();
    }
    if (path.contains('/fortune/palm/history')) {
      return palmHistory?.call() ?? _notFound();
    }
    if (path.contains('/fortune/tarot/history')) {
      return tarotHistory?.call() ?? _notFound();
    }
    if (path.contains('/compatibility/history')) {
      return compatibilityHistory?.call() ?? _notFound();
    }
    if (sajuTopicsSelect != null && path.contains('/topics/select')) {
      return sajuTopicsSelect();
    }
    if (sajuInterpret != null && path.contains('/interpret')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return sajuInterpret(body);
    }
    // 등급 조회(`/api/public/grades`) 등 - GradeRepository가 예외/비정상
    // 응답을 전부 안전하게 폴백 처리하므로 명시 Mock이 필요 없다.
    return _notFound();
  });
}

/// [CrossCheckResultScreen]까지 포함한 공용 라우팅 래퍼. 각 결과화면의
/// CTA가 호출하는 `Navigator.pushNamed('/cross-check/result')`가 실제로
/// [CrossCheckResultScreen]을 띄우도록 onGenerateRoute에 그 경로 하나만
/// 등록한다(전체 AppRouter를 그대로 쓰면 다른 화면의 전역 의존성까지
/// 전부 Provider로 등록해야 해서 테스트가 불필요하게 무거워진다).
// [버그 수정 — 실제 재현 확인] 파라미터 타입을 List<ChangeNotifierProvider>로
// 선언하면, 각기 다른 제네릭 타입 인자를 가진 ChangeNotifierProvider<T>
// 리터럴들이 리스트 리터럴의 타입을 아래로 추론(downward inference)받아
// 전부 ChangeNotifierProvider<dynamic>으로 묵시적 캐스팅된다. 그 결과
// MultiProvider가 각 Provider를 `Provider<dynamic>`으로 등록해버려,
// 화면이 `context.watch<FaceProvider>()`처럼 구체 타입으로 조회하면
// ProviderNotFoundException이 발생한다(실제 재현: 아래 flutter test 실행
// 로그에서 "Could not find the correct Provider<FaceProvider>" 확인).
// provider 패키지가 공개 의존성으로 노출하는 공용 상위 타입
// [SingleChildWidget]을 쓰면 각 ChangeNotifierProvider<T> 리터럴이 자신의
// 구체 타입 그대로 보존된다.
Widget _wrapWithCrossCheckRoute({
  required List<SingleChildWidget> providers,
  required Widget home,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == AppRouter.crossCheckResultRoute) {
          return MaterialPageRoute<void>(
            builder: (_) => const CrossCheckResultScreen(),
          );
        }
        return null;
      },
      home: home,
    ),
  );
}

/// 타로상담 SFX AudioPlayer 플러그인 메서드 채널을 테스트 환경에서
/// 안전하게 무력화한다(tarot_ui_verification_test.dart와 동일 패턴 -
/// 실제 오디오 재생 없이도 TarotAudioController가 예외 없이 동작하게 함).
void _mockAudioChannels() {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthTokenStore.save(token: 'cross-check-test-token', userId: 1);
  });

  tearDown(() async {
    await AuthTokenStore.clear();
  });

  group('5개 결과화면 교차검증 CTA 직접 실행(외부 검수 지시 ③ Task 5)', () {
    testWidgets('[관상] "다른 운세와 비교해보기" 탭 -> 교차검증 화면 도달 + '
        '사주↔관상(SajuFaceDriveRule) 판정(judged) 1건 이상 표시', (tester) async {
      final faceRepo = FaceRepository();
      final tarotRepo = TarotRepository();
      final palmRepo = PalmRepository();
      final compatRepo = CompatibilityRepository();

      final authProvider = AuthProvider(AuthRepository());
      final faceProvider = FaceProvider(faceRepo);
      final orchestratorProvider = OrchestratorProvider(
        FortuneOrchestrator(
          gateway: DefaultDoorEngineGateway(
            tarotRepository: tarotRepo,
            faceRepository: faceRepo,
            palmRepository: palmRepo,
            compatibilityRepository: compatRepo,
          ),
        ),
      );

      final faceHistoryJson = {
        'success': true,
        'data': [
          {
            'id': 'face_cross_1',
            'features': {
              '이마': '넓고 둥근 이마로 적극적이고 활동적인 기운이 느껴집니다',
              '눈': '또렷한 눈매로 추진력과 열정이 강한 인상입니다',
            },
            'topicResults': {'직업': '진취적이고 도전적인 성향이 직업운에 긍정적으로 작용합니다'},
            'summary': '전반적으로 적극적이고 열정적이며 추진력이 강한 인상입니다',
            'createdAt': '2024-06-01T00:00:00.000Z',
          },
        ],
      };

      final mockClient = _buildMockClient(
        faceHistory: () => http.Response(
          jsonEncode(faceHistoryJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await http.runWithClient(() async {
        // 1) 실제 로그인 플로우(AuthRepository.restoreSession ->
        //    `/api/public/auth/me`)로 생년월일을 가진 사용자를 세팅한다.
        await authProvider.restoreSession();
        expect(authProvider.isLoggedIn, true);
        expect(authProvider.currentUser?.birthDate, '1990-03-15');

        // 2) 관상 결과화면 표시용 상태만 debugInjectResult로 직접 주입
        //    (화면 렌더링과 오케스트레이터의 getHistory() 조회는 서로
        //    분리되어 있으므로, 오케스트레이터가 같은 내용을 보려면
        //    위 faceHistoryJson처럼 history 엔드포인트도 함께 서빙해야
        //    한다 - DoorEngineGateway 주석의 "history-first" 설계 그대로).
        faceProvider.debugInjectResult(
          FaceResultModel(
            id: 'face_cross_1',
            features: const {
              '이마': '넓고 둥근 이마로 적극적이고 활동적인 기운이 느껴집니다',
              '눈': '또렷한 눈매로 추진력과 열정이 강한 인상입니다',
            },
            topicResults: const {'직업': '진취적이고 도전적인 성향이 직업운에 긍정적으로 작용합니다'},
            summary: '전반적으로 적극적이고 열정적이며 추진력이 강한 인상입니다',
            createdAt: DateTime(2024, 6, 1),
          ),
        );

        await tester.pumpWidget(
          _wrapWithCrossCheckRoute(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: faceProvider),
              ChangeNotifierProvider.value(value: orchestratorProvider),
            ],
            home: const FaceResultScreen(),
          ),
        );
        await tester.pump();

        final cta = find.text('다른 운세와 비교해보기');
        expect(cta, findsOneWidget, reason: 'Task 5 위반: 관상 결과화면에 교차검증 CTA가 없음');
        await tester.ensureVisible(cta);
        await tester.pump();
        await tester.tap(cta);
        // 네비게이션 + CrossCheckResultScreen.initState의
        // postFrameCallback -> OrchestratorProvider.load() 완료까지.
        // (실제 네트워크 지연이 아니라 Mock이므로 Future.delayed 같은
        // 가상 타이머 의존이 없어, C-07/타로 hang 수정과 달리 일반
        // pump() 반복만으로 충분하다 - 아래 pump들로 실측 확인함.)
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byType(CrossCheckResultScreen),
          findsOneWidget,
          reason: 'Task 5 위반: CTA 탭 후 교차검증 화면으로 이동하지 않음',
        );
        expect(
          orchestratorProvider.status,
          OrchestratorStatus.loaded,
          reason:
              'Task 5 위반: 오케스트레이터가 loaded 상태에 도달하지 못함 '
              '(에러메시지=${orchestratorProvider.errorMessage})',
        );
        // 사주↔관상 규칙이 실제로 판정(judged)까지 도달했는지 - "엔진
        // 결과가 실제로 화면에 전파되는지"를 증명하는 핵심 단언.
        expect(
          orchestratorProvider.judged,
          isNotEmpty,
          reason:
              'Task 5 위반: 로그인 사용자(유효 생년월일) + 관상 결과가 '
              '모두 있는데도 사주↔관상 판정이 전혀 생성되지 않음',
        );
        expect(
          orchestratorProvider.judged.any((r) => r.pair == '사주↔관상'),
          true,
          reason: 'Task 5 위반: 사주↔관상(SajuFaceDriveRule) 판정이 결과에 없음',
        );
        // 화면에도 판정 배지(일치/보완/상충 중 하나)가 실제로 그려지는지.
        final verdictLabels = ['일치', '보완', '상충'];
        final anyVerdictShown = verdictLabels.any(
          (label) => find.text(label).evaluate().isNotEmpty,
        );
        expect(
          anyVerdictShown,
          true,
          reason: 'Task 5 위반: 교차검증 화면에 판정 배지(일치/보완/상충)가 렌더링되지 않음',
        );
      }, () => mockClient);
    });

    testWidgets('[손금] "다른 운세와 비교해보기" 탭 -> 교차검증 화면 도달(사주↔손금 판정 또는 '
        '정직한 미판정 중 하나가 실제로 렌더링됨)', (tester) async {
      final faceRepo = FaceRepository();
      final tarotRepo = TarotRepository();
      final palmRepo = PalmRepository();
      final compatRepo = CompatibilityRepository();

      final authProvider = AuthProvider(AuthRepository());
      final palmProvider = PalmProvider(palmRepo);
      final orchestratorProvider = OrchestratorProvider(
        FortuneOrchestrator(
          gateway: DefaultDoorEngineGateway(
            tarotRepository: tarotRepo,
            faceRepository: faceRepo,
            palmRepository: palmRepo,
            compatibilityRepository: compatRepo,
          ),
        ),
      );

      final palmHistoryJson = {
        'success': true,
        'data': [
          {
            'id': 'palm_cross_1',
            'lines': {
              '생명선': '길고 뚜렷한 생명선으로 안정적이고 신중한 성향이 드러납니다',
              '두뇌선': '차분하고 현실적인 사고를 나타내는 두뇌선입니다',
            },
            'topicResults': {'재물': '신중하고 꼼꼼한 재물 관리 성향이 보입니다'},
            'summary': '전반적으로 안정적이고 현실적인 기질이 두드러집니다',
            'createdAt': '2024-06-01T00:00:00.000Z',
          },
        ],
      };

      final mockClient = _buildMockClient(
        palmHistory: () => http.Response(
          jsonEncode(palmHistoryJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await http.runWithClient(() async {
        await authProvider.restoreSession();
        expect(authProvider.isLoggedIn, true);

        palmProvider.debugInjectResult(
          PalmResultModel(
            id: 'palm_cross_1',
            lines: const {
              '생명선': '길고 뚜렷한 생명선으로 안정적이고 신중한 성향이 드러납니다',
              '두뇌선': '차분하고 현실적인 사고를 나타내는 두뇌선입니다',
            },
            topicResults: const {'재물': '신중하고 꼼꼼한 재물 관리 성향이 보입니다'},
            summary: '전반적으로 안정적이고 현실적인 기질이 두드러집니다',
            createdAt: DateTime(2024, 6, 1),
          ),
        );

        await tester.pumpWidget(
          _wrapWithCrossCheckRoute(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: palmProvider),
              ChangeNotifierProvider.value(value: orchestratorProvider),
            ],
            home: const PalmResultScreen(),
          ),
        );
        await tester.pump();

        final cta = find.text('다른 운세와 비교해보기');
        expect(cta, findsOneWidget, reason: 'Task 5 위반: 손금 결과화면에 교차검증 CTA가 없음');
        await tester.ensureVisible(cta);
        await tester.pump();
        await tester.tap(cta);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byType(CrossCheckResultScreen),
          findsOneWidget,
          reason: 'Task 5 위반: CTA 탭 후 교차검증 화면으로 이동하지 않음',
        );
        expect(orchestratorProvider.status, OrchestratorStatus.loaded);
        expect(
          orchestratorProvider.judged.any((r) => r.pair == '사주↔손금'),
          true,
          reason: 'Task 5 위반: 사주↔손금(SajuPalmTemperamentRule) 판정이 결과에 없음',
        );
      }, () => mockClient);
    });

    testWidgets('[궁합] "다른 운세와 비교해보기" 탭 -> 교차검증 화면 도달 + 사주↔궁합 판정', (
      tester,
    ) async {
      final faceRepo = FaceRepository();
      final tarotRepo = TarotRepository();
      final palmRepo = PalmRepository();
      final compatRepo = CompatibilityRepository();

      final authProvider = AuthProvider(AuthRepository());
      final compatProvider = CompatibilityProvider(compatRepo);
      final orchestratorProvider = OrchestratorProvider(
        FortuneOrchestrator(
          gateway: DefaultDoorEngineGateway(
            tarotRepository: tarotRepo,
            faceRepository: faceRepo,
            palmRepository: palmRepo,
            compatibilityRepository: compatRepo,
          ),
        ),
      );

      final compatHistoryJson = {
        'success': true,
        'data': [
          {
            'id': 'compat_cross_1',
            'nameA': '나',
            'nameB': '상대',
            'type': 'love',
            'score': 82,
            'topicResults': {'애정': '서로를 아끼는 마음이 깊은 궁합입니다'},
            'summary': '두 분은 서로를 보완하는 좋은 궁합입니다',
            'createdAt': '2024-06-01T00:00:00.000Z',
          },
        ],
      };

      final mockClient = _buildMockClient(
        compatibilityHistory: () => http.Response(
          jsonEncode(compatHistoryJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await http.runWithClient(() async {
        await authProvider.restoreSession();
        expect(authProvider.isLoggedIn, true);

        compatProvider.debugInjectResult(
          CompatibilityResultModel(
            id: 'compat_cross_1',
            nameA: '나',
            nameB: '상대',
            type: 'love',
            score: 82,
            topicResults: const {'애정': '서로를 아끼는 마음이 깊은 궁합입니다'},
            summary: '두 분은 서로를 보완하는 좋은 궁합입니다',
            createdAt: DateTime(2024, 6, 1),
          ),
        );

        await tester.pumpWidget(
          _wrapWithCrossCheckRoute(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: compatProvider),
              ChangeNotifierProvider.value(value: orchestratorProvider),
            ],
            home: const CompatibilityResultScreen(),
          ),
        );
        await tester.pump();

        final cta = find.text('다른 운세와 비교해보기');
        expect(cta, findsOneWidget, reason: 'Task 5 위반: 궁합 결과화면에 교차검증 CTA가 없음');
        await tester.ensureVisible(cta);
        await tester.pump();
        await tester.tap(cta);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byType(CrossCheckResultScreen),
          findsOneWidget,
          reason: 'Task 5 위반: CTA 탭 후 교차검증 화면으로 이동하지 않음',
        );
        expect(orchestratorProvider.status, OrchestratorStatus.loaded);
        expect(
          orchestratorProvider.judged.any((r) => r.pair == '사주↔궁합'),
          true,
          reason: 'Task 5 위반: 사주↔궁합(SajuCompatibilityRelationRule) 판정이 결과에 없음',
        );
      }, () => mockClient);
    });

    testWidgets('[타로] "운세비교" 액션 탭 -> 교차검증 화면 도달 + 타로↔사주 판정', (tester) async {
      _mockAudioChannels();

      final faceRepo = FaceRepository();
      final tarotRepo = TarotRepository();
      final palmRepo = PalmRepository();
      final compatRepo = CompatibilityRepository();

      final authProvider = AuthProvider(AuthRepository());
      final tarotProvider = TarotProvider(tarotRepo);
      final orchestratorProvider = OrchestratorProvider(
        FortuneOrchestrator(
          gateway: DefaultDoorEngineGateway(
            tarotRepository: tarotRepo,
            faceRepository: faceRepo,
            palmRepository: palmRepo,
            compatibilityRepository: compatRepo,
          ),
        ),
      );

      const cardPast = TarotCard(
        id: 'past_1',
        name: 'The Fool',
        nameKr: '바보',
        isReversed: false,
      );
      final tarotResult = TarotResultModel(
        id: 'tarot_cross_1',
        question: '지금 새로운 일을 시작해도 좋을까요?',
        spreadType: 'one_card',
        positions: const [
          TarotSpreadPosition(label: '현재', card: cardPast, interpretation: '지금이 좋은 때입니다'),
        ],
        summary: '지금은 기회를 잡고 순조로운 흐름을 따라 지금 시작하기 좋은 적기입니다',
        createdAt: DateTime(2024, 6, 1),
        topic: 'general',
      );

      final tarotHistoryJson = {
        'success': true,
        'data': [
          {
            'id': tarotResult.id,
            'question': tarotResult.question,
            'spreadType': tarotResult.spreadType,
            'positions': [
              {
                'label': '현재',
                'card': {
                  'id': cardPast.id,
                  'name': cardPast.name,
                  'nameKr': cardPast.nameKr,
                  'isReversed': cardPast.isReversed,
                },
                'interpretation': '지금이 좋은 때입니다',
              },
            ],
            'summary': tarotResult.summary,
            'createdAt': '2024-06-01T00:00:00.000Z',
            'topic': 'general',
          },
        ],
      };

      final mockClient = _buildMockClient(
        tarotHistory: () => http.Response(
          jsonEncode(tarotHistoryJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      await http.runWithClient(() async {
        await authProvider.restoreSession();
        expect(authProvider.isLoggedIn, true);

        tarotProvider.debugInjectResult(tarotResult);

        await tester.pumpWidget(
          _wrapWithCrossCheckRoute(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: tarotProvider),
              ChangeNotifierProvider(create: (_) => TarotSessionController()),
              ChangeNotifierProvider(create: (_) => TarotAudioController()),
              ChangeNotifierProvider.value(value: orchestratorProvider),
            ],
            home: const TarotResultScreen(),
          ),
        );

        // 카드 리빌 연출(3600ms) + 콘텐츠 애니메이션(2600ms) 종료까지
        // 유한 pump만 사용한다(OzBackground 무한 Ticker 때문에
        // pumpAndSettle은 타임아웃됨 - tarot_ui_verification_test.dart와
        // 동일 패턴).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));

        final cta = find.text('운세비교');
        expect(cta, findsOneWidget, reason: 'Task 5 위반: 타로 결과화면 액션바에 운세비교가 없음');
        await tester.tap(cta);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byType(CrossCheckResultScreen),
          findsOneWidget,
          reason: 'Task 5 위반: 운세비교 탭 후 교차검증 화면으로 이동하지 않음',
        );
        expect(orchestratorProvider.status, OrchestratorStatus.loaded);
        expect(
          orchestratorProvider.judged.any((r) => r.pair == '타로↔사주'),
          true,
          reason: 'Task 5 위반: 타로↔사주(TarotSajuTimingRule) 판정이 결과에 없음',
        );
      }, () => mockClient);
    });

    testWidgets('[사주] "다른 운세와 비교해보기" 탭 -> 교차검증 화면 도달(최소 미판정 정직 표시 확인)', (
      tester,
    ) async {
      final faceRepo = FaceRepository();
      final tarotRepo = TarotRepository();
      final palmRepo = PalmRepository();
      final compatRepo = CompatibilityRepository();

      final authProvider = AuthProvider(AuthRepository());
      final sajuProvider = SajuRenewalProvider(SajuRenewalApi());
      final orchestratorProvider = OrchestratorProvider(
        FortuneOrchestrator(
          gateway: DefaultDoorEngineGateway(
            tarotRepository: tarotRepo,
            faceRepository: faceRepo,
            palmRepository: palmRepo,
            compatibilityRepository: compatRepo,
          ),
        ),
      );

      http.Response topicsSelectResponse() {
        final body = {
          'success': true,
          'data': {
            'first_topic': {
              'topic_id': 'MONEY_001',
              'scene': 'money',
              'title': '테스트 이야기 제목',
              'is_timing': false,
              'evidence_fact_keys': <String>[],
            },
            'candidates': <Map<String, dynamic>>[],
            'key_facts': <String>['wood', 'fire'],
            'fact_schema_version': 'v1',
          },
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      http.Response interpretResponse(Map<String, dynamic> requestBody) {
        if (requestBody['mode'] == 'detail') {
          final body = {
            'success': true,
            'data': {
              'topic_id': 'MONEY_001',
              'title': '테스트 이야기 제목',
              'blocks': [
                {'n': 1, 'body': '핵심 블록 본문'},
                {
                  'n': 2,
                  'body': '왜 블록 본문',
                  'evidence': {'type': 'elements', 'text': '근거 텍스트'},
                },
                {'n': 3, 'body': '생활 블록 본문'},
                {'n': 5, 'body': '포인트 블록 본문'},
              ],
              'source': 'template',
            },
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final body = {
          'success': true,
          'data': {
            'topic_id': 'MONEY_001',
            'title': '테스트 이야기 제목',
            'summary': '테스트 요약 내용입니다. 이것은 마지막 문장입니다.',
            'evidence': {'type': 'elements', 'text': '테스트 근거'},
            'source': 'template',
          },
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      final mockClient = _buildMockClient(
        sajuTopicsSelect: topicsSelectResponse,
        sajuInterpret: interpretResponse,
      );

      await http.runWithClient(() async {
        await authProvider.restoreSession();
        expect(authProvider.isLoggedIn, true);

        await tester.pumpWidget(
          _wrapWithCrossCheckRoute(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: sajuProvider),
              ChangeNotifierProvider.value(value: orchestratorProvider),
            ],
            home: const StoryDetailScreen(),
          ),
        );
        // story_detail_screen_c07_test.dart의 pumpToDetail과 동일한
        // 패턴으로 detailState=success까지 실제 HTTP 흐름으로 도달한다.
        unawaited(sajuProvider.startCalculating());
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        await sajuProvider.onAccessGranted();
        await tester.pump();
        await tester.pump();

        final cta = find.text('다른 운세와 비교해보기');
        expect(cta, findsOneWidget, reason: 'Task 5 위반: 사주 결과화면에 교차검증 CTA가 없음');
        await tester.ensureVisible(cta);
        await tester.pump();
        await tester.tap(cta);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.byType(CrossCheckResultScreen),
          findsOneWidget,
          reason: 'Task 5 위반: CTA 탭 후 교차검증 화면으로 이동하지 않음',
        );
        expect(orchestratorProvider.status, OrchestratorStatus.loaded);
        // 이 테스트는 타로/관상/손금/궁합 중 어느 것도 채우지 않았으므로
        // (로그인 사용자 + 사주 원국만 있음) 전부 "미판정"이어야 정직한
        // 동작이다 - 판정을 허위로 만들어내면 그게 오히려 결함이다.
        expect(orchestratorProvider.judged, isEmpty);
        expect(orchestratorProvider.unjudged, isNotEmpty);
        expect(find.text('아직 비교할 수 없는 조합'), findsOneWidget);
      }, () => mockClient);
    });
  });
}
