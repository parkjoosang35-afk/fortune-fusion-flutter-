// ═══════════════════════════════════════════════════════════════
// FILE: sintong_home_v2_routing.dart
// [신통방통 홈 v2] 새 디자인의 "목차/진입" 화면(귀인지도/정통사주/타로/
// 소원방/손금관상)에 있는 옵션 리스트 항목과 하단 CTA를 실제 기존
// 기능 화면으로 연결하는 라우팅 매핑을 한 곳에 모은다.
//
// [원칙] 이 파일은 새 화면/새 API/새 상태관리를 추가하지 않는다 —
// 오직 "어느 버튼을 누르면 기존의 어떤 라우트로 가는지"만 결정한다.
// 실제 사주 계산/타로 뽑기/소원 작성/사진 업로드 로직은 모두 기존
// 화면(JeontongEightyScreen/TarotQuestionScreen/WishRoomEntryGate/
// showFacePalmSelectSheet 등)이 그대로 담당한다.
// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../../fortune/tarot/presentation/tarot_question_screen.dart';
import '../../../guinji/presentation/guinji_landing_screen.dart';
import '../../../wish_room/presentation/wish_room_entry_gate.dart';
import '../../../pass/presentation/pass_gate_helper.dart';
import '../../../../core/widgets/face_palm_select_sheet.dart';
import '../../domain/jeontong_eighty_matrix.dart';
import 'sintong_home_v2_data.dart';
import 'sub_screens/guinji_guide_screen.dart';
import 'sub_screens/saju_guide_screen.dart';
import 'sub_screens/tarot_guide_screen.dart';
import 'sub_screens/wish_guide_screen.dart';
import 'sub_screens/palm_guide_screen.dart';

/// 홈 히어로/칩/시트카드에서 카테고리를 "더블탭"했을 때 이동할 서브
/// 목차 화면(guide/saju/tarot/wish/palm) 자체로의 진입. 실제 라우팅은
/// 각 서브 화면 위젯이 Navigator.push로 직접 처리하므로 여기서는
/// 카테고리 enum → 위젯 생성만 담당한다(SintongSubScreenRouter 참고).

/// 정통사주 서브 화면의 5개 옵션(index 0~4)을 눌렀을 때의 목적지.
///
/// - index 0(오늘의 운세, 무료): [JeontongEightyMatrix]의 'D01'
///   ("오늘의 운세") 카테고리로 곧장 이동 — 프로필이 없으면 입력화면을
///   먼저 거치는 기존 [JeontongEightyScreen._onTapItem] 로직과 동일하게
///   처리한다.
/// - index 1~4(월/緣/財/康): 해당 대카테고리(B/E/F/G)의 첫 소카테고리로
///   이동한다. 기존 앱에는 "카테고리 그룹만 먼저 고르고 세부항목은 다음
///   화면에서" 같은 중간 단계가 없으므로, 각 그룹의 대표 소카테고리
///   1개를 확정 목적지로 삼는다(80종 전체를 보고 싶으면 정통사주
///   서브화면 자체의 CTA "생년월시 입력하기"나 기존 게이트를 이용).
Future<void> openJeontongOption(BuildContext context, int optionIndex) async {
  // 그룹 대표 소카테고리 매핑: [월간사주(B군), 인연·궁합(E군), 재물·직업(F군),
  // 건강·평생운(G군)]. JeontongEightyMatrix.all에서 각 major의 첫 항목을
  // 사용해 존재하지 않는 id를 하드코딩하는 위험을 없앤다.
  String repFor(JeontongMajorCode major) => JeontongEightyMatrix.all
      .firstWhere((e) => e.major == major)
      .id;

  final categoryId = switch (optionIndex) {
    0 => 'D01', // 오늘의 운세(무료) — saju_engine 고정 id, 항상 존재.
    1 => repFor(JeontongMajorCode.b), // 신년·월간 사주
    2 => repFor(JeontongMajorCode.e), // 인연·궁합
    3 => repFor(JeontongMajorCode.f), // 재물·직업
    _ => repFor(JeontongMajorCode.g), // 건강·평생운
  };

  final entry = JeontongEightyMatrix.byId(categoryId);
  if (entry == null || !context.mounted) return;

  await navigateWithPassGate(
    context,
    title: entry.title,
    route: JeontongEightyMatrix.loadingRoute,
    requiresPass: true,
    arguments: entry.id,
  );
}

/// 정통사주 서브 화면 하단 CTA("생년월시 입력하기") — 프로필 입력 화면으로
/// 직접 이동(특정 카테고리 지정 없이 그리드로 이어지는 기존 동작).
void openJeontongInputCta(BuildContext context) {
  Navigator.of(context).pushNamed('/jeontong/input');
}

/// 타로 서브 화면의 4개 옵션(index 0~3)을 눌렀을 때의 목적지.
/// 모두 AI 타로 질문 화면(`/ai-fortune/tarot/question`)으로 이동하되,
/// initialSpreadType만 다르게 넘긴다(기존 [TarotQuestionScreen] 계약
/// 그대로 재사용 — 새 로직 없음).
void openTarotOption(BuildContext context, int optionIndex) {
  final spreadType = switch (optionIndex) {
    0 => 'one_card', // 오늘의 한 장
    1 => 'three_card', // 과거·현재·미래
    2 => 'one_card', // 연애·관계 리딩 — topic만 love로 지정
    _ => 'five_card', // 10장 켈틱 크로스 — 기존 최대 스프레드(5카드)로 대체
  };
  final topic = optionIndex == 2 ? 'love' : null;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TarotQuestionScreen(
        initialSpreadType: spreadType,
        initialTopic: topic,
      ),
    ),
  );
}

/// 타로 서브 화면 하단 CTA("한 장 뽑기") — 기본 원카드 질문화면으로 이동.
void openTarotCta(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          const TarotQuestionScreen(initialSpreadType: 'one_card'),
    ),
  );
}

/// 소원방 서브 화면의 5개 옵션(건강/인연/재물/시험/일상) 및 하단 CTA —
/// 모두 동일하게 소원방 진입 게이트로 이동한다. [WishRoomComposeScreen]이
/// 카테고리 사전 선택 파라미터를 받지 않는 기존 구조(원장(seal) 선택으로
/// categoryId가 파생되는 방식)라, 특정 카테고리를 미리 선택해 넘겨주는
/// 것은 이번 시각 레이어 교체 범위를 벗어난다 — 소원방 홈으로 진입시켜
/// 사용자가 그 안에서 작성하도록 한다.
void openWishRoom(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const WishRoomEntryGate()),
  );
}

/// 귀인지도 서브 화면의 4개 방향 옵션 및 하단 CTA("내 귀인지도 열기") —
/// 모두 동일하게 귀인지도 랜딩 화면으로 이동(기존 홈 스토리히어로 탭과
/// 동일한 목적지, [GuinjiLandingScreen]).
void openGuinji(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const GuinjiLandingScreen()),
  );
}

/// 손금·관상 서브 화면의 3개 옵션(관상/손금/통합) 및 하단 CTA("사진
/// 올리기") — 기존 [showFacePalmSelectSheet] 바텀시트를 그대로 띄운다.
/// "통합 리딩" 옵션은 전용 화면이 없으므로 동일 시트에서 사용자가 관상/
/// 손금 중 하나를 골라 순서대로 진행하도록 안내한다(신규 라우트 없음).
void openPalm(BuildContext context) {
  showFacePalmSelectSheet(context);
}

/// 홈 화면(히어로 이미지/타이틀 탭, 칩 더블탭, 하단 시트 카드 탭)에서
/// 해당 카테고리의 진입 목차 화면(guide/saju/tarot/wish/palm)으로
/// 이동한다. README "라우팅(Flutter Navigator 매핑)" 표 그대로.
void openSubScreen(BuildContext context, SHomeV2Category category) {
  final Widget screen = switch (category) {
    SHomeV2Category.guide => const GuinjiGuideSubScreen(),
    SHomeV2Category.saju => const SajuGuideSubScreen(),
    SHomeV2Category.tarot => const TarotGuideSubScreen(),
    SHomeV2Category.wish => const WishGuideSubScreen(),
    SHomeV2Category.palm => const PalmGuideSubScreen(),
  };
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

/// [SHomeV2Category] → 옵션 탭 핸들러 통합 진입점. 각 서브 화면 위젯이
/// optionIndex만 넘기면 카테고리별로 올바른 목적지로 라우팅한다.
void openSubOption(
  BuildContext context,
  SHomeV2Category category,
  int optionIndex,
) {
  switch (category) {
    case SHomeV2Category.guide:
      openGuinji(context);
    case SHomeV2Category.saju:
      openJeontongOption(context, optionIndex);
    case SHomeV2Category.tarot:
      openTarotOption(context, optionIndex);
    case SHomeV2Category.wish:
      openWishRoom(context);
    case SHomeV2Category.palm:
      openPalm(context);
  }
}

/// [SHomeV2Category] → 서브 화면 하단 CTA 버튼 핸들러 통합 진입점.
void openSubCta(BuildContext context, SHomeV2Category category) {
  switch (category) {
    case SHomeV2Category.guide:
      openGuinji(context);
    case SHomeV2Category.saju:
      openJeontongInputCta(context);
    case SHomeV2Category.tarot:
      openTarotCta(context);
    case SHomeV2Category.wish:
      openWishRoom(context);
    case SHomeV2Category.palm:
      openPalm(context);
  }
}
