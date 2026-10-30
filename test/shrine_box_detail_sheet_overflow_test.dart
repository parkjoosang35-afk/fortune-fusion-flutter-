// [신통방통 앱 반응형 화면 규격 통일] 부적함(/box) 카드 그리드 — 세로 오버플로 회귀 테스트.
//
// 버그: GridView.count(childAspectRatio: 96/252)는 셀 높이를 "셀 너비에
// 비례"해서 계산하지만, 카드 내용의 실제 높이는 BujeokSheet(w: 96)가 화면
// 폭과 무관하게 항상 고정 픽셀(96×220.8)로 그려지는 탓에 셀 너비가 줄어도
// 거의 줄어들지 않는다 — 그 결과 좁은 화면(360·320px 폭)에서 평범한
// 데이터로도 Column이 RenderFlex 오버플로를 일으켰다(실측: 360px 폭에서
// 24px, 320px 폭에서 59px 초과). 특별히 긴 텍스트가 필요 없는, 일반적인
// 사용 환경에서도 발생하는 공통 레이아웃 결함이었다.
//
// 수정: LayoutBuilder로 실제 사용 가능한 폭을 측정해 셀 너비를 셈한 뒤
// BujeokSheet에 그대로 전달하고(이미지가 셀 폭에 맞춰 그려짐), Wrap으로
// 카드 높이가 내용물의 실제 필요 높이를 그대로 반영하도록 했다.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/data/models.dart';
import 'package:flutter_app/features/shrine/screens/screens_v3.dart';
import 'package:flutter_app/features/shrine/shrine_module.dart' show shrine;
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/widgets/bujeok.dart' show BujeokLayout;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    shrine = await Shrine.load();
    final raw = jsonDecode(await rootBundle.loadString('assets/shrine/data/shrine.json')) as Map;
    BujeokLayout.init(raw['bujeokLayout']);
  });

  final conditions = <(Size, double, String)>[
    (const Size(390, 844), 1.0, '일반 폭(390px)'),
    (const Size(360, 640), 1.0, '좁은 폭(360px) — 수정 전 24px 오버플로 확인됨'),
    (const Size(320, 568), 1.0, '가장 좁은 폭(320px) — 수정 전 59px 오버플로 확인됨'),
    (const Size(360, 640), 1.3, '좁은 폭 + 글자 크게(1.3배)'),
  ];

  for (final (size, textScale, label) in conditions) {
    testWidgets('부적함 카드 그리드가 평범한 데이터로도 $label 에서 오버플로 없이 표시된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = ShrineSessionProvider(prefs);

      // 평범한(가장 흔한) 타입/이야기 조합 — 'fate' + 'room'. 긴 텍스트가
      // 아닌 일반적인 데이터로도 버그가 재현됨을 증명하기 위해 일부러
      // "가장 긴" 조합이 아닌 기본 조합을 사용한다.
      final spec = shrine.talismans.compose(type: 'fate', flavor: 'observe', story: 'room', ending: 'A');
      provider.update((s) => s.copy(box: [
            BoxItem(key: spec.key, no: 'N°0001', date: '2026-01-01', spec: spec, source: const StorySource('room', 'A')),
            BoxItem(key: spec.key, no: 'N°0002', date: '2026-01-02', spec: spec, source: const StorySource('room', 'A')),
            BoxItem(key: spec.key, no: 'N°0003', date: '2026-01-03', spec: spec, source: const StorySource('room', 'A')),
          ]));

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: ChangeNotifierProvider<ShrineSessionProvider>.value(
            value: provider,
            child: const MaterialApp(home: BoxScreen()),
          ),
        ),
      );
      await tester.pump();

      // 오버플로(RenderFlex overflowed) 등 렌더링 예외가 전혀 없어야 한다.
      expect(tester.takeException(), isNull);
    });
  }
}
