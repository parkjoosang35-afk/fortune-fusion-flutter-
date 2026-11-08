import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/saju_dark_tokens.dart';
import '../utils/saju_motion_prefs.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프] 공용 베이스 위젯 모음.
/// `design_handoff_jeongtong_saju_v3/design_files/saju/screens-a.jsx`의
/// `DarkBase`/`StarField`/`SJTopBar`/`.sj-btn-*`을 1:1로 Flutter화.

/// 고정 시드 기반 별 필드(의사난수 — 매 빌드마다 동일한 별 배치).
class SajuStarField extends StatefulWidget {
  const SajuStarField({
    super.key,
    this.count = 40,
    this.seed = 3,
    this.opacity = 1,
  });

  final int count;
  final int seed;
  final double opacity;

  @override
  State<SajuStarField> createState() => _SajuStarFieldState();
}

class _SajuStarFieldState extends State<SajuStarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_StarSpec> _stars;
  bool _reduceMotionApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _stars = List.generate(widget.count, (i) {
      double r(int n) {
        final v = math.sin((i + 1) * 12.9898 * (n + widget.seed)) * 43758.5453;
        return (v - v.floorToDouble());
      }

      return _StarSpec(
        x: r(1),
        y: r(2),
        size: r(3) * 1.6 + 0.4,
        delay: r(4) * 4,
        period: 3 + r(5) * 4,
      );
    });
  }

  // [E-Reduce Motion — docs/04_모션.md §2 "A-03 별 필드 opacity .25↔1" /
  // §5 "A-01~A-07 정지(정지 프레임 = 각 루프의 0% 상태)"] 기존에는
  // disableAnimations를 전혀 조회하지 않아 별 반짝임이 항상 돌았다.
  // Reduce Motion이면 컨트롤러를 0(= 각 루프의 0% 상태)에 고정한다.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = sajuReduceMotion(context);
    if (reduce && !_reduceMotionApplied) {
      _reduceMotionApplied = true;
      _controller.stop();
      _controller.value = 0;
    } else if (!reduce && _reduceMotionApplied) {
      _reduceMotionApplied = false;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [E-Semantics — docs/08_QA_체크리스트.md "장식(Bagua·별·장면
    // 오브제)은 접근성 트리에서 숨김"] 순수 장식 요소이므로 스크린
    // 리더 트리에서 완전히 제외한다.
    //
    // [버그 수정 재발 대응 — 정통사주 진입 화면 깜박거림(APK 실기기
    // 재신고, 2026-11-07)] df4516ec에서 MidnightBottomNavBar의
    // BackdropFilter 하나만 RepaintBoundary로 격리했지만, Android
    // Impeller의 "애니메이션 중인 ClipPath(sajuDimensionEnterRoute의
    // 원형 확산 진입 전환) 안에서 매 프레임 별도 레이어로 재합성돼야
    // 하는 자식"을 깜박이게 하는 근본 결함은 BackdropFilter에만
    // 국한되지 않는다 — 불투명도(Opacity) < 1로 고정된 채 매 프레임
    // 다시 그려지는 자식(saveLayer 유발)도 동일 증상을 일으킬 수 있다.
    // 이 위젯(SajuStarField)은 opacity(0.55/0.8 등, 1.0 아님)로 감싼
    // CustomPaint를 7초 주기로 끊임없이 다시 그리며, 정통사주 01 화면을
    // 포함한 모든 saju_renewal 화면 배경(SajuDarkBase)에 항상 깔려
    // 있어 진입 전환 애니메이션과 정확히 겹친다 — 하단바와 동일한
    // 구조적 패턴이므로 같은 해법(RepaintBoundary로 격리)을 적용한다.
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Opacity(
            opacity: widget.opacity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _StarFieldPainter(_stars, _controller.value),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _StarSpec {
  _StarSpec({
    required this.x,
    required this.y,
    required this.size,
    required this.delay,
    required this.period,
  });
  final double x, y, size, delay, period;
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter(this.stars, this.t);
  final List<_StarSpec> stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = SajuGold.g100;
    for (final s in stars) {
      // twinkle: opacity .25<->1 over `period` seconds, offset by delay.
      final elapsedSeconds = (t * 7) + s.delay;
      final phase = (elapsedSeconds % s.period) / s.period;
      final twinkle = 0.25 + 0.75 * (0.5 - 0.5 * math.cos(phase * 2 * math.pi));
      paint.color = SajuGold.g100.withValues(alpha: twinkle.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) => true;
}

/// 다크 베이스 배경(ink.900 + 보라빛 radial glow).
///
/// [버그 수정 — 대표 신고 "정통사주 점들 다 없애"] 기존에는 이 공용
/// 배경에 반짝이는 별 장식(SajuStarField, 36개)이 항상 깔려 있었다.
/// 실기기에서 화면 전체에 점이 너무 많다는 신고를 받아, 모든 정통사주
/// 화면(SajuDarkBase를 쓰는 홈/출생정보입력/분석중/분석완료/오류/더보기
/// 등)에서 별 장식을 완전히 제거한다 — radial glow 배경은 유지하고
/// SajuStarField 호출만 삭제(위젯 자체는 다른 곳에서 재사용할 가능성을
/// 열어두기 위해 클래스 정의는 남겨둠).
class SajuDarkBase extends StatelessWidget {
  const SajuDarkBase({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SajuInk.i900,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 0.9,
                colors: [Color(0xBF2A2640), Colors.transparent],
                stops: [0.0, 0.7],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 1),
                radius: 0.7,
                colors: [Color(0x802A2640), Colors.transparent],
                stops: [0.0, 0.7],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 공통 상단바 — 좌측 아이콘버튼 / 중앙 모노 타이틀 / 우측 슬롯.
class SajuTopBar extends StatelessWidget {
  const SajuTopBar({super.key, this.left, this.right, required this.title});

  final Widget? left;
  final Widget? right;
  final String title;

  @override
  Widget build(BuildContext context) {
    // [E-44pt 대응 — 레이아웃 영향 없이 확장, 재수정]
    // docs/02_컴포넌트.md §C-13 "3슬롯(좌 36 · 중앙 mono 라벨 · 우
    // 36)"은 그대로 지키면서(= 좁은 화면 320~375pt에서 타이틀이 2줄로
    // 꺾이지 않도록, saju_topbar_wrap_check_test.dart로 실측 보장),
    // SajuIconButton의 실제 탭 가능 영역은 44×44가 되어야 한다
    // (docs §C-01 "Icon 버튼 히트 영역 44×44").
    //
    // [버그 수정 — OverflowBox는 그리기만 overflow되고 히트테스트는
    // 확장되지 않는다] 이전 구현은 `SizedBox(width:36, child:
    // OverflowBox(...44x44...))` 패턴이었는데, 실제 tester.tapAt()으로
    // 실측한 결과 36×36 밖을 탭하면 전혀 반응하지 않았다 — Flutter의
    // RenderBox.hitTest()는 "position이 자신의 size 안에 있을 때만"
    // 자식을 검사하므로, 부모가 36×36으로 타이트하게 제약하면 그 경계
    // 밖은 히트테스트 트리에 영원히 도달할 수 없다(paint overflow와
    // hit-test는 별개).
    //
    // [해법] TopBar 전체를 화면 폭만큼의 Stack으로 만들고, 좌우
    // 아이콘은 Positioned(44×44)로 36pt 슬롯 중심에 겹쳐 배치한다.
    // Positioned의 44×44 영역이 Stack 자신의 bounds(화면 전체 폭) 안에
    // 완전히 포함되므로 히트테스트가 정상 동작한다(별도 widget test로
    // 가설 검증 완료). 타이틀은 Padding(horizontal: 36)으로 기존
    // Row+Expanded와 동일한 가용폭 제약을 유지한다.
    //
    // [버그 수정 — 재재수정: Positioned의 음수 오프셋도 Stack bounds
    // 밖은 히트 불가능] 최초 수정에서는 `Positioned(left: -4, width:
    // 44)`로 36pt 슬롯 "중심"에 맞춰 양쪽으로 4pt씩 걸치게 했으나,
    // 실제 프로덕션 구조(SafeArea→Column, 화면 전체 폭, 좌우 여백
    // 없음)로 `tester.tapAt()` 실측한 결과 x<0 구간(왼쪽 아이콘의
    // 좌측 4pt)이 Stack bounds(screen width 안) 밖이라 전혀 도달하지
    // 못해 유효 히트 폭이 40pt(44pt 요구사항 미달)로 줄어드는 결함이
    // 재발했다(OverflowBox 때와 동일한 근본 원인 — RenderBox 계열은
    // 모두 "자신의 size 안의 position만 자식에 전달"한다, Stack도
    // 예외가 아니다). 오른쪽 아이콘도 `right: -4`가 화면 오른쪽 밖으로
    // 넘쳐 동일하게 깨졌다.
    //
    // [올바른 해법] Positioned를 `left: 0`/`right: 0`(각각 Stack bounds
    // 안쪽)으로 두어 44×44 히트 박스 전체가 Stack 범위 안에 완전히
    // 포함되게 하고, 그 안에서 36×36 비주얼은 `Align`으로 화면 가장자리
    // 쪽에 그대로 붙인다(왼쪽 아이콘은 `centerLeft`로 x=[0,36] 유지,
    // 오른쪽 아이콘은 `centerRight`로 x=[width-36,width] 유지 — 기존
    // Row(SizedBox(width:36)) 구조와 완전히 동일한 비주얼 위치, 히트
    // 영역만 바깥쪽(안쪽 화면 중앙 방향)으로 8pt 확장됨).
    return SizedBox(
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 타이틀 — [버그 방지] Stack의 non-positioned 자식은 느슨한
          // 제약으로 Stack 전체 폭(좌우 36pt 슬롯 포함)을 그대로
          // 받는다. 기존 Row+Expanded 구조에서는 타이틀이 정확히
          // (전체폭 − 72)로 제약되어 좁은 화면에서 올바르게 줄바꿈
          // 판정되었으므로, 동일한 제약을 Padding으로 명시해 그대로
          // 유지한다(그렇지 않으면 긴 타이틀이 아이콘 영역까지
          // 넓어지는 회귀가 생길 수 있다 —
          // saju_topbar_wrap_check_test.dart로 실측 확인).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Center(
              child: Text(
                title,
                style: SajuType.mono10,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (left != null)
            Positioned(
              left: 0,
              top: 0,
              width: 44,
              height: 44,
              child: Align(alignment: Alignment.centerLeft, child: left),
            ),
          if (right != null)
            Positioned(
              right: 0,
              top: 0,
              width: 44,
              height: 44,
              child: Align(alignment: Alignment.centerRight, child: right),
            ),
        ],
      ),
    );
  }
}

/// 원형 아이콘 버튼(sj-icon-btn).
///
/// [버그 수정 — E-44pt(docs/08_QA_체크리스트.md "터치 영역 최소
/// 44pt(아이콘 버튼·용어 링크 포함)")] docs/02_컴포넌트.md §C-01은
/// "Icon 36×36 원"(비주얼 크기)과 "Icon 버튼 히트 영역 44×44"(탭 가능
/// 영역)를 별도로 규정한다. 기존 구현은 `Container(width: 36, height:
/// 36)`에 직접 `InkWell`을 씌워 비주얼과 히트 영역이 완전히 같았다
/// (36×36 — 44pt 미달, 실측 확인된 결함).
///
/// [재수정 — OverflowBox는 paint만 overflow되고 hitTest는 확장되지
/// 않는다] 이전 구현은 이 위젯 내부에서 `SizedBox(36) + OverflowBox
/// (44)`로 44×44 히트 영역을 자체 확보하려 했으나, `tester.tapAt()`
/// 실측 결과 36×36 경계 밖은 전혀 탭에 반응하지 않았다(Flutter
/// RenderBox.hitTest()는 자신의 `_size` 안의 position만 자식에
/// 전달하므로, 부모가 36×36으로 타이트하게 제약하면 그 경계 밖은
/// 히트테스트 트리에 영원히 도달 불가능 — paint overflow와 hitTest는
/// 완전히 별개 메커니즘).
///
/// [역할 분리] 44×44 히트 영역 확장은 이제 이 위젯을 감싸는
/// `SajuTopBar`가 `Stack` + `Positioned(width: 44, height: 44)`로
/// 전담한다(Positioned 영역이 Stack 자신의 bounds 안에 완전히
/// 포함되므로 히트테스트가 정상 동작 — 별도 widget test로 검증).
/// 따라서 `SajuIconButton` 자체는 "36×36 비주얼 + 탭 핸들러"만
/// 책임지는 단순한 위젯으로 되돌린다. `SajuTopBar` 밖에서 단독으로
/// 쓰일 경우에도 최소 36×36의 탭 영역은 확보된다(44pt 요구사항은
/// 호출부가 `SajuTopBar`의 Positioned처럼 바깥에서 영역을 확장해
/// 주는 것을 전제로 한다 — 현재 전체 코드베이스의 유일한 호출 경로는
/// `SajuTopBar.left`이므로 이 전제가 항상 충족된다).
class SajuIconButton extends StatelessWidget {
  const SajuIconButton({super.key, required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SajuText.card,
              border: Border.all(color: SajuText.line),
            ),
            child: Text(
              icon,
              style: const TextStyle(color: SajuText.fg, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

enum SajuButtonVariant { primary, secondary, ghost }

/// 공용 버튼(.sj-btn-primary/secondary/ghost). 눌림 시 scale(.96).
class SajuButton extends StatefulWidget {
  const SajuButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = SajuButtonVariant.primary,
    this.loading = false,
    this.leading,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onTap;
  final SajuButtonVariant variant;
  final bool loading;
  final Widget? leading;
  final double height;

  @override
  State<SajuButton> createState() => _SajuButtonState();
}

class _SajuButtonState extends State<SajuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.loading;
    Color bg;
    Color fg;
    Border? border;
    List<BoxShadow>? shadow;
    // B-1(docs/08_QA_체크리스트.md) / docs/01_디자인토큰.md §2-2 `T-cta`
    // ("Gowun Batang 700 16 −0.01em, 모든 CTA") · docs/02_컴포넌트.md
    // C-01(Primary/Secondary 텍스트 = T-cta) · 원본
    // `design_files/saju/saju-tokens.css` `.sj-btn`(font-family:
    // var(--font-body)=Gowun Batang) — Primary/Secondary는 Gowun
    // Batang 700 16을 쓴다. 단, Ghost는 원본
    // `design_files/saju/screens-b.jsx`(↻ 새로운 이야기 버튼)가
    // 인라인으로 `fontFamily: Pretendard, fontWeight: 500, fontSize:
    // 14`를 명시적으로 오버라이드하므로 Ghost만 Pretendard 500 14를
    // 쓴다(docs/02 C-01 Ghost 행: "Pretendard 500 14"와 일치).
    String labelFontFamily;
    FontWeight labelFontWeight;
    double labelFontSize;
    switch (widget.variant) {
      case SajuButtonVariant.primary:
        bg = SajuGold.g100;
        fg = SajuInk.i900;
        shadow = [
          BoxShadow(
            color: SajuGold.glow,
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ];
        labelFontFamily = SajuType.body;
        labelFontWeight = FontWeight.w700;
        labelFontSize = 16;
        break;
      case SajuButtonVariant.secondary:
        bg = SajuText.card;
        fg = SajuText.fg;
        border = Border.all(color: SajuText.lineGold);
        labelFontFamily = SajuType.body;
        labelFontWeight = FontWeight.w700;
        labelFontSize = 16;
        break;
      case SajuButtonVariant.ghost:
        bg = Colors.transparent;
        fg = SajuText.muted;
        border = Border.all(color: SajuText.line);
        labelFontFamily = SajuType.ui;
        labelFontWeight = FontWeight.w500;
        labelFontSize = 14;
        break;
    }
    return Opacity(
      opacity: disabled && widget.variant != SajuButtonVariant.primary
          ? 0.6
          : 1,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: SajuMotion.press,
          child: AnimatedContainer(
            duration: SajuMotion.press,
            width: double.infinity,
            height: widget.height,
            decoration: BoxDecoration(
              color: disabled && widget.variant == SajuButtonVariant.primary
                  ? bg.withValues(alpha: 0.5)
                  : bg,
              borderRadius: BorderRadius.circular(14),
              border: border,
              boxShadow: shadow,
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.leading != null) ...[
                        widget.leading!,
                        const SizedBox(width: 10),
                      ],
                      // [작은 화면/글자확대 잘림 수정 — 2026 반응형 규격
                      // 통일] 버튼 라벨이 긴 경우(예: "오늘의 프리패스
                      // 2회 받기") 작은 화면 + 글자확대(1.3배) 조건에서
                      // Row 가로 폭을 초과해 RenderFlex 오버플로가
                      // 실측됐다(320×568@1.3, 41px). 이 버튼은 여러
                      // 화면이 공유하는 공용 컴포넌트이므로 여기 한
                      // 곳만 고치면 전체에 적용된다 — Flexible +
                      // ellipsis로 넘칠 때만 줄여 보이게 하고, 평소
                      // 짧은 라벨의 모양은 그대로 유지한다.
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: labelFontFamily,
                            fontWeight: labelFontWeight,
                            fontSize: labelFontSize,
                            letterSpacing:
                                widget.variant == SajuButtonVariant.ghost
                                ? 0
                                : -0.16, // T-cta 자간 −0.01em(16px 기준)
                            color: fg,
                          ),
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

/// [버그 수정 — 결과보기 결제 후 "상세 해석 생성 중" 로딩 공백 해결]
/// Access Gate 통과(복주머니/프리패스/광고 소진) 직후 서버가
/// `interpret(mode=detail)`로 LLM 상세 해석을 생성하는 동안(통상
/// 10~20초) 화면에 어떤 로딩 표시도 없어서, 사용자가 "멈췄다/오류"로
/// 오인하는 문제가 실제로 보고되었다(복주머니 차감 애니메이션이 끝나는
/// 즉시 버튼 로딩이 꺼지고, 그 뒤 LLM 생성 구간은 완전히 빈 대기였음).
/// 이 전체화면 오버레이를 그 구간 내내(결제 로딩 애니메이션 종료 ~
/// storyDetail/error 상태 전환 직전까지) 띄워 "진행 중"임을 명확히
/// 알린다 — 다른 화면(③ 분석 세레모니)과 톤을 맞춘 심플한 버전.
class SajuDetailGeneratingOverlay extends StatefulWidget {
  const SajuDetailGeneratingOverlay({super.key});

  @override
  State<SajuDetailGeneratingOverlay> createState() =>
      _SajuDetailGeneratingOverlayState();
}

/// [UI 개선 — 2026-12 로딩 디자인 리디자인] 기존 구현은 94%-불투명 검은
/// 배경 위에 단순 골드 링 하나가 도는 것뿐이라 "너무 구려 보인다"는
/// 사용자 피드백을 받았다. 앱의 다른 화면이 이미 쓰고 있는 다크 디자인
/// 언어(별 필드 배경 · 골드 글로우 · Serif 타이포)를 그대로 재사용해
/// 완전 불투명 배경 + 별빛 + 숨쉬는 글로우 + 도넛형 회전 아크 + 중앙
/// 글자(卦) + 진행 점(dots) 조합으로 바꾼다. 로직(표시/해제 타이밍)은
/// 전혀 바꾸지 않는다 — 시각 레이어만 교체한다.
class _SajuDetailGeneratingOverlayState
    extends State<SajuDetailGeneratingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;

  static const List<String> _messages = [
    '당신만의 이야기를 쓰고 있어요',
    '사주의 결을 하나씩 풀어내고 있어요',
    '조금만 더 기다려 주세요',
  ];

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: SajuInk.i900,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // [버그 수정 — 대표 신고 "정통사주 점들 다 없애"] 기존 별
            // 필드(30개) 제거.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.1),
                  radius: 0.85,
                  colors: [Color(0x402A2640), Colors.transparent],
                  stops: [0.0, 0.75],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_spin, _pulse]),
                    builder: (context, _) {
                      final pulseScale = 0.88 + (_pulse.value * 0.18);
                      final glyphAlpha = 0.75 + (_pulse.value * 0.25);
                      return SizedBox(
                        width: 112,
                        height: 112,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 숨쉬는 외곽 글로우.
                            Container(
                              width: 104 * pulseScale,
                              height: 104 * pulseScale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    SajuGold.g300.withValues(alpha: 0.3),
                                    SajuGold.g300.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                            // 고정 얇은 테두리 링.
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: SajuText.line,
                                  width: 1,
                                ),
                              ),
                            ),
                            // 도넛형 회전 아크 — SweepGradient + 중앙 마스킹.
                            RotationTransition(
                              turns: _spin,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: [
                                      SajuGold.g300.withValues(alpha: 0.0),
                                      SajuGold.g300.withValues(alpha: 0.15),
                                      SajuGold.g100,
                                    ],
                                    stops: const [0.0, 0.7, 1.0],
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 68,
                                    height: 68,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: SajuInk.i900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              '卦',
                              style: TextStyle(
                                fontFamily: SajuType.serif,
                                fontWeight: FontWeight.w700,
                                fontSize: 27,
                                color: SajuGold.g100.withValues(
                                  alpha: glyphAlpha.clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    '이야기를 짓는 중',
                    style: TextStyle(
                      fontFamily: SajuType.serif,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      letterSpacing: -0.02 * 19,
                      color: SajuGold.g100,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CyclingMessage(messages: _messages),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CyclingMessage extends StatefulWidget {
  const _CyclingMessage({required this.messages});
  final List<String> messages;

  @override
  State<_CyclingMessage> createState() => _CyclingMessageState();
}

class _CyclingMessageState extends State<_CyclingMessage> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _idx = (_idx + 1) % widget.messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            widget.messages[_idx],
            key: ValueKey(_idx),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: SajuType.ui,
              fontWeight: FontWeight.w500,
              fontSize: 14.5,
              color: SajuText.fg2,
            ),
          ),
        ),
        const SizedBox(height: 18),
        // 진행 점(dots) — 메시지 사이클과 동기화된 가벼운 진행 표시.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.messages.length, (i) {
            final active = i == _idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 16 : 5,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: active ? SajuGold.g300 : SajuText.line,
              ),
            );
          }),
        ),
      ],
    );
  }
}
