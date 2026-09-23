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
import 'package:flutter/material.dart';
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
          .ancestor(
            of: pastLabelFinder.first,
            matching: find.byType(InkWell),
          )
          .first;
      await tester.tap(pastCardFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 상세 시트가 열리고, 그 안에 원래 포지션 interpretation 전문이 표시돼야 한다.
      expect(
        find.textContaining('과거에는 두려움 없이 새로운 시작을 했던 흔적이 보입니다.'),
        findsOneWidget,
      );
      // 심화 관점 섹션 헤더도 함께 표시돼야 한다.
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
        final faceDownFinder = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'OzFaceDownCard',
        );
        expect(faceDownFinder, findsNWidgets(78));
      },
    );
  });
}
