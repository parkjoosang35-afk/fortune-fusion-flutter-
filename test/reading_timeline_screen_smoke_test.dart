// [v7 통합 — Option B 검증] ReadingTimelineScreen이 ReadingArtifact를
// 받아 예외 없이 렌더링되고, "다음" 버튼으로 마지막 단계(총평)까지
// 이동한 뒤 onFinished가 정확히 1회 호출되는지 확인하는 스모크 테스트.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/fortune/shared/domain/reading_artifact.dart';
import 'package:flutter_app/features/fortune/shared/presentation/reading_timeline_screen.dart';

ReadingArtifact _sampleArtifact() {
  return ReadingArtifact(
    id: 'ra_face_test',
    kind: ReadingKind.face,
    createdAt: DateTime(2026, 1, 1),
    engine: const ReadingEngineMeta(version: 1),
    steps: const [
      ReadingStep(
        key: '이마',
        chip: '額',
        title: '넓고 맑은 이마',
        body: '이마는 초년의 운과 일의 자리를 봐요.',
        measures: [MeasureRow(label: '이마 폭', value: '넓음')],
        cite: CiteRef(src: '神相全編', srcKo: '신상전편', text: '이마가 넓고 반듯하면...'),
      ),
      ReadingStep(
        key: '눈',
        chip: '目',
        title: '맑고 깊은 눈매',
        body: '눈은 마음의 창이라 했어요.',
        cite: CiteRef(src: '麻衣相法', srcKo: '마의상법', text: '눈이 길고 흑백이 분명하면...'),
      ),
    ],
    total: const ReadingTotal(
      key: '晩',
      keyKo: '대기만성 · 晩成',
      title: '늦게 피어 오래 가는 얼굴',
      body: '운이 뒤로 갈수록 쌓이는 얼굴이에요.',
      cite: CiteRef(src: '麻衣相法', srcKo: '마의상법', text: '관상은 심상만 못하다'),
    ),
    sourceResultId: 'result_test',
  );
}

void main() {
  testWidgets('ReadingTimelineScreen은 예외 없이 렌더링되고 다음→총결과 흐름이 동작한다', (
    tester,
  ) async {
    var finishedCount = 0;
    final artifact = _sampleArtifact();

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingTimelineScreen(
          artifact: artifact,
          onFinished: () => finishedCount++,
        ),
      ),
    );
    await tester.pump();

    // 1단계(이마) 렌더 확인.
    expect(find.text('1 / 3'), findsOneWidget);
    expect(finishedCount, 0);

    // 타이핑 애니메이션을 끝까지 진행시킨다.
    // 주의: _pulseCtrl(SealRail 호흡 애니메이션)이 ..repeat(reverse: true)로
    // 무한 반복되므로 pumpAndSettle은 절대 수렴하지 않고 타임아웃된다.
    // 따라서 고정 길이의 pump를 여러 번 호출해 타이핑 애니메이션만 진행시킨다.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    // "다음" 버튼으로 2단계(눈)로 이동.
    await tester.tap(find.text('다음 ›'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('2 / 3'), findsOneWidget);

    // "다음" 버튼으로 3단계(총평, 마지막)로 이동.
    await tester.tap(find.text('다음 ›'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('3 / 3'), findsOneWidget);

    // 마지막 단계에서는 "총결과 보기" 버튼이 노출되고, 누르면 onFinished 호출.
    expect(find.text('◈ 관상 총결과 보기 ›'), findsOneWidget);
    await tester.tap(find.text('◈ 관상 총결과 보기 ›'));
    await tester.pump();
    expect(finishedCount, 1);

    expect(tester.takeException(), isNull);
  });
}
