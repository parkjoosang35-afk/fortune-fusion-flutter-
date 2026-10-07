// ignore_for_file: no_leading_underscores_for_local_identifiers
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/auth/application/auth_provider.dart';
import 'package:flutter_app/features/auth/data/auth_repository.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_renewal_api.dart';
import 'package:flutter_app/features/saju_renewal/screens/calculating_screen.dart';
import 'package:flutter_app/features/saju_renewal/state/saju_renewal_provider.dart';

/// [E-Semantics 실측] docs/08_QA_체크리스트.md "E. 모션·접근성":
/// "03 단계 문구 변경 시 announce".
///
/// 03(CalculatingScreen)의 하단 단계 라벨이 실제로 Semantics
/// (liveRegion: true)로 감싸져 있어, 세레모니 STEP이 진행되며 문구가
/// 바뀔 때마다 TalkBack/VoiceOver가 재공지(announce)할 수 있는
/// 상태인지 widget test로 검증한다.
///
/// [검증 전략] 실제 HandleSemanticsAction이 호출되는지는 플랫폼
/// 엔진 레벨이라 widget test로 직접 가로챌 수 없으므로, 대신
/// SemanticsNode 트리에서 "liveRegion 플래그가 켜진 노드의 label이
/// _kSteps 진행에 따라 실제로 변한다"는 것을 확인한다 — liveRegion
/// 플래그 자체가 TalkBack/VoiceOver에 "이 노드가 바뀌면 announce
/// 하라"는 신호이므로, 플래그 존재 + 라벨 변화가 곧 구현 증거다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// topics/select(및 그 재시도, LIFE_000 폴백 interpret 등 모든 요청)를
  /// 보류해 03 화면이 9단계 세레모니 내내 "대기" 상태로 머물게 만든다
  /// — 세레모니 STEP(1~9) 진행 자체는 서버 응답과 무관하게 로컬
  /// 타이머로만 돌아가므로, 이 상태에서도 1~9단계 문구 변화를 전부
  /// 관찰할 수 있다. 발급된 모든 Completer를 추적해두었다가 테스트
  /// 마지막에 일괄 resolve해, selectTopics()의 http 20s timeout
  /// Timer가 테스트 종료 후까지 pending으로 남는 것을 방지한다
  /// (안 그러면 "Timer is still pending" 검증 실패 — 기능 검증과
  /// 무관한 테스트 하네스 정리 이슈).
  final pendingCompleters = <Completer<http.Response>>[];
  MockClient neverRespondingClient() {
    return MockClient((request) async {
      final c = Completer<http.Response>();
      pendingCompleters.add(c);
      return c.future;
    });
  }

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository())),
        ChangeNotifierProvider(
          create: (_) => SajuRenewalProvider(SajuRenewalApi()),
        ),
      ],
      child: const MaterialApp(home: CalculatingScreen()),
    );
  }

  /// 현재 렌더 트리에서 liveRegion: true 인 SemanticsNode들의 라벨
  /// 목록을 수집한다(여러 개면 전부 반환, 보통 1개여야 한다).
  List<String> liveRegionLabels(WidgetTester tester) {
    final root = tester.binding.rootElement!.renderObject!.debugSemantics;
    final found = <String>[];
    void visit(SemanticsNode? node) {
      if (node == null) return;
      final data = node.getSemanticsData();
      if (data.flagsCollection.isLiveRegion) {
        found.add(data.label);
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
    return found;
  }

  testWidgets('E-Semantics: 03 화면 하단 단계 라벨에 liveRegion:true가 설정되어 있고, '
      '세레모니 STEP이 진행되며 라벨이 실제로 바뀐다(announce 대상 변화 확인)', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(wrap());

      // 화면②에서 입력완료를 눌렀다고 가정하고 세레모니를 시작시킨다.
      // (topics/select는 영원히 보류되므로 03은 9단계까지 "대기" 상태로
      // 머문다 — _ceremonyReachedEnd 이후에도 waitingForServer=true.)
      final context = tester.element(find.byType(CalculatingScreen));
      unawaited(context.read<SajuRenewalProvider>().startCalculating());

      // ── 1단계: 세레모니 시작 직후(250ms 지연 + STEP 1 진입) ──
      await tester.pump(const Duration(milliseconds: 300));
      final step1Labels = liveRegionLabels(tester);
      expect(
        step1Labels,
        isNotEmpty,
        reason:
            '03 화면에 liveRegion:true 인 Semantics 노드가 전혀 없음 — '
            '단계 라벨이 announce 가능한 상태로 구현되지 않았음',
      );
      expect(
        step1Labels.first,
        contains('태어난 순간을 확인하고 있어요'), // _kSteps[0].ko
        reason: 'STEP 1 진입 직후 liveRegion 라벨이 C-03-1 문구와 일치해야 함',
      );

      // ── STEP 1 → STEP 2로 전환(SajuMotion.step = 880ms 경과) ──
      await tester.pump(const Duration(milliseconds: 900));
      final step2Labels = liveRegionLabels(tester);
      expect(
        step2Labels.first,
        contains('여덟 글자를 새기고 있어요'), // _kSteps[1].ko
        reason: 'STEP 2 전환 후 liveRegion 라벨이 C-03-2 문구로 바뀌어야 함(announce 대상)',
      );
      // STEP 1과 STEP 2의 라벨이 실제로 달라야 "문구 변경 시 announce"가
      // 성립한다(동일하면 liveRegion이어도 TalkBack이 재공지할 내용이 없음).
      expect(
        step1Labels.first,
        isNot(equals(step2Labels.first)),
        reason: '단계 전환 전후 liveRegion 라벨이 동일함 — 문구 변경이 감지되지 않음',
      );

      // ── STEP 2 → STEP 3로 전환 ──
      await tester.pump(const Duration(milliseconds: 900));
      final step3Labels = liveRegionLabels(tester);
      expect(
        step3Labels.first,
        contains('다섯 기운의 균형을 살피고 있어요'), // _kSteps[2].ko
        reason: 'STEP 3 전환 후 liveRegion 라벨이 C-03-3 문구로 바뀌어야 함',
      );

      // ── 9단계까지 모두 흘려보내 "대기" 상태(waitingForServer) 진입 ──
      // STEP 4~9: 6단계 * 880ms + 여유
      await tester.pump(const Duration(milliseconds: 880 * 6 + 200));
      final waitLabels = liveRegionLabels(tester);
      expect(
        waitLabels,
        isNotEmpty,
        reason: '9단계 완료(대기 상태) 진입 후에도 liveRegion 노드가 있어야 함',
      );
      expect(
        waitLabels.first,
        contains('당신의 이야기를 고르고 있어요'), // _kSteps.last.ko (waitingForServer)
        reason:
            'topics/select 응답을 받지 못해 대기 상태(waitingForServer)에 '
            '머무는 동안 liveRegion 라벨은 마지막 단계(STORY SELECT) 문구를 '
            '유지해야 함',
      );

      // [클린업] 지금까지 발급된 모든 pending HTTP 요청(topics/select
      // 1차 호출 등)을 즉시 실패 응답으로 resolve해, 이후 로직(E-04 1회
      // 재시도, LIFE_000 폴백 interpret 등)이 추가로 새 pending
      // Completer를 만들 때마다 반복 처리한다. 모든 체인이 끝나(= 더는
      // 새 Completer가 생기지 않을 때까지) 마무리되면, 20s http.timeout
      // Timer가 테스트 종료 후까지 남아 "Timer is still pending" 검증에
      // 걸리는 것을 방지할 수 있다(기능 검증과 무관한 하네스 정리).
      for (var round = 0; round < 6; round++) {
        final toResolve = List<Completer<http.Response>>.from(
          pendingCompleters,
        );
        pendingCompleters.clear();
        for (final c in toResolve) {
          if (!c.isCompleted) {
            c.complete(http.Response('not found', 404));
          }
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }, () => neverRespondingClient());
  });
}
