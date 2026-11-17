// ═══════════════════════════════════════════════════════════════
// [궁합지도 "친구 궁합 결과" 완전 빈 화면 버그 조사] 사용자 보고
// ("이제는 궁합지도가 안돼네?" + 스크린샷: AppBar 제목은 정상 표시되지만
// 본문이 완전히 흰 빈 화면) 재현 테스트.
//
// 실제 서버 응답(gr_77, 2026-11 curl로 직접 확인한 JSON)을
// [GunghapProvider.debugSetResult]로 그대로 주입해 네트워크 호출 없이
// `GunghapResultScreen`의 렌더링 경로만 단독으로 재현한다.
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/gunghap/application/gunghap_provider.dart';
import 'package:flutter_app/features/gunghap/data/gunghap_repository.dart';
import 'package:flutter_app/features/gunghap/presentation/gunghap_result_screen.dart';
import 'package:flutter_app/features/luckpouch/application/luck_pouch_provider.dart';
import 'package:flutter_app/features/wallet/application/wallet_provider.dart';
import 'package:flutter_app/features/wallet/data/wallet_repository.dart';
import 'package:flutter_app/core/theme/text_scale_provider.dart';

// 실제 GET /api/public/gunghap/results/gr_77 응답(2026-11 curl 확인).
const _grResult = <String, dynamic>{
  'resultId': 'gr_77',
  'ownerName': null,
  'guestName': '박우배',
  'relationType': 'BI_HWA',
  'relationTypeLabel': '동류동반',
  'relationTypeDesc': '같은 오행으로 결이 비슷해 편안하게 동행하는 관계',
  'chemistryScore': 77,
  'grade': '중상',
  'gradeCode': 'B',
  'majorId': 'friend',
  'subName': '친구 궁합',
  'categories': [
    {'categoryId': 'friend', 'grade': '중상', 'gradeCode': 'B'},
  ],
  'unlocked': false,
  'unlockCost': 100,
  'owner': {
    'dayMasterKr': '갑',
    'dayMasterElement': '목',
    'elementCounts': {'목': 2, '화': 0, '토': 3, '금': 0, '수': 3},
  },
  'member': {
    'dayMasterKr': '을',
    'dayMasterElement': '목',
    'elementCounts': {'목': 1, '화': 2, '토': 0, '금': 1, '수': 4},
  },
};

void main() {
  testWidgets(
    'GunghapResultScreen renders visible content for real gr_77 result data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final provider = GunghapProvider(GunghapRepository());
      // fetchResult()가 실제 네트워크를 타지 않도록, initState의
      // postFrameCallback이 끝나기 전에 미리 result를 심어 둔다 —
      // 그래도 _load()가 다시 fetchResult를 호출해 실패하면서
      // result를 지울 수 있으므로(네트워크 에러 시 _result는 유지됨,
      // fetchResult 구현 참고) 문제없다.
      provider.debugSetResult(_grResult);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GunghapProvider>.value(value: provider),
            ChangeNotifierProvider<LuckPouchProvider>(
              create: (_) => LuckPouchProvider(WalletProvider(WalletRepository())),
            ),
            ChangeNotifierProvider<TextScaleProvider>(
              create: (_) => TextScaleProvider(),
            ),
          ],
          child: const MaterialApp(
            home: GunghapResultScreen(resultId: 'gr_77'),
          ),
        ),
      );

      // initState의 addPostFrameCallback이 debugSetResult로 미리 심어둔
      // _result를 지우지 않는지(네트워크 실패 시 _result 유지) 한 프레임만
      // 더 확인한다. 애니메이션 컨트롤러(KenBurnsHero/StarMap/ScoreRing)가
      // 계속 도는 상태로 pump(duration)을 반복하면 테스트 하네스의 semantics
      // 트리 갱신 타이밍 이슈(assert)가 나므로, 여기서는 pump() 1회로
      // "첫 프레임에 실제로 무엇이 그려지는지"만 확인한다(실제 버그 재현
      // 목적에는 이것으로 충분 — 문제는 "전혀 안 보임"이지 "느리게 보임"이
      // 아니다).
      await tester.pump();

      // 디버그: 현재 위젯 트리에 어떤 Text들이 있는지 출력.
      final allTexts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      // ignore: avoid_print
      print('--- ALL TEXT WIDGETS (${allTexts.length}) ---');
      for (final t in allTexts) {
        // ignore: avoid_print
        print('TEXT: $t');
      }

      // AppBar 제목이 정상 표시되는지 확인(스크린샷과 동일 증상 재현 여부).
      expect(find.text('친구 궁합 결과'), findsOneWidget);

      // 본문에 실제 콘텐츠(예: 상대방 이름, 관계 설명)가 보이는지 확인.
      expect(
        find.textContaining('박우배님의 결과예요'),
        findsOneWidget,
        reason: '본문에 "나님과 박우배님의 결과예요" 텍스트가 있어야 하는데 없다면 '
            '_ResultBody가 렌더링되지 않거나 그 안에서 조용히 실패한 것.',
      );

      // [클린업] GHScoreRing(점수 카운트업, Future.delayed(scoreDelay) 1회성
      // 타이머)과 _KenBurnsHero(ken-burns 확대, repeat(reverse:true) 무한
      // 애니메이션)가 테스트 종료 시점에도 아직 동작 중이면 "Timer is
      // still pending" 에러가 난다(버그와 무관한 테스트 하네스 문제).
      // scoreDelay(350ms)를 다 소진시킨 뒤 위젯 트리를 비워 모든
      // AnimationController를 dispose시키고 테스트를 마친다.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
