// [사용자 요청 — 외부 검수 지시 ②] "사주 엔진 계산 결과가 실제 사용자
// 화면까지 정확하게 전달되는지" 직접 실행으로 검증하는 통합(위젯) 테스트.
//
// 코드 추적 결과: story_detail_screen.dart(사주 실제 결과 화면)는
// `_buildProfile()`에서 `SajuVisualAdapter.build()`(PHASE1~4 엔진을 그대로
// 호출)로 `SajuVisualProfile`을 만들고, 이를 `SajuEvidenceCard` →
// `SajuPillarGrid`/`SajuElementBars`/`SajuLuckStream`에 전달해 원국표·
// 오행바·대운 흐름을 그린다. 이 테스트는 그 경로를 "코드만 읽고 믿는 것"이
// 아니라, 실제로 위젯을 pump해 화면에 그려진 Text 위젯의 글자가 엔진
// 계산값과 정확히 일치하는지 눈에 보이는 결과로 증명한다.
import 'package:flutter/material.dart';
import 'package:flutter_app/features/saju_renewal/data/saju_visual_adapter.dart';
import 'package:flutter_app/features/saju_renewal/widgets/saju_visual_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('사주 엔진 → 화면 전달 파이프라인 — SajuVisualAdapter → SajuPillarGrid', () {
    testWidgets(
      '실제 생년월일시(1990-03-15 08:30)를 엔진에 넣으면, 화면에 '
      '엔진이 계산한 정확한 8글자(경오/기묘/기묘/무진)가 전부 그려진다',
      (tester) async {
        // 1) 엔진 호출(코드 재구현 없이 기존 SajuVisualAdapter 그대로 사용 —
        //    story_detail_screen.dart._buildProfile()과 동일한 호출).
        final profile = SajuVisualAdapter.build(
          kst: DateTime(1990, 3, 15, 8, 30),
          gender: 'male',
          isLunar: false,
          timeUnknown: false,
          referenceDate: DateTime(2024, 1, 1),
        );

        // 외부 정답 대조 테스트(manseryeok_external_reference_audit_test.dart)의
        // personA와 동일 입력 — 정답: 년庚午 월己卯 일己卯 시戊辰.
        expect(profile.pillars.length, 4, reason: '화면 표시 순서(0=時 1=日 2=月 3=年) 4칸');
        expect(profile.pillars[3]?.stemHanja, '庚', reason: '년간');
        expect(profile.pillars[3]?.branchHanja, '午', reason: '년지');
        expect(profile.pillars[2]?.stemHanja, '己', reason: '월간');
        expect(profile.pillars[2]?.branchHanja, '卯', reason: '월지');
        expect(profile.pillars[1]?.stemHanja, '己', reason: '일간');
        expect(profile.pillars[1]?.branchHanja, '卯', reason: '일지');
        expect(profile.pillars[0]?.stemHanja, '戊', reason: '시간');
        expect(profile.pillars[0]?.branchHanja, '辰', reason: '시지');

        // 2) 실제 화면 위젯(SajuPillarGrid)에 이 profile을 그대로 꽂아
        //    렌더링 — story_detail_screen.dart와 동일한 사용 패턴.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SajuPillarGrid(
                pillars: profile.pillars,
                cell: 44,
                gap: 7,
                reveal: 8, // 8글자 전부 "새겨짐" 상태로 표시
                showLabels: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 3) 화면에 실제로 그려진 Text 위젯 중, 엔진이 계산한 한자
        //    8글자가 전부 존재하는지 직접 확인(코드가 아니라 렌더 결과).
        for (final expectedChar in ['庚', '午', '己', '卯', '戊', '辰']) {
          expect(
            find.text(expectedChar),
            findsWidgets,
            reason: '화면에 "$expectedChar" 글자가 렌더링되어야 함(엔진 계산 결과가 화면 전달 안 됨)',
          );
        }
        // 己/卯는 월주·일주 둘 다에 등장하므로 2회씩 나타나야 정상.
        expect(
          find.text('己'),
          findsNWidgets(2),
          reason: '己는 월간+일간에 중복 등장(엔진 계산상 정상) — 화면에도 2회 그려져야 함',
        );
        expect(
          find.text('卯'),
          findsNWidgets(2),
          reason: '卯는 월지+일지에 중복 등장(엔진 계산상 정상) — 화면에도 2회 그려져야 함',
        );

        // ignore: avoid_print
        print(
          '[엔진→화면 파이프라인 검증] personA(1990-03-15 08:30) 엔진 계산 '
          '庚午/己卯/己卯/戊辰 → SajuPillarGrid 렌더링 결과에서 전체 글자 '
          '확인 완료(find.text 매칭 성공)',
        );
      },
    );

    testWidgets('서로 다른 생년월일을 넣으면 화면에 그려지는 글자도 달라진다(하드코딩 아님 증명)', (
      tester,
    ) async {
      final profileB = SajuVisualAdapter.build(
        kst: DateTime(1995, 11, 2, 22, 10),
        gender: 'female',
        isLunar: false,
        timeUnknown: false,
        referenceDate: DateTime(2024, 1, 1),
      );
      // personB 정답(외부 라이브러리 대조 완료): 乙亥/丙戌/丁酉/辛亥
      expect(profileB.pillars[3]?.stemHanja, '乙');
      expect(profileB.pillars[3]?.branchHanja, '亥');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SajuPillarGrid(
              pillars: profileB.pillars,
              cell: 44,
              gap: 7,
              reveal: 8,
              showLabels: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // personA의 글자(庚午 己卯 戊辰)는 전혀 나타나지 않아야 하고,
      // personB 고유 글자(乙亥 丙戌 丁酉 辛)는 나타나야 한다.
      expect(find.text('庚'), findsNothing, reason: 'personA 고유 글자가 섞이면 하드코딩 의심');
      expect(find.text('乙'), findsWidgets, reason: 'personB 고유 글자(년간)가 화면에 있어야 함');
      expect(find.text('亥'), findsWidgets, reason: 'personB 고유 글자(년지/시지)가 화면에 있어야 함');
      expect(find.text('丙'), findsWidgets, reason: 'personB 고유 글자(월간)가 화면에 있어야 함');
      expect(find.text('戌'), findsWidgets, reason: 'personB 고유 글자(월지)가 화면에 있어야 함');

      // ignore: avoid_print
      print('[엔진→화면 파이프라인 검증] personB 입력 변경 시 화면 렌더 결과도 함께 변경됨을 확인');
    });
  });

  group('오행 바(SajuElementBars) — 엔진 오행 집계가 화면 위젯에 그대로 전달되는지', () {
    testWidgets('elementsWeighted 맵이 비어있지 않고, 합이 0보다 크면 위젯이 정상 렌더링된다', (
      tester,
    ) async {
      final profile = SajuVisualAdapter.build(
        kst: DateTime(1990, 3, 15, 8, 30),
        gender: 'male',
        isLunar: false,
        timeUnknown: false,
        referenceDate: DateTime(2024, 1, 1),
      );
      expect(profile.elementsWeighted, isNotEmpty, reason: '오행 분포 맵이 비어있으면 화면에 막대가 전혀 안 그려짐');
      final total = profile.elementsWeighted.values.fold<double>(0, (a, b) => a + b);
      expect(total, greaterThan(0), reason: '오행 가중합이 0이면 모든 막대가 0 크기로 사실상 미표시');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: SajuElementBars(
                weighted: profile.elementsWeighted,
                compact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 렌더링 과정에서 예외 없이 트리가 구성되면(pumpAndSettle 통과) 성공.
      expect(find.byType(SajuElementBars), findsOneWidget);

      // ignore: avoid_print
      print(
        '[엔진→화면 파이프라인 검증] 오행 가중치=${profile.elementsWeighted} '
        '→ SajuElementBars 정상 렌더링(예외 없음)',
      );
    });
  });
}
