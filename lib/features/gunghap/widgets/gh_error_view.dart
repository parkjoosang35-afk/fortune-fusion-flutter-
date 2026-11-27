// ═══════════════════════════════════════════════════════════════
// FILE: gh_error_view.dart
// [궁합지도 핸드오프 v4] `00_DEV_MAPPING.md` §5 "### S29 · S30 · S31 오류"
// (598-625줄 부근) 공용 에러 상태 콘텐츠.
//
// [설계 결정 — 전용 Scaffold를 새로 만들지 않는다] 화면 매핑표(§1,
// 55-99줄)는 S29/S30/S31을 모두 "공통 에러"로만 표기하고 전용 Flutter
// 파일을 지정하지 않는다. 또한 명세 표의 "← / 하단바" 유무가 화면마다
// 다르다(S29/S30=있음, S31=없음) — 이는 "이 콘텐츠가 어느 기존 화면
// 안에 끼워지느냐"에 따라 달라지는 값이므로, 이 위젯은 Scaffold/AppBar/
// bottomNav를 스스로 만들지 않고 "mono 라벨 · 제목 · 설명 · 주버튼 ·
// 보조버튼" 본문 콘텐츠만 제공한다. 호출부(각 기존 화면의 GHScreen)가
// 이미 가진 AppBar(←)/bottomNav 유무를 그대로 상속해 명세의 "←/하단바"
// 요구사항을 자연스럽게 충족한다:
//  - S29(server)  → gunghap_result_screen.dart (AppBar← + bottomNav 있음)
//  - S30(calc)    → gunghap_direct_input_screen.dart (AppBar← + bottomNav 있음)
//  - S31(invalid) → gunghap_guest_input_screen.dart (웹 게스트 화면 —
//    애초에 AppBar/bottomNav 자체가 없는 설계라 "없음" 요구사항을 이미
//    충족한다)
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../theme/gh_tokens.dart';
import '../theme/gh_typography.dart';
import 'gh_button.dart';
import 'star_map.dart';

class GHErrorView extends StatelessWidget {
  const GHErrorView({
    super.key,
    required this.monoLabel,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.topPadding = 72,
  });

  /// 예: "ERR · SERVER" / "ERR · ENGINE" / "ERR · LINK" (mono, rose).
  final String monoLabel;

  /// 2줄 가능(명세 "21/700 2줄" 수준 — gh_typography title(21) 재사용).
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  /// S29/S30은 보조 "이전 화면으로"가 있고, S31은 없다(명세 표).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        children: [
          // [S29/S30/S31 공통 일러스트] 두 별이 지그재그 선으로 끊어져
          // 이어진 StarMap(참고 PNG: 연결이 흐려짐/계산 실패/링크 단절을
          // 모두 같은 별자리 모티프로 표현) — labels/draw 없이 정적으로.
          SizedBox(
            height: 150,
            child: StarMap(draw: false, labels: false),
          ),
          const SizedBox(height: 18),
          Text(monoLabel, style: GHText.mono(color: GHColors.rose)),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GHText.title(
              size: 21,
              color: GHColors.fg,
            ).copyWith(height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GHText.ui(size: 13.5, height: 1.6, color: GHColors.gray),
          ),
          const SizedBox(height: 28),
          GHButton(label: primaryLabel, onPressed: onPrimary),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 4),
            GHButton(
              label: secondaryLabel!,
              variant: GHButtonVariant.text,
              expand: false,
              onPressed: onSecondary,
            ),
          ],
        ],
      ),
    );
  }
}
