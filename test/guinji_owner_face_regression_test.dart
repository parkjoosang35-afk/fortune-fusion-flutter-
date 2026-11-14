import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/api/api_result.dart';
import 'package:flutter_app/core/theme/text_scale_provider.dart';
import 'package:flutter_app/features/guinji/application/guinji_provider.dart';
import 'package:flutter_app/features/guinji/data/guinji_repository.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_map_result_screen.dart';
import 'package:flutter_app/features/guinji/widgets/guinji_animated_graph.dart';

class _Repository extends GuinjiRepository {
  @override
  Future<ApiResult<Map<String, dynamic>>> fetchMyMap() async => ApiResult.ok({
    'map': {'mapId': 'test-map', 'name': '검증'},
    'members': [], 'relationships': [],
  });
}

void main() {
  test('앱 재진입 시 지도별 저장된 소유자 얼굴을 복원하고 로그아웃 시 비운다', () async {
    SharedPreferences.setMockInitialValues({
      'guinji.ownerFace.test-map': 'assets/images/guinji/chars/m30_face.jpg',
    });
    final provider = GuinjiProvider(_Repository());
    expect(await provider.loadMyMap(), isTrue);
    expect(provider.ownerFacePath, 'assets/images/guinji/chars/m30_face.jpg');
    expect(provider.people, isEmpty);
    provider.clearOnLogout();
    expect(provider.ownerFacePath, isNull);
  });

  testWidgets('참여자가 없어도 결과 지도는 입력에서 고른 소유자 얼굴을 직접 받는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const face = 'assets/images/guinji/chars/m30_face.jpg';
    // [2026-11-14 나머지 실패 조사] GuinjiMapResultScreen이 "결과페이지
    // 글씨 확대" 기능(커밋 e294710f, 이 테스트보다 나중에 추가됨) 적용
    // 대상이 되어 ResultTextScaleOverlay(TextScaleProvider 필요)로
    // 감싸졌다. 이 테스트는 GuinjiProvider만 주입해 ProviderNotFoundException이
    // 발생했었다 — guinji_map_screens_smoke_test.dart와 동일한 원인이라
    // 동일하게 TextScaleProvider를 MultiProvider에 추가해 보강한다.
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GuinjiProvider(_Repository())),
        ChangeNotifierProvider<TextScaleProvider>(
          create: (_) => TextScaleProvider(),
        ),
      ],
      child: const MaterialApp(home: GuinjiMapResultScreen(ownerFacePath: face)),
    ));
    await tester.pump();
    final graph = tester.widget<GuinjiAnimatedRelationGraph>(find.byType(GuinjiAnimatedRelationGraph));
    expect(graph.people, isEmpty);
    expect(graph.ownerFacePath, face);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
