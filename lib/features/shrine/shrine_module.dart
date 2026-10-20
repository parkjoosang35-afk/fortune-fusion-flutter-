// 신당 THE SHRINE — 신통방통 앱에 붙이는 Flutter 기능 모듈
// [provider+Navigator 1.0 포팅] 원본은 flutter_riverpod(Provider/Override)+
// go_router(RouteBase) 기반이나, 이 프로젝트는 provider(ChangeNotifier)+
// Navigator 1.0 고정 정책이므로 아래와 같이 치환한다.
//  · Riverpod `Provider<T>`                → package:provider 의 `Provider<T>`
//    (app.dart의 MultiProvider에 등록, context.read<T>() 로 읽는다)
//  · `ShrineModule.overrides(...)`         → app.dart에 직접 Provider<T> 등록
//    (신당 모듈은 "등록해야 할 타입 목록"만 안내하는 정적 도움말로 남긴다)
//  · `shrineRoutes()`(go_router RouteBase)  → widgets/shrine_screen_router.dart
//    + widgets/shrine_nav.dart (Navigator 1.0)
//  · `_guard()`                             → ShrineNav._guard (shrine_nav.dart)
// ─────────────────────────────────────────────────────────────
//   · 진입점:   ShrineTab()          ← 하단바 탭의 body
//   · 네비게이션: ShrineNav.go(context, id, params: {...})
//   · 초기화:   await ShrineModule.init()   ← 신통방통 main() 에서 한 번
// 모든 신당 경로는 kShrineBase('/shrine') 아래에 있다는 개념만 유지한다
// (Navigator 1.0 에는 실제 path가 없으므로 ShrineNav id 문자열로 대체).
// ─────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/models.dart';
import 'theme/tokens.dart';
import 'widgets/bujeok.dart' show BujeokLayout;

// ═════════ 결제 — 신통방통 결제창을 연다 (신당은 결제를 직접 처리하지 않는다) ═════════
/// 결제가 필요한 지점 2곳:
///  ① 신당 내부(/hall) 「제단 앞으로 다가가기」(화면 탭 포함)  → ShrineProduct.entry
///  ② 추가 이야기 목록에서 다른 이야기 카드 탭                → ShrineProduct.tale(id)
class ShrineProduct {
  final String id; // 신통방통 상품 ID 로 매핑 (예: 'shrine_entry', 'shrine_tale_room')
  final String title; // 결제창에 보일 이름
  const ShrineProduct(this.id, this.title);
  static const entry = ShrineProduct('shrine_entry', '신당 입장 · 붉은 방울');
  static ShrineProduct tale(String taleId, String title) =>
      ShrineProduct('shrine_tale_$taleId', '신당 이야기 · $title');
}

/// 신통방통 개발팀이 구현: 기존 신통방통 결제창(ResultAccessGateSheet 3택 등)을
/// 띄우고 결과를 돌려준다. (구현체는 application/shrine_payment_gateway.dart,
/// TodoWrite #11에서 작성 — 이 파일은 추상 인터페이스만 정의한다.)
abstract class ShrinePaymentGateway {
  /// 이미 구매(이용권 보유)했으면 true — 결제창 없이 통과
  Future<bool> isOwned(ShrineProduct p);

  /// 신통방통 결제창을 연다. 결제 완료 true · 취소/실패 false
  Future<bool> openCheckout(BuildContext context, ShrineProduct p);
}

/// 기본값(연동 전): 결제 없이 통과 — 반드시 신통방통 구현으로 교체(app.dart에서
/// Provider<ShrinePaymentGateway> 등록 시 실제 게이트웨이로 바꾼다).
class FreePassGateway implements ShrinePaymentGateway {
  @override
  Future<bool> isOwned(ShrineProduct p) async => true;
  @override
  Future<bool> openCheckout(BuildContext context, ShrineProduct p) async => true;
}

/// 결제 확인 후 진행. 이미 보유 → 바로 진행 / 미보유 → 신통방통 결제창 → 성공 시
/// 진행 / 취소 → 그 자리에 머묾.
/// [포팅] 원본 `shrinePay(context, ref, product, onPaid)`에서 `ref` 매개변수를
/// 제거하고, `context.read<ShrinePaymentGateway>()`로 게이트웨이를 읽는다.
Future<void> shrinePay(
    BuildContext context, ShrineProduct p, VoidCallback onPaid) async {
  final pay = _readPaymentGateway(context);
  if (await pay.isOwned(p)) {
    onPaid();
    return;
  }
  if (!context.mounted) return;
  final ok = await pay.openCheckout(context, p);
  if (ok && context.mounted) onPaid();
}

/// provider 패키지의 Provider<ShrinePaymentGateway>가 app.dart에 등록되어
/// 있지 않으면 FreePassGateway로 안전하게 폴백한다(개발 중 화면 단독
/// 테스트를 위함 — 실제 운영 배포 전에는 반드시 app.dart에 실제 게이트웨이가
/// 등록되어 있어야 한다).
ShrinePaymentGateway _readPaymentGateway(BuildContext context) {
  try {
    return Provider.of<ShrinePaymentGateway>(context, listen: false);
  } catch (_) {
    return FreePassGateway();
  }
}

/// 신당 경로 접두사 개념(Navigator 1.0 에는 실제 path가 없어 문서용으로만 남김)
/// · 신당을 나갈 때 돌아갈 신통방통 경로 — AppShell._openShrine()/ShrineNav.exit()
///   가 실제 이동을 담당하므로 이 상수 자체는 더 이상 go_router처럼 쓰이지
///   않지만, 원본과 동일한 개념 상수로 유지한다(주석/문서 목적).
const kShrineBase = '/shrine';
const kShrineExit = '/home'; // ← AppShell에서 하단바 홈 탭으로 되돌아가는 것으로 매핑

late Shrine shrine;

class ShrineModule {
  static bool _ready = false;
  static late SharedPreferences prefs;

  /// 신통방통 main() 에서 runApp 전에 한 번 호출
  static Future<void> init() async {
    if (_ready) return;
    shrine = await Shrine.load();
    final raw =
        jsonDecode(await rootBundle.loadString('assets/shrine/data/shrine.json')) as Map;
    BujeokLayout.init(raw['bujeokLayout']);
    prefs = await SharedPreferences.getInstance();
    _ready = true;
  }
}

/// 신당 전용 테마 — 신통방통(소원방 팔레트) 안에서 신당 화면만 먹색·검붉은 톤으로 감싼다
class ShrineTheme extends StatelessWidget {
  final Widget child;
  const ShrineTheme({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: C.bg,
          useMaterial3: true,
          colorScheme: const ColorScheme.dark(
              surface: C.bg, primary: C.red, secondary: C.gold),
        ),
        child: child,
      );
}
