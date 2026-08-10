import 'package:flutter/material.dart';

/// [STEP8-2 로그인 필수 UI] 로그인 완료 후 "원래 가려던 프리패스 화면"으로
/// 자동 복귀시키기 위한 전역 Navigator 키.
///
/// `app_router.dart`(모든 화면 import를 갖고 있어 무거움)에 두지 않고 별도의
/// 가벼운 파일로 분리해, `pass_gate_helper.dart`처럼 특정 기능 레이어에서도
/// 부담 없이 import할 수 있게 한다.
///
/// ProfileCheckScreen이 `pushNamedAndRemoveUntil('/home', ...)`으로 스택을
/// 완전히 교체하고 나면 그 화면(State) 자체의 BuildContext는 곧 dispose되어
/// 더 이상 Navigator.of(context)로 추가 라우팅을 이어갈 수 없다. 이 전역 키로
/// 얻은 루트 Navigator의 context를 사용하면, 홈으로 이동을 완료한 *다음* 프레임에
/// pending 요청(PendingPassGateRequest)을 그대로 재실행할 수 있다.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
