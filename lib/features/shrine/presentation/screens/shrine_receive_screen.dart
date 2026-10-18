// shrine_receive_screen.dart — 受(의식 5단계: 소지부 수령).
// 레퍼런스: 신당 디자인 핸드오프 screens/receive.dart ReceiveScreen +
// design_files/screens-c.jsx ReceiveBase.
// 위치: 계시(示) 직후, 결말 이전(受는 RITE 그룹). idle → saved → share 3상태.
// 저장은 1080×1920 PNG(무료, 기기에만 저장) — shrine_talisman_export.dart가
// 프로젝트 기존 gal/share_plus 패턴으로 수행한다.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../shrine_talisman_export.dart';
import '../widgets/shrine_bujeok.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

enum _ReceiveState { idle, saved, share }

class ShrineReceiveScreen extends StatefulWidget {
  const ShrineReceiveScreen({super.key});
  @override
  State<ShrineReceiveScreen> createState() => _ShrineReceiveScreenState();
}

class _ShrineReceiveScreenState extends State<ShrineReceiveScreen> {
  _ReceiveState _st = _ReceiveState.idle;
  bool _hideName = true;
  bool _saving = false;
  final _exportKey = GlobalKey();

  Future<void> _save(ShrineSession s) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await ShrineTalismanExport.savePng(_exportKey, topicKey: s.topic.name);
      if (!mounted) return;
      if (bytes != null) {
        context.read<ShrineSessionProvider>().set((x) => x.copyWith(kept: true));
        setState(() => _st = _ReceiveState.saved);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    final bytes = await ShrineTalismanExport.capture(_exportKey);
    if (bytes == null) return;
    await ShrineTalismanExport.share(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final topic = shrineTopics[s.topic]!;
    final ts = s.textSize.scale;
    final saved = _st == _ReceiveState.saved;
    final share = _st == _ReceiveState.share;
    final talisman = SizedBox(
        width: 160,
        child: DecoratedBox(
            decoration: const BoxDecoration(boxShadow: ShrineGlow.ember),
            child: ShrineBujeok(name: s.name, birth: s.birth, hour: s.hour, topic: topic)));

    return ShrineScreenScaffold(
      back: false,
      rail: const ShrineRiteRail(4),
      background: [
        ShrineSafeVideo('give', loop: true, reduceMotion: s.reduceMotion, align: const Alignment(0, -.64)),
        const Positioned.fill(child: ColoredBox(color: Color(0x94070404))),
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(center: Alignment(0, -.08), radius: .6, colors: [
          Color(0x38FFAA5A),
          Color(0x00FFAA5A)
        ])))),
        const ShrineBottomFade(.46),
        // 화면 밖 1080×1920 PNG 레이아웃 — 저장/공유가 실제로 캡처하는 레이어.
        ShrineTalismanLayer(exportKey: _exportKey, session: s, hideName: _hideName && share),
      ],
      atmosphere: ShrineAtmosphere(petals: 2, embers: share ? 0 : 6),
      child: Stack(children: [
        Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(child: Text('受 · 所持符', style: ShrineType.mono()))),
        // 소지부 — saved면 아래로 내려가며 사라짐(봉투로 대체)
        Positioned(
            top: 122,
            left: 0,
            right: 0,
            child: Center(
                child: AnimatedSlide(
                    offset: saved ? const Offset(0, .3) : Offset.zero,
                    duration: const Duration(milliseconds: 1400),
                    curve: ShrineMotion.ease,
                    child: AnimatedOpacity(
                        opacity: saved ? 0 : 1,
                        duration: const Duration(milliseconds: 1400),
                        child: talisman)))),
        if (saved)
          Positioned(
              top: 252,
              left: 0,
              right: 0,
              child: Center(
                  child: ShrineFadeRise(
                      delay: const Duration(seconds: 1),
                      child: _ShrineEnvelope(seal: topic.key, label: '${s.displayName} · ${topic.name}')))),
        // 대사 + 액션
        AnimatedPositioned(
          duration: ShrineMotion.screen,
          curve: ShrineMotion.ease,
          left: 16,
          right: 16,
          bottom: share ? 300 : 30,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ShrineDialoguePanel(
                child: saved
                    ? Text('간직하셨습니다.\n이제 어떻게 지니는지 일러 드리지요.', style: ShrineType.say(ts))
                    : ShrineTypewriter(
                        '이제, 당신의 것을 가져가십시오.\n이것은 태우지 않습니다.',
                        speed: ShrineMotion.typeTalk,
                        instant: s.reduceMotion,
                        style: ShrineType.say(ts))),
            if (!share) ...[
              const SizedBox(height: 12),
              if (!saved) ...[
                ShrineRedButton('소지부 간직하기', ts: ts, enabled: !_saving, onTap: () => _save(s)),
                const SizedBox(height: ShrineSpace.buttonGap),
                Row(children: [
                  Expanded(
                      child: ShrinePill(
                          onTap: () => ShrineNav.go(context, 'use'), child: const Text('사용법 먼저 보기'))),
                  const SizedBox(width: ShrineSpace.buttonGap),
                  Expanded(
                      child: ShrinePill(
                          onTap: () => ShrineNav.go(context, 'story'), child: const Text('이야기로 가기'))),
                ]),
                const SizedBox(height: 8),
                Text('1080×1920 이미지 · 무료 · 이 기기에만 저장', style: ShrineType.ui(1, size: 11, c: ShrineColor.faint)),
              ] else ...[
                ShrineRedButton('사용법 보기', ts: ts, onTap: () => ShrineNav.go(context, 'use')),
                const SizedBox(height: ShrineSpace.buttonGap),
                Row(children: [
                  Expanded(
                      child: ShrinePill(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('✓ ', style: ShrineType.ui(1, c: ShrineColor.gold)),
                    const Text('사진첩에 저장됨'),
                  ]))),
                  const SizedBox(width: ShrineSpace.buttonGap),
                  Expanded(
                      child: ShrinePill(
                          onTap: () => setState(() => _st = _ReceiveState.share), child: const Text('나누기'))),
                ]),
              ],
            ],
          ]),
        ),
        if (share) ...[
          Positioned.fill(
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _st = _ReceiveState.saved))),
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 288,
              child: _ShrineShareSheet(
                preview: SizedBox(
                    width: 40,
                    child: ShrineBujeok(
                        name: _hideName ? '' : s.name, birth: s.birth, topic: topic, frame: false)),
                hideName: _hideName,
                onToggle: () => setState(() => _hideName = !_hideName),
                onShare: _share,
              )),
        ],
      ]),
    );
  }
}

class _ShrineEnvelope extends StatelessWidget {
  final String seal, label;
  const _ShrineEnvelope({required this.seal, required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 210,
      height: 140,
      child: Stack(children: [
        Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFD8C393), Color(0xFFC9B07C)])))),
        Positioned.fill(child: CustomPaint(painter: _ShrineFlap())),
        Positioned(
            top: 62,
            left: 88,
            child: Transform.rotate(
                angle: -.07,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: ShrineColor.jusa, borderRadius: BorderRadius.circular(4)),
                  child: Text(seal, style: ShrineType.display(20, c: ShrineColor.hanji1).copyWith(height: 1)),
                ))),
        Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(child: Text(label, style: ShrineType.mono(c: const Color(0x993A2616), size: 9)))),
      ]));
}

class _ShrineFlap extends CustomPainter {
  @override
  void paint(Canvas c, Size s) => c.drawPath(
      Path()
        ..moveTo(2, 2)
        ..lineTo(s.width / 2, s.height * .54)
        ..lineTo(s.width - 2, 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x593A2616));
  @override
  bool shouldRepaint(_ShrineFlap oldDelegate) => false;
}

class _ShrineShareSheet extends StatelessWidget {
  final Widget preview;
  final bool hideName;
  final VoidCallback onToggle, onShare;
  const _ShrineShareSheet(
      {required this.preview, required this.hideName, required this.onToggle, required this.onShare});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
      decoration: const BoxDecoration(
          color: Color(0xF00E0706),
          borderRadius: BorderRadius.vertical(top: Radius.circular(ShrineRadius.sheet)),
          border: Border(top: BorderSide(color: ShrineColor.goldLine))),
      child: Column(children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0x40EFE4D2), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 78,
              height: 139,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ShrineColor.line),
                  gradient: const RadialGradient(colors: [Color(0xFF2A120C), ShrineColor.bg])),
              child: preview),
          const SizedBox(width: 16),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('나누기 · SHARE', style: ShrineType.mono()),
            const SizedBox(height: 8),
            Text('부적은 원래 주는 것이었습니다. 이름은 가리고 문양만 보낼 수도 있습니다.',
                style: ShrineType.saySmall(1).copyWith(fontSize: 13.5)),
            const SizedBox(height: 10),
            GestureDetector(
                onTap: onToggle,
                child: Row(children: [
                  Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4), border: Border.all(color: ShrineColor.gold)),
                      child: Text(hideName ? '✓' : '', style: ShrineType.ui(1, size: 10, c: ShrineColor.gold))),
                  const SizedBox(width: 8),
                  Text('이름 가리기', style: ShrineType.ui(1, size: 12.5, c: ShrineColor.muted)),
                ])),
          ])),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          for (final l in ['이미지 보내기', '링크 복사', '스토리에 올리기']) ...[
            Expanded(child: ShrinePill(onTap: onShare, child: Text(l, style: ShrineType.ui(1, size: 12.5)))),
            if (l != '스토리에 올리기') const SizedBox(width: 9),
          ],
        ]),
      ]));
}
