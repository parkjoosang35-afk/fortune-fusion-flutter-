import '../../../features/pass/application/pass_provider.dart';
import '../assets/asset_type.dart';
import '../assets/open_pass_state.dart';

/// [재화 구조 정리 및 재연결] 공통 접근 체크 로직.
///
/// 모든 화면은 "이 콘텐츠를 열어도 되는가"를 개별 판단하지 않고, 반드시 이
/// 클래스를 거쳐서 체크한다(공통 정책 체크 로직을 기준으로 구현한다는 원칙).
///
/// [정리 이력] 과거 "3대 자산(열림패스/행복머니/복주머니)" 설계 당시에는
/// WalletProvider·LuckPouchProvider도 함께 주입받아 `happyMoneyState`/
/// `canSpendHappyMoney`/`luckPouchState`/`canSpendLuckPouch`를 제공했으나,
/// 어느 화면도 호출하지 않는 죽은 코드였다(상점/커뮤니티 진입은 잔액과 무관하게
/// 항상 허용). 최종 2-자산 구조(프리패스+복주머니) 정리에 맞춰 제거했다 —
/// 복주머니 잔액/이력이 필요한 화면은 [WalletProvider]/[LuckPouchProvider]를
/// 직접 구독한다.
///
/// [app.dart]에서 `ProxyProvider<PassProvider, AccessChecker>`로 등록되어,
/// PassProvider가 갱신될 때마다 최신 인스턴스로 갈아끼워진다. 이 클래스 자체는
/// 상태를 들고 있지 않고(ChangeNotifier가 아님), 매 호출 시점에 PassProvider의
/// "현재 값"만 읽는다.
class AccessChecker {
  const AccessChecker({required PassProvider pass}) : _pass = pass;

  final PassProvider _pass;

  // ── 열림패스(운세군) ──

  /// 현재 열림패스 상태(inactive/active/expired) + 남은 시간을 함께 반환.
  OpenPassState get openPassState => OpenPassState.fromModel(_pass.status);

  /// 열림패스가 지금 활성 상태인가. [FeatureScope.fortune] 콘텐츠의
  /// 잠금 여부를 판단하는 유일한 기준으로 사용한다.
  bool isOpenPassActive() => openPassState.isActive;

  /// 열림패스 남은 시간(비활성/만료 시 Duration.zero).
  Duration getOpenPassRemainingTime() => openPassState.remaining;

  /// 운세군 콘텐츠(무료 공개 영역이 아닌 상세 구간) 접근 가능 여부.
  /// = 열림패스 활성 여부와 동일하다(운세군은 열림패스 외 다른 자산으로
  /// 잠금을 풀지 않는다 — §8 금지 원칙).
  bool canAccessFortuneScope() => isOpenPassActive();

  // ── FeatureScope 기반 단일 진입점 ──

  /// [scope]가 요구하는 주 자산 기준으로 "이 화면에 들어갈 수 있는가"를
  /// 판단한다. shop/community는 화면 진입 자체를 막지 않으므로(구매/적립은
  /// 화면 안에서 이루어짐) 기본 true이며, fortune만 열림패스로 게이트한다.
  bool canEnter(FeatureScope scope) {
    switch (scope) {
      case FeatureScope.fortune:
        return true; // 무료 공개 영역은 항상 진입 가능, 구간별 잠금은 섹션 단위로 판단
      case FeatureScope.community:
      case FeatureScope.shop:
        return true;
    }
  }
}
