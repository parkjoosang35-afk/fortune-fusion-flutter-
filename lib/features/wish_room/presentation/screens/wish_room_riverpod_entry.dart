import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/http_wish_room_repository.dart';
import '../providers/wish_room_providers.dart';
import 'wish_room_entry_screen.dart';

/// [소원방 공식 화면] 앱 진입점 — 라우트 `/community/wish-room`의 실제
/// 대상 위젯이다.
///
/// [Provider ↔ Riverpod 공존] 소원방 화면 서브트리에서만 Riverpod
/// ProviderScope를 새로 열되, 앱 전역 package:provider 트리(app.dart의
/// MultiProvider)는 그대로 유지된다.
///
/// [실 서버 연동 전환] 이 위젯은 [wishRoomRepositoryProvider]를
/// override해 소원방 모듈 전체가 admin_web `/api/wish-room/*` 실 서버
/// API를 호출하는 [HttpWishRoomRepository]를 통해서만 데이터에 접근하게
/// 한다 — Controller/위젯 코드는 이 사실을 몰라도 되며, Mock/로컬 재화
/// 연동 단계에서 실 서버 연동으로 바뀐 지금도 코드 변경이 전혀 필요
/// 없었다(교체 지점 설계가 의도대로 동작한 사례). 복주머니 지급/차감은
/// 이제 클라이언트의 [LuckPouchProvider]가 아니라 서버(§ "서버 확정,
/// idempotency 적용" 원칙)가 전담하므로, 이 위젯은 더 이상
/// `LuckPouchProvider`를 읽지 않는다.
///
/// [버그 수정: 인트로 화면 이후 빈 화면] 이 위젯은 원래 ProviderScope로
/// [WishRoomEntryScreen] 딱 하나만 감쌌다. 인트로 화면이 메인 화면으로
/// 전환할 때 `Navigator.of(context).pushReplacement(...)`를 호출하는데,
/// 이 서브트리 안에 별도의 Navigator가 없어 그 호출이 앱의 루트
/// Navigator(app_router.dart)를 찾아 실행됐다. 그 결과 전환된
/// WishRoomScreen이 ProviderScope **밖**에 놓여 Riverpod provider를 찾지
/// 못해 렌더링에 실패했고, 릴리즈 모드에서는 예외가 화면에 표시되지 않아
/// "인트로 화면만 뜨고 다음은 회색 빈 화면"으로 보였다. 소원 작성/기록
/// 화면으로의 추가 이동도 같은 문제를 겪을 상황이었다. 해결책은 이
/// ProviderScope 내부에 소원방 모듈 전용 중첩 Navigator를 두어, 인트로→
/// 메인 전환을 포함한 모든 내부 화면 전환이 항상 ProviderScope 서브트리
/// 안에서만 일어나도록 하는 것이다.
class WishRoomRiverpodEntry extends StatelessWidget {
  const WishRoomRiverpodEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final navigatorKey = GlobalKey<NavigatorState>();
    return ProviderScope(
      overrides: [
        wishRoomRepositoryProvider.overrideWith(
          (ref) => HttpWishRoomRepository(),
        ),
      ],
      // 중첩 Navigator: 이 서브트리 안에서 발생하는 모든
      // Navigator.of(context) 호출(인트로→메인 전환, 소원 작성/기록 화면
      // 이동, pop 등)이 앱의 루트 Navigator가 아니라 이 Navigator를 찾아
      // 사용하도록 한다. 이렇게 해야 화면이 전환되어도 항상 ProviderScope
      // 서브트리 내부에 남는다.
      //
      // NavigatorPopHandler로 감싸서, 기기 뒤로가기(Android back)를 이
      // 내부 Navigator가 먼저 처리(스택이 있으면 pop)하고, 더 이상 pop할
      // 스택이 없을 때만 상위(앱 루트) Navigator로 위임해 소원방 화면
      // 자체를 벗어날 수 있게 한다.
      child: NavigatorPopHandler(
        onPopWithResult: (dynamic result) =>
            navigatorKey.currentState?.maybePop(),
        child: Navigator(
          key: navigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute(
            settings: settings,
            builder: (_) => const WishRoomEntryScreen(),
          ),
        ),
      ),
    );
  }
}
