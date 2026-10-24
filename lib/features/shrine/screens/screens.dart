// 10개 화면. 웹 프로토타입(prototype/shrine-screens-a/b.jsx)과 1:1 대응.
// ※ 픽셀·타이밍 기준은 언제나 웹 프로토타입. 이 파일은 구조·로직의 출발점이다.
// [provider+Navigator 1.0 포팅] 원본은 flutter_riverpod(ConsumerWidget/
// WidgetRef)+go_router(context.go)이나, 이 프로젝트는 provider(ChangeNotifier)
// +Navigator 1.0 고정 정책이므로 아래 규칙으로 기계적으로 치환했다(③ 지시
// — 화면 로직·레이아웃·수치는 일절 변경하지 않고 API 호출만 치환).
//  · ConsumerStatefulWidget/ConsumerState → StatefulWidget/State
//  · ConsumerWidget(build(context, ref))  → StatelessWidget(build(context))
//  · ref.watch(shrineProvider)            → context.watch<ShrineSessionProvider>().state
//  · ref.read(shrineProvider)             → context.read<ShrineSessionProvider>().state
//  · ref.read(shrineProvider.notifier)    → context.read<ShrineSessionProvider>()
//  · context.go('$kShrineBase/id')        → ShrineNav.go(context, 'id', params: {...})
//  · context.go(kShrineExit)              → ShrineNav.exit(context)
//  · shrinePay(context, ref, p, onPaid)   → shrinePay(context, p, onPaid)
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../shrine_module.dart' show shrine, ShrineProduct, shrinePay;
import '../data/models.dart';
import '../state/shrine_session_provider.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';
import '../widgets/shrine_nav.dart';
import '../widgets/shrine_video.dart';
import '../widgets/talisman_stage.dart';
import '../widgets/sheets.dart';
import '../widgets/bujeok.dart';
import '../widgets/shrine_fx.dart' show EntryOmen, SignStroke, shrineHaptic, ShrineHapticLevel;
import 'screens_v3.dart' show CoachOverlay;
import '../../../core/sound/sound_route_trigger.dart';

String _img(String n) => 'assets/shrine/img/$n.jpg';
String _art(String n) => 'assets/shrine/art/$n.jpg';

/// 공통 상단바 (소리·설정 연결)
Widget _top(
  BuildContext ctx, {
  VoidCallback? back,
  Widget? center,
  Widget? trailing,
}) {
  final st = ctx.watch<ShrineSessionProvider>().state;
  return Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: TopBar(
      onBack: back,
      center: center,
      trailing: trailing,
      soundOn: st.sound,
      onSound: () => ctx.read<ShrineSessionProvider>().update(
        (s) => s.copy(sound: !s.sound),
      ),
      onSettings: () => showSettingsSheet(ctx),
    ),
  );
}

// ─────────────────────────── 01 메인 입장 ───────────────────────────
class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});
  @override
  State<EntryScreen> createState() => _EntryState();
}

class _EntryState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  // 로고 2.2s → 카피 1.2s 지연 → 보조 1.6s → CTA 2.0s → 하단 링크 2.2s
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward();
  @override
  void initState() {
    super.initState();
    ShrineVideoCache.precache(['door', 'talk']);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _in(double from, Widget c) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) {
      final t = ((_a.value * 3.6 - from) / 1.4).clamp(0.0, 1.0);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      );
    },
  );
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    // [신통방통 사운드 배치 개발 기획서 §5.1] shrine 라우트 BGM(08_shrine_E)
    // 트리거(앰비언스 없음).
    return SoundRouteTrigger(
      routeKey: 'shrine',
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const ShrineVideo(name: 'entry', poster: 'entry'),
            const BottomShade(),
            const RedBreath(),
            Positioned(
              left: 24,
              right: 24,
              bottom: 26,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _a,
                      builder: (_, __) {
                        final p = (_a.value * 3.6 / 2.2 - .14).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: p,
                          child: Transform.scale(
                            scale: 1.12 - .12 * p,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('신당', style: t.logo),
                                Padding(
                                  padding: const EdgeInsets.only(top: 30),
                                  child: Column(
                                    children: '神堂'
                                        .split('')
                                        .map(
                                          (c) => Text(
                                            c,
                                            style: t.display(
                                              17,
                                              w: FontWeight.w900,
                                              c: C.redHot,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _in(
                      1.2,
                      Text(
                        '당신이 여기까지 온 이유…\n나는 알고 있습니다.',
                        textAlign: TextAlign.center,
                        style: t.body(19, w: FontWeight.w700, h: 1.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _in(
                      1.6,
                      Text(
                        '문을 열기 전에, 한 번 더 생각하세요.',
                        style: t.body(13, c: C.faint),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // [U8-3 포팅] 오늘의 일진 한 줄 · 소멸 임박 부적 전갈
                    // (원본 CSS `animation: up 1s ease 1.4s both` 위치 그대로
                    // — sub 문구와 CTA 버튼 사이, 緣起 버튼보다 위).
                    const EntryOmen(),
                    const SizedBox(height: 8),
                    _in(
                      2.0,
                      RedButton(
                        '지금 신당으로 들어가기',
                        ts: st.ts,
                        onTap: () => ShrineNav.go(context, 'door'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // [U5 포팅] 입장 화면 보조 링크 — 緣起(신당 이야기) 수동 진입.
                    _in(
                      2.1,
                      TextButton(
                        onPressed: () {
                          context.read<ShrineSessionProvider>().update(
                            (s) => s.copy(aboutBack: 'entry'),
                          );
                          ShrineNav.go(context, 'about');
                        },
                        child: Text(
                          '緣起  이 신당은 무엇을 하는 곳입니까 ›',
                          style: t.ui(13, c: C.gold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _in(
                      2.2,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => context
                                .read<ShrineSessionProvider>()
                                .update((s) => s.copy(sound: !s.sound)),
                            child: Text(
                              st.sound ? '◉  사운드 끄기' : '◎  사운드 켜기',
                              style: t.ui(13, c: C.muted),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ShrineNav.go(context, 'hall'),
                            child: Text(
                              '▷  영상 건너뛰기',
                              style: t.ui(13, c: C.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 「‹ 신통방통」 작은 필 버튼 → 신통방통 메인 (웹 .ent-home: 높이 24 · 10.5pt · muted · 금 테)
                      GestureDetector(
                        onTap: () => ShrineNav.exit(context),
                        child: Container(
                          height: 24,
                          padding: const EdgeInsets.fromLTRB(7, 0, 9, 0),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x8C080404),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: C.goldLine),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('‹', style: t.ui(12, c: C.gold)),
                              const SizedBox(width: 4),
                              Text('신통방통', style: t.ui(10.5, c: C.muted)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ShrineNav.go(context, 'list'),
                        child: Text(
                          'STORIES ›',
                          style: t.mono.copyWith(color: C.gold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── 02 문 열림 ───────────────────────────
class DoorScreen extends StatefulWidget {
  const DoorScreen({super.key});
  @override
  State<DoorScreen> createState() => _DoorState();
}

class _DoorState extends State<DoorScreen> {
  bool _out = false;
  void _done() {
    if (_out || !mounted) return;
    setState(() => _out = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) ShrineNav.go(context, 'hall');
    });
  }

  @override
  void initState() {
    super.initState();
    if (context.read<ShrineSessionProvider>().state.reduce)
      Future.delayed(
        const Duration(milliseconds: 400),
        () => mounted ? ShrineNav.go(context, 'hall') : null,
      );
    // 사운드: 0s 저음 → 0.9s 문 → 3.6s 방울 (ShrineSound 연결)
  }

  @override
  Widget build(BuildContext context) {
    final t = T(context.watch<ShrineSessionProvider>().state.ts);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          ShrineVideo(name: 'door', poster: 'door', loop: false, onEnd: _done),
          const Embers(count: 12),
          Positioned(
            left: 0,
            right: 0,
            bottom: 64,
            child: Text(
              '문 너머에서, 무언가 숨을 고릅니다.',
              textAlign: TextAlign.center,
              style: t.body(14, c: C.muted),
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _out ? 1 : 0,
              duration: const Duration(milliseconds: 700),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x80E0412F), C.bg],
                    stops: [0, .7],
                  ),
                ),
              ),
            ),
          ),
          _top(context, trailing: _skip(() => ShrineNav.go(context, 'hall'))),
        ],
      ),
    );
  }
}

Widget _skip(VoidCallback f) => GestureDetector(
  onTap: f,
  child: Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0x80080404),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: C.goldLine),
    ),
    child: Text(
      'SKIP ›',
      style: T(1).mono.copyWith(color: C.muted, letterSpacing: 2.5),
    ),
  ),
);

// ─────────────────────────── 03 신당 내부 ───────────────────────────
class HallScreen extends StatefulWidget {
  const HallScreen({super.key});
  @override
  State<HallScreen> createState() => _HallState();
}

class _HallState extends State<HallScreen> {
  bool _done = false;

  /// 「제단 앞으로 다가가기」 → 신통방통 결제창 (이미 이용권 있으면 바로 통과)
  /// [U5 포팅] 첫 방문(aboutSeen == false)이면 緣起(AboutScreen)를 먼저 보여주고,
  /// 다 보면 aboutBack 라우트(talk/connect)로 이어간다 — 원본 U5-1 "진입 ① 첫 방문 시" 반영.
  void _enter() => shrinePay(context, ShrineProduct.entry, () {
    final provider = context.read<ShrineSessionProvider>();
    final dest = provider.state.name != null ? 'talk' : 'connect';
    if (!provider.state.aboutSeen) {
      provider.update((s) => s.copy(aboutBack: dest));
      ShrineNav.go(context, 'about');
    } else {
      ShrineNav.go(context, dest);
    }
  });
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    return Scaffold(
      body: GestureDetector(
        onTap: () => _done ? _enter() : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 켄번스 28s (scale 1.04 → 1.14) — KenBurns 위젯으로 감싸 구현
            Image.asset(
              _img('hall'),
              fit: BoxFit.cover,
              alignment: const Alignment(0, -.1),
            ),
            const BottomShade(
              stops: [0, .18, .42, .66, .82],
              colors: [
                Color(0x59070404),
                Colors.transparent,
                Colors.transparent,
                Color(0xDB070404),
                C.bg,
              ],
            ),
            const Embers(count: 12),
            if (_done)
              const Align(alignment: Alignment(0, -.12), child: TapPulse()),
            Positioned(
              left: 22,
              right: 22,
              bottom: 150,
              child: Column(
                children: [
                  Text('月華 · 신당의 주인', style: t.mono),
                  const SizedBox(height: 12),
                  Typewriter(
                    '신당의 주인이\n당신을 기다리고 있었습니다.',
                    msPerChar: st.reduce ? 0 : Dur.typeEntry,
                    align: TextAlign.center,
                    style: t.display(21),
                    onDone: () => setState(() => _done = true),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 44,
              child: AnimatedOpacity(
                opacity: _done ? 1 : 0,
                duration: const Duration(seconds: 1),
                child: RedButton('제단 앞으로 다가가기', ts: st.ts, onTap: _enter),
              ),
            ),
            _top(context, back: () => ShrineNav.go(context, 'entry')),
          ],
        ),
      ),
    );
  }
}

/// 탭 유도 원 — 14px 점 + 90px 링 2.2s 확산 ×2
class TapPulse extends StatefulWidget {
  const TapPulse({super.key});
  @override
  State<TapPulse> createState() => _TapPulseState();
}

class _TapPulseState extends State<TapPulse>
    with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Widget _ring(double off) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) {
      final p = (_a.value + off) % 1;
      return Opacity(
        opacity: 1 - p,
        child: Transform.scale(
          scale: .3 + 1.1 * p,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xB3FFDCB4)),
            ),
          ),
        ),
      );
    },
  );
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(0),
          _ring(.5),
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF3DC),
              boxShadow: [
                BoxShadow(
                  color: Color(0xB3FFC88C),
                  blurRadius: 18,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────── 04 월화와 대화 ───────────────────────────
class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key});
  @override
  State<TalkScreen> createState() => _TalkState();
}

class _TalkState extends State<TalkScreen> {
  int step = 0;
  String? pick;
  bool done = false;
  final _tw = GlobalKey<TypewriterState>();
  @override
  void initState() {
    super.initState();
    ShrineVideoCache.precache(['write', 'burn']);
  }

  void _next([String? v]) {
    if (v != null) pick = v;
    setState(() {
      step++;
      done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    // v3: 이름 부르며 환영. 실제 기록이 있을 때만 재방문 대사
    final last = st.box.isEmpty ? null : st.box.last;
    final text = [
      st.visited
          ? '다시 오셨군요, ${st.name}님.${last != null ? '\n\n지난번에 가져가신 ${last.spec.name}는\n잘 간직하고 계십니까.' : ''}'
          : '오셨군요, ${st.name}님.\n\n오늘은 어떤 이야기가\n당신을 기다리고 있을까요.',
      '천천히 살펴보십시오.\n어떤 길을 걸을지는\n당신이 정하는 것입니다.\n\n먼저, 태어난 날의 기운부터\n펼쳐 보겠습니다.',
    ][step];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ShrineVideo(name: 'talk', poster: 'talk'),
          const BottomShade(
            stops: [0, .16, .38, .58, 1],
            colors: [
              Color(0x66070404),
              Colors.transparent,
              Colors.transparent,
              Color(0xD1070404),
              Color(0xF2070404),
            ],
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 26,
            child: SafeArea(
              top: false,
              child: GestureDetector(
                onTap: () => _tw.currentState?.finish(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpeakerBadge('월화', hanja: '月華'),
                    const SizedBox(height: 12),
                    // 규칙: 대사가 끝나야 선택지가 뜬다
                    Typewriter(
                      text,
                      key: _tw,
                      msPerChar: st.reduce ? 0 : Dur.typeTalk,
                      style: t.body(19, w: FontWeight.w700, h: 1.6),
                      onDone: () => setState(() => done = true),
                    ),
                    const SizedBox(height: 18),
                    if (done && step == 0) ...[
                      Pill(
                        st.visited ? '네, 다시 왔습니다' : '…저를 아세요?',
                        ts: st.ts,
                        onTap: () => _next('q'),
                      ),
                      const SizedBox(height: 10),
                      Pill(
                        '(조심스럽게 앞에 앉는다)',
                        ts: st.ts,
                        onTap: () => _next('s'),
                      ),
                    ],
                    if (done && step == 1)
                      RedButton(
                        '나의 정통사주 펼치기',
                        ts: st.ts,
                        onTap: () => ShrineNav.go(context, 'saju'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _top(
            context,
            back: () => step > 0
                ? setState(() {
                    step--;
                    done = false;
                  })
                : ShrineNav.go(context, 'hall'),
          ),
          const CoachOverlay(),
        ],
      ),
    );
  }
}

// ─────────────────────────── 05 정보 입력 ───────────────────────────
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});
  @override
  State<InfoScreen> createState() => _InfoState();
}

class _InfoState extends State<InfoScreen> {
  int q = 0;
  late final name = TextEditingController(
    text: context.read<ShrineSessionProvider>().state.name ?? '',
  );
  late final birth = TextEditingController(
    text: context.read<ShrineSessionProvider>().state.birth ?? '',
  );
  String time = '';
  bool get validBirth {
    final b = birth.text;
    if (!RegExp(r'^\d{4}\.\d{2}\.\d{2}$').hasMatch(b)) return false;
    final m = int.parse(b.substring(5, 7)), d = int.parse(b.substring(8));
    return m >= 1 && m <= 12 && d >= 1 && d <= 31;
  }

  bool get ok => [name.text.trim().isNotEmpty, validBirth, true][q];
  void _submit() {
    if (!ok) return;
    if (q < 2) {
      setState(() => q++);
      return;
    }
    context.read<ShrineSessionProvider>().update(
      (s) => s.copy(
        name: name.text.trim(),
        birth: birth.text,
        time: time.isEmpty ? '모름' : time,
        season: seasonOf(int.parse(birth.text.substring(5, 7))),
        visits: s.visits + 1,
      ),
    );
    ShrineNav.go(context, 'saju');
  }

  String _fmt(String v) {
    final n = v.replaceAll(RegExp(r'\D'), '');
    final s = n.length > 8 ? n.substring(0, 8) : n;
    return [
      if (s.isNotEmpty) s.substring(0, s.length.clamp(0, 4)),
      if (s.length > 4) s.substring(4, s.length.clamp(4, 6)),
      if (s.length > 6) s.substring(6),
    ].join('.');
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final asks = [
      ('名 · NAME', '이름이 무엇입니까?', '부적에 직접 적어 드립니다.'),
      ('生 · BIRTH', '태어난 날을\n알려 주십시오.', '양력 기준'),
      ('時 · TIME', '태어난 시간은요?', '모르셔도 괜찮습니다.'),
    ];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 배경: 대화 영상을 blur(14) brightness(.55) scale(1.12) 로 밀어낸다
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Transform.scale(
              scale: 1.12,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  .55,
                  0,
                  0,
                  0,
                  0,
                  0,
                  .55,
                  0,
                  0,
                  0,
                  0,
                  0,
                  .55,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Image.asset(_img('talk'), fit: BoxFit.cover),
              ),
            ),
          ),
          const BottomShade(
            stops: [0, .4, .7],
            colors: [Color(0x80070404), Color(0x4D070404), Color(0xE6070404)],
          ),
          // 명부(名簿) — 입력하는 즉시 붓글씨로 적힌다
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Center(
              child: Ledger(
                name: name.text,
                birth: birth.text,
                time: time,
                sig: shrine.topic(st.topic).sig,
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 40,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(asks[q].$1, style: t.mono), const SizedBox(height: 10),
                  Text(asks[q].$2, style: t.display(26)),
                  const SizedBox(height: 6),
                  Text(asks[q].$3, style: t.body(13, c: C.muted)),
                  const SizedBox(height: 22),
                  // 밑줄형 입력 — 박스형은 '설문', 밑줄형은 '한지에 적기'
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x59EFE4D2)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: q == 2
                              ? GestureDetector(
                                  onTap: () async {
                                    final r = await showTimePicker(
                                      context: context,
                                      initialTime: const TimeOfDay(
                                        hour: 12,
                                        minute: 0,
                                      ),
                                    );
                                    if (r != null)
                                      setState(
                                        () => time =
                                            '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}',
                                      );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      time.isEmpty ? '--:--' : time,
                                      style: t.body(22),
                                    ),
                                  ),
                                )
                              : TextField(
                                  autofocus: true,
                                  controller: q == 0 ? name : birth,
                                  maxLength: q == 0 ? 6 : 10,
                                  keyboardType: q == 1
                                      ? TextInputType.number
                                      : TextInputType.name,
                                  style: t.body(22),
                                  onChanged: (v) {
                                    if (q == 1) {
                                      final f = _fmt(v);
                                      birth.value = TextEditingValue(
                                        text: f,
                                        selection: TextSelection.collapsed(
                                          offset: f.length,
                                        ),
                                      );
                                    }
                                    setState(() {});
                                  },
                                  onSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    counterText: '',
                                    hintText: q == 0 ? '홍길동' : '1995.08.14',
                                    hintStyle: t.body(
                                      22,
                                      c: const Color(0x47EFE4D2),
                                    ),
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: _submit,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ok
                                  ? const Color(0xFFF4EBDE)
                                  : const Color(0x24EFE4D2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '확인',
                              style: t.ui(
                                13,
                                w: FontWeight.w600,
                                c: ok ? const Color(0xFF1A0E0A) : C.faint,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (q == 2) ...[
                    const SizedBox(height: 10),
                    Pill(
                      '시간은 모릅니다',
                      ts: st.ts,
                      onTap: () {
                        time = '모름';
                        _submit();
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '적은 정보는 이 기기 밖으로 나가지 않습니다.',
                    style: t.ui(11, c: C.faint),
                  ),
                ],
              ),
            ),
          ),
          _top(
            context,
            back: () => q > 0
                ? setState(() => q--)
                : ShrineNav.go(
                    context,
                    context.read<ShrineSessionProvider>().state.name != null
                        ? 'talk'
                        : 'connect',
                  ),
          ),
        ],
      ),
    );
  }
}

/// 명부 카드 — 150px 한지, -1.5°
class Ledger extends StatelessWidget {
  final String name, birth, time, sig;
  const Ledger({
    super.key,
    required this.name,
    required this.birth,
    required this.time,
    required this.sig,
  });
  @override
  Widget build(BuildContext context) {
    final t = T(1);
    return Transform.rotate(
      angle: -0.026,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 150,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [C.hanjiTop, Color(0xFFDCC697)],
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 50,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '名簿 · 神堂',
                  style: t.mono.copyWith(
                    color: const Color(0x995A2814),
                    letterSpacing: 2.5,
                  ),
                ),
                SizedBox(
                  height: 112,
                  child: Center(
                    child: name.isEmpty
                        ? Text(
                            '이름',
                            style: t.body(13, c: const Color(0x595A2814)),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: name
                                .split('')
                                .map(
                                  (c) => Text(
                                    c,
                                    style: t.brushName.copyWith(fontSize: 44),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
                _row(
                  '生',
                  birth.length == 10
                      ? hanjaDate(birth)
                      : (birth.isEmpty ? '—' : birth),
                ),
                _row('時', time.isEmpty ? '—' : (time == '모름' ? '未詳' : time)),
              ],
            ),
          ),
          Positioned(
            right: -12,
            bottom: -12,
            child: Transform.rotate(
              angle: .14,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.red,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: Glow.red(18),
                ),
                child: Text(
                  sig,
                  style: t.display(16, w: FontWeight.w900, c: C.btnText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.only(top: 6),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0x4D5A3214))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          k,
          style: T(
            1,
          ).mono.copyWith(color: const Color(0x995A2814), letterSpacing: 1),
        ),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: T(1).display(11, c: const Color(0xFF5A2A14)),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────── 06 부적 의식 ───────────────────────────
enum Ph { write, paper, burn, reveal, read }

class RitualScreen extends StatefulWidget {
  const RitualScreen({super.key});
  @override
  State<RitualScreen> createState() => _RitualState();
}

class _RitualState extends State<RitualScreen> with TickerProviderStateMixin {
  Ph ph = Ph.write;
  double burnT = 0;
  int an = 0;
  late AnimationController ink, burn;
  Timer? _an;
  // [U8-1 포팅] 붓이 쓰는 지점(nameAt, 0~1)까지만 자동 진행하고 마지막
  // 이름 부분은 손가락으로 긋게 한다 — 원본 `nameAt = name ? (steps-1.5)/
  // steps : 1`. 이름이 없으면 nameAt=1(서명 단계 자체가 없음).
  late final double nameAt;
  bool signing = false;
  @override
  void initState() {
    super.initState();
    final st = context.read<ShrineSessionProvider>().state;
    final name = st.name ?? '';
    final n = name.length + 3;
    ink = AnimationController(vsync: this, duration: Dur.brushPerChar * n);
    final spec = st.pending!.spec;
    final steps = bjCompose(
      type: spec.type,
      phrase: spec.phrase,
      key: spec.key,
      flavor: spec.flavor,
      story: spec.story,
      ending: spec.ending,
      element: spec.element,
      base: spec.base,
      motif: spec.motif,
      name: name,
    ).steps;
    nameAt = name.isNotEmpty ? (steps - 1.5) / steps : 1;
    burn =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 6200),
          )
          ..addListener(() => setState(() => burnT = burn.value))
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed)
              Future.delayed(
                const Duration(milliseconds: 600),
                () => mounted && ph == Ph.burn ? _go(Ph.reveal) : null,
              );
          });
    ShrineVideoCache.precache(['climax']);
  }

  @override
  void dispose() {
    ink.dispose();
    burn.dispose();
    _an?.cancel();
    super.dispose();
  }

  void _go(Ph p) {
    setState(() => ph = p);
    final reduce = context.read<ShrineSessionProvider>().state.reduce;
    if (p == Ph.paper) {
      if (reduce) {
        // 원본: `if (app.reduce) { setInk(1); return; }` — 움직임 줄이기면
        // 이름이 있어도 서명 단계 자체를 건너뛰고 바로 완성 상태로 간다.
        ink.value = 1;
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          // animateTo(nameAt)는 duration(전체 0→1 소요시간)에 nameAt 비율을
          // 곱한 시간만큼만 재생한다 — 원본 `dur = 900*(len+3)*nameAt`와
          // 동일한 결과(같은 속도로 nameAt에서 멈춤).
          ink.animateTo(nameAt).then((_) {
            if (!mounted || ph != Ph.paper) return;
            if (nameAt < 1) {
              setState(() => signing = true);
              shrineHaptic(context, ShrineHapticLevel.mid);
            }
          });
        });
      }
    }
    // ⚠ 태우기는 영상 진행률과 분리된 고정 6.2s 타이머 (영상이 늦어도 반드시 끝까지 탐) + 안전 9s
    if (p == Ph.burn) {
      burn.forward(from: 0);
      Future.delayed(
        const Duration(seconds: 9),
        () => mounted && ph == Ph.burn ? _go(Ph.reveal) : null,
      );
    }
    if (p == Ph.reveal)
      Future.delayed(
        Duration(milliseconds: reduce ? 1000 : 3800),
        () => mounted ? _go(Ph.read) : null,
      );
    if (p == Ph.read) {
      _an = Timer.periodic(Duration(milliseconds: reduce ? 300 : 1000), (tm) {
        setState(() => an++);
        if (an >= shrine.analysis.length) {
          tm.cancel();
          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;
            ShrineNav.go(context, 'receive');
          });
        } // v3: 태운 그 부적을 선물로
      });
    }
  }

  // 웹과 동일: burnLine = clamp((t − .05) / .9)
  double get burnLine => ((burnT - .05) / .9).clamp(0.0, 1.0);

  // [U8-1] SignStroke onProgress — 원본 `v => setInk(nameAt + (1-nameAt)*v)`.
  void _onSignProgress(double v) {
    ink.value = nameAt + (1 - nameAt) * v;
  }

  // [U8-1] SignStroke onDone / 「대신 써 주십시오」 건너뛰기 — 둘 다 원본처럼
  // signing을 끄고 ink를 1로 고정한다.
  void _finishSigning() {
    setState(() => signing = false);
    ink.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final topic = shrine.topic(st.topic);
    final spec = st.pending!.spec; // /meaning 에서 구성된 부적 — /receive 도 같은 것
    final stepIdx = {
      Ph.write: 0,
      Ph.paper: 0,
      Ph.burn: 1,
      Ph.reveal: 2,
      Ph.read: 3,
    }[ph]!;
    final dim = ph == Ph.reveal || ph == Ph.read;
    Widget bg = switch (ph) {
      Ph.write => ShrineVideo(
        name: 'write',
        poster: 'write',
        loop: false,
        onEnd: () => _go(Ph.paper),
      ),
      Ph.paper => Image.asset(_img('paper'), fit: BoxFit.cover),
      _ => ShrineVideo(
        name: 'burn',
        poster: 'paper',
        loop: false,
      ), // 배경 분위기만 — 진행은 burn 타이머
    };
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: dim ? .35 : 1,
            duration: const Duration(milliseconds: 1400),
            child: TalismanStage(
              background: bg,
              overlay: (ph == Ph.paper || ph == Ph.burn)
                  ? AnimatedBuilder(
                      animation: ink,
                      builder: (_, __) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () => (ph == Ph.paper && ink.value >= 1)
                                ? _go(Ph.burn)
                                : null,
                            // 노란 종이 + 초서 (bujeokLayout) — 타는 동안 아래부터 마스크
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (r) => LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: const [
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black,
                                  Colors.black,
                                ],
                                stops: [
                                  0,
                                  ph == Ph.burn ? burnLine : 0,
                                  ((ph == Ph.burn ? burnLine : 0) + .04).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  1,
                                ],
                              ).createShader(r),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xF2F6C300),
                                          Color(0xF2ECB000),
                                        ],
                                      ),
                                    ),
                                  ),
                                  BujeokInk(
                                    name: st.name ?? '',
                                    spec: spec,
                                    ink: ink.value,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // [U8-1] 서명 자리 — 원본 CSS `.signzone` 좌표
                          // (right:4%·top:70%·width:18%·height:26%, .paperzone
                          // = 이 overlay 영역 자체가 기준 박스).
                          if (ph == Ph.paper && signing && ink.value < 1)
                            LayoutBuilder(
                              builder: (context, c) => Positioned(
                                right: c.maxWidth * .04,
                                top: c.maxHeight * .70,
                                width: c.maxWidth * .18,
                                height: c.maxHeight * .26,
                                child: SignStroke(
                                  onProgress: _onSignProgress,
                                  onDone: () {
                                    setState(() => signing = false);
                                    ink.value = 1;
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(),
            ),
          ),
          const BottomShade(
            stops: [0, .22, .7, 1],
            colors: [
              Color(0x8C070404),
              Colors.transparent,
              Colors.transparent,
              Color(0xE6070404),
            ],
          ),
          if (ph == Ph.burn || ph == Ph.reveal) const Embers(count: 26),
          // 좌상단 4단계: 筆 → 符 → 示 → 讀 (현재 금빛 글로우, 지난 단계 검붉은 채움)
          Positioned(
            left: 18,
            top: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < shrine.ritual.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < stepIdx
                                ? C.red
                                : const Color(0x99080404),
                            border: Border.all(
                              color: i == stepIdx
                                  ? C.gold
                                  : (i < stepIdx
                                        ? const Color(0x99D6AA64)
                                        : C.line),
                            ),
                            boxShadow: i == stepIdx ? Glow.gold() : null,
                          ),
                          child: Text(
                            shrine.ritual[i]['sig'],
                            style: t.display(
                              13,
                              w: FontWeight.w900,
                              c: i == stepIdx
                                  ? C.gold
                                  : (i < stepIdx ? C.btnText : C.faint),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Text(
                          shrine.ritual[i]['label'],
                          style: t.ui(13, c: i == stepIdx ? C.fg : C.faint),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: SafeArea(
              top: false,
              child: switch (ph) {
                Ph.write => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpeakerBadge('월화', hanja: '月華'),
                    const SizedBox(height: 10),
                    Text(
                      '${st.name}… ${st.name}.\n이름을 적겠습니다.',
                      style: t.body(19, w: FontWeight.w700, h: 1.6),
                    ),
                  ],
                ),
                Ph.paper => AnimatedBuilder(
                  animation: ink,
                  builder: (_, __) => ink.value < 1
                      ? (signing
                            // [U8-1] 서명 단계 안내 — 원본
                            // `signing && ink<1` 분기(shrine-screens-a.jsx
                            // 287행 캡션). 「대신 써 주십시오」로 건너뛰기.
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SpeakerBadge('월화', hanja: '月華'),
                                  const SizedBox(height: 10),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(text: '마지막 한 획은\n'),
                                        TextSpan(
                                          text: '손수 그으십시오.',
                                          style: TextStyle(
                                            color: C.gold,
                                            shadows: Glow.gold()
                                                .map(
                                                  (b) => Shadow(
                                                    color: b.color,
                                                    blurRadius: b.blurRadius,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    style: t.body(19, w: FontWeight.w700, h: 1.6),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '오른쪽 아래 금빛 줄을 위에서 아래로 따라 그으세요',
                                    style: t.mono.copyWith(color: C.gold),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      alignment: Alignment.centerLeft,
                                    ),
                                    onPressed: _finishSigning,
                                    child: Text(
                                      '대신 써 주십시오',
                                      style: t.ui(12, c: C.faint).copyWith(
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                '붓이 이름을 따라갑니다',
                                textAlign: TextAlign.center,
                                style: t.mono.copyWith(color: C.gold),
                              ))
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: '다 되었습니다.\n'),
                                  TextSpan(
                                    text: '부적을 누르십시오.',
                                    style: TextStyle(
                                      color: C.redHot,
                                      shadows: Glow.red(20)
                                          .map(
                                            (b) => Shadow(
                                              color: b.color,
                                              blurRadius: b.blurRadius,
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: t.body(19, w: FontWeight.w700, h: 1.6),
                            ),
                            const SizedBox(height: 12),
                            const TapPulse(),
                          ],
                        ),
                ),
                Ph.burn => Text(
                  '불이 이름을 삼킵니다…',
                  textAlign: TextAlign.center,
                  style: t.body(19, w: FontWeight.w700, c: C.muted),
                ),
                Ph.reveal => Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 먹번짐: blur 20 + scale 1.4 + 자간 .4em → 0 (2.4s)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Dur.reveal,
                        curve: const Cubic(.2, .7, .2, 1),
                        builder: (_, p, __) => ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: 20 * (1 - p),
                            sigmaY: 20 * (1 - p),
                          ),
                          child: Transform.scale(
                            scale: 1.4 - .4 * p,
                            child: Opacity(
                              opacity: p,
                              child: Text(
                                spec.sig,
                                style: t.display(
                                  150,
                                  w: FontWeight.w900,
                                  c: C.redHot,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        spec.phrase.characters.join(' '),
                        style: t
                            .display(22, w: FontWeight.w900, c: C.gold)
                            .copyWith(letterSpacing: 11),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${spec.phraseMeaning}.\n${topic.reveal}',
                        textAlign: TextAlign.center,
                        style: t.body(16, h: 1.8),
                      ),
                    ],
                  ),
                ),
                Ph.read => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('재의 모양을\n읽고 있습니다', style: t.display(22)),
                    const SizedBox(height: 18),
                    for (var i = 0; i < shrine.analysis.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Transform.rotate(
                              angle: .785,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                width: 8,
                                height: 8,
                                color: i < an
                                    ? (i == shrine.analysis.length - 1
                                          ? C.redHot
                                          : C.gold)
                                    : const Color(0x26EFE4D2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              shrine.fill(
                                shrine.analysis[i],
                                name: st.name,
                                season: st.season,
                                topicId: st.topic,
                              ),
                              style: t.body(14, c: i < an ? C.fg : C.faint),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              },
            ),
          ),
          _top(
            context,
            back: () => ShrineNav.go(context, 'meaning'),
            trailing: ph == Ph.write ? _skip(() => _go(Ph.paper)) : null,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── 07 스토리 ───────────────────────────
const _sceneVideo = {'talk': 'talk', 'doorv': 'door', 'climax': 'climax'};
const _flash = {'mem1', 'mem2'};

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});
  @override
  State<StoryScreen> createState() => _StoryState();
}

class _StoryState extends State<StoryScreen> {
  late StoryPos pos;
  bool typed = false;
  String? picked;
  int? left;
  Timer? _timer;
  String? chap;
  final _tw = GlobalKey<TypewriterState>();
  @override
  void initState() {
    super.initState();
    final saved = context.read<ShrineSessionProvider>().state.pos;
    pos = (saved != null && shrine.nodes.containsKey(saved.node))
        ? saved
        : StoryPos(shrine.start, 0, {}, []);
    _enterNode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  StoryNode get node => shrine.nodes[pos.node]!;
  Line get line => node.lines[pos.line];
  bool get atEnd => pos.line >= node.lines.length - 1;
  void _save() =>
      context.read<ShrineSessionProvider>().update((s) => s.copy(pos: pos));
  void _enterNode() {
    if (node.chapter != null && pos.line == 0) {
      chap = node.chapter;
      Future.delayed(
        context.read<ShrineSessionProvider>().state.reduce
            ? const Duration(milliseconds: 600)
            : Dur.chapter,
        () {
          if (mounted) setState(() => chap = null);
        },
      );
    }
  }

  void _onTyped() {
    setState(() => typed = true);
    if (node.climax &&
        atEnd &&
        context.read<ShrineSessionProvider>().state.timer) {
      left = node.timer;
      _timer = Timer.periodic(const Duration(seconds: 1), (tm) {
        setState(() => left = left! - 1);
        if (left! <= 0) {
          tm.cancel();
          _choose(
            Choice.fromJson({
              'label': node.timeoutLabel,
              'flag': node.timeoutFlag,
            }),
            timeout: true,
          );
        }
      });
    }
  }

  void _advance() {
    if (!typed) {
      _tw.currentState?.finish();
      return;
    }
    if (!atEnd)
      setState(() {
        pos = StoryPos(pos.node, pos.line + 1, pos.flags, pos.path);
        typed = false;
        _save();
      });
  }

  void _choose(Choice c, {bool timeout = false}) {
    if (picked != null) return;
    _timer?.cancel();
    setState(() => picked = c.label);
    final flags = {...pos.flags, ...node.set, if (c.flag != null) c.flag!};
    final path = [...pos.path, PathStep(c.label, timeout: timeout)];
    final reduce = context.read<ShrineSessionProvider>().state.reduce;
    Future.delayed(
      Duration(milliseconds: reduce ? 150 : (node.cards ? 1300 : 700)),
      () {
        if (!mounted) return;
        if (c.next != null) {
          setState(() {
            pos = StoryPos(c.next!, 0, flags, path);
            picked = null;
            typed = false;
            left = null;
            _save();
            _enterNode();
          });
        } else {
          final code = shrine.judge(flags); // 선택 기록으로 결말 판정
          context.read<ShrineSessionProvider>().finish(code, path, flags);
          ShrineNav.go(context, 'end', params: {'code': code});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final art = line.art ?? node.art;
    final flash = _flash.contains(art);
    final text = shrine.fill(
      line.text,
      name: st.name,
      season: st.season,
      topicId: st.topic,
    );
    final cardsMode = node.cards && atEnd && typed;
    final total = shrine.nodes.values
        .map((n) => n.step)
        .reduce((a, b) => a > b ? a : b);
    const hnum = ['壹', '貳', '參'];

    Widget scene = _sceneVideo.containsKey(art)
        ? ShrineVideo(
            key: ValueKey(art),
            name: _sceneVideo[art]!,
            poster: art == 'climax' ? 'end-a' : _sceneVideo[art]!,
            loop: art != 'doorv',
          )
        : Image.asset(
            _img(art),
            key: ValueKey(art),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
    if (flash) {
      // 회상: sepia(.55) saturate(.8) contrast(1.05) brightness(.92)
      scene = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .62,
          .48,
          .12,
          0,
          0,
          .25,
          .68,
          .1,
          0,
          0,
          .19,
          .37,
          .36,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: scene,
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(duration: Dur.crossfade, child: scene),
          const BottomShade(
            stops: [0, .16, .44, .66, 1],
            colors: [
              Color(0x8C070404),
              Colors.transparent,
              Colors.transparent,
              Color(0xC7070404),
              Color(0xF5070404),
            ],
          ),
          if (node.climax) const RedBreath(),
          // 레터박스: 회상·클라이맥스 상단 7%, 클라이맥스 하단 4%
          Align(
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1200),
              curve: const Cubic(.6, 0, .2, 1),
              height:
                  MediaQuery.of(context).size.height *
                  ((node.climax || flash) ? .07 : 0),
              color: Colors.black,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 1200),
              height:
                  MediaQuery.of(context).size.height * (node.climax ? .04 : 0),
              color: Colors.black,
            ),
          ),
          if (flash)
            Positioned(
              top: MediaQuery.of(context).size.height * .15,
              left: 0,
              right: 0,
              child: Text(
                '回想 · MEMORY',
                textAlign: TextAlign.center,
                style: t.mono.copyWith(color: const Color(0xB3EFD2AA)),
              ),
            ),
          node.climax ? const SizedBox() : const Embers(count: 8),

          Positioned(
            left: 14,
            right: 14,
            bottom: 22,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!cardsMode)
                    GestureDetector(
                      onTap: _advance,
                      child: _DialogPanel(
                        who: line.who,
                        child: Typewriter(
                          (line.who == 'voice' ? '“' : '') +
                              text +
                              (line.who == 'voice' ? '”' : ''),
                          key: _tw,
                          msPerChar: st.reduce ? 0 : Dur.typeStory,
                          onDone: _onTyped,
                          style: t.body(
                            16.5,
                            h: 1.75,
                            c: line.who == 'narr'
                                ? const Color(0xC7EFE4D2)
                                : line.who == 'voice'
                                ? const Color(0xFFF0C9BF)
                                : C.fg,
                          ),
                        ),
                        showNext: typed && !atEnd,
                      ),
                    ),
                  if (cardsMode) ...[
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: t.body(17, w: FontWeight.w700, h: 1.6),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final c in node.choices)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              child: _TarotCard(
                                choice: c,
                                state: picked == null
                                    ? 0
                                    : (picked == c.label ? 1 : -1),
                                onTap: () => _choose(c),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('한 장을 고르세요', style: t.mono),
                  ],
                  if (typed && atEnd && node.climax && left != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _Incense(left: left!, total: node.timer!),
                    ),
                  if (typed && atEnd && !node.cards) ...[
                    const SizedBox(height: 10),
                    for (var i = 0; i < node.choices.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => _choose(node.choices[i]),
                          child: AnimatedOpacity(
                            opacity:
                                picked != null &&
                                    picked != node.choices[i].label
                                ? .3
                                : 1,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                16,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: picked == node.choices[i].label
                                    ? const Color(0xD95A0E0C)
                                    : const Color(0xB80A0505),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: picked == node.choices[i].label
                                      ? C.redHot
                                      : C.goldLine,
                                ),
                                boxShadow: picked == node.choices[i].label
                                    ? Glow.red(24)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: C.goldDim),
                                    ),
                                    child: Text(
                                      hnum[i],
                                      style: t.display(
                                        11,
                                        w: FontWeight.w900,
                                        c: C.gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      node.choices[i].label,
                                      style: t.body(
                                        14.5,
                                        w: FontWeight.w700,
                                        h: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          _top(
            context,
            back: () => ShrineNav.go(context, 'recommend'),
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${shrine.title} · ${shrine.en}',
                  style: t.mono.copyWith(color: C.muted),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 1; i <= total; i++)
                      Container(
                        width: 16,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: i < node.step
                              ? C.gold
                              : i == node.step
                              ? (node.climax ? C.redHot : C.gold)
                              : const Color(0x29EFE4D2),
                          boxShadow: i == node.step && node.climax
                              ? Glow.red(6)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // 챕터 카드 2.6s
          if (chap != null)
            IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Dur.chapter,
                builder: (_, p, __) => Opacity(
                  opacity: p < .15
                      ? p / .15
                      : p > .7
                      ? (1 - p) / .3
                      : 1,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        radius: .7,
                        colors: [Color(0x8C070404), Color(0xEB070404)],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('CHAPTER', style: t.mono),
                          const SizedBox(height: 12),
                          Text(
                            chap!.split(' · ')[0],
                            style: t
                                .display(64, w: FontWeight.w900, c: C.redHot)
                                .copyWith(
                                  letterSpacing: 6.4,
                                  shadows: const [
                                    Shadow(color: C.redGlow, blurRadius: 40),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            chap!.split(' · ')[1],
                            style: t
                                .body(20, w: FontWeight.w700)
                                .copyWith(letterSpacing: 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DialogPanel extends StatelessWidget {
  final String who;
  final Widget child;
  final bool showNext;
  const _DialogPanel({
    required this.who,
    required this.child,
    required this.showNext,
  });
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xC7100807), Color(0xE00A0505)],
          ),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(4),
            bottom: Radius.circular(12),
          ),
          border: Border(top: BorderSide(color: Color(0x73C9A368))),
        ),
        child: child,
      ),
      if (who == 'wolhwa')
        const Positioned(
          top: -12,
          left: 14,
          child: SpeakerBadge('월화', hanja: '月華'),
        ),
      if (who == 'voice')
        const Positioned(
          top: -12,
          left: 14,
          child: SpeakerBadge('목소리', voice: true),
        ),
      if (showNext)
        Positioned(
          right: 14,
          bottom: 8,
          child: Text(
            'NEXT ▾',
            style: T(1).mono.copyWith(fontSize: 9, color: C.gold),
          ),
        ),
    ],
  );
}

/// 한지 분기 카드 — 딜링(회전) → 선택 시 −14px·1.04 / 나머지 회색·가라앉음
class _TarotCard extends StatelessWidget {
  final Choice choice;
  final int state;
  final VoidCallback onTap;
  const _TarotCard({
    required this.choice,
    required this.state,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: const Cubic(.3, 1.2, .4, 1),
      transform:
          Matrix4.translationValues(
            0,
            state == 1
                ? -14
                : state == -1
                ? 20
                : 0,
            0,
          )..scale(
            state == 1
                ? 1.04
                : state == -1
                ? .92
                : 1.0,
          ),
      child: AnimatedOpacity(
        opacity: state == -1 ? .2 : 1,
        duration: const Duration(milliseconds: 600),
        child: AspectRatio(
          aspectRatio: 3 / 4.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: hanjiGradient,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xBFD6AA64)),
              boxShadow: state == 1
                  ? Glow.red(24)
                  : const [
                      BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 40,
                        offset: Offset(0, 16),
                      ),
                    ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              children: [
                Expanded(
                  child: Image.asset(
                    _art(choice.card!),
                    fit: BoxFit.cover,
                    colorBlendMode: BlendMode.multiply,
                    color: C.hanjiTop,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  choice.label,
                  style: T(1).body(
                    14,
                    w: FontWeight.w700,
                    c: const Color(0xFF22160E),
                    h: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Incense extends StatelessWidget {
  final int left, total;
  const _Incense({required this.left, required this.total});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text('香', style: T(1).mono.copyWith(color: C.gold)),
      const SizedBox(width: 10),
      Expanded(
        child: LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth * left / total;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0x1AEFE4D2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  height: 3,
                  width: w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B4A2E), C.gold],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(seconds: 1),
                  left: w - 3,
                  top: -1.5,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF7A4A),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xB3FF5A3C),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(width: 10),
      Text(
        '${left < 0 ? 0 : left}s',
        style: T(1).mono.copyWith(color: C.redHot, letterSpacing: 1.5),
      ),
    ],
  );
}

// ─────────────────────────── 08 엔딩 ───────────────────────────
class EndingScreen extends StatelessWidget {
  final String code;
  const EndingScreen({super.key, required this.code});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final e = shrine.endings[code]!;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _img(e.art),
            fit: BoxFit.cover,
            alignment: const Alignment(0, -.4),
          ),
          const BottomShade(
            stops: [0, .2, .38, .62, .78],
            colors: [
              Color(0x66070404),
              Colors.transparent,
              Colors.transparent,
              Color(0xE6070404),
              C.bg,
            ],
          ),
          const RedBreath(),
          // 우측 수집 레일: 획득 컬러 / 미획득 흑백 25% / 현재 붉은 테두리
          Positioned(
            right: 12,
            top: 112,
            child: Column(
              children: shrine.endings.values.map((v) {
                final got = st.endings.containsKey(v.code) || v.code == code;
                return Container(
                  width: 50,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: v.code == code ? C.redHot : C.line,
                    ),
                    boxShadow: v.code == code ? Glow.red(16) : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: got
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              )
                            : const ColorFilter.matrix([
                                .05,
                                .15,
                                .02,
                                0,
                                0,
                                .05,
                                .15,
                                .02,
                                0,
                                0,
                                .05,
                                .15,
                                .02,
                                0,
                                0,
                                0,
                                0,
                                0,
                                1,
                                0,
                              ]),
                        child: Image.asset(_img(v.thumb), fit: BoxFit.cover),
                      ),
                      Align(
                        alignment: const Alignment(0, .9),
                        child: Text(
                          got ? v.code : '${v.code} ?',
                          style: T(1).mono.copyWith(
                            fontSize: 9,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 30,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 結 도장 46px, -5°, 2.6배 → 1배 (0.9s, 0.5s 지연)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1400),
                    curve: const Interval(.36, 1, curve: Cubic(.3, 1.5, .5, 1)),
                    builder: (_, p, __) => Opacity(
                      opacity: p.clamp(0, 1),
                      child: Transform.rotate(
                        angle: -.087,
                        child: Transform.scale(
                          scale: 2.6 - 1.6 * p,
                          child: Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.red,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: Glow.red(),
                            ),
                            child: Text(
                              '結',
                              style: t.display(
                                22,
                                w: FontWeight.w900,
                                c: C.btnText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '엔딩 $code. ${e.name}',
                    style: t.body(15, w: FontWeight.w700, c: C.gold),
                  ),
                  const SizedBox(height: 10),
                  Text(e.line, style: t.display(25, w: FontWeight.w900)),
                  const SizedBox(height: 24),
                  RedButton(
                    '월화의 풀이 듣기',
                    ts: st.ts,
                    onTap: () {
                      context.read<ShrineSessionProvider>().update(
                        (s) => s.copy(
                          meaningSrc: StorySource(
                            'red-bell',
                            code,
                            s.lastFlags,
                            s.lastPath,
                          ),
                        ),
                      );
                      ShrineNav.go(context, 'meaning');
                    },
                  ),
                  const SizedBox(height: 10),
                  Pill(
                    '결과만 보기',
                    ts: st.ts,
                    onTap: () =>
                        ShrineNav.go(context, 'result', params: {'code': code}),
                  ),
                ],
              ),
            ),
          ),
          _top(
            context,
            back: () => ShrineNav.go(context, 'recommend'),
            center: Text('ENDING · ${st.endings.length} / 4', style: t.mono),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── 09 결과 두루마리 ───────────────────────────
class ResultScreen extends StatelessWidget {
  final String code;
  final bool shared;
  final String? sharedData;
  const ResultScreen({
    super.key,
    required this.code,
    this.shared = false,
    this.sharedData,
  });
  @override
  Widget build(BuildContext context) {
    final st = context.watch<ShrineSessionProvider>().state;
    final t = T(st.ts);
    final e = shrine.endings[code]!;
    // 공유 링크: d = base64(utf8(JSON{name(가린 이름), topic, path})) — 생년월일·계절·사주 없음
    Map? sd;
    try {
      if (shared && sharedData != null)
        sd = jsonDecode(
          utf8.decode(base64.decode(base64.normalize(sharedData!))),
        );
    } catch (_) {}
    final name = sd?['name'] ?? st.name,
        season = shared ? null : st.season,
        topicId = sd?['topic'] ?? st.topic;
    // v3 결과 확장 — 공유 뷰에서는 보이지 않음
    final myT = shared
        ? null
        : st.box
              .where(
                (b) => b.source.story == 'red-bell' && b.source.ending == code,
              )
              .lastOrNull;
    final flav = shared || st.lastFlags.isEmpty
        ? null
        : shrine.talismans.interpret(st.lastFlags);
    final sajuNote = shared ? null : st.saju?.topics[topicId]?.note;
    final path = sd != null
        ? (sd['path'] as List).map((p) => PathStep.fromJson(p)).toList()
        : st.lastPath;
    String f(String s) =>
        shrine.fill(s, name: name, season: season, topicId: topicId);
    final ink = t.body(14.5, c: const Color(0xFF3A2616), h: 1.95);

    return Scaffold(
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.2),
                radius: .9,
                colors: [Color(0xFF2A0D0B), C.bg],
              ),
            ),
          ),
          const Embers(count: 10),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 40),
            child: Column(
              children: [
                _rod(),
                // 펼침 1.8s — 위에서 아래로 clip
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Dur.unroll,
                  curve: const Cubic(.5, 0, .2, 1),
                  builder: (_, p, child) => ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: p,
                      child: child,
                    ),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [C.hanjiTop, Color(0xFFE2CEA3)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                          child: Column(
                            children: [
                              Text(
                                'ENDING $code · ${e.name}',
                                style: t.mono.copyWith(
                                  color: const Color(0x8C3C1E0F),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                shared ? '${name ?? '누군가'}님의 이야기' : '당신의 이야기',
                                style: t.display(
                                  22,
                                  w: FontWeight.w900,
                                  c: const Color(0xFF3A1A0E),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                f(
                                  shrine.readings[topicId] ??
                                      shrine.readings['fate']!,
                                ),
                                textAlign: TextAlign.center,
                                style: ink.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...e.body.map(
                                (p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    f(p),
                                    textAlign: TextAlign.center,
                                    style: ink,
                                  ),
                                ),
                              ),
                              if (sajuNote != null)
                                _rbox(
                                  t,
                                  '命 사주의 근거 · ${st.saju!.source == 'SAMPLE' ? 'SAMPLE' : '정통사주'}',
                                  sajuNote,
                                  const Color(0x14784620),
                                  const Color(0x2E5A3214),
                                ),
                              if (flav != null)
                                _rbox(
                                  t,
                                  '選 선택의 의미 · ${flav.k} ${flav.label}',
                                  '${flav.said} ${flav.story}',
                                  const Color(0x0FA11D19),
                                  const Color(0x40A11D19),
                                ),
                              if (myT != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 14),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0x143C1408),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      BujeokSheet(
                                        w: 64,
                                        name: nameShown(name, myT.mode),
                                        spec: myT.spec,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '符 받은 부적 · ${myT.no}',
                                              style: t.mono.copyWith(
                                                color: const Color(0x8C3C1E0F),
                                                letterSpacing: 1.5,
                                              ),
                                            ),
                                            Text(
                                              '${myT.spec.name} · ${myT.spec.phrase}',
                                              style: t.display(
                                                15,
                                                w: FontWeight.w900,
                                                c: const Color(0xFF3A1A0E),
                                              ),
                                            ),
                                            Text(
                                              myT.spec.phraseMeaning,
                                              style: t.body(
                                                12,
                                                c: const Color(0xFF5A3A22),
                                                h: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (myT != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: BjOneBadge(
                                    name: nameShown(name, myT.mode),
                                    spec: myT.spec,
                                    serial: '神堂 · ${myT.no}',
                                    onScroll: true,
                                  ),
                                ),
                              if (path.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 18),
                                  padding: const EdgeInsets.only(top: 14),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Color(0x4D5A3214)),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '걸어온 길',
                                        style: t.mono.copyWith(
                                          color: const Color(0x8C3C1E0F),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      for (var i = 0; i < path.length; i++)
                                        Text(
                                          '${i + 1}. ${path[i].label}${path[i].timeout ? ' — 향이 다 탔다' : ''}',
                                          style: t.body(
                                            13,
                                            c: const Color(0xFF5A3A22),
                                            h: 1.55,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 10),
                              ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (r) => const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black],
                                  stops: [0, .35],
                                ).createShader(r),
                                child: Image.asset(
                                  _art('scroll'),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  color: C.hanjiTop,
                                  colorBlendMode: BlendMode.multiply,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 22,
                          top: 22,
                          child: Transform.rotate(
                            angle: .14,
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xD9A11D19),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '神堂',
                                style: t.display(
                                  15,
                                  w: FontWeight.w900,
                                  c: const Color(0xE6A11D19),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _rod(),
                const SizedBox(height: 18),
                if (shared)
                  RedButton(
                    '나도 신당에 들어가기',
                    ts: st.ts,
                    onTap: () {
                      context.read<ShrineSessionProvider>().resetData();
                      ShrineNav.goAndClearStack(context, 'entry');
                    },
                  )
                else ...[
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.goldLine),
                    ),
                    child: Row(
                      children: [
                        _act(
                          '⤓',
                          '저장하기',
                          () => saveEndingCard(context, e, name),
                        ),
                        _act('⇪', '공유하기', () {
                          // 공개용만: 사용자가 고른 이름 표시 방식으로 가린 이름 · 주제 · 경로. 생년월일·계절·사주 원본 없음
                          final shown = myT != null
                              ? nameShown(name, myT.mode)
                              : (name == null || name.isEmpty
                                    ? ''
                                    : '${name.characters.first}○');
                          final d = base64.encode(
                            utf8.encode(
                              jsonEncode({
                                'name': shown,
                                'topic': topicId,
                                'path': path.map((p) => p.toJson()).toList(),
                              }),
                            ),
                          );
                          Share.share(
                            '${e.line.replaceAll('\n', ' ')}\nhttps://YOUR_DOMAIN/shrine/result/$code?s=1&d=${Uri.encodeComponent(d)}',
                            subject: '신당 · ${e.name}',
                          );
                        }),
                        _act('↻', '다시보기', () {
                          context.read<ShrineSessionProvider>().update(
                            (s) => s.copy(clearPos: true),
                          );
                          ShrineNav.go(context, 'story');
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '모은 결말 ${st.endings.length} / 4 · 다른 선택은 다른 결말과 다른 부적으로 이어집니다',
                    textAlign: TextAlign.center,
                    style: t.mono.copyWith(letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 10),
                  if (myT == null)
                    RedButton(
                      '이 결말의 부적 받기',
                      ts: st.ts,
                      onTap: () {
                        context.read<ShrineSessionProvider>().update(
                          (s) => s.copy(
                            meaningSrc: StorySource(
                              'red-bell',
                              code,
                              s.lastFlags,
                              s.lastPath,
                            ),
                          ),
                        );
                        ShrineNav.go(context, 'meaning');
                      },
                    ),
                  const SizedBox(height: 10),
                  Pill(
                    '이어지는 이야기 보기 — 「무너진 신당의 밤」 열림',
                    ts: st.ts,
                    onTap: () => ShrineNav.go(context, 'list'),
                  ),
                ],
              ],
            ),
          ),
          _top(
            context,
            back: () => shared
                ? ShrineNav.go(context, 'entry')
                : ShrineNav.go(context, 'end', params: {'code': code}),
            center: Text('RESULT · 結果', style: t.mono),
          ),
        ],
      ),
    );
  }

  Widget _rbox(T t, String h, String body, Color bg, Color bd) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: bd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          h,
          style: t.mono.copyWith(
            color: const Color(0x8C3C1E0F),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(body, style: t.body(13.5, c: const Color(0xFF3A2616), h: 1.7)),
      ],
    ),
  );
  Widget _rod() => Container(
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: -10),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4A2414), Color(0xFF2A120A), Color(0xFF160904)],
      ),
    ),
  );
  Widget _act(String g, String l, VoidCallback f) => Expanded(
    child: GestureDetector(
      onTap: f,
      child: Container(
        color: const Color(0xF20E0706),
        padding: const EdgeInsets.symmetric(vertical: 15),
        margin: const EdgeInsets.symmetric(horizontal: .5),
        child: Column(
          children: [
            Text(g, style: const TextStyle(fontSize: 17, color: C.gold)),
            const SizedBox(height: 8),
            Text(l, style: T(1).ui(12.5)),
          ],
        ),
      ),
    ),
  );
}

// 10 이야기 목록 → screens_v3.dart ListScreenV3 (v3에서 교체)
