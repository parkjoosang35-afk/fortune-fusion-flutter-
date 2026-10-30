import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/fortune/shared/domain/reading_artifact.dart';
import 'package:flutter_app/features/fortune/shared/presentation/seal_reading_flow.dart';
import 'package:flutter_app/features/wishroom/application/wishroom_provider.dart';
import 'package:flutter_app/features/wishroom/data/models.dart';
import 'package:flutter_app/features/wishroom/data/wr_api.dart';

class _FakeWrRepository implements WrRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.3),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '풀이 봉인 확인 시트가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다(긴 소원문구)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final provider = WishRoomProvider(_FakeWrRepository())
          ..room = WishRoom.fromJson({
            'id': 'test-room',
            'ownerId': 'test-owner',
            'text':
                '이 소원은 아주 길게 작성된 소원 문구입니다. 화면이 작을 때 '
                '이 문구와 안내 텍스트, 버튼이 모두 잘리지 않고 보이는지 '
                '확인하기 위한 실측 테스트용 텍스트입니다. 조금 더 길게.',
            'char': 'F03',
            'devotionCount': 0,
            'supportCount': 0,
            'pouchReceived': 0,
            'level': 1,
            'points': 0,
            'levelName': '시작',
            'curLevelPts': 0,
            'nextLevelPts': 100,
            'brightness': 1.0,
          });

        final artifact = ReadingArtifact(
          id: 'artifact-1',
          kind: ReadingKind.face,
          createdAt: DateTime(2026, 1, 1),
          engine: const ReadingEngineMeta(),
          steps: const [],
          total: const ReadingTotal(
            key: '晩',
            keyKo: '만',
            title: '대기만성형 얼굴',
            body: '천천히 피어나는 운을 지녔습니다.',
          ),
          sourceResultId: 'src-1',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: ChangeNotifierProvider<WishRoomProvider>.value(
              value: provider,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () =>
                          sealReadingToWishRoom(context, artifact),
                      child: const Text('열기'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('얹어서 봉인'), findsOneWidget);
      },
    );
  }
}
