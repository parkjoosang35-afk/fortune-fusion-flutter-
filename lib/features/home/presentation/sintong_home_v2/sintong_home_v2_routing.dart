// ═══════════════════════════════════════════════════════════════
// FILE: sintong_home_v2_routing.dart
// [신통방통 홈 v2] 새 디자인(히어로 캐러셀/칩/하단 시트)의 6개 카테고리
// (귀인지도/정통사주/타로/소원방/관상/손금)를 눌렀을 때 이동할 목적지를
// 한 곳에 모은다.
//
// [히어로 캐러셀 6개 확장] 원래 palm 1개("손금·관상" 통합 슬라이드)로
// 묶여 있었으나, 사용자 요청으로 관상을 별도 카테고리([face])로 분리해
// 히어로 캐러셀도 6개 슬라이드로 확장한다. palm은 이제 손금 전용이며,
// 두 카테고리 모두 기존 [openFaceReading]/[openPalmReading]으로 곧장
// 연결한다(더 이상 통합 선택 시트를 거치지 않음).
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
    case SHomeV2Category.face:
      // 관상 — 곧장 관상 촬영 화면으로 이동(통합 시트 없음).
      openFaceReading(context);
    case SHomeV2Category.palm:
      // 손금 — 곧장 손금 촬영 화면으로 이동(통합 시트 없음).
      openPalmReading(context);
  }
}

/// [관상/손금 개별 전용 목적지] 관상/손금은 기존 [showFacePalmSelectSheet]
/// 통합 선택 시트를 거치지 않고, 히어로 슬라이드/칩/시트 카드 모두 곧장
/// 각자의 촬영 화면으로 연결한다. 동일한 라우트(`/ai-fortune/face/capture`,
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
    // [얼굴 잘림 수정] 인물 얼굴이 원본 사진 상단부(약 15~30% 지점)에
    // 있어 기본 중앙 크롭에서 완전히 잘려 나갔다 — 상단 쪽으로 크게 이동.
    imageAlignment: Alignment(0, -0.8),
  ),
  SHomeV2SheetCard(
    category: SHomeV2Category.saju,
    thumbAsset: 'assets/images/sintong_home_v2/sheet-3-saju.jpg',
    title: '정통사주',
    // 얼굴이 약 25~35% 지점 — "조금 내리고"(살짝 아래로) 요청 반영.
    imageAlignment: Alignment(0, -0.3),
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
    // 얼굴이 약 30~45% 지점 — "좀 내리고"(살짝 아래로) 요청 반영.
    imageAlignment: Alignment(0, -0.15),
  ),
  SHomeV2SheetCard(
    thumbAsset: 'assets/images/sintong_home_v2/sheet-6-palm.jpg',
    title: '손금',
    customOnTap: openPalmReading,
  ),
];
