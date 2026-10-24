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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../engine/life_system.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import 'shrine_nav.dart';

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

// ═══════════ U8-3 — 오늘의 일진 한 줄 · 소멸 임박 전갈 ═══════════
// 원본: shrine-u8.jsx todayGZ/ILJIN/iljinLine/EntryOmen.
// ⚠ 원본 주석 그대로 유지: "실서비스는 정통사주 엔진의 일진 값을 그대로
// 쓸 것(이 계산은 시연용)". 기준일 2000-01-01 = 戊午(60갑자 54번째).
const String _gzStem = '甲乙丙丁戊己庚辛壬癸';
const String _gzBr = '子丑寅卯辰巳午未申酉戌亥';
const Map<String, String> _stemEl = {
  '甲': '木', '乙': '木', '丙': '火', '丁': '火', '戊': '土',
  '己': '土', '庚': '金', '辛': '金', '壬': '水', '癸': '水',
};
const Map<String, String> _elKo = {
  '木': '나무', '火': '불', '土': '흙', '金': '쇠', '水': '물',
};
const Map<String, String> _genEl = {'木': '火', '火': '土', '土': '金', '金': '水', '水': '木'}; // 생(生)
const Map<String, String> _ctrlEl = {'木': '土', '土': '水', '水': '火', '火': '金', '金': '木'}; // 극(剋)

class TodayGz {
  final String gz;
  final String stem;
  final String el;
  const TodayGz(this.gz, this.stem, this.el);
}

/// 원본 `todayGZ(now)` 1:1 포팅.
TodayGz todayGZ(DateTime now) {
  final base = DateTime.utc(2000, 1, 1);
  final t = DateTime.utc(now.year, now.month, now.day);
  final days = t.difference(base).inDays;
  final n = ((54 + days) % 60 + 60) % 60;
  final stem = _gzStem[n % 10];
  final br = _gzBr[n % 12];
  return TodayGz(stem + br, stem, _stemEl[stem]!);
}

/// 원본 `ILJIN` 6종 문구 — 오늘 일진 오행(d) 기준 서술.
String _iljinText(String relation, String d) {
  final nm = _elKo[d]!;
  switch (relation) {
    case 'same':
      return '오늘은 당신과 같은 $nm의 기운이 겹치는 날입니다. 고집은 한 걸음 물리십시오.';
    case 'give':
      return '오늘 들어온 $nm의 기운이 당신을 북돋습니다. 미뤄 둔 일을 꺼내도 좋은 날입니다.';
    case 'take':
      return '오늘은 당신의 기운이 $nm을(를) 키우느라 조금 빠지는 날입니다. 무리하지 마십시오.';
    case 'hit':
      return '오늘 들어온 $nm의 기운이 당신을 누릅니다. 말을 아끼고 서두르지 마십시오.';
    case 'win':
      return '오늘은 당신이 $nm의 기운을 다스리는 날입니다. 정한 일을 밀고 나가셔도 됩니다.';
    default:
      return '오늘은 $nm의 기운이 들어오는 날입니다. 마음을 고요히 두십시오.';
  }
}

class IljinLine {
  final String gz;
  final String el;
  final String text;
  const IljinLine(this.gz, this.el, this.text);
}

/// 원본 `iljinLine(app)` 포팅. 사용자 일간 오행(me)과 오늘 일진 오행(t.el)의
/// 관계 6종(same/give/take/hit/win/none)을 판정한다.
/// [dayOffset 미채택] 원본은 Tweaks 패널 시연 전용 `app.data.dayOffset`로
/// "하루/열흘 지나기"를 테스트하지만, 이 값은 실제 서비스 사용자 데이터가
/// 아니라 웹 프로토타입 디버그 전용 상태이므로 Flutter ShrineState에는
/// 포팅하지 않는다(항상 DateTime.now() 기준).
IljinLine iljinLine(ShrineState st) {
  final t = todayGZ(DateTime.now());
  final me = st.saju?.dayElement;
  String k = 'none';
  if (me != null) {
    if (me == t.el) {
      k = 'same';
    } else if (_genEl[t.el] == me) {
      k = 'give';
    } else if (_genEl[me] == t.el) {
      k = 'take';
    } else if (_ctrlEl[t.el] == me) {
      k = 'hit';
    } else if (_ctrlEl[me] == t.el) {
      k = 'win';
    }
  }
  return IljinLine(t.gz, t.el, _iljinText(k, t.el));
}

/// 입장 화면 한 줄 — 소멸 임박 부적이 있으면 그 전갈이 우선(원본 `EntryOmen`).
/// urgent: 기운이 남은 날(left) ≤ 3이고 오늘 아직 향을 올리지 않은 부적 중
/// 가장 급한 것. 없으면 오늘의 일진 한 줄을 9초 보여주고 사라진다.
class EntryOmen extends StatefulWidget {
  const EntryOmen({super.key});

  @override
  State<EntryOmen> createState() => _EntryOmenState();
}

class _EntryOmenState extends State<EntryOmen> {
  bool _show = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  ({BoxItem b, Life l})? _urgent(ShrineState st) {
    final cands = <({BoxItem b, Life l})>[];
    for (final b in st.box) {
      final l = lifeOf(b);
      if ((l.st == 'wane' || l.st == 'full' || l.st == 'born') &&
          l.left <= 3 &&
          !l.tendedToday) {
        cands.add((b: b, l: l));
      }
    }
    if (cands.isEmpty) return null;
    cands.sort((a, b) => a.l.left.compareTo(b.l.left));
    return cands.first;
  }

  // [타이머 재등록 버그 수정] build()는 ShrineSessionProvider의 무관한 상태
  // 변경(예: 사운드 토글)으로도 재호출될 수 있다. 매번 _timer?.cancel() 후
  // 새로 걸면 9초 카운트다운이 계속 리셋되어 원본의 "9초 후 사라짐"이 깨진다.
  // 원본 useEffect([urgent])는 urgent 값이 바뀔 때만 1회 재등록하므로, 여기서는
  // 이미 타이머가 돌고 있으면(= _timer != null) 재등록하지 않는 가드를 둔다.
  void _armAutoHide(bool hasUrgent) {
    if (hasUrgent) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return; // 이미 카운트다운 중 — 리셋하지 않음
    _timer = Timer(const Duration(milliseconds: 9000), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final urgent = _urgent(st);
    // 원본 useEffect([urgent]) — urgent가 없을 때만 9초 타이머를 건다.
    _armAutoHide(urgent != null);
    if (!_show) return const SizedBox.shrink();
    if (urgent != null) {
      final sp = urgent.b.spec;
      final name = (st.name != null && st.name!.isNotEmpty) ? '${st.name}님의 ' : '';
      return GestureDetector(
        onTap: () {
          shrineHaptic(context, ShrineHapticLevel.light);
          ShrineNav.go(context, 'box', params: {'open': urgent.b.no});
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0x995A0E0C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x99E0412F)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.red,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x99D6AA64)),
                ),
                child: Text(
                  '衰',
                  style: t.display(15, w: FontWeight.w900, c: const Color(0xFFF8EAD6)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$name${sp.name}이 ${urgent.l.left}일 뒤 기운을 다합니다.',
                      style: t.body(12.5, w: FontWeight.w600, c: C.fg, h: 1.5),
                    ),
                    Text(
                      '향을 올리시겠습니까 ›',
                      style: t.ui(11.5, w: FontWeight.w600, c: const Color(0xFFFF9A86)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final ij = iljinLine(st);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x9E080404),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.goldLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: C.goldLine),
              ),
              child: Text(
                ij.gz[0],
                style: t.display(15, w: FontWeight.w900, c: C.gold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('今日 · ${ij.gz}일', style: t.mono.copyWith(letterSpacing: 2)),
                  const SizedBox(height: 2),
                  Text(ij.text, style: t.body(12.5, c: C.fg, h: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════ U8-1 — 마지막 획 직접 쓰기 ═══════════
// 원본: shrine-u8.jsx SignStroke · shrine.css .signzone/.sz-guide/.sz-hand/
// .sz-pulse(@keyframes srRip). 부적 오른쪽 아래 세로 영역(원본 CSS
// `right:4%; top:70%; width:18%; height:26%` — RitualScreen의 .paperzone
// 기준 좌표)에 금빛 점선 가이드를 두고, 위→아래로 드래그(포인터 다운→무브)
// 하면 진행도(p, 0→1, 되돌아가지 않음)가 올라간다. p>=.96에서 자동 완성.
class SignStroke extends StatefulWidget {
  final ValueChanged<double> onProgress;
  final VoidCallback onDone;
  const SignStroke({super.key, required this.onProgress, required this.onDone});

  @override
  State<SignStroke> createState() => _SignStrokeState();
}

class _SignStrokeState extends State<SignStroke> {
  double _p = 0;
  bool _dragging = false;
  bool _done = false;

  void _move(Offset localPos, double height) {
    if (!_dragging || _done) return;
    final v = (localPos.dy / height).clamp(0.0, 1.0);
    if (v > _p) {
      final prevQuarter = (_p * 4).floor();
      setState(() => _p = v);
      widget.onProgress(v);
      // 원본: `Math.floor(v*4) > Math.floor(p*4)` — 25% 구간마다 약한 진동.
      if ((v * 4).floor() > prevQuarter) {
        shrineHaptic(context, ShrineHapticLevel.light);
      }
    }
    if (v >= .96) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    setState(() => _p = 1);
    widget.onProgress(1);
    shrineHaptic(context, ShrineHapticLevel.strong);
    // [ShrineAudio.bell 미채택] 원본 `window.ShrineAudio.bell()` — 이 프로젝트는
    // U8-4까지 효과음을 포팅한 적이 없어(진동만 이식) 여기서도 생략한다.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return Listener(
          onPointerDown: (e) {
            _dragging = true;
            _move(e.localPosition, h);
          },
          onPointerMove: (e) => _move(e.localPosition, h),
          onPointerUp: (_) => _dragging = false,
          onPointerCancel: (_) => _dragging = false,
          child: SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // sz-guide — 금빛 점선 세로줄(원본 repeating-linear-gradient).
                // 완성 전까지 흔들림(nudge) 유지 — 되돌아가지 않는 점은
                // "흔들림은 완성 전까지만 보여 끌림을 유도한다"는 원본 취지와
                // 일치하므로 애니메이션 없이 고정 불투명도로 근사한다(저사양
                // degrade 원칙 — 무한 반복 애니메이션 추가 비용을 들이지
                // 않음). 이미 채워진 구간(붉은 `i` 바)만 progress로 표시.
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 3,
                    height: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: const Color(0xB2F8C900),
                      boxShadow: const [BoxShadow(color: Color(0x80F8C900), blurRadius: 10)],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: _p,
                    child: Container(
                      width: 3,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC8170F),
                        boxShadow: [BoxShadow(color: Color(0xB3C8170F), blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
                // sz-hand — 진행 위치를 따라가는 금빛 원 손잡이. 완성되면 숨김.
                if (_p < 1)
                  Positioned(
                    left: 1.5 - 11,
                    top: h * _p - 11,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF8C900), width: 2),
                        color: const Color(0x40F8C900),
                        boxShadow: const [BoxShadow(color: Color(0xB3F8C900), blurRadius: 14)],
                      ),
                    ),
                  ),
                // sz-pulse — 완성 순간 금빛 파문(원본 @keyframes srRip: scale
                // .4→5, opacity 1→0, .9s).
                if (_p >= 1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: .4, end: 5),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOut,
                        builder: (_, scale, __) => Opacity(
                          opacity: (1 - (scale - .4) / 4.6).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: scale,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [Color(0x99F8C900), Colors.transparent]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
