// shrine_app_shell_entry_point_test.dart — 회귀 테스트: 신당(神堂) 모듈
// 재구축(커밋 85b3ad0) 과정에서 app_router.dart/app_shell.dart가 구버전
// 경로(features/shrine/presentation/..., features/shrine/application/...)를
// 참조해 flutter analyze 에러 7건이 발생했던 사고를 재발 방지하기 위한
// 테스트. 이번에 신규 모듈(features/shrine/widgets/shrine_screen_router.dart,
// features/shrine/state/shrine_session_provider.dart)로 교정한 두 지점을
// 직접 검증한다.
//
//  1) app_router.dart '/shrine' named route → shrineScreenFor('entry', null)
//     이 실제로 EntryScreen을 반환하는지(위젯 타입 단위, video_player 등
//     무거운 의존성 때문에 실제 렌더링/pumpWidget까지는 하지 않는다).
//  2) app_shell.dart _openShrine()의 분기 로직과 동일한 식
//     (state.box.isNotEmpty)이 ShrineState 기본값/소지부 보유 상태에서
//     기대한 bool을 내는지 — 구버전 전용 필드였던 ShrineState.kept를
//     신규 모델의 box 리스트로 대체한 판단이 맞는지 고정한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/shrine/widgets/shrine_screen_router.dart';
import 'package:flutter_app/features/shrine/screens/screens.dart';
import 'package:flutter_app/features/shrine/screens/screens_v3.dart';
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/engine/shrine_engine.dart';

void main() {
  group('신당 라우터 재구축 회귀 테스트 (app_router/app_shell 신규 모듈 연동)', () {
    test("shrineScreenFor('entry', null) → EntryScreen 반환 (app_router.dart '/shrine' named route 연동)", () {
      final w = shrineScreenFor('entry', null);
      expect(w, isA<EntryScreen>());
    });

    test("shrineScreenFor('list', null) → ListScreenV3 반환 (app_shell.dart 소지부 보유 재방문자 분기 대상)", () {
      final w = shrineScreenFor('list', null);
      expect(w, isA<ListScreenV3>());
    });

    test('알 수 없는 id는 EntryScreen으로 안전 폴백', () {
      final w = shrineScreenFor('no-such-id', null);
      expect(w, isA<EntryScreen>());
    });

    test(
      'ShrineState 기본값(box 비어있음) → app_shell._openShrine()의 kept 대체식이 false '
      '(구버전 kept=false 기본값과 동일한 분기 결과 — entry로 진입)',
      () {
        const state = ShrineState();
        final keptEquivalent = state.box.isNotEmpty;
        expect(keptEquivalent, isFalse);
      },
    );

    test(
      '소지부 1개 이상 보유 시 app_shell._openShrine()의 kept 대체식이 true '
      '(재방문자 분기 — list로 진입)',
      () {
        final state = const ShrineState().copy(
          box: [
            const BoxItem(
              key: 'myeong|A|red-bell|A',
              no: 'N0001',
              date: '2026-10-20',
              spec: TalismanSpec(
                key: 'myeong',
                type: 'myeong',
                flavor: 'A',
                sig: '命',
                name: '칠성부',
                head: '七星符',
                base: 'base',
                paper: 'paper',
                phrase: 'phrase',
                phraseMeaning: 'meaning',
                motif: 'motif',
                border: 'border',
                seal: 'seal',
                designId: 'd1',
              ),
              source: StorySource('red-bell', 'A'),
            ),
          ],
        );
        final keptEquivalent = state.box.isNotEmpty;
        expect(keptEquivalent, isTrue);
      },
    );
  });
}
