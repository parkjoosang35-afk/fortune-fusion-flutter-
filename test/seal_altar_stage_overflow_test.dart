// [신통방통 앱 반응형 화면 규격 통일] 부적 봉인(SealScreen) 제단 단계
// (_AltarStage) 안전 확인 테스트.
//
// _AltarStage는 screens_v3.dart의 BoxScreen 카드와 동일하게
// BujeokSheet(w: 96) 고정 픽셀 이미지를 사용한다(해당 유사 패턴은
// shrine_box_detail_sheet_overflow_test.dart에서 실제 RenderFlex
// 오버플로 버그로 확인되어 수정됨 — 커밋 참고: "부적함(/box) 카드 그리드
// 세로 오버플로 수정"). 다만 BoxScreen과 달리 이곳은 GridView.count의
// "셀 너비에 비례한 고정 높이" 제약이 없고 Center → Column(mainAxisSize:
// min) 구조이므로, 좁은 화면·글자 확대 조합에서도 안전한지 실측으로
// 조사했다. 조사 결과: 320px 폭 + 글자 크게(1.3배) 포함 모든 조건에서
// 오버플로 없음 확인(안전) — 소스 수정 불필요.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/data/models.dart';
import 'package:flutter_app/features/shrine/screens/seal_screen.dart';
import 'package:flutter_app/features/shrine/shrine_module.dart' show shrine;
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/widgets/bujeok.dart' show BujeokLayout;
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    shrine = await Shrine.load();
    final raw = jsonDecode(await rootBundle.loadString('assets/shrine/data/shrine.json')) as Map;
    BujeokLayout.init(raw['bujeokLayout']);
  });

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets('부적 봉인 화면 제단 단계(_AltarStage)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale 에서 오버플로 없이 표시된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = ShrineSessionProvider(prefs);
      final spec = shrine.talismans.compose(type: 'fate', flavor: 'observe', story: 'room', ending: 'A');
      provider.update((s) => s.copy(box: [
            BoxItem(key: spec.key, no: 'N°0001', date: '2026-01-01', spec: spec, source: const StorySource('room', 'A')),
          ]));

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<ShrineSessionProvider>.value(value: provider),
              ChangeNotifierProvider<WishRoomProvider>(create: (_) => WishRoomProvider(_FakeWrRepository())),
            ],
            child: MaterialApp(home: SealScreen(itemNo: 'N°0001', wishRoomId: 'r1', wishText: '평범한 소원 테스트 문구')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // road -> place/lay 단계 전환(타이머 기반) 대기.
      await tester.pump(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
    });
  }
}
