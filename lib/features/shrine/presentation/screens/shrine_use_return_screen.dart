// shrine_use_return_screen.dart — 奉(봉헌하기 — 재방문 안내).
// [Dart 레퍼런스 없음] design_files/screens-c.jsx UseReturn(259-288줄)을
// 직접 Flutter로 번역했다. 원본의 Flames(촛불 파티클) 장식은 이 화면 전용
// 신규 컴포넌트를 만들지 않고 기존 ShrineAtmosphere(embers)로 대체한다
// (표준 불변 제약: 기존 엔진 재구현 금지 — 이미 있는 분위기 레이어 재사용).
// "이 부적을 봉헌하기" → burn(奉 소각) 화면으로 재진입한다.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_bujeok.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_rite_rail.dart';

class ShrineUseReturnScreen extends StatefulWidget {
  const ShrineUseReturnScreen({super.key});
  @override
  State<ShrineUseReturnScreen> createState() => _ShrineUseReturnScreenState();
}

class _ShrineUseReturnScreenState extends State<ShrineUseReturnScreen> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    final topic = shrineTopics[s.topic]!;
    final ts = s.textSize.scale;
    return ShrineScreenScaffold(
      rail: const ShrineRiteRail(5),
      background: [
        Positioned.fill(
            child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0x73000000), BlendMode.darken),
                child: Image.asset('${kShrineImageBase}shrine.jpg', fit: BoxFit.cover))),
        const ShrineBottomFade(.70),
      ],
      atmosphere: const ShrineAtmosphere(petals: 2, embers: 5),
      child: Stack(children: [
        Positioned(
          left: 22,
          right: 22,
          top: 400,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('奉 · 다시 올리기', style: ShrineType.mono()),
            const SizedBox(height: 10),
            Text('효력을 다했다고 느끼면,\n다시 이곳으로 오십시오.',
                style: ShrineType.display(25 * ts).copyWith(height: 1.35)),
            const SizedBox(height: 12),
            Text('지니던 한 장을 가져오시면, 월화가 그 이름을 기억하고 불에 올려 드립니다.',
                style: ShrineType.saySmall(ts)),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  border: Border.all(color: ShrineColor.goldLine),
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0x990E0706)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 34,
                    child: ShrineBujeok(name: s.name, birth: s.birth, topic: topic, frame: false)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s.displayName}님의 ${topic.name}',
                        style: ShrineType.say(1, size: 14.5, w: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text('受 · 이 기기에 보관',
                        style: ShrineType.mono(c: ShrineColor.faint, size: 9)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: 40,
          child: Column(children: [
            ShrineRedButton('이 부적을 봉헌하기', ts: ts, onTap: () => ShrineNav.go(context, 'burn')),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: ShrinePill(
                onTap: () => setState(() => _asked = true),
                child: _asked
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                        Text('✓ ', style: ShrineType.ui(1, c: ShrineColor.gold)),
                        const Text('동지 무렵 알려 드리겠습니다'),
                      ])
                    : const Text('동지 무렵 알려 받기'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
