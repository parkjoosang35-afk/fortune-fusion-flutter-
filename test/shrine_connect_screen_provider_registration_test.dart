// shrine_connect_screen_provider_registration_test.dart — 회귀 테스트:
// 신당 ConnectScreen("門 신통방통 회원으로 들어가기")에서
// context.read<MemberRepository>()를 호출하는데, app.dart에
// Provider<MemberRepository>가 등록되지 않아 ProviderNotFoundException이
// 발생 → try/catch 없이 그대로 전파되어 async 함수가 중단되고
// `busy` 플래그가 되돌아오지 않아 CTA 버튼이 영원히 멈춰 다음 화면
// (talk/info)으로 전혀 넘어가지 않았다(대표 제보 스크린샷).
// SajuScreen의 context.read<SajuRepository>()도 동일한 미등록 문제였다.
//
// 이 테스트는 ShrinePaymentGateway 버그(먼저 수정됨)와 똑같은 패턴의
// 재발을 방지하기 위해, app.dart와 동일하게 MemberRepository/
// SajuRepository를 Provider 트리에 등록한 상태에서 ConnectScreen의
// CTA를 탭하면 다음 화면으로 실제로 전환되는지 직접 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/features/shrine/engine/shrine_engine.dart';
import 'package:flutter_app/features/shrine/screens/screens_v3.dart';
import 'package:flutter_app/features/shrine/screens/screens.dart';
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';
import 'package:flutter_app/features/shrine/widgets/common.dart';
import 'package:flutter_app/features/shrine/widgets/shrine_nav.dart';

const ctaBusyLabel = '명부에 옮겨 적는 중…';
const ctaIdleLabel = '동의하고 명부 옮기기';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await _initPrefs();
  });

  Widget harness() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ShrineSessionProvider(
            // ShrineModule.prefs 대신 테스트 전용 인스턴스를 직접 생성한다
            // (ShrineModule.init()은 asset 번들 로드가 필요해 단위 테스트
            // 범위를 벗어난다 — 상태 저장 로직 자체는 이 테스트의 관심사가
            // 아니다).
            _TestPrefsHolder.instance,
          ),
        ),
        // [회귀 방지] 이 두 Provider가 app.dart에 실제로 등록되어 있어야
        // ConnectScreen/SajuScreen이 정상 동작한다 — 등록을 빠뜨리면 바로
        // 아래 testWidgets가 즉시 실패해야 한다.
        Provider<MemberRepository>(create: (_) => SampleMemberRepository()),
        Provider<SajuRepository>(create: (_) => SampleSajuRepository()),
      ],
      child: const MaterialApp(home: ConnectScreen()),
    );
  }

  testWidgets(
    'ConnectScreen: CTA 탭 -> MemberRepository.link() 성공 후 '
    '다음 화면으로 전환되고 busy 로딩 문구 상태에 멈추지 않는다',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.byType(RedButton), findsOneWidget);
      expect(find.text(ctaIdleLabel), findsOneWidget);

      // 명부 패널 등 신규 디자인 요소로 인해 스크롤 영역이 늘어나
      // CTA 버튼이 테스트 뷰포트 밖에 위치할 수 있으므로 먼저 스크롤한다.
      await tester.ensureVisible(find.text(ctaIdleLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text(ctaIdleLabel));
      // 항목 이동 애니메이션(420ms x 3개 + 500ms 대기) 이후
      // SampleMemberRepository.link()가 추가로 1200ms 지연 후 완료된다.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(ctaBusyLabel), findsOneWidget,
          reason: '탭 직후에는 busy=true 상태(로딩 문구)여야 한다');

      await tester.pumpAndSettle(const Duration(milliseconds: 4000));

      // [핵심 회귀 검증] MemberRepository가 미등록이었다면 link() 호출에서
      // ProviderNotFoundException이 던져져 busy가 계속 true로 남고,
      // ShrineNav.go()도 호출되지 못해 ConnectScreen 자체에 그대로 머문다.
      // 수정 후에는 SampleMemberRepository가 name/birth 모두 채워 반환하므로
      // 'talk' 화면(TalkScreen)으로 push 전환되어야 한다.
      expect(find.byType(ConnectScreen), findsNothing,
          reason: 'ConnectScreen을 벗어나 다음 화면으로 push 전환되어야 한다');
      expect(find.byType(TalkScreen), findsOneWidget,
          reason: 'MemberProfile.name/birth가 모두 있으면 talk 화면으로 이동해야 한다');
    },
  );
}

class _TestPrefsHolder {
  static late SharedPreferences instance;
}

Future<void> _initPrefs() async {
  _TestPrefsHolder.instance = await SharedPreferences.getInstance();
}
