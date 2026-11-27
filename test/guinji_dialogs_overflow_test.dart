import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// [반응형 화면 규격 통일] 귀인지도(guinji) 내 showDialog 구조 5종을
// 각 소스 파일의 실제 위젯 트리와 동일하게 재구성해 검증한다. 모두
// private 메서드 내부(또는 provider/네트워크 흐름 뒤)에 있어 직접
// import해 호출하기 어려우므로, force_update_dialog_overflow_test.dart
// 와 동일한 접근 방식(동일 구조 재현)을 사용한다.
//
// [조사 결과 — 5개 다이얼로그 전체 (390x844@1.0 ~ 320x568@2.5 매트릭스)]
// ✅ 발견 & 수정 (실제 버그):
//   1) 귀인지도 랭킹 삭제 확인 (guinji_map_ranking_screen.dart _confirmDelete):
//      320x568@2.0에서 8px, @2.5에서 282px RenderFlex 오버플로 확인.
//      원인: 긴 이름(p.name) 보간 제목 + 본문 + 액션 2개가 다이얼로그
//      높이를 초과. 수정: AlertDialog(scrollable: true) 적용(제목+본문만
//      스크롤, 액션 버튼은 고정 유지하는 Flutter 기본 동작).
//   2) 귀인지도 마일스톤 축하 (guinji_map_result_screen.dart
//      _maybeShowMilestoneCelebration): 320x568@2.5에서 142px 오버플로
//      확인. 원인: 커스텀 Dialog(AlertDialog 아님)의 Column이 스크롤
//      래퍼 없이 고정 높이 초과. 수정: Column을 SingleChildScrollView로
//      감쌈.
// ⬜ 조사 & 안전 확인 (버그 없음, 수정 불필요):
//   3) 귀인지도 참여완료 (guinji_join_screen.dart) — 5개 조건 전체 통과.
//   4) 귀인지도 링크 재발급 확인 (guinji_map_share_screen.dart
//      _confirmReissue) — 5개 조건 전체 통과.
//   5) 귀인지도 링크 중단 확인 (guinji_map_share_screen.dart
//      _confirmRevoke) — 5개 조건 전체 통과.
// (디자인/색상/문구/애니메이션 변경 없음 — 레이아웃 구조만 수정)

// 1) guinji_join_screen.dart _handleSubmit() 내부 "참여 완료" AlertDialog.
Future<void> showJoinCompleteDialogLike(
  BuildContext context, {
  required String ownerName,
  required String hanja,
  required String label,
  required int chemistryScore,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1C1430),
      title: const Text(
        '참여 완료',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        '$ownerName님과 당신은 $hanja $label의 결이에요.\n케미 점수 $chemistryScore점',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

// 2) guinji_map_ranking_screen.dart _confirmDelete() 삭제 확인 다이얼로그.
// [수정] scrollable: true — 긴 이름 제목 + 큰 textScale에서 발생한
// 8px(@2.0)/282px(@2.5) 오버플로를 해결 (실제 소스와 동기화).
Future<bool?> showRankingDeleteDialogLike(
  BuildContext context, {
  required String name,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      scrollable: true,
      title: Text('$name님을 지도에서 뺄까요'),
      content: const Text('관계 결과와 열어 둔 풀이도 함께 사라져요'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('빼기'),
        ),
      ],
    ),
  );
}

// 3) guinji_map_result_screen.dart _maybeShowMilestoneCelebration() 축하 다이얼로그.
// [수정] Column을 SingleChildScrollView로 감쌈 — 320x568@2.5에서
// 발생한 142px 오버플로를 해결 (실제 소스와 동기화).
Future<void> showMilestoneDialogLike(
  BuildContext context, {
  required int rewardPoint,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF231A3C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '축하 이벤트 달성',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '친구 3명이 귀인지도에 모였어요.\n고마운 마음을 담아 복주머니 ${rewardPoint > 0 ? rewardPoint : 30}개를 보내드려요.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('좋아요'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// 4) guinji_map_share_screen.dart _confirmReissue() 재발급 확인 다이얼로그.
Future<bool?> showReissueDialogLike(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('새 링크를 만들까요?'),
      content: const Text(
        '이전 링크로 들어오던 사람은 더 이상 들어올 수 없어요.\n'
        '이미 지도에 합류한 친구는 그대로 남아있어요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('새 링크 만들기'),
        ),
      ],
    ),
  );
}

// 5) guinji_map_share_screen.dart _confirmRevoke() 중단 확인 다이얼로그.
Future<bool?> showRevokeDialogLike(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('링크를 중단할까요?'),
      content: const Text(
        '이 링크로 더 이상 새로운 친구가 들어올 수 없어요.\n'
        '언제든 다시 열 수 있어요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('중단하기'),
        ),
      ],
    ),
  );
}

void main() {
  final conditions = <(Size, double)>[
    (const Size(390, 844), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(320, 568), 1.5),
    (const Size(320, 568), 2.0),
    (const Size(320, 568), 2.5),
  ];

  for (final (size, textScale) in conditions) {
    final suffix =
        '${size.width.toInt()}x${size.height.toInt()}@$textScale';

    testWidgets('귀인지도 참여완료 다이얼로그가 $suffix에서 오버플로 없이 뜬다', (tester) async {
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
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showJoinCompleteDialogLike(
                    context,
                    ownerName: '아주긴닉네임표기테스트지도소유자',
                    hanja: '貴',
                    label: '천생귀인',
                    chemistryScore: 92,
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      var ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
    });

    testWidgets('귀인지도 랭킹 삭제 확인 다이얼로그가 $suffix에서 오버플로 없이 뜬다', (tester) async {
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
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showRankingDeleteDialogLike(
                    context,
                    name: '아주긴이름표기테스트닉네임유저',
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      var ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
    });

    testWidgets('귀인지도 마일스톤 축하 다이얼로그가 $suffix에서 오버플로 없이 뜬다', (tester) async {
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
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showMilestoneDialogLike(context, rewardPoint: 30),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      var ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
    });

    testWidgets('귀인지도 링크 재발급 확인 다이얼로그가 $suffix에서 오버플로 없이 뜬다', (tester) async {
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
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showReissueDialogLike(context),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      var ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
    });

    testWidgets('귀인지도 링크 중단 확인 다이얼로그가 $suffix에서 오버플로 없이 뜬다', (tester) async {
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
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showRevokeDialogLike(context),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      var ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      ex = tester.takeException();
      if (ex != null) debugDumpRenderTree();
      expect(ex, isNull);
    });
  }
}
