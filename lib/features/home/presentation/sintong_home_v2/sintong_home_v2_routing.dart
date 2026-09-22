// ═══════════════════════════════════════════════════════════════
// FILE: sintong_home_v2_routing.dart
// [신통방통 홈 v2] 새 디자인(히어로 캐러셀/칩/하단 시트)의 5개 카테고리
// (귀인지도/정통사주/타로/소원방/손금·관상)를 눌렀을 때 이동할 목적지를
// 한 곳에 모은다.
//
// [중요 수정] 원래 이 파일은 "새 디자인 전용 서브 목차 화면(guide/saju/
// tarot/wish/palm GuideSubScreen)"을 만들어 그리로 연결했으나, 이는
// 사용자가 요청한 범위(메인 화면만 교체)를 벗어난 것이었다. 사용자
// 피드백("귀인지도 클릭시 넘어가야 하는데 안 넘어가고 ... 완전히
// 개판") 반영 — 새 서브 화면을 전부 걷어내고, 기존 앱에 이미 있던
// 진짜 화면으로 직접 연결한다(v1 home_screen.dart의 서비스카드
// onTap과 완전히 동일한 목적지).
//
// [원칙] 이 파일은 새 화면/새 API/새 상태관리를 추가하지 않는다 — 오직
// "어느 카테고리를 누르면 기존의 어떤 화면으로 가는지"만 결정한다.
// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../../../core/router/app_router.dart' show AppRouter;
import '../../../../core/widgets/face_palm_select_sheet.dart';
import '../../../wish_room/presentation/wish_room_entry_gate.dart';
import '../../../guinji/presentation/guinji_landing_screen.dart';
import '../../domain/jeontong_eighty_matrix.dart';
import 'sintong_home_v2_data.dart';

/// 홈 화면(히어로 슬라이드 탭, 칩 탭, 하단 시트 카드 탭)에서 해당
/// 카테고리를 눌렀을 때 이동할 실제 기존 화면. v1 home_screen.dart의
/// `_buildServiceSpecs()` onTap과 완전히 동일한 목적지를 그대로
/// 재사용한다(신규 화면 없음).
void openSubScreen(BuildContext context, SHomeV2Category category) {
  switch (category) {
    case SHomeV2Category.guide:
      // 귀인지도 — 기존 홈 스토리히어로/귀인지도 CTA와 동일한 목적지.
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GuinjiLandingScreen()));
    case SHomeV2Category.saju:
      // 정통사주 — 기존 서비스카드와 동일: 80종 매트릭스 게이트 화면.
      Navigator.of(context).pushNamed(JeontongEightyMatrix.gateRoute);
    case SHomeV2Category.tarot:
      // 타로 — 기존 서비스카드와 동일: 타로 인트로 화면.
      Navigator.of(context).pushNamed(AppRouter.tarotIntroRoute);
    case SHomeV2Category.wish:
      // 소원방 — 기존 서비스카드와 동일: 소원방 진입 게이트.
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const WishRoomEntryGate()));
    case SHomeV2Category.palm:
      // 손금·관상 — 기존 서비스카드와 동일: 관상/손금 선택 바텀시트.
      showFacePalmSelectSheet(context);
  }
}
