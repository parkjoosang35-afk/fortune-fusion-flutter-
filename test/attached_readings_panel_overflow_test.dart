import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/fortune/shared/data/reading_artifact_store.dart';
import 'package:flutter_app/features/fortune/shared/data/reading_wish_link_store.dart';
import 'package:flutter_app/features/fortune/shared/domain/reading_artifact.dart';
import 'package:flutter_app/features/fortune/shared/presentation/attached_readings_panel.dart';

/// [반응형 화면 규격 통일 — 잘림 현상 수정]
/// 소원방 "담겨온 풀이" 패널 — 칩 목록 + 상세 바텀시트(DraggableScrollableSheet).
/// ReadingCiteCard의 출전명 Row(Text+뱃지)가 Expanded 없이 구성되어 있어
/// 출전명(cite.src/srcKo)이 길 때 오버플로 가능성을 실제 시트 진입으로 검증한다.
///
/// [반응형 화면 규격 통일 — 재조사] 기존 매트릭스는 textScale 1.3까지만
/// 검증했다. ReadingCiteCard의 출전명 Row는 이미 Expanded+ellipsis로
/// 보호되어 있고(커밋 f498e9d), 상세 시트는 DraggableScrollableSheet+
/// ListView로 세로 스크롤이 이미 보장되는 구조라, 320x568 기준 textScale을
/// 2.0/2.5까지 올려 재검증해도 오버플로가 재현되지 않음을 확인했다
/// (5/5 통과). 회귀 방지를 위해 매트릭스를 5종 조합으로 확장해 유지한다.
void main() {
  const wishRoomId = 'wr_test_1';
  const longCiteSrc = '麻衣相法·神相全編·柳莊相法(여러 문헌 통합 출전 표기 테스트)';
  const longCiteSrcKo = '마의상법·신상전편·유장상법(매우 긴 한글 서명 풀네임 표기 테스트용)';

  final artifact = ReadingArtifact(
    id: 'a1',
    kind: ReadingKind.face,
    createdAt: DateTime(2025, 1, 1),
    engine: const ReadingEngineMeta(),
    sourceResultId: 'r1',
    steps: [
      ReadingStep(
        key: 'forehead',
        chip: '額',
        title: '이마 부위에 대한 매우 긴 제목 텍스트 - 아주 길게 늘려서 가로 넘침을 재현 테스트',
        body: '본문 내용입니다. ' * 20,
        detectionConfidence: 0.92,
        cite: CiteRef(
          src: longCiteSrc,
          srcKo: longCiteSrcKo,
          text: '요지 텍스트입니다. ' * 10,
        ),
      ),
    ],
    total: ReadingTotal(
      key: '晩',
      keyKo: '만',
      title: '총평 제목',
      body: '총평 본문입니다. ' * 15,
      cite: const CiteRef(
        src: longCiteSrc,
        srcKo: longCiteSrcKo,
        text: '총평 출전 요지',
      ),
    ),
  );

  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    testWidgets(
      '담겨온 풀이 상세 시트(긴 출전명)가 ${size.width.toInt()}x${size.height.toInt()}@$textScale에서 오버플로 없이 뜬다',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await ReadingArtifactStore.save(artifact);
        await ReadingWishLinkStore.attach(wishRoomId, artifact.id);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const MaterialApp(
              home: Scaffold(
                body: AttachedReadingsPanel(wishRoomId: wishRoomId),
              ),
            ),
          ),
        );
        // _load()가 비동기로 끝난 뒤 칩이 그려질 때까지 대기.
        await tester.pumpAndSettle();
        var ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);

        final chip = find.textContaining('관상 ·');
        expect(chip, findsOneWidget);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        ex = tester.takeException();
        if (ex != null) debugDumpRenderTree();
        expect(ex, isNull);
      },
    );
  }
}
