// shrine_settings_sheet.dart — 설정 시트. r22 상단 · 소리 / 움직임 줄이기 /
// 클라이맥스 제한 시간 / 글자 크기 / 기록 지우기 / 허구 고지.
// 레퍼런스: design_files/screens-a.jsx SettingsSheet.
// provider 패턴에 맞춰 ShrineSessionProvider.set(...) 으로 즉시 저장한다.
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import 'shrine_chrome.dart';

void showShrineSettingsSheet(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierLabel: '설정',
    barrierDismissible: true,
    barrierColor: const Color(0x8C070404),
    transitionDuration: ShrineMotion.screen,
    pageBuilder: (_, __, ___) => const _ShrineSettingsSheetBody(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: ShrineMotion.ease);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

class _ShrineSettingsSheetBody extends StatelessWidget {
  const _ShrineSettingsSheetBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShrineSessionProvider>();
    final s = provider.state;
    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // 시트 내부 탭은 닫히지 않도록 흡수.
        child: Container(
          constraints: const BoxConstraints(maxHeight: 650),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
          decoration: const BoxDecoration(
            color: Color(0xEB0E0706),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
            border: Border(top: BorderSide(color: ShrineColor.goldLine)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                        color: const Color(0x40EFE4D2), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('설정', style: ShrineType.display(21)),
                    const Spacer(),
                    ShrineIconBtn(
                        semantic: '닫기',
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Text('✕', style: TextStyle(color: ShrineColor.fg, fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 14),
                _SettingsRow(
                  label: '소리',
                  sub: '입장 후에만 재생됩니다',
                  trailing: _Toggle(on: s.sound, onTap: () => provider.set((x) => x.copyWith(sound: !x.sound))),
                ),
                _SettingsRow(
                  label: '움직임 줄이기',
                  sub: '파티클·문 열림 생략, 글자 즉시 표시',
                  trailing: _Toggle(
                      on: s.reduceMotion, onTap: () => provider.set((x) => x.copyWith(reduceMotion: !x.reduceMotion))),
                ),
                _SettingsRow(
                  label: '클라이맥스 제한 시간',
                  sub: '끄면 향이 타지 않고 기다립니다',
                  trailing: _Toggle(
                      on: s.climaxTimer, onTap: () => provider.set((x) => x.copyWith(climaxTimer: !x.climaxTimer))),
                ),
                _SettingsRow(
                  label: '글자 크기',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final size in ShrineTextSize.values)
                        GestureDetector(
                          onTap: () => provider.set((x) => x.copyWith(textSize: size)),
                          child: Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                            decoration: BoxDecoration(
                              color: s.textSize == size ? const Color(0x38C9A368) : null,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: ShrineColor.line),
                            ),
                            child: Text(size.ko,
                                style: ShrineType.ui(1,
                                    size: 12.5, c: s.textSize == size ? ShrineColor.fg : ShrineColor.muted)),
                          ),
                        ),
                    ],
                  ),
                ),
                _SettingsRow(
                  label: '기록 지우기',
                  sub: '이름·결말·소지부가 이 기기에서 지워집니다',
                  trailing: GestureDetector(
                    onTap: () => provider.wipe(),
                    child: Text('지우기', style: ShrineType.ui(1, size: 13, c: ShrineColor.redHot)),
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: ShrineColor.goldLine),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('虛構 · NOTICE', style: ShrineType.mono()),
                      const SizedBox(height: 8),
                      Text(
                        '신당의 이야기와 인물, 부적과 계시는 모두 창작 연출물입니다. 실제 무속 상담이나 의료·투자·법률 조언이 아니며, 어떤 효능도 약속하지 않습니다.',
                        style: ShrineType.saySmall(s.textSize.scale),
                      ),
                    ],
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

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? sub;
  final Widget trailing;
  const _SettingsRow({required this.label, this.sub, required this.trailing});
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ShrineColor.line))),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: ShrineType.ui(1, size: 14.5, w: FontWeight.w500)),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(sub!, style: ShrineType.ui(1, size: 11.5, c: ShrineColor.faint)),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );
}

class _Toggle extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  const _Toggle({required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ShrineMotion.press,
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: on ? const Color(0x59C9A368) : const Color(0x1AEFE4D2),
            border: Border.all(color: on ? ShrineColor.gold : ShrineColor.line),
          ),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: on ? ShrineColor.gold : const Color(0x80EFE4D2)),
          ),
        ),
      );
}
