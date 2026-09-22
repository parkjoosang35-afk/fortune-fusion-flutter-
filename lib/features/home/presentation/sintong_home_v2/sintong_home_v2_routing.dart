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
import '../../../pass/presentation/pass_gate_helper.dart';
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

/// [전체보기 시트 확장 — 관상/손금 개별 카드] 기존 5개 카테고리(guide/
/// saju/tarot/wish/palm) 중 palm은 "관상+손금 통합" 선택 시트 1개로
/// 묶여있었으나, 시트 그리드에 관상/손금을 각각 별도 카드로 추가하기
/// 위해 전용 목적지 함수를 분리한다. 기존 [showFacePalmSelectSheet]
/// 내부에서 쓰던 것과 완전히 동일한 라우트(`/ai-fortune/face/capture`,
/// `/ai-fortune/palm/capture`)와 게이트 로직([navigateWithPassGate])을
/// 그대로 재사용한다(신규 라우트/화면 없음).
void openFaceReading(BuildContext context) {
  navigateWithPassGate(
    context,
    title: '오늘의 관상',
    route: '/ai-fortune/face/capture',
    requiresPass: true,
  );
}

void openPalmReading(BuildContext context) {
  navigateWithPassGate(
    context,
    title: '손금',
    route: '/ai-fortune/palm/capture',
    requiresPass: true,
  );
}

/// 홈 하단 시트 "전체보기" 그리드 — 2행(3+3) 총 6칸.
/// 1행: 소원방/타로/정통사주(README index.html 원본 순서 그대로).
/// 2행: 귀인지도/관상/손금(사용자 요청으로 추가한 3칸 — 관상·손금은
/// [SHomeV2Category.palm]의 통합 선택 시트를 거치지 않고 각각 곧장
/// 촬영 화면으로 연결한다).
const List<SHomeV2SheetCard> sHomeV2SheetCards = [
  SHomeV2SheetCard(
    category: SHomeV2Category.wish,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-1-wish.jpg',
    title: '소원방',
  ),
  SHomeV2SheetCard(
    category: SHomeV2Category.tarot,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-2-tarot.jpg',
    title: '타로',
  ),
  SHomeV2SheetCard(
    category: SHomeV2Category.saju,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-3-saju.jpg',
    title: '정통사주',
  ),
  SHomeV2SheetCard(
    category: SHomeV2Category.guide,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-4-guide.jpg',
    title: '귀인지도',
  ),
  SHomeV2SheetCard(
    thumbAsset: 'assets/images/sintong_home_v2/sheet-5-face.jpg',
    title: '관상',
    customOnTap: openFaceReading,
  ),
  SHomeV2SheetCard(
    thumbAsset: 'assets/images/sintong_home_v2/sheet-6-palm.jpg',
    title: '손금',
    customOnTap: openPalmReading,
  ),
];
