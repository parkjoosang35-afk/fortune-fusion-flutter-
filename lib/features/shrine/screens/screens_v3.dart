// v3 화면 — 회원 연결 · 정통사주 · 주제 추천 · 선택의 의미 · 부적 받기 · 부적함 · 추가 이야기 · 이야기 목록 · 첫 사용 안내
// 웹 shrine-screens-c.jsx / shrine-screens-d.jsx 와 1:1. 픽셀·타이밍 기준은 웹 레퍼런스.
// [provider+Navigator 1.0 포팅] screens.dart와 동일한 규칙으로 기계적으로 치환했다(③ 지시
// — 화면 로직·레이아웃·수치는 일절 변경하지 않고 API 호출만 치환).
//  · ConsumerStatefulWidget/ConsumerState → StatefulWidget/State
//  · ConsumerWidget(build(context, ref))  → StatelessWidget(build(context))
//  · ref.watch(shrineProvider)            → context.watch<ShrineSessionProvider>().state
//  · ref.read(shrineProvider)             → context.read<ShrineSessionProvider>().state
//  · ref.read(shrineProvider.notifier)    → context.read<ShrineSessionProvider>()
//  · ref.read(memberRepoProvider)         → context.read<MemberRepository>()
//  · ref.read(sajuRepoProvider)           → context.read<SajuRepository>()
//  · context.go('$kShrineBase/id')        → ShrineNav.go(context, 'id', params: {...})
//  · context.canPop()/context.pop()       → ShrineNav.canPop(context)/ShrineNav.pop(context)
//  · shrinePay(context, ref, p, onPaid)   → shrinePay(context, p, onPaid)
//  · showTalisManual(context, ref, {...}) → showTalisManual(context, {...})
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import '../shrine_module.dart' show shrine, shrinePay, ShrineProduct, kShrineBase;
import '../data/models.dart';
import '../engine/shrine_engine.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/shrine_video.dart';
import '../widgets/bujeok.dart';
import '../widgets/sheets.dart';
import '../widgets/shrine_nav.dart';
import 'screens_v32.dart' show showTalisManual;

String _img(String n) => 'assets/shrine/img/$n.jpg';
const _elColor = {'木': Color(0xFF6F9A5A), '火': Color(0xFFE0412F), '土': Color(0xFFC9A368), '金': Color(0xFFD9D2C4), '水': Color(0xFF5B7FA8)};

Widget _top(BuildContext ctx, {VoidCallback? back, Widget? center, Widget? trailing}) {
  final st = ctx.watch<ShrineSessionProvider>().state;
  return Positioned(top: 0, left: 0, right: 0, child: TopBar(onBack: back, center: center, trailing: trailing, soundOn: st.sound,
    onSound: () => ctx.read<ShrineSessionProvider>().update((s) => s.copy(sound: !s.sound)), onSettings: () => showSettingsSheet(ctx)));
}

/// SAMPLE 표시 — 엔진 연동 전 예시 응답임을 화면에 밝힌다 (실제 연동 후 source == 'STB_SAJU_ENGINE' 이면 숨김)
class SampleTag extends StatelessWidget {
  final String text; const SampleTag([this.text = '정통사주 엔진 연동 전 예시 응답']);
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 10), height: 22, padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(color: const Color(0x0FC9A368), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0x73C9A368))),
    child: Text('SAMPLE · $text', style: T(1).mono.copyWith(fontSize: 9, letterSpacing: 1.6, color: const Color(0xCCC9A368))));
}

Widget _card({required Widget child, Color border = C.line, EdgeInsets pad = const EdgeInsets.fromLTRB(16, 14, 16, 14)}) => Container(
  margin: const EdgeInsets.only(bottom: 10), padding: pad,
  decoration: BoxDecoration(color: const Color(0xD10E0706), borderRadius: BorderRadius.circular(14), border: Border.all(color: border)), child: child);

/// 순차 등장 (opacity + 14px 상승, .9s)
class _Reveal extends StatelessWidget {
  final bool on; final Widget child; const _Reveal(this.on, this.child);
  @override
  Widget build(BuildContext context) => AnimatedSlide(offset: on ? Offset.zero : const Offset(0, .06), duration: const Duration(milliseconds: 900), curve: const Cubic(.2, .7, .2, 1),
    child: AnimatedOpacity(opacity: on ? 1 : 0, duration: const Duration(milliseconds: 900), child: child));
}

// ═══════════ 門 회원 연결 (/connect) ═══════════
// v3.3 디자인(웹 .cn2 — shrine-screens-d.jsx / shrine.css .cn2-*) 1:1 포팅.
// 상단 두 인장(神通 보라그라데이션 · 神堂 붉은그라데이션, 회전+광채)을 붉은 실(SVG 경로 포팅)이 잇고,
// 아래 명부(名簿) 패널(헤더 "名簿 · 옮겨 적을 것" + 개수) 안에 원형 한자(名·生·時) + 값 + 토글 스위치 행.
// 꺼진 항목은 값에 붉은 취소선 · 이름/생년월일을 빼면 경고 문구 노출.
// 연결 시 항목이 하나씩(0.42s 간격) 매듭으로 건너가며 붉게 채워지고 체크로 바뀐다.
// [디자인 불일치 수정] 과거 구현은 이 섹션을 "구조만 맞춰두고 시각은 추후 웹 레퍼런스 따라 맞춘다"는
// 주석과 함께 미완성 상태로 남겨두었다(×표시 임시 대체, 명부 패널·토글·경고문·◇불릿·실 장식 누락,
// 버튼 문구 상이). 대표 확인 결과 실제 신당 화면과 다르다는 지적을 받아 웹 레퍼런스 기준으로 재구현했다.
class ConnectScreen extends StatefulWidget { const ConnectScreen({super.key}); @override State<ConnectScreen> createState() => _ConnectState(); }
class _ConnectState extends State<ConnectScreen> {
  final sel = {'name': true, 'birth': true, 'time': true};
  bool busy = false;
  int moved = 0;
  final List<Timer> _timers = [];

  @override
  void dispose() { for (final tm in _timers) { tm.cancel(); } super.dispose(); }

  Future<void> _link() async {
    if (busy) return;
    final order = sel.entries.where((e) => e.value).map((e) => e.key).toList();
    final st = context.read<ShrineSessionProvider>().state;
    setState(() { busy = true; moved = 0; });
    final stepMs = st.reduce ? 80 : 420;
    for (var i = 0; i < order.length; i++) {
      _timers.add(Timer(Duration(milliseconds: stepMs * (i + 1)), () { if (mounted) setState(() => moved = i + 1); }));
    }
    final waitMs = st.reduce ? 400 : stepMs * (order.length + 1) + 500;
    await Future.delayed(Duration(milliseconds: waitMs));
    if (!mounted) return;
    final m = await context.read<MemberRepository>().link(scope: order.toSet());
    final season = m.birth == null ? null : seasonOf(int.parse(m.birth!.substring(5, 7)));
    context.read<ShrineSessionProvider>().update((s) => s.copy(memberId: m.memberId, memberScope: order,
      name: m.name, birth: m.birth, time: m.time ?? '모름', season: season, visits: s.visits + 1));
    if (!mounted) return;
    ShrineNav.go(context, m.name == null || m.birth == null ? 'info' : 'talk');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts);
    final rows = [
      ('name', '名', '이름', '박서연', '월화가 부르고, 부적에 적습니다'),
      ('birth', '生', '생년월일', '1995.08.14 · 양력', '정통사주 해석에 씁니다'),
      ('time', '時', '태어난 시간', '14:20', '없으면 시주(時柱)를 빼고 풀이합니다'),
    ];
    final selected = rows.where((r) => sel[r.$1]!).toList();
    final selectedCount = selected.length;
    final warn = !sel['name']! || !sel['birth']!;
    return Scaffold(body: Stack(fit: StackFit.expand, children: [
      ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3), child: ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xB3000000), BlendMode.darken), child: Image.asset(_img('hall'), fit: BoxFit.cover))),
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -.64), radius: 1, colors: [Color(0x38A11D19), Colors.transparent]))),
      const BottomShade(stops: [0, .4, .8], colors: [Color(0x66070404), Color(0xB3070404), C.bg]),
      Positioned.fill(child: SafeArea(top: false, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 86, 20, 26), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 두 인장(印章) + 붉은 실
        SizedBox(height: 104, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _Seal(label: '神通', caption: 'SINTONG · 신통방통', hot: false)),
          SizedBox(width: 112, child: _ThreadLink(busy: busy)),
          Expanded(child: _Seal(label: '神堂', caption: 'THE SHRINE · 신당', hot: true)),
        ])),
        const SizedBox(height: 6),
        Center(child: Text('門 · 신통방통 회원으로 들어가기', style: t.mono.copyWith(color: C.gold))), const SizedBox(height: 10),
        Center(child: Text('이미 알려 주신 것은\n다시 묻지 않겠습니다.', textAlign: TextAlign.center, style: t.display(23))), const SizedBox(height: 6),
        Center(child: Text('신통방통에 등록된 정보 중, 허락하신 것만 신당으로 가져옵니다.', textAlign: TextAlign.center, style: t.body(13, c: C.muted, h: 1.6))),
        const SizedBox(height: 16),
        // 명부(名簿) 패널
        Container(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.goldLine),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xEB1A0C0A), Color(0xEB0C0605)])),
          child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
              Text('名簿 · 옮겨 적을 것', style: t.mono.copyWith(color: C.gold)), const Spacer(),
              Text('$selectedCount / 3', style: t.mono.copyWith(color: C.muted)),
            ])),
            const Divider(height: 1, thickness: 1, color: C.line),
            for (final r in rows) _LedgerRow(
              on: sel[r.$1]!,
              moved: busy && sel[r.$1]! && moved > selected.indexOf(r),
              glyph: r.$2, label: r.$3, value: r.$4, why: r.$5, ts: st.ts,
              last: r == rows.last,
              onTap: busy ? null : () => setState(() => sel[r.$1] = !sel[r.$1]!),
            ),
            if (warn) Padding(padding: const EdgeInsets.fromLTRB(2, 2, 2, 10), child: Text('이름과 생년월일을 빼면, 다음 화면에서 직접 적어 주셔야 합니다.', style: t.ui(11.5, c: C.redHot))),
          ]),
        ),
        const SizedBox(height: 14),
        // 약속
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final f in ['비밀번호와 로그인 정보는 신당에 남기지 않습니다.', '공유 링크·이미지에 생년월일과 사주 원본은 담기지 않습니다.', '연결은 설정에서 언제든 끊을 수 있습니다.'])
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('◇', style: t.ui(11.5, c: C.gold)), const SizedBox(width: 8),
                Expanded(child: Text(f, style: t.ui(11.5, c: C.muted))),
              ])),
          ]),
        ),
        const SizedBox(height: 14),
        RedButton(busy ? (moved < selectedCount ? '명부에 옮겨 적는 중…' : '신당의 문을 엽니다') : '동의하고 명부 옮기기', ts: st.ts, onTap: busy ? null : _link),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: busy ? null : () => ShrineNav.go(context, 'info'), child: Text('회원 연결 없이 직접 적기', style: t.ui(13, c: C.muted).copyWith(decoration: TextDecoration.underline))),
          const SampleTag('회원 연동 전 예시 회원'),
        ]),
      ])))),
      _top(context, back: () => ShrineNav.go(context, 'hall')),
    ]));
  }
}

/// 인장(印章) — 神通(보라 그라데이션) / 神堂(붉은 그라데이션), 회전 + 광채
class _Seal extends StatelessWidget {
  final String label, caption; final bool hot;
  const _Seal({required this.label, required this.caption, required this.hot});
  @override
  Widget build(BuildContext context) => Column(children: [
    Transform.rotate(angle: hot ? .07 : -.07, child: Container(width: 66, height: 66, alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: hot ? const [Color(0xFFB8241F), Color(0xFF6E0F0C)] : const [Color(0xFF2A1748), Color(0xFF120A24)]),
        border: Border.all(color: hot ? const Color(0x99D6AA64) : const Color(0x73F5CF6A)),
        boxShadow: [BoxShadow(color: hot ? C.redGlow : const Color(0x2EF5CF6A), blurRadius: hot ? 30 : 26)],
      ),
      child: Text(label, textAlign: TextAlign.center, style: T(1).display(16, w: FontWeight.w900, c: hot ? C.btnText : const Color(0xFFF5CF6A)).copyWith(height: 1.05)),
    )),
    const SizedBox(height: 9),
    Text(caption, style: T(1).mono.copyWith(fontSize: 8.5, letterSpacing: 2)),
  ]);
}

/// 두 인장을 잇는 붉은 실 — 웹 SVG 경로(M4 30 C40 6,60 54,80 30 S120 6,156 30)를 CustomPainter로 포팅.
/// [애니메이션 주의] 웹의 달리는 점선 애니메이션은 무한 반복(infinite)이라 포팅 시 pumpAndSettle 계열
/// 위젯 테스트를 영원히 멈추게 할 위험이 있어, 매듭(knot)이 busy 상태에서만 번쩍이는 정적 버전으로 포팅했다.
class _ThreadLink extends StatelessWidget {
  final bool busy; const _ThreadLink({required this.busy});
  @override
  Widget build(BuildContext context) => SizedBox(height: 50, child: CustomPaint(painter: _ThreadPainter(busy: busy), size: Size.infinite));
}
class _ThreadPainter extends CustomPainter {
  final bool busy; _ThreadPainter({required this.busy});
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 160, sy = size.height / 60;
    Offset p(double x, double y) => Offset(x * sx, y * sy);
    final path = Path()
      ..moveTo(p(4, 30).dx, p(4, 30).dy)
      ..cubicTo(p(40, 6).dx, p(40, 6).dy, p(60, 54).dx, p(60, 54).dy, p(80, 30).dx, p(80, 30).dy)
      ..cubicTo(p(100, 6).dx, p(100, 6).dy, p(120, 6).dx, p(120, 6).dy, p(156, 30).dx, p(156, 30).dy);
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.3..strokeCap = StrokeCap.round..color = const Color(0x8CE0412F));
    canvas.drawCircle(p(80, 30), busy ? 4.2 : 3.2, Paint()..color = const Color(0xFFE0412F)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
  @override
  bool shouldRepaint(covariant _ThreadPainter old) => old.busy != busy;
}

/// 명부 행 — 원형 한자(名·生·時) 글자 + 라벨/부연 + 값(끄면 취소선) + 토글 스위치.
/// 연결 애니메이션 중(moved) 원이 붉게 채워지며 ✓로 바뀐다.
class _LedgerRow extends StatelessWidget {
  final bool on, moved, last; final String glyph, label, value, why; final double ts; final VoidCallback? onTap;
  const _LedgerRow({required this.on, required this.moved, required this.last, required this.glyph, required this.label, required this.value, required this.why, required this.ts, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = T(ts);
    return GestureDetector(onTap: onTap, child: Container(
      constraints: const BoxConstraints(minHeight: 64), padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
      child: Row(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 400), width: 34, height: 34, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: moved ? C.red : Colors.black.withValues(alpha: .25),
            border: Border.all(color: moved || on ? const Color(0xB3D6AA64) : C.goldDim),
            boxShadow: moved ? Glow.red(14) : null),
          child: Text(moved ? '✓' : glyph, style: T(1).display(14, w: FontWeight.w900, c: moved ? C.btnText : C.gold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.body(14.5, w: FontWeight.w700, c: on ? C.fg : C.muted)),
          Text(on ? why : '가져오지 않습니다', style: t.ui(11, c: C.faint)),
        ])),
        const SizedBox(width: 8),
        Text(value, style: t.mono.copyWith(fontSize: 12, letterSpacing: 0, color: on ? C.gold : C.faint,
          decoration: on ? null : TextDecoration.lineThrough, decorationColor: C.redHot, decorationThickness: 1.5)),
        const SizedBox(width: 10),
        _LedgerSwitch(on: on),
      ]),
    ));
  }
}

/// 토글 스위치 — 웹 .cn2-sw 1:1 (44x26 알약형, 20px 원형 손잡이, on일 때 붉은 그라데이션 + 글로우)
class _LedgerSwitch extends StatelessWidget {
  final bool on; const _LedgerSwitch({required this.on});
  @override
  Widget build(BuildContext context) => AnimatedContainer(duration: const Duration(milliseconds: 350),
    width: 44, height: 26, padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(999),
      gradient: on ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB8241F), Color(0xFF7F1411)]) : null,
      color: on ? null : const Color(0x1AEFE4D2),
      border: Border.all(color: on ? const Color(0x99D6AA64) : C.line),
      boxShadow: on ? Glow.red(12) : null),
    child: AnimatedAlign(duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFFF8EAD6) : const Color(0xFF6A5A52)))),
  );
}

// ═══════════ 命 정통사주 해석 (/saju) ═══════════
class SajuScreen extends StatefulWidget { const SajuScreen({super.key}); @override State<SajuScreen> createState() => _SajuState(); }
class _SajuState extends State<SajuScreen> {
  SajuResult? saju; bool loading = true; int open = 0; Timer? _t;
  @override
  void initState() {
    super.initState();
    final st = context.read<ShrineSessionProvider>().state;
    context.read<SajuRepository>().fetch(birth: st.birth ?? '', time: st.time).then((r) {
      if (!mounted) return;
      setState(() { saju = r; loading = false; });
      if (r != null) context.read<ShrineSessionProvider>().update((s) => s.copy(saju: r));
      _t = Timer.periodic(Duration(milliseconds: st.reduce ? 60 : 380), (tm) { setState(() => open++); if (open > 6) tm.cancel(); });
    });
  }
  @override void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts);
    if (loading) return const Scaffold(body: Center(child: SizedBox()));   // 스켈레톤 없음 (디자인 원칙)
    if (saju == null) return Scaffold(body: Stack(children: [
      Positioned(left: 16, right: 16, top: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('사주를 불러오지\n못했습니다.', style: t.display(25, w: FontWeight.w900)), const SizedBox(height: 10),
        Text('생년월일 없이 이야기만 보실 수 있습니다.', style: t.body(14, c: C.muted)), const SizedBox(height: 20),
        RedButton('주제 고르기', ts: st.ts, onTap: () => ShrineNav.go(context, 'recommend'))])),
      _top(context, back: () => ShrineNav.go(context, 'talk')),
    ]));
    final s = saju!; final maxE = s.elements.values.fold<int>(1, (a, b) => b > a ? b : a);
    final pillars = [('時', s.pillars['hour']), ('日', s.pillars['day']), ('月', s.pillars['month']), ('年', s.pillars['year'])];
    return Scaffold(body: Stack(children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1), radius: 1.1, colors: [Color(0xFF2A0D0B), C.bg]))),
      ListView(padding: const EdgeInsets.fromLTRB(16, 104, 16, 40), children: [
        Text('命 · ${st.name}님의 정통사주', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 10),
        Text('태어난 날의\n기운을 펼칩니다.', style: t.display(25, w: FontWeight.w900)),
        if (s.source == 'SAMPLE') const Align(alignment: Alignment.centerLeft, child: SampleTag()),
        const SizedBox(height: 18),
        _Reveal(open > 0, Row(children: [for (final p in pillars) Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: p.$1 == '日' ? C.redHot : C.line), boxShadow: p.$1 == '日' ? Glow.red(22) : null,
            gradient: p.$1 == '日' ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x995A0E0C), Color(0xD90E0706)]) : null,
            color: p.$1 == '日' ? null : const Color(0xCC0E0706)),
          child: Column(children: [
            Text('${p.$1}柱', style: t.mono.copyWith(fontSize: 9, letterSpacing: 1.8)), const SizedBox(height: 6),
            for (var i = 0; i < 2; i++) Text(p.$2 == null ? '·' : p.$2!.characters.elementAt(i),
              style: t.display(28, w: FontWeight.w900, c: p.$2 == null ? const Color(0x26EFE4D2) : (p.$1 == '日' && i == 0 ? C.redHot : C.fg)).copyWith(height: 1.05)),
            if (p.$2 == null) Text('시간 미상', style: t.ui(9, c: C.faint)),
          ])))])),
        const SizedBox(height: 12),
        _Reveal(open > 1, _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('日干 · 타고난 기질', style: t.mono), const Spacer(), Text(s.dayStem, style: t.display(26, w: FontWeight.w900, c: _elColor[s.dayElement]!))]),
          Text(s.dayLabel, style: t.body(17, w: FontWeight.w700, c: C.gold, h: 1.35)),
          if (s.temperament != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.temperament!, style: t.body(13.5, c: const Color(0xD9EFE4D2), h: 1.75))),
        ]))),
        _Reveal(open > 2, _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('五行 · 다섯 기운의 균형', style: t.mono), const SizedBox(height: 10),
          Row(children: [for (final e in s.elements.entries) Expanded(child: Column(children: [
            Container(width: 14, height: 64, alignment: Alignment.bottomCenter, decoration: BoxDecoration(color: const Color(0x12EFE4D2), borderRadius: BorderRadius.circular(7)),
              child: AnimatedContainer(duration: const Duration(milliseconds: 1200), curve: const Cubic(.2, .7, .2, 1), height: open > 2 ? 64 * e.value / maxE : 0,
                decoration: BoxDecoration(color: _elColor[e.key], borderRadius: BorderRadius.circular(7)))),
            const SizedBox(height: 5), Text(e.key, style: t.display(16, w: FontWeight.w900, c: _elColor[e.key]!)), Text('${e.value}', style: t.mono.copyWith(fontSize: 10, letterSpacing: 0)),
          ]))]),
        ]))),
        _Reveal(open > 3, Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('强 · 강점', style: t.mono), for (final x in s.strengths) Text('· $x', style: t.body(13, c: const Color(0xD9EFE4D2)))]))),
          const SizedBox(width: 10),
          Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('愼 · 주의할 점', style: t.mono), for (final x in s.cautions) Text('· $x', style: t.body(13, c: const Color(0xD9EFE4D2)))]))),
        ])),
        _Reveal(open > 4, _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('主題 · 주제별 풀이', style: t.mono),
          for (final tp in shrine.topics) if (s.topics[tp.id]?.note != null) Padding(padding: const EdgeInsets.only(top: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(6)), child: Text(tp.sig, style: t.display(14, w: FontWeight.w900, c: C.btnText))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tp.label, style: t.body(14, w: FontWeight.w700, h: 1.3)), Text(s.topics[tp.id]!.note!, style: t.body(12.5, c: C.muted, h: 1.6))])),
          ])),
          const SizedBox(height: 8), Text('엔진이 근거를 주지 않은 주제는 표시하지 않습니다.', style: t.ui(11, c: C.faint)),
        ]))),
        if (s.hourUnknown) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('태어난 시간을 모르셔서 시주(時柱)를 빼고 풀이했습니다.', textAlign: TextAlign.center, style: t.ui(11, c: C.faint))),
        _Reveal(open > 5, Column(children: [
          RedButton('오늘 열어 볼 이야기 고르기', ts: st.ts, onTap: () => ShrineNav.go(context, 'recommend')), const SizedBox(height: 10),
          Pill('해석만 보고 나가기', ts: st.ts, onTap: () => ShrineNav.go(context, 'list')),
        ])),
      ]),
      _top(context, back: () => ShrineNav.go(context, 'talk'), center: Text('SAJU · 正統四柱', style: t.mono)),
    ]));
  }
}

// ═══════════ 推 주제 추천 (/recommend) ═══════════
class RecommendScreen extends StatefulWidget { const RecommendScreen({super.key}); @override State<RecommendScreen> createState() => _RecState(); }
class _RecState extends State<RecommendScreen> {
  String? pick;
  @override
  void initState() { super.initState(); final st = context.read<ShrineSessionProvider>().state; pick = recommend(st.saju).pick ?? st.topic; }
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts); final rec = recommend(st.saju);
    final recT = rec.pick == null ? null : shrine.topic(rec.pick);
    return Scaffold(body: Stack(fit: StackFit.expand, children: [
      ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: const ShrineVideo(name: 'talk', poster: 'talk')),
      const BottomShade(stops: [0, .3, .6, 1], colors: [Color(0x80070404), Color(0x8C070404), Color(0xF2070404), Color(0xF2070404)]),
      Positioned(left: 16, right: 16, bottom: 22, child: SafeArea(top: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const SpeakerBadge('월화', hanja: '月華'), const SizedBox(height: 10),
        if (recT != null) ...[
          Text.rich(TextSpan(style: t.display(17, h: 1.65), children: [TextSpan(text: '${st.name}님의 명(命)을 보니,\n오늘은 '), TextSpan(text: recT.label, style: const TextStyle(color: C.redHot)), const TextSpan(text: '의 이야기가\n먼저 문을 두드립니다.')])),
          const SizedBox(height: 10),
          _card(border: C.goldLine, pad: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('推 · 추천 이유 — 사주 근거', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 6),
            Text(rec.reason!, style: t.body(13, c: const Color(0xD9EFE4D2), h: 1.6)), const SizedBox(height: 10),
            Row(children: [for (final r in rec.ranked) Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: Row(children: [
              Text(shrine.topic(r.key).sig, style: t.display(12, w: FontWeight.w900, c: r.key == rec.pick ? C.redHot : C.faint)), const SizedBox(width: 6),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: r.value.score, minHeight: 4,
                backgroundColor: const Color(0x14EFE4D2), color: r.key == rec.pick ? C.redHot : const Color(0x99C9A368)))),
            ])))]),
          ])),
        ] else Text('무엇이 가장 궁금해서\n이곳에 오셨습니까?', style: t.display(17, h: 1.65)),
        const SizedBox(height: 6),
        for (final tp in shrine.topics) Padding(padding: const EdgeInsets.only(bottom: 7), child: Stack(children: [
          TopicButton(sig: tp.sig, label: tp.id == rec.pick ? '${tp.label}  ·  추천' : tp.label, desc: tp.d, ts: st.ts, onTap: () => setState(() => pick = tp.id)),
          if (pick == tp.id) Positioned.fill(child: IgnorePointer(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(R.opt), border: Border.all(color: C.redHot), boxShadow: Glow.red(24))))),
        ])),
        const SizedBox(height: 6),
        Opacity(opacity: pick == null ? .45 : 1, child: RedButton(pick == null ? '주제를 고르십시오' : '「붉은 방울」 · ${shrine.topic(pick).label}으로 들어가기', ts: st.ts, onTap: pick == null ? null : () {
          context.read<ShrineSessionProvider>().update((s) => s.copy(topic: pick, clearPos: true)); ShrineNav.go(context, 'story'); })),
        const SizedBox(height: 8),
        Center(child: Text(rec.pick != null ? '추천과 다른 주제를 고르셔도 됩니다.' : '사주 근거가 충분하지 않아 추천하지 않았습니다.', style: t.ui(11, c: C.faint))),
      ]))),
      _top(context, back: () => ShrineNav.go(context, 'saju')),
    ]));
  }
}

// ═══════════ 義 선택의 의미 → 부적 구성 (/meaning) ═══════════
class MeaningScreen extends StatefulWidget { const MeaningScreen({super.key}); @override State<MeaningScreen> createState() => _MeaningState(); }
class _MeaningState extends State<MeaningScreen> {
  int step = 0; final _ts = <Timer>[];
  @override
  void initState() { super.initState(); final r = context.read<ShrineSessionProvider>().state.reduce;
    for (final (i, ms) in [600, 1700, 2900].indexed) { _ts.add(Timer(Duration(milliseconds: r ? 100 * (i + 1) : ms), () => mounted ? setState(() => step = i + 1) : null)); } }
  @override void dispose() { for (final x in _ts) { x.cancel(); } super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts); final src = st.meaningSrc!;
    final isMain = src.story == 'red-bell'; final tale = isMain ? null : shrine.tales[src.story];
    final type = isMain ? (st.topic ?? 'love') : tale!.talis;
    final flav = shrine.talismans.interpret(src.flags);
    final note = st.saju?.topics[type]?.note;
    final spec = shrine.talismans.compose(type: type, flavor: flav.id, story: src.story, ending: src.ending, element: st.saju?.dayElement);
    final endName = isMain ? shrine.endings[src.ending]!.name : tale!.endings[src.ending]!.name;
    final topicLabel = shrine.topics.where((x) => x.id == type).firstOrNull?.label;
    return Scaffold(body: Stack(fit: StackFit.expand, children: [
      const ShrineVideo(name: 'talk', poster: 'talk'),
      const BottomShade(stops: [0, .2, .44, .7], colors: [Color(0x73070404), Color(0x40070404), Color(0xE0070404), Color(0xF7070404)]),
      Positioned(left: 16, right: 16, bottom: 22, child: SafeArea(top: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('義 · ${isMain ? '붉은 방울' : tale!.title} · 결말 ${src.ending} $endName', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 8),
        const SpeakerBadge('월화', hanja: '月華'), const SizedBox(height: 8),
        Text('${st.name}님은 ${flav.said}', style: t.display(16.5, h: 1.65)),
        Text(flav.story, style: t.body(14, c: C.muted, h: 1.6)), const SizedBox(height: 10),
        _Reveal(step >= 1, _card(border: C.goldLine, pad: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_tag('命 사주의 근거', C.gold), const Spacer(), Text('정통사주 엔진', style: t.mono)]), const SizedBox(height: 6),
          note != null ? Text('${topicLabel ?? ''} — $note', style: t.body(13, h: 1.6)) : Text('이 주제에 대해 엔진이 준 근거가 없어, 사주 해석은 덧붙이지 않습니다.', style: t.body(11.5, c: C.faint)),
          if (st.saju?.source == 'SAMPLE') const SampleTag(),
        ]))),
        _Reveal(step >= 2, _card(border: const Color(0x73E0412F), pad: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_tag('選 이야기 속 선택', C.redHot), const Spacer(), Text('${flav.k} · ${flav.label}', style: t.mono)]), const SizedBox(height: 6),
          Text('이야기에서 고르신 길: ${src.path.length > 3 ? src.path.sublist(src.path.length - 3).map((p) => '"${p.label}"').join(' → ') : src.path.map((p) => '"${p.label}"').join(' → ')}', style: t.body(13, h: 1.6)),
          Text('이것은 이야기 안에서의 의미입니다. 실제 성격이나 과거를 맞힌 것이 아닙니다.', style: t.body(11.5, c: C.faint)),
        ]))),
        _Reveal(step >= 3, Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x73D6AA64)),
            gradient: const LinearGradient(colors: [Color(0x805A0E0C), Color(0xD90E0706)])),
          child: Row(children: [
            BujeokSheet(w: 92, name: nameShown(st.name, 'full'), spec: spec), const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('符 · 써 드릴 부적', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 4),
              Text('${spec.name} · ${spec.phrase}', style: t.display(17, h: 1.3)),
              Text('${spec.phraseMeaning} — ${topicLabel ?? ''} × ${flav.label}', style: t.body(12.5, c: C.muted, h: 1.5)),
              Text(spec.designId, style: t.mono.copyWith(fontSize: 9, letterSpacing: 1)),
            ])),
          ]))),
        Opacity(opacity: step >= 3 ? 1 : .4, child: RedButton('월화에게 부적을 부탁하기', ts: st.ts, onTap: step < 3 ? null : () {
          context.read<ShrineSessionProvider>().update((s) => s.copy(pending: Pending(spec, StorySource(src.story, src.ending), flav.id, isMain ? '$kShrineBase/result/${src.ending}' : '$kShrineBase/list')));
          ShrineNav.go(context, 'ritual');
        })),
      ]))),
      _top(context, back: () => isMain ? ShrineNav.go(context, 'end', params: {'code': src.ending}) : ShrineNav.go(context, 'tale-end', params: {'id': src.story, 'code': src.ending})),
    ]));
  }
  Widget _tag(String s, Color c) => Container(height: 22, padding: const EdgeInsets.symmetric(horizontal: 9), alignment: Alignment.center,
    decoration: BoxDecoration(color: c.withValues(alpha: .16), borderRadius: BorderRadius.circular(5)), child: Text(s, style: T(1).body(11.5, w: FontWeight.w700, c: c, h: 1)));
}

// ═══════════ 受 부적 받기 (/receive) — 태운 그 부적(pending.spec)을 선물 ═══════════
enum RPh { give, unroll, name, keep, use }
class ReceiveScreen extends StatefulWidget { const ReceiveScreen({super.key}); @override State<ReceiveScreen> createState() => _ReceiveState(); }
class _ReceiveState extends State<ReceiveScreen> {
  RPh ph = RPh.give; String mode = 'full'; BoxItem? item; bool dup = false;
  void _go(RPh p) { setState(() => ph = p); if (p == RPh.unroll) Future.delayed(Duration(milliseconds: context.read<ShrineSessionProvider>().state.reduce ? 300 : 2600), () => mounted && ph == RPh.unroll ? _go(RPh.name) : null); }
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts); final p = st.pending!; final sp = p.spec;
    final copy = shrine.talismans.copy[sp.type] as Map; final flavLabel = (shrine.talismans.flavors[p.flavor] as Map?)?['label'] ?? '';
    final shown = nameShown(st.name, ph == RPh.name ? mode : (item?.mode ?? mode));
    final serial = '神堂 · ${item?.no ?? 'N°${(st.issued + 1).toString().padLeft(4, '0')}'}';
    final srcLabel = p.source.story == 'red-bell' ? '「붉은 방울」 결말 ${p.source.ending}' : '「${shrine.tales[p.source.story]!.title}」 결말 ${p.source.ending}';
    void leave() { context.read<ShrineSessionProvider>().update((s) => s.copy(clearPending: true)); ShrineNav.goPath(context, p.back); }
    final sheetW = ph == RPh.use ? 120.0 : ph == RPh.name ? 170.0 : 200.0;
    return Scaffold(body: Stack(fit: StackFit.expand, children: [
      if (ph == RPh.give) ShrineVideo(name: 'give', poster: 'give', loop: false, onEnd: () => _go(RPh.unroll))
      else ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), child: ColorFiltered(colorFilter: const ColorFilter.matrix([.32,0,0,0,0, 0,.32,0,0,0, 0,0,.32,0,0, 0,0,0,1,0]), child: Image.asset(_img('give'), fit: BoxFit.cover))),
      const BottomShade(stops: [0, .26, .62, 1], colors: [Color(0x99070404), Color(0x26070404), Color(0x66070404), Color(0xF5070404)]),
      if (ph != RPh.give) const Embers(count: 14),
      if (ph != RPh.give) AnimatedPositioned(duration: const Duration(milliseconds: 1000), curve: Curves.ease, top: 98,
        left: ph == RPh.use ? null : 0, right: ph == RPh.use ? 22 : 0,
        child: Center(child: TweenAnimationBuilder<double>(key: ValueKey(ph == RPh.unroll), tween: Tween(begin: ph == RPh.unroll ? 0 : 1, end: 1), duration: const Duration(milliseconds: 2400), curve: const Cubic(.3, .9, .3, 1),
          builder: (_, v, child) => ClipRect(child: Align(alignment: Alignment.bottomCenter, heightFactor: v, child: Opacity(opacity: v.clamp(0, 1), child: child))),
          child: GestureDetector(onTap: ph == RPh.keep || ph == RPh.name ? () => showTalisManual(context, spec: sp, item: item) : null,
            child: Transform.rotate(angle: ph == RPh.use ? .07 : 0, child: BujeokSheet(w: sheetW, name: shown, spec: sp, serial: ph == RPh.use ? null : serial)))))),
      Positioned(left: 20, right: 20, bottom: 26, child: SafeArea(top: false, child: switch (ph) {
        RPh.give => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const SpeakerBadge('월화', hanja: '月華'), const SizedBox(height: 10),
          Text.rich(TextSpan(style: t.body(19, w: FontWeight.w700, h: 1.6), children: [const TextSpan(text: '태운 것은 끝이 아닙니다.\n방금 올린 그 부적을,\n'),
            TextSpan(text: '${st.name ?? '당신'}님 몫으로 한 장 더 옮겨 적었습니다.', style: const TextStyle(color: C.redHot))]))]),
        RPh.unroll => Column(mainAxisSize: MainAxisSize.min, children: [
          Text(sp.head, style: t.display(26, w: FontWeight.w900, c: C.gold).copyWith(letterSpacing: 10)), const SizedBox(height: 10),
          Text('${sp.phrase.characters.join(' ')} · ${sp.phraseMeaning}', style: t.body(13, c: C.muted))]),
        RPh.name => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          BjOneBadge(name: shown, spec: sp, serial: serial, compact: true), const SizedBox(height: 12),
          Text('名 · 이름을 어떻게 남기시겠습니까', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 8),
          for (final m in [('full', '이름 전부', st.name ?? '—'), ('initial', '첫 글자만', nameShown(st.name, 'initial')), ('hidden', '적지 않음', '持者不記')])
            GestureDetector(onTap: () => setState(() => mode = m.$1), child: Container(margin: const EdgeInsets.only(bottom: 7), height: 46, padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: mode == m.$1 ? const Color(0x8C5A0E0C) : const Color(0xC70E0706), borderRadius: BorderRadius.circular(11), border: Border.all(color: mode == m.$1 ? C.redHot : C.line)),
              child: Row(children: [
                Container(width: 16, height: 16, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.goldDim)),
                  child: mode == m.$1 ? Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: C.redHot, boxShadow: Glow.red(8))) : null),
                const SizedBox(width: 12), Text(m.$2, style: t.ui(14)), const Spacer(),
                Text(m.$3, style: m.$1 == 'hidden' ? t.display(16, c: C.redHot) : T(1).logo.copyWith(fontSize: 20, color: C.redHot, height: 1)),
              ]))),
          Text('공유 이미지에는 생년월일이 들어가지 않습니다.', style: t.ui(11, c: C.faint)), const SizedBox(height: 10),
          RedButton('부적 간직하기', ts: st.ts, onTap: () { final r = context.read<ShrineSessionProvider>().issue(p, mode); setState(() { item = r.item; dup = r.dup; }); _go(RPh.keep); }),
        ]),
        RPh.keep => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          BjOneBadge(name: shown, spec: sp, serial: serial, compact: true), const SizedBox(height: 10),
          Text('持 · ${dup ? '이미 간직한 부적' : '부적함에 담았습니다'}', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 6),
          Text('${st.name != null ? '${st.name}님의 ' : ''}${sp.name} · ${sp.phrase}', style: t.display(21, h: 1.4)),
          Text('${sp.phraseMeaning}. ${copy['line']}', style: t.body(14, c: C.muted)),
          Text('義  $srcLabel · $flavLabel에서 나온 부적', style: t.body(12, c: C.faint)), const SizedBox(height: 10),
          _acts([('⤓', '사진첩 저장', () => _save(item!)), ('持', '부적함 보기', () => ShrineNav.go(context, 'box')), ('用', '간직하는 법', () => _go(RPh.use))]),
          const SizedBox(height: 10),
          RedButton(p.back.startsWith('$kShrineBase/result') ? '결과 두루마리 보기' : '다른 이야기 보기', ts: st.ts, onTap: leave),
          if (dup) Padding(padding: const EdgeInsets.only(top: 10), child: Text('같은 길에서 나온 부적은 이미 간직하고 계십니다. 다른 선택은 다른 부적이 됩니다.', textAlign: TextAlign.center, style: t.ui(11, c: C.faint))),
        ]),
        RPh.use => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('用 · 간직하는 법', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 6),
          Text('${sp.name}는\n이렇게 지니십시오.', style: t.display(21, h: 1.4)), const SizedBox(height: 10),
          _card(border: C.goldLine, pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), child: Column(children: [
            for (final (i, u) in (copy['use'] as List).indexed) Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: C.line))),
              child: Row(children: [Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.goldDim)),
                child: Text(['壹', '貳', '參'][i], style: t.display(12, w: FontWeight.w900, c: C.gold))), const SizedBox(width: 12), Text(u, style: t.body(14, w: FontWeight.w700))]))])),
          Pill('부적 설명서 전체 보기 — 뜻 · 삼갈 것 · 보내는 법', ts: st.ts, onTap: () => showTalisManual(context, spec: sp, item: item)), const SizedBox(height: 10),
          RedButton(p.back.startsWith('$kShrineBase/result') ? '결과 두루마리 보기' : '다른 이야기 보기', ts: st.ts, onTap: leave),
          Padding(padding: const EdgeInsets.only(top: 10), child: Text('부적은 창작 연출물이며 효험을 보증하지 않습니다.', textAlign: TextAlign.center, style: t.ui(11, c: C.faint))),
        ]),
      })),
      _top(context, back: leave, trailing: ph == RPh.give ? GestureDetector(onTap: () => _go(RPh.unroll), child: Container(height: 32, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0x80080404), borderRadius: BorderRadius.circular(999), border: Border.all(color: C.goldLine)), child: Text('SKIP ›', style: t.mono.copyWith(letterSpacing: 2.5, color: C.muted)))) : null),
    ]));
  }
  Future<void> _save(BoxItem it) async {
    final st = context.read<ShrineSessionProvider>().state; final copy = shrine.talismans.copy[it.spec.type] as Map;
    final src = it.source.story == 'red-bell' ? '「붉은 방울」 결말 ${it.source.ending}' : '「${shrine.tales[it.source.story]!.title}」 결말 ${it.source.ending}';
    final png = await renderBujeokPng(name: nameShown(st.name, it.mode), spec: it.spec, serial: '神堂 · ${it.no}', title: '${it.spec.name} · ${it.spec.phrase}',
      line: '${it.spec.phraseMeaning} — ${copy['line']}', sub: '${it.date} · $src');
    await Gal.putImageBytes(png, name: '신당_${it.spec.name}_${it.spec.phrase}');
    context.read<ShrineSessionProvider>().updateBox(it.no, (b) => b.copy(saved: true));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('부적을 사진첩에 저장했습니다')));
  }
}

Widget _acts(List<(String, String, VoidCallback)> a) => Container(clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.goldLine)),
  child: Row(children: [for (final x in a) Expanded(child: GestureDetector(onTap: x.$3, child: Container(color: const Color(0xF20E0706), margin: const EdgeInsets.symmetric(horizontal: .5), padding: const EdgeInsets.fromLTRB(0, 13, 0, 11),
    child: Column(children: [Text(x.$1, style: T(1).display(16, w: FontWeight.w900, c: C.gold)), const SizedBox(height: 7), Text(x.$2, style: T(1).ui(12))]))))]));

// ═══════════ 持 부적함 (/box) — 컬렉션 ═══════════
class BoxScreen extends StatefulWidget { const BoxScreen({super.key}); @override State<BoxScreen> createState() => _BoxState(); }
class _BoxState extends State<BoxScreen> {
  String flt = 'all';
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts); final types = (shrine.talismans.types as Map).keys.cast<String>().toList();
    final list = st.box.where((b) => flt == 'all' || b.spec.type == flt).toList().reversed.toList();
    return Scaffold(body: Stack(children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1), radius: 1, colors: [Color(0xFF220B09), C.bg]))),
      ListView(padding: const EdgeInsets.fromLTRB(16, 104, 16, 40), children: [
        Text('持符 · 내 부적함', style: t.mono), const SizedBox(height: 10),
        Text('간직한 부적 ${st.box.length}장', style: t.display(24, w: FontWeight.w900)), const SizedBox(height: 6),
        Text('이야기와 선택이 다르면 같은 종류라도 다른 부적이 됩니다. 같은 길에서 나온 부적은 다시 펼쳐 봅니다.', style: t.body(13, c: C.muted)), const SizedBox(height: 14),
        SizedBox(height: 32, child: ListView(scrollDirection: Axis.horizontal, children: [
          _chip('전체 ${st.box.length}', flt == 'all', () => setState(() => flt = 'all')),
          for (final ty in types) _chip('${(shrine.talismans.types as Map)[ty]['sig']} ${st.box.where((b) => b.spec.type == ty).length}', flt == ty, () => setState(() => flt = ty)),
        ])),
        const SizedBox(height: 14),
        if (list.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Column(children: [
          Text('封', style: t.display(48, w: FontWeight.w900, c: const Color(0x1AEFE4D2))), const SizedBox(height: 10),
          Text('아직 간직한 부적이 없습니다.\n이야기를 마치면 월화가 부적을 써 드립니다.', textAlign: TextAlign.center, style: t.body(13, c: C.faint))])),
        GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 10, childAspectRatio: 96 / 240, children: [
          for (final b in list) GestureDetector(onTap: () => showTalisManual(context, spec: b.spec, item: b, actions: [
              ('名', '이름 표시', () => context.read<ShrineSessionProvider>().updateBox(b.no, (x) => x.copy(mode: x.mode == 'full' ? 'initial' : x.mode == 'initial' ? 'hidden' : 'full'))),
              ('話', '이야기 보기', () { Navigator.pop(context); b.source.story == 'red-bell' ? ShrineNav.go(context, 'end', params: {'code': b.source.ending}) : ShrineNav.go(context, 'tale-end', params: {'id': b.source.story, 'code': b.source.ending}); }),
              ('詳', '상세 · 저장', () { Navigator.pop(context); _detail(b); }),
            ]), child: Column(children: [
            BujeokSheet(w: 96, name: nameShown(st.name, b.mode), spec: b.spec), const SizedBox(height: 8),
            Text(b.spec.name, style: t.body(13, w: FontWeight.w700, h: 1.2)),
            Text(b.spec.phrase, style: t.display(11, w: FontWeight.w900, c: C.gold).copyWith(letterSpacing: 3)),
            Text(b.no, style: t.mono.copyWith(fontSize: 9, letterSpacing: 1)),
          ])),
        ]),
      ]),
      _top(context, back: () => ShrineNav.canPop(context) ? ShrineNav.pop(context) : ShrineNav.go(context, 'list')),
    ]));
  }
  Widget _chip(String l, bool on, VoidCallback f) => Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(onTap: f, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 11), alignment: Alignment.center,
    decoration: BoxDecoration(color: on ? C.red : const Color(0xB30E0706), borderRadius: BorderRadius.circular(999), border: Border.all(color: on ? const Color(0x99D6AA64) : C.line)),
    child: Text(l, style: T(1).ui(12, c: on ? C.btnText : C.muted)))));
  void _detail(BoxItem b) => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => Consumer<ShrineSessionProvider>(builder: (ctx, provider, __) {
    final st = provider.state; final cur = st.box.firstWhere((x) => x.no == b.no); final t = T(st.ts); final copy = shrine.talismans.copy[cur.spec.type] as Map;
    final src = cur.source.story == 'red-bell' ? '「붉은 방울」 결말 ${cur.source.ending}' : '「${shrine.tales[cur.source.story]!.title}」 결말 ${cur.source.ending}';
    return Container(padding: const EdgeInsets.fromLTRB(18, 22, 18, 28), decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B0D0B), Color(0xFF0A0505)]), border: Border(top: BorderSide(color: C.goldLine))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: BujeokSheet(w: 144, name: nameShown(st.name, cur.mode), spec: cur.spec, serial: '神堂 · ${cur.no}')), const SizedBox(height: 14),
        Text('${cur.spec.head} · ${cur.no} · ${cur.spec.designId}', style: t.mono.copyWith(color: C.gold)),
        Text('${cur.spec.name} · ${cur.spec.phrase}', style: t.display(22, h: 1.3)),
        Text('${cur.date} · $src에서 받음', style: t.ui(12, c: C.faint)), const SizedBox(height: 6),
        Text('${cur.spec.phraseMeaning}. ${copy['line']}', style: t.body(14, c: C.muted)), const SizedBox(height: 12),
        _acts([
          ('⤓', cur.saved ? '다시 저장' : '사진첩 저장', () async { final png = await renderBujeokPng(name: nameShown(st.name, cur.mode), spec: cur.spec, serial: '神堂 · ${cur.no}', title: '${cur.spec.name} · ${cur.spec.phrase}', line: '${cur.spec.phraseMeaning} — ${copy['line']}', sub: '${cur.date} · $src');
            await Gal.putImageBytes(png); provider.updateBox(cur.no, (x) => x.copy(saved: true)); }),
          ('名', '이름 표시', () => provider.updateBox(cur.no, (x) => x.copy(mode: x.mode == 'full' ? 'initial' : x.mode == 'initial' ? 'hidden' : 'full'))),
          ('話', '이야기 보기', () { Navigator.pop(ctx); cur.source.story == 'red-bell' ? ShrineNav.go(context, 'end', params: {'code': cur.source.ending}) : ShrineNav.go(context, 'tale-end', params: {'id': cur.source.story, 'code': cur.source.ending}); }),
        ]),
      ]));
  }));
}

// ═══════════ 추가 이야기 재생 (/tale/:id) — 메인 StoryScreen 과 같은 엔진 ═══════════
class TaleScreen extends StatefulWidget { final String id; const TaleScreen({super.key, required this.id}); @override State<TaleScreen> createState() => _TaleState(); }
class _TaleState extends State<TaleScreen> {
  late Tale S; late StoryPos pos; bool typed = false; String? picked; int? left; Timer? _timer; String? chap;
  final _tw = GlobalKey<TypewriterState>();
  @override
  void initState() {
    super.initState(); S = shrine.tales[widget.id]!;
    final saved = context.read<ShrineSessionProvider>().state.talePos[widget.id];
    pos = (saved != null && S.nodes.containsKey(saved.node)) ? saved : StoryPos(S.start, 0, {}, []);
    _enter();
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  StoryNode get node => S.nodes[pos.node]!;
  void _save() => context.read<ShrineSessionProvider>().update((s) => s.copy(talePos: {...s.talePos, widget.id: pos}));
  void _enter() { if (node.chapter != null && pos.line == 0) { chap = node.chapter; Future.delayed(Duration(milliseconds: context.read<ShrineSessionProvider>().state.reduce ? 600 : 2600), () => mounted ? setState(() => chap = null) : null); } }
  void _next() { if (!typed) { _tw.currentState?.finish(); return; } if (pos.line < node.lines.length - 1) setState(() { pos = StoryPos(pos.node, pos.line + 1, pos.flags, pos.path); typed = false; _save(); }); }
  void _startTimer() { final st = context.read<ShrineSessionProvider>().state; if (!node.climax || !st.timer) return; left = node.timer; _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (tm) { setState(() => left = left! - 1); if (left! <= 0) { tm.cancel(); _choose(Choice.fromJson({'label': node.timeoutLabel, 'flag': node.timeoutFlag}), timeout: true); } }); }
  void _choose(Choice c, {bool timeout = false}) {
    if (picked != null) return; _timer?.cancel(); setState(() => picked = c.label);
    final flags = {...pos.flags, ...node.set, if (c.flag != null) c.flag!}; final path = [...pos.path, PathStep(c.label, timeout: timeout)];
    Future.delayed(Duration(milliseconds: context.read<ShrineSessionProvider>().state.reduce ? 150 : 700), () {
      if (!mounted) return;
      if (c.next != null) { setState(() { pos = StoryPos(c.next!, 0, flags, path); picked = null; typed = false; left = null; _save(); _enter(); }); return; }
      final code = S.judge(flags);
      context.read<ShrineSessionProvider>().update((s) => s.copy(talePos: {...s.talePos, widget.id: null},
        taleEndings: {...s.taleEndings, widget.id: {...(s.taleEndings[widget.id] ?? {}), code: DateTime.now().millisecondsSinceEpoch}},
        meaningSrc: StorySource(widget.id, code, flags, path)));
      if (!mounted) return;
      ShrineNav.go(context, 'tale-end', params: {'id': widget.id, 'code': code});
    });
  }
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts); final line = node.lines[pos.line]; final art = line.art ?? node.art;
    final atEnd = pos.line >= node.lines.length - 1; final show = atEnd && typed; final total = S.nodes.values.map((n) => n.step).reduce((a, b) => a > b ? a : b);
    final text = shrine.fill(line.text, name: st.name, season: st.season, topicId: st.topic);
    return Scaffold(body: Stack(fit: StackFit.expand, children: [
      AnimatedSwitcher(duration: Dur.crossfade, child: art == 'talk' ? const ShrineVideo(key: ValueKey('v'), name: 'talk', poster: 'talk') : Image.asset(_img(art), key: ValueKey(art), fit: BoxFit.cover)),
      const BottomShade(), if (node.climax) const RedBreath(), const Embers(count: 8),
      if (chap != null) Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(S.title, style: t.mono), const SizedBox(height: 10),
        Text(chap!.split(' · ')[0], style: t.display(64, w: FontWeight.w900, c: C.redHot).copyWith(shadows: [const Shadow(color: C.redGlow, blurRadius: 30)])),
        Text(chap!.split(' · ').length > 1 ? chap!.split(' · ')[1] : '', style: t.body(16, c: C.muted).copyWith(letterSpacing: 6))])),
      Positioned(left: 14, right: 14, bottom: 22, child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(onTap: _next, child: Container(constraints: const BoxConstraints(minHeight: 116), padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          decoration: BoxDecoration(color: C.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.goldLine)),
          child: Stack(clipBehavior: Clip.none, children: [
            if (line.who != 'narr') Positioned(top: -30, left: -4, child: SpeakerBadge(line.who == 'wolhwa' ? '월화' : '목소리', hanja: line.who == 'wolhwa' ? '月華' : null, voice: line.who == 'voice')),
            Typewriter(line.who == 'voice' ? '"$text"' : text, key: _tw, msPerChar: st.reduce ? 0 : Dur.typeStory, style: t.body(15.5, c: line.who == 'narr' ? C.muted : C.fg, h: 1.75),
              onDone: () { setState(() => typed = true); if (atEnd) _startTimer(); }),
          ]))),
        if (show && left != null) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
          Text('香', style: t.mono.copyWith(color: C.gold)), const SizedBox(width: 10),
          Expanded(child: LinearProgressIndicator(value: left! / node.timer!, minHeight: 3, backgroundColor: const Color(0x1AEFE4D2), color: C.gold)),
          const SizedBox(width: 10), Text('${left}s', style: t.mono.copyWith(color: C.redHot, letterSpacing: 1.5))])),
        if (show) ...[const SizedBox(height: 10), for (final (i, c) in node.choices.indexed) Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(onTap: () => _choose(c),
          child: AnimatedOpacity(duration: const Duration(milliseconds: 300), opacity: picked != null && picked != c.label ? .3 : 1, child: Container(constraints: const BoxConstraints(minHeight: 52), padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            decoration: BoxDecoration(color: picked == c.label ? const Color(0xD95A0E0C) : const Color(0xD10E0706), borderRadius: BorderRadius.circular(11), border: Border.all(color: picked == c.label ? C.redHot : C.goldLine), boxShadow: picked == c.label ? Glow.red(24) : null),
            child: Row(children: [Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: C.goldDim)),
              child: Text(['壹', '貳', '參'][i], style: t.display(11, w: FontWeight.w900, c: C.gold))), const SizedBox(width: 12), Expanded(child: Text(c.label, style: t.body(14.5, w: FontWeight.w700, h: 1.4)))])))))],
      ]))),
      _top(context, back: () => ShrineNav.go(context, 'list'), center: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${S.title} · ${S.en}', style: t.mono.copyWith(color: C.muted)), const SizedBox(height: 7),
        Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < total; i++) Container(width: 16, height: 2, margin: const EdgeInsets.symmetric(horizontal: 2.5),
          color: i + 1 <= node.step ? (node.climax && i + 1 == node.step ? C.redHot : C.gold) : const Color(0x29EFE4D2))])])),
    ]));
  }
}

// ═══════════ 추가 이야기 결말 (/tale-end/:id/:code) ═══════════
class TaleEndScreen extends StatelessWidget {
  final String id, code; const TaleEndScreen({super.key, required this.id, required this.code});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts); final S = shrine.tales[id]!; final e = S.endings[code]!;
    final got = st.taleEndings[id] ?? {}; final src = st.meaningSrc?.story == id ? st.meaningSrc! : StorySource(id, code);
    final key = shrine.talismans.compose(type: S.talis, flavor: shrine.talismans.interpret(src.flags).id, story: id, ending: code).key;
    final has = st.box.any((b) => b.key == key); final tName = (shrine.talismans.types as Map)[S.talis]['name'];
    return Scaffold(body: Stack(fit: StackFit.expand, children: [
      Image.asset(_img(e.art), fit: BoxFit.cover),
      const BottomShade(stops: [0, .18, .3, .52, .7], colors: [Color(0x66070404), Colors.transparent, Colors.transparent, Color(0xE6070404), C.bg]),
      const RedBreath(),
      Positioned(left: 20, right: 20, bottom: 24, child: SafeArea(top: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(6), boxShadow: Glow.red()),
          child: Text('結', style: t.display(19, w: FontWeight.w900, c: C.btnText))), const SizedBox(width: 12), Text('${S.title} · 結 ${got.length} / ${S.endings.length}', style: t.mono)]),
        const SizedBox(height: 12), Text('결말 $code. ${e.name}', style: t.body(15, w: FontWeight.w700, c: C.gold)), const SizedBox(height: 8),
        Text(e.line, style: t.display(21, w: FontWeight.w900)), const SizedBox(height: 12),
        ConstrainedBox(constraints: const BoxConstraints(maxHeight: 170), child: SingleChildScrollView(child: Column(children: [
          for (final p in e.body) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(shrine.fill(p, name: st.name, season: st.season, topicId: st.topic), style: t.body(13.5, c: const Color(0xD1EFE4D2), h: 1.8)))]))),
        const SizedBox(height: 14),
        has ? RedButton('다른 이야기 보기', ts: st.ts, onTap: () => ShrineNav.go(context, 'list'))
            : RedButton('월화의 풀이와 $tName 받기', ts: st.ts, onTap: () { context.read<ShrineSessionProvider>().update((s) => s.copy(meaningSrc: src)); ShrineNav.go(context, 'meaning'); }),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: Pill('다른 선택으로 다시', ts: st.ts, onTap: () { context.read<ShrineSessionProvider>().update((s) => s.copy(talePos: {...s.talePos, id: null})); ShrineNav.go(context, 'tale', params: {'id': id}); })),
          const SizedBox(width: 10), Expanded(child: Pill('부적함', ts: st.ts, onTap: () => ShrineNav.go(context, 'box')))]),
      ]))),
      _top(context, back: () => ShrineNav.go(context, 'list')),
    ]));
  }
}

// ═══════════ 10 이야기 목록 v2 (/list) ═══════════
class ListScreenV3 extends StatelessWidget {
  const ListScreenV3({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; final t = T(st.ts);
    int done(String id) => (st.taleEndings[id] ?? {}).length;
    final finished = ['room', 'night', 'other'].where((id) => done(id) > 0).length + (st.endings.isNotEmpty ? 1 : 0);
    final unlock = {'room': (true, ''), 'night': (st.endings.isNotEmpty, '「붉은 방울」 결말 1개'), 'other': (st.box.isNotEmpty, '부적 1장 간직하기'), 'secret': (finished >= 4, '이야기 4편 모두 마치기 · $finished/4')};
    final totalEnd = st.endings.length + st.taleEndings.values.fold<int>(0, (a, m) => a + m.length);
    return Scaffold(body: Stack(children: [
      const DecoratedBox(decoration: BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1), radius: 1, colors: [Color(0xFF220B09), C.bg]))),
      ListView(padding: const EdgeInsets.fromLTRB(16, 104, 16, 40), children: [
        Text('STORIES · 神堂 記錄', style: t.mono), const SizedBox(height: 10),
        Text('신당에 남겨진 이야기', style: t.display(24, w: FontWeight.w900)), const SizedBox(height: 14),
        Row(children: [_stat(t, '$finished', '마친 이야기'), const SizedBox(width: 8), _stat(t, '$totalEnd', '모은 결말'), const SizedBox(width: 8),
          _stat(t, '${st.box.length}', '간직한 부적 ›', onTap: () => ShrineNav.go(context, 'box'))]),
        const SizedBox(height: 16),
        GestureDetector(onTap: () => ShrineNav.go(context, st.name != null ? 'recommend' : 'connect'), child: Container(height: 230, clipBehavior: Clip.antiAlias, margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: C.goldLine)),
          child: Stack(fit: StackFit.expand, children: [Image.asset(_img('door'), fit: BoxFit.cover, alignment: const Alignment(0, -.2)),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xF2070404)], stops: [.3, 1]))),
            Positioned(left: 16, right: 16, bottom: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${shrine.en} · 約 ${shrine.minutes} MIN', style: t.mono), const SizedBox(height: 6),
              Text(shrine.title, style: t.body(20, w: FontWeight.w700, h: 1.3)), Text(shrine.intro, style: t.body(12.5, c: C.muted, h: 1.5))])),
          ]))),
        for (final id in ['room', 'night', 'other', 'secret']) Builder(builder: (_) {
          final S = shrine.tales[id]!; final u = unlock[id]!; final n = done(id); final prog = st.talePos[id] != null;
          return GestureDetector(onTap: () { if (!u.$1) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('잠긴 이야기입니다 — ${u.$2}'))); return; }
              if (st.name == null) { ShrineNav.go(context, 'connect'); return; }
              // 다른 이야기 → 신통방통 결제창 (이미 구매했으면 바로 통과)
              shrinePay(context, ShrineProduct.tale(id, S.title), () => ShrineNav.go(context, 'tale', params: {'id': id})); },
            child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: id == 'secret' ? const Color(0x73A11D19) : C.line),
                gradient: id == 'secret' ? const LinearGradient(colors: [Color(0xB33C0A08), Color(0xD10E0706)]) : null, color: id == 'secret' ? null : const Color(0xD10E0706)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 84, height: 112, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: C.goldLine)),
                  child: Stack(fit: StackFit.expand, children: [
                    u.$1 ? Image.asset(_img(S.cover), fit: BoxFit.cover) : ColorFiltered(colorFilter: const ColorFilter.matrix([.07,.21,.02,0,0, .07,.21,.02,0,0, .07,.21,.02,0,0, 0,0,0,1,0]), child: Image.asset(_img(S.cover), fit: BoxFit.cover)),
                    if (!u.$1) Center(child: Text('封', style: t.display(30, w: FontWeight.w900, c: C.redHot)))])),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: 112, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(S.en, style: t.mono.copyWith(fontSize: 9, letterSpacing: 1.8)), const SizedBox(height: 4),
                  Text(S.title, style: t.body(16, w: FontWeight.w700, c: u.$1 ? C.fg : C.muted, h: 1.3)),
                  Text(u.$1 ? S.intro : '잠김 — ${u.$2}', maxLines: 2, overflow: TextOverflow.ellipsis, style: t.body(u.$1 ? 12 : 11.5, c: u.$1 ? C.muted : C.redHot, h: 1.5)),
                  const Spacer(),
                  Row(children: [
                    Text('約 ${S.minutes} MIN', style: t.mono.copyWith(letterSpacing: 1)), const SizedBox(width: 8),
                    Container(height: 20, padding: const EdgeInsets.symmetric(horizontal: 8), alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: n > 0 || prog ? C.goldLine : (u.$1 ? const Color(0x80E0412F) : C.line))),
                      child: Text(n > 0 ? '結 $n/${S.endings.length}' : prog ? '이어보기' : u.$1 ? 'OPEN' : 'SEALED', style: t.mono.copyWith(fontSize: 9, letterSpacing: 1.2, color: n > 0 || prog ? C.gold : (u.$1 ? C.redHot : C.faint)))),
                    const Spacer(),
                    Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEFB800), borderRadius: BorderRadius.circular(4)),
                      child: Text((shrine.talismans.types as Map)[S.talis]['sig'], style: t.display(12, w: FontWeight.w900, c: const Color(0xFFC81A10)))),
                  ]),
                ]))),
              ])));
        }),
      ]),
      _top(context, back: () => ShrineNav.canPop(context) ? ShrineNav.pop(context) : ShrineNav.go(context, 'entry')),
    ]));
  }
  Widget _stat(T t, String n, String l, {VoidCallback? onTap}) => Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    decoration: BoxDecoration(color: const Color(0xBF0E0706), borderRadius: BorderRadius.circular(12), border: Border.all(color: onTap != null ? C.goldLine : C.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: t.display(26, w: FontWeight.w900, c: C.gold).copyWith(height: 1)), const SizedBox(height: 6), Text(l, style: t.body(11.5, c: C.muted, h: 1.2))]))));
}

// ═══════════ 첫 사용 안내 (talk · saju · recommend · story 위에 한 번) ═══════════
class CoachOverlay extends StatefulWidget { const CoachOverlay({super.key}); @override State<CoachOverlay> createState() => _CoachState(); }
class _CoachState extends State<CoachOverlay> {
  int i = 0;
  static const steps = [('門', '화면을 누르면 다음으로', '대사는 누르면 바로 끝까지 나옵니다.'), ('選', '선택이 이야기를 바꿉니다', '고른 길은 기록되고, 결말과 부적에 남습니다.'),
    ('符', '부적은 직접 눌러 태웁니다', '다 써지면 부적을 한 번 누르십시오.'), ('持', '받은 부적은 부적함에', '언제든 다시 펼치고 사진첩에 저장할 수 있습니다.')];
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state; if (st.coached) return const SizedBox.shrink();
    final t = T(st.ts); final s = steps[i]; void close() => context.read<ShrineSessionProvider>().update((x) => x.copy(coached: true));
    return Positioned.fill(child: ColoredBox(color: const Color(0x9E000000), child: Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(18), child: Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: C.goldLine),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1D0E0C), Color(0xFF0B0505)])),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 110, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line),
          gradient: const RadialGradient(center: Alignment(0, .2), colors: [Color(0x40A11D19), Color(0xCC0E0706)])), child: Center(child: Text(s.$1, style: t.display(40, w: FontWeight.w900, c: C.redHot)))),
        const SizedBox(height: 8),
        Text('${s.$1} · 처음 오신 분께 ${i + 1}/${steps.length}', style: t.mono.copyWith(color: C.gold)), const SizedBox(height: 4),
        Text(s.$2, style: t.display(19, h: 1.35)), Text(s.$3, style: t.body(13.5, c: C.muted, h: 1.6)), const SizedBox(height: 10),
        Row(children: [TextButton(onPressed: close, child: Text('건너뛰기', style: t.ui(13, c: C.faint))), const Spacer(),
          SizedBox(width: 120, child: RedButton(i < steps.length - 1 ? '다음' : '들어가기', ts: st.ts, onTap: () => i < steps.length - 1 ? setState(() => i++) : close()))]),
      ]))))));
  }
}
