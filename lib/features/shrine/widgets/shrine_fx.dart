// 신당(THE SHRINE) U8 — 1차: 화면을 늘리지 않고 기존 순간을 깊게
// 원본(유일한 소스 오브 트루스): /tmp/shrine_v3/merged/prototype/shrine-u8.jsx
// 이 파일은 U8-4(공통 유틸)에 해당하는 3종을 포팅한다:
//   ② 진동 규칙 shrineHaptic(level) — 설정(pref.haptic)에서 끌 수 있음
//   ③ 꺼진 촛불 기다림 CandleWait — 로딩 화면 대체
//   ④ 신당 말투 오류 문구 D_ERR
// ─────────────────────────────────────────────────────────────
// [vibration 패키지 미채택] 원본 JS는 navigator.vibrate(pattern)으로 강(强)
// 단계에서 [40,60,80]ms 패턴 진동을 재생하지만, 이 프로젝트 pubspec.yaml에는
// 패턴 진동 패키지(vibration)가 없다(2026-신규 요건, 아직 미확정). 우선
// Flutter 내장 HapticFeedback(다른 신당 외 기능 — guinji_arrival_overlay.dart,
// pouch_box_tab_screen.dart — 와 동일 계열)으로 근사 구현한다:
//   light  → HapticFeedback.selectionClick()   (원본 12ms)
//   mid    → HapticFeedback.mediumImpact()     (원본 30ms)
//   strong → HapticFeedback.heavyImpact()      (원본 [40,60,80]ms 패턴)
// 추후 정밀 패턴 재현이 필요해지면 vibration 패키지 추가를 사용자에게 재확인할 것.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';

/// ② 진동 규칙 — 약: 선택·탭·서명 진행 / 중: 인장·향 꽂힘·문 열림 / 강: 클라이맥스·부적 완성·저장 완료
enum ShrineHapticLevel { light, mid, strong }

/// 원본 `window.shrineHaptic(level)` 포팅. 설정 `pref.haptic`(ShrineState.haptic)이
/// false면 아무 것도 하지 않는다(원본: `if (p.haptic === false || !navigator.vibrate) return;`).
void shrineHaptic(BuildContext context, ShrineHapticLevel level) {
  final enabled = context.read<ShrineSessionProvider>().state.haptic;
  if (!enabled) return;
  switch (level) {
    case ShrineHapticLevel.light:
      HapticFeedback.selectionClick();
      break;
    case ShrineHapticLevel.mid:
      HapticFeedback.mediumImpact();
      break;
    case ShrineHapticLevel.strong:
      HapticFeedback.heavyImpact();
      break;
  }
}

/// ④ 신당 말투 오류 문구 — 원본 `D_ERR` 1:1 포팅(문구 변경 금지).
const Map<String, String> dErr = {
  'offline': '바람이 촛불을 흔듭니다. 잠시 뒤 다시 오십시오.',
  'saju': '태어난 날의 기운을 아직 읽지 못했습니다. 이야기만 먼저 걸으셔도 됩니다.',
  'save': '부적을 사진첩에 담지 못했습니다. 사진 권한을 열어 주시면 다시 담겠습니다.',
  'pay': '값이 치러지지 않았습니다. 문은 그대로 열어 두겠습니다.',
  'share': '연기가 멀리 닿지 못했습니다. 잠시 뒤 다시 건네 주십시오.',
  'generic': '촛불이 잠시 흔들렸습니다. 다시 한 번 눌러 주십시오.',
};

/// ③ 꺼진 촛불 기다림 — 로딩 화면 대신(저장 · 사주 엔진 · 결제 대기).
/// 원본 CSS `@keyframes cwLight`(2.4s ease-in infinite):
///   0%{opacity:0;scale(.3)} 40%{opacity:1;scale(1)} 80%{opacity:1;scale(1.05)} 100%{opacity:0;scale(.9)}
class CandleWait extends StatefulWidget {
  final String label;
  final double size;
  const CandleWait({super.key, this.label = '기운을 읽는 중', this.size = 1});

  @override
  State<CandleWait> createState() => _CandleWaitState();
}

class _CandleWaitState extends State<CandleWait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // cwLight 키프레임을 선형 보간 — ease-in 근사(각 구간 선형, 원본과 시각적으로 동등).
  static double _flameOpacity(double t) {
    if (t < .4) return t / .4;
    if (t < .8) return 1;
    return 1 - (t - .8) / .2;
  }

  static double _flameScale(double t) {
    if (t < .4) return .3 + .7 * (t / .4);
    if (t < .8) return 1 + .05 * ((t - .4) / .4);
    return 1.05 - .15 * ((t - .8) / .2);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final candleW = 14.0 * s, candleH = 54.0 * s;
    return Semantics(
      label: widget.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: candleW,
            height: candleH,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Stack(
                clipBehavior: Clip.none,
                children: [
                  // b — 초 몸통(하단 78%)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: candleH * .78,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFD9C9A8),
                            Color(0xFFF2E6CC),
                            Color(0xFFB8A684),
                          ],
                          stops: [0, .4, 1],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                          bottomLeft: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // 심지 — top 18%, height 6%
                  Positioned(
                    left: candleW / 2 - .75,
                    top: candleH * .18,
                    width: 1.5,
                    height: candleH * .06,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFF2A1A10)),
                    ),
                  ),
                  // 불꽃 — top -6%, width 60%, height 28%
                  Positioned(
                    left: candleW * .2,
                    top: -candleH * .06,
                    width: candleW * .6,
                    height: candleH * .28,
                    child: Opacity(
                      opacity: _flameOpacity(_c.value),
                      child: Transform.scale(
                        scale: _flameScale(_c.value),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(999),
                              topRight: Radius.circular(999),
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                            gradient: RadialGradient(
                              center: const Alignment(0, .4),
                              colors: const [
                                Color(0xFFFFF6C0),
                                Color(0xFFFFA040),
                                Colors.transparent,
                              ],
                              stops: const [0, .55, .75],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(widget.label, style: T(1).mono.copyWith(color: C.gold)),
        ],
      ),
    );
  }
}
