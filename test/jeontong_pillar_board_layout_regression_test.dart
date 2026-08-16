// [회귀 방지] 사주 결과 화면 하단 "사주 원국 · 실계산 상세"의 PillarBoard가
// 실제 서비스에서 완전히 빈 칸으로 렌더링되던 버그(정식 오픈 전 발견)의
// 재발 방지 테스트.
//
// 근본 원인: PillarBoard 내부 _Row가 `CrossAxisAlignment.stretch`를 쓰는
// Row였는데, 이 위젯이 결과 화면의 ListView 안에 직접 들어가면서 부모로부터
// 무한대(Infinity) 높이 제약을 받아 "BoxConstraints forces an infinite
// height" 렌더링 예외가 발생했다. 예외가 던져지면 천간/지지 칸 전체가
// 그려지지 않고 빈 공간만 남았다(실제 사주 계산 데이터 자체는 항상
// 정상이었음 — 계산 로직 문제가 아니라 순수 레이아웃 버그).
//
// 수정: _Row를 IntrinsicHeight로 감싸 Row에 유한한 높이를 제공.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/jeontong_eighty_report_builder.dart';
import 'package:flutter_app/features/home/domain/saju_interpreter.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/jeontong_saju_detail_section.dart';
import 'package:flutter_app/features/home/presentation/jeontong_design/pillar_board.dart';

void main() {
  testWidgets(
      '[회귀] PillarBoard는 ListView 안에서도 레이아웃 예외 없이 '
      '천간/지지 한자를 실제로 렌더링한다', (tester) async {
    await tester.runAsync(() async {
      await SajuRules.preload();
    });

    final kst = DateTime(1990, 5, 15, 14, 30);
    final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
      kst: kst,
      gender: 'male',
      isLunar: false,
      referenceDate: DateTime.now(),
    );

    // 실제 결과 화면(_ResultBody)과 동일한 조건: ListView 안에 배치 —
    // 버그 재현의 핵심 조건이었으므로 그대로 유지한다.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            JeontongSajuDetailSection(
              categoryLabel: '평생 총운',
              birthDateTimeUtc: kst.subtract(const Duration(hours: 9)),
              gender: 'male',
              isLunar: false,
              referenceDate: DateTime.now(),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(PillarBoard), findsOneWidget);
    // 4기둥 중 최소 년주 천간/일주 지지 한자가 실제로 화면에 그려지는지
    // 확인 — 빈 칸 회귀 시 이 expect가 실패한다.
    expect(find.text(built.profile.yearPillar.stemHanja), findsWidgets);
    expect(find.text(built.profile.dayPillar.branchHanja), findsWidgets);
  });
}
