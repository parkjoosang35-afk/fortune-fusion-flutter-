import 'package:flutter/material.dart';

import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// W3 · 링크 만료·중단 — `design_handoff_guinji_map_v5/SPEC.md` §6 W3
/// "링크 만료·중단 (웹 · 앱 공통 문구)" + `COPY.md` "W3 링크 만료·중단" +
/// `design_files/guinji-guest.jsx`의 `GsExpired` 함수(173~183줄) 1:1 이식.
///
/// [트리거 — G1/W1 연결] `guinji_map_guest_join_screen.dart`가 다음 두
/// 시점 중 하나에서 백엔드 `code`가 `NOT_FOUND`(지도를 찾을 수 없음) 또는
/// `REVOKED`(지도 주인이 링크를 중단함)로 돌아오면 이 화면을 보여준다:
///   1. 최초 진입 시 `GET /guinji/g/{token}/profile`(`_loadHostProfile`) —
///      단, 이 API는 `NOT_FOUND`만 반환할 수 있다(비로그인 전용이라
///      `REVOKED` 판정 로직 자체가 없음, `profile/route.ts` 참고).
///   2. 제출 시 `POST /guinji/g/{token}/join`(`_handleSubmit`) —
///      `NOT_FOUND`·`REVOKED` 둘 다 가능.
///
/// [테마 선택 — 디자인 결정 완료] 원본 JSX `GsExpired`는 `TP.*`(=
/// [GmColors], G2/G3와 같은 "심야의 신전" 팔레트)를 그대로 쓴다. 이 화면은
/// 바이럴 게스트 플로우 호출부(G1)와 다른 화면으로 push되므로, SPEC/원본
/// 1차 소스에 충실하게 [GmColors]를 그대로 채택한다(G1 자체 전용 토큰인
/// `GiColors`/`guinji_invitation_theme.dart`는 "심야의 신전" 틀 안에서도
/// 서로 다른 변형이라 이 화면에는 가져오지 않는다 — W3는 G1의 하위 상태가
/// 아니라 G2/G3와 같은 결 위에 있는 독립된 종료 화면).
class GuinjiInviteExpiredScreen extends StatelessWidget {
  const GuinjiInviteExpiredScreen({super.key, this.onCreateOwnMap});

  static const routeName = '/guinji-map/invite-expired';

  /// `내 귀인지도 만들기` — SPEC 유일한 동작. 게스트는 이 관계에 더 이상
  /// 참여할 수 없으므로(토큰 자체가 무효), 유일한 선택지는 완전히 새로운
  /// 자기 지도 여정을 시작하는 것뿐이다.
  final VoidCallback? onCreateOwnMap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GmColors.bg,
      // [2026-12 보강 — SPEC §2 `bgGlow` 전역 배경] `design_files/
      // guinji-guest.jsx`의 `GsExpired`(173줄~)는 공유 셸 `GsShell`로
      // 래핑돼 `<TpBg />`를 공유한다. `GmColors.bgGradient` 단색
      // 그라데이션만 쓰던 기존 구현을 [GmTempleBg]로 교체한다.
      body: GmTempleBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // SPEC "점선 금 인장 70(貴, -5°, .7)".
                Transform.rotate(
                  angle: -5 * 3.14159265 / 180,
                  child: Container(
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    child: CustomPaint(
                      painter: const _GmDashedRectPainter(
                        color: GmColors.gold,
                        radius: 14,
                      ),
                      child: Opacity(
                        opacity: 0.7,
                        child: Center(
                          child: Text(
                            '貴',
                            style: TextStyle(
                              fontFamily: GmText.display,
                              fontWeight: FontWeight.w900,
                              fontSize: 34,
                              height: 1,
                              color: GmColors.gold.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // SPEC "제목22" · COPY.md W3 title.
                const Text(
                  '초대 링크가\n닫혀 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GmText.display,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    height: 1.4,
                    color: GmColors.fg,
                  ),
                ),
                const SizedBox(height: 10),
                // SPEC "본문14" · COPY.md W3 body.
                const Text(
                  '링크가 만료됐거나 공유가 중단됐어요.\n초대한 분에게 새 링크를 요청해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GmText.ui,
                    fontSize: 14,
                    height: 1.6,
                    color: GmColors.muted,
                  ),
                ),
                const Spacer(flex: 4),
                // SPEC footer "+ Primary" · COPY.md W3 cta.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        onCreateOwnMap ??
                        () => Navigator.of(context).pushNamedAndRemoveUntil(
                          '/guinji-map',
                          (route) => false,
                        ),
                    style: gmPrimary(),
                    child: const Text('내 귀인지도 만들기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `guinji_guest_result_screen.dart`의 `_GmDashedRectPainter`와 완전히
/// 동일한 패키지-불필요 점선 테두리 구현(파일 간 private class 공유 불가라
/// 복제). `path.computeMetrics()` + `extractPath`로 dash/gap 간격을 그린다.
class _GmDashedRectPainter extends CustomPainter {
  const _GmDashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        const dashLen = 5.0, gapLen = 3.5;
        final next = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GmDashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
