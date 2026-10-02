// 공용 NavPill(뒤로가기+신통방통 홈) + "신통방통 홈으로 갈까요" 확인시트.
// app2/fx2.jsx › NavPill() · shell2.jsx › app.back()/app.exitHome()/exitAsk 1:1.
//
// [버그수정 — 전수 감사로 발견] 원본은 TopBar(nav=true)가 기본값이라 모든 메인
// 화면(홈·탐색·알림·꾸미기·보관함·캐릭터샵·타인의 소원방) 좌상단에 NavPill이
// 항상 떠 있다. 기존 Flutter 구현은 WrNavPill 클래스만 존재할 뿐(Welcome 화면
// 전용) 다른 화면 어디에도 쓰이지 않았다. 이 파일은 WrNavPill을 재노출하고,
// "뒤로가기 히스토리가 없으면(=탭 루트) 신통방통 홈 확인" 로직은 Flutter
// Navigator 1.0 + IndexedStack 구조에 맞춰 단순화한다:
//   - onBack(): Navigator.maybePop()으로 push된 화면(캐릭터샵/타인방 등)에서는
//     그냥 뒤로 가고, WishRoomShell 탭 루트(= push된 라우트가 없음)에서는
//     원본과 동일하게 exitAsk 확인시트를 띄운다.
//   - onExitHome(): 원본처럼 확인 없이 곧장 앱 루트로 돌아간다(= 소원방 모듈
//     전체 종료, popUntil(isFirst)).
import 'package:flutter/material.dart';
import '../core/theme/wr_theme.dart';

export '../features/intro/wish_room_intro_screen.dart' show WrNavPill;

/// 소원방 모듈 전체를 벗어나 앱 홈으로. app2 exitHome() 1:1.
void wrExitHome(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
}

/// 탭 루트(= 더 이상 pop할 화면이 없음)에서 호출되는 뒤로가기.
/// Navigator.maybePop()이 실패(= 이 라우트가 네비게이션 스택의 바닥)하면
/// "신통방통 홈으로 갈까요" 확인시트를 띄운다. push된 화면(캐릭터샵·타인의
/// 소원방 등)에서는 그냥 maybePop()만으로 충분하므로 이 함수를 쓰지 않는다.
Future<void> wrBackOrAskExit(BuildContext context, {String? message}) async {
  final popped = await Navigator.of(context).maybePop();
  if (popped || !context.mounted) return;
  _showExitAskSheet(context, message: message);
}

void _showExitAskSheet(BuildContext context, {String? message}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: WrDeco.sheet,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🕯', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 10),
        Text('신통방통 홈으로 갈까요', style: WrF.display(18)),
        const SizedBox(height: 6),
        Text(message ?? '촛불은 계속 켜져 있어요. 언제든 다시 오세요.',
            textAlign: TextAlign.center, style: WrF.body(13, color: WrC.muted, height: 1.6)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.of(sheetCtx).pop(),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: WrC.line)),
            child: Text('머무를게요', style: WrF.body(13, color: WrC.fg)),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton(
            onPressed: () {
              Navigator.of(sheetCtx).pop();
              wrExitHome(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: WrC.blossom),
            child: const Text('홈으로', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]),
      ]),
    ),
  );
}
