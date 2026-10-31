import 'package:flutter/material.dart';
import '../../features/fortune/sintong/screens/home_reading_sheet.dart';
import '../../features/pass/presentation/pass_gate_helper.dart';

/// [홈 "상담" 카드 → "관상/손금" 통합 카드 교체] 관상/손금을 하나의 카드로
/// 합쳐 눌렀을 때 나타나는 선택 바텀시트.
///
/// [관상·손금 신통방통 "새벽 한지" 리스킨] 시트 UI를 핸드오프의
/// [HomeReadingSheet](觀·紋 스탬프 + 실루엣 + 마법진 모티프)로 교체했다.
/// 기존 라우팅 로직(오늘의 관상 → `/ai-fortune/face/capture`, 손금 →
/// `/ai-fortune/palm/capture`, 둘 다 [navigateWithPassGate]로 열림패스
/// 게이트 통과)은 전혀 변경하지 않는다. 새 라우트/화면은 만들지 않는다
/// (기존 face/palm capture 화면 그대로 유지).
Future<void> showFacePalmSelectSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // [반응형 화면 규격 통일 — 잘림 현상 수정] HomeReadingSheet는 두
    // _ChoiceCard(실루엣 76px 고정 + 텍스트 3줄)를 높이 제한 없는
    // Column(mainAxisSize:min)으로 쌓기만 해, 좁은 화면+글자 확대
    // 조합(320x568@2.0배, @2.5배)에서 각각 341px/679px RenderFlex
    // 오버플로가 실측 확인됐다. ConstrainedBox(maxHeight: 85%)+
    // SingleChildScrollView로 감싸 넘칠 때만 스크롤되게 한다
    // (디자인/문구/색상/카드 내용 변경 없음).
    builder: (ctx) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: SingleChildScrollView(
          child: HomeReadingSheet(
            onFaceTap: () {
              Navigator.of(ctx).pop();
              navigateWithPassGate(
                context,
                title: '오늘의 관상',
                route: '/ai-fortune/face/capture',
                requiresPass: true,
              );
            },
            onPalmTap: () {
              Navigator.of(ctx).pop();
              navigateWithPassGate(
                context,
                title: '손금',
                route: '/ai-fortune/palm/capture',
                requiresPass: true,
              );
            },
          ),
        ),
      ),
    ),
  );
}
