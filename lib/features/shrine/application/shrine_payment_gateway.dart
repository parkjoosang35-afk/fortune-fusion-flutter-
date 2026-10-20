// 신당(THE SHRINE) 결제 게이트웨이 — 신통방통 "결과보기 통합 권한 시스템 v1.0"
// 실제 구현체. shrine_module.dart의 추상 인터페이스 `ShrinePaymentGateway`가
// 예고해 둔 자리(§ 주석: "구현체는 application/shrine_payment_gateway.dart,
// TodoWrite #11에서 작성")를 채운다.
//
// [버그 배경] 이 파일이 없던 동안 app.dart에 Provider<ShrinePaymentGateway>가
// 등록되지 않아, shrine_module.dart의 `_readPaymentGateway()`가 항상
// 예외를 잡아 기본값 `FreePassGateway()`로 폴백했다. `FreePassGateway.isOwned()`는
// 무조건 true를 반환하므로 `shrinePay()`가 게이트 UI를 띄우지 않고 즉시
// `onPaid()`를 호출해버렸다 — 「제단 앞으로 다가가기」를 눌러도 프리패스/
// 복주머니/광고 3택 시트가 전혀 뜨지 않았던 원인이다.
//
// [§8.1 공통화 원칙] 신당 전용 차감/판정 로직을 새로 만들지 않고, 정통사주·
// 타로·궁합 등과 동일하게 ResultAccessGateSheet(공통 3택 UI) +
// ResultAccessProvider(이미 app.dart에 전역 등록됨)를 그대로 재사용한다.
import 'package:flutter/material.dart';
import '../../result_access/presentation/result_access_gate_sheet.dart';
import '../shrine_module.dart';

class SintongShrinePaymentGateway implements ShrinePaymentGateway {
  const SintongShrinePaymentGateway();

  /// 신당 콘텐츠에는 "사전 소유 시 무조건 통과"라는 개념이 없다 — 정통사주/
  /// 타로와 동일하게 「제단 앞으로 다가가기」(혹은 다른 이야기 탭) 시점마다
  /// 매번 결과보기 3택(프리패스/복주머니/광고)으로 그 자리에서 판정한다.
  /// 따라서 항상 false를 반환해 shrinePay()가 반드시 openCheckout을 거쳐
  /// 실제 게이트 시트를 띄우도록 강제한다.
  @override
  Future<bool> isOwned(ShrineProduct p) async => false;

  /// 신통방통 공통 결과보기 게이트 시트(프리패스로 보기/복주머니로 보기/
  /// 광고 보고 무료로 보기)를 띄운다. 사용자가 3가지 중 하나로 성공적으로
  /// 권한을 확정하면 non-null 결과가 돌아온다(취소/로그인 이동 등은 null).
  @override
  Future<bool> openCheckout(BuildContext context, ShrineProduct p) async {
    final result = await showResultAccessGateSheet(
      context,
      contentType: 'shrine',
      contentId: p.id,
      categoryKey: 'shrine',
      contentTitle: p.title,
      returnRoute: '/shrine',
    );
    return result != null;
  }
}
