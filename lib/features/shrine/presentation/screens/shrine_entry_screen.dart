// shrine_entry_screen.dart — 01 메인 입장.
// 레퍼런스: design_files/screens-a.jsx S01Entry.
// [사용자 확정 결정 ④] 광고 게이트는 "진입" 지점에만 적용한다(수령 지점은
// 게이트 없음). 이 화면이 신당 콘텐츠의 유일한 입구이므로, 광고 게이트
// 연동은 P6b에서 이 화면의 "신당에 들어서기" 버튼 onTap에 삽입될 예정이다
// (현재 P1 단계에서는 게이트 없이 바로 door로 이동 — P6b에서 교체).
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_scaffold.dart';
import '../widgets/shrine_settings_sheet.dart';

class ShrineEntryScreen extends StatelessWidget {
  const ShrineEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;
    return ShrineScreenScaffold(
      back: false,
      settings: false,
      skip: null,
      background: [
        ShrineSafeVideo('entry', loop: true, reduceMotion: s.reduceMotion),
        const ShrineBottomFade(.7),
      ],
      atmosphere: const ShrineAtmosphere(petals: 6),
      child: Align(
        alignment: const Alignment(0, .62),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShrineFadeRise(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('신당', style: ShrineType.logo()),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('神堂', style: ShrineType.logoHanja()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ShrineFadeRise(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  '문이 열린 순간,\n이야기는 당신을 기억한다.',
                  textAlign: TextAlign.center,
                  style: ShrineType.say(s.textSize.scale, size: 18).copyWith(height: 1.75),
                ),
              ),
              const SizedBox(height: 14),
              ShrineFadeRise(
                delay: const Duration(milliseconds: 400),
                child: Text('THE SHRINE · 소리를 켜면 더 깊어집니다',
                    style: ShrineType.mono(c: ShrineColor.faint)),
              ),
              const SizedBox(height: 26),
              ShrineFadeRise(
                delay: const Duration(milliseconds: 600),
                child: SizedBox(
                  width: double.infinity,
                  child: ShrineRedButton(
                    '신당에 들어서기',
                    // [P6b에서 교체 예정] 광고 게이트("진입" 1지점)를 여기에 연결한다.
                    onTap: () => ShrineNav.go(context, 'door'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ShrineFadeRise(
                delay: const Duration(milliseconds: 800),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => ShrineNav.go(context, 'more'),
                      child: Text('추가 이야기',
                          style: ShrineType.ui(s.textSize.scale, size: 12.5, c: ShrineColor.muted)),
                    ),
                    Text('  ·  ', style: ShrineType.ui(1, size: 12.5, c: ShrineColor.faint)),
                    GestureDetector(
                      onTap: () => showShrineSettingsSheet(context),
                      child: Text('설정 · 소리',
                          style: ShrineType.ui(s.textSize.scale, size: 12.5, c: ShrineColor.muted)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ShrineFadeRise(
                delay: const Duration(milliseconds: 900),
                child: Text('모든 이야기와 부적은 창작 연출물입니다',
                    style: ShrineType.ui(1, size: 10.5, c: ShrineColor.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

