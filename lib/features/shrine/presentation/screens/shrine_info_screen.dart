// shrine_info_screen.dart — 05 정보 입력(이름 · 생년월일 · 시).
// 레퍼런스: design_files/screens-a.jsx S05Info.
// [사용자 확정 결정 ②] 명부 카드의 사주 세로쓰기는 신당 스타터의 가짜
// saju() 함수가 아니라 ShrineSajuAdapter(기존 정통사주 만세력 엔진 재사용)로
// 계산한다. 입력은 전부 기기 내 세션(ShrineSessionProvider)에만 저장되며
// 서버로 전송되지 않는다(지시서 §1.2).
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show showDatePicker;
import 'package:provider/provider.dart';
import '../../application/shrine_session_provider.dart';
import '../../domain/shrine_rite_data.dart';
import '../../domain/shrine_saju_adapter.dart';
import '../../domain/shrine_session.dart';
import '../../domain/shrine_tokens.dart';
import '../shrine_navigation.dart';
import '../widgets/shrine_chrome.dart';
import '../widgets/shrine_hanji.dart';
import '../widgets/shrine_scaffold.dart';

class ShrineInfoScreen extends StatefulWidget {
  const ShrineInfoScreen({super.key});
  @override
  State<ShrineInfoScreen> createState() => _ShrineInfoScreenState();
}

class _ShrineInfoScreenState extends State<ShrineInfoScreen> {
  late int _step;
  late TextEditingController _nameCtrl;
  late bool _birthSet;

  @override
  void initState() {
    super.initState();
    final s = context.read<ShrineSessionProvider>().state;
    _step = s.infoStep.clamp(0, 2);
    _nameCtrl = TextEditingController(text: s.name);
    // 이 화면에 다시 들어왔다면(infoStep이 1 이상) 생년월일은 이미
    // 한 번 선택된 것으로 간주한다.
    _birthSet = s.infoStep >= 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _valid {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        return _birthSet;
      default:
        return true;
    }
  }

  Future<void> _pickBirth() async {
    final session = context.read<ShrineSessionProvider>();
    final picked = await showDatePicker(
      context: context,
      initialDate: session.state.birth,
      firstDate: DateTime(1920, 1, 1),
      lastDate: DateTime(2020, 12, 31),
    );
    if (picked != null && mounted) {
      session.set((x) => x.copyWith(birth: picked));
      setState(() => _birthSet = true);
    }
  }

  void _pickHour(String? hourLabel) {
    context.read<ShrineSessionProvider>().set(
        (x) => hourLabel == null ? x.copyWith(clearHour: true) : x.copyWith(hour: hourLabel));
  }

  void _next() {
    if (!_valid) return;
    final provider = context.read<ShrineSessionProvider>();
    if (_step < 2) {
      setState(() => _step += 1);
      provider.set((x) => x.copyWith(infoStep: _step));
    } else {
      provider.set((x) => x.copyWith(infoStep: 0)); // 완료 시 단계 초기화(다음 재진입 대비).
      // [P2 범위] 筆(부적 쓰기) 화면은 아직 미구현 — shrine_screen_router.dart의
      // 플레이스홀더로 일단 연결한다.
      ShrineNav.go(context, 'write');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<ShrineSessionProvider>().state;

    const tags = ['名 · NAME', '生 · BIRTH', '時 · HOUR'];
    const questions = ['이름을 알려 주십시오.', '태어난 날은 언제입니까.', '태어난 시를 아십니까.'];

    final birth = s.birth;
    final birthLabel =
        '${birth.year} · ${birth.month.toString().padLeft(2, '0')} · ${birth.day.toString().padLeft(2, '0')}';
    final no = '${birth.month.toString().padLeft(2, '0')}${birth.day.toString().padLeft(2, '0')}';

    return ShrineScreenScaffold(
      rail: _ShrineDots(n: 3, i: _step),
      background: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Transform.scale(
              scale: 1.12,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(Color(0x73000000), BlendMode.darken),
                child: Image.asset('${kShrineImageBase}talk.jpg', fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 70),
              // 명부 카드 — 입력하는 대로 붓이 따라 씀.
              ClipRRect(
                borderRadius: BorderRadius.circular(ShrineRadius.card),
                child: SizedBox(
                  height: 300,
                  child: Stack(children: [
                    const Positioned.fill(child: ShrineHanjiPaper()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Column(children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('名簿',
                                style: ShrineType.display(22, w: FontWeight.w900, c: ShrineColor.ink)
                                    .copyWith(letterSpacing: 6)),
                            const Spacer(),
                            Text('N° $no',
                                style: ShrineType.mono(c: const Color(0x8C3A2616)).copyWith(letterSpacing: 2)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(height: 1, color: const Color(0x403A2616)),
                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: _step >= 1
                                      ? VerticalKanjiColumn(
                                          text: ShrineSajuAdapter.verticalPillarText(
                                              birth: s.birth, hourLabel: _step >= 2 ? s.hour : null),
                                          size: 12,
                                          color: const Color(0xB23A2616),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                const SizedBox(width: 18),
                                _BrushNamePreview(name: s.name),
                              ],
                            ),
                          ),
                        ),
                        Text('입력하는 대로 붓이 따라 씁니다',
                            style: ShrineType.ui(1, size: 10.5, c: const Color(0x8C3A2616))),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 36),
              Text(tags[_step], style: ShrineType.mono()),
              const SizedBox(height: 10),
              Text(questions[_step], style: ShrineType.say(s.textSize.scale, size: 19)),
              const SizedBox(height: 22),
              _buildField(s, birthLabel),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ShrineRedButton(_step < 2 ? '다음' : '월화에게 건네기', onTap: _next, enabled: _valid),
              ),
              const SizedBox(height: 14),
              Text(
                '이름과 생년월일은 이 기기 안에만 남습니다.\n어디로도 보내지 않습니다.',
                textAlign: TextAlign.center,
                style: ShrineType.ui(1, size: 11, c: ShrineColor.faint).copyWith(height: 1.6),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(ShrineSession s, String birthLabel) {
    switch (_step) {
      case 0:
        return Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ShrineColor.gold))),
          padding: const EdgeInsets.only(bottom: 10),
          child: EditableText(
            controller: _nameCtrl,
            focusNode: FocusNode(),
            style: ShrineType.ui(1, size: 18, w: FontWeight.w500),
            cursorColor: ShrineColor.gold,
            backgroundCursorColor: ShrineColor.faint,
            maxLines: 1,
            onChanged: (v) {
              final trimmed = v.characters.take(4).toString();
              context.read<ShrineSessionProvider>().set((x) => x.copyWith(name: trimmed));
              setState(() {});
            },
          ),
        );
      case 1:
        return GestureDetector(
          onTap: _pickBirth,
          child: Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ShrineColor.gold))),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Text(_birthSet ? birthLabel : 'YYYY · MM · DD',
                  style: ShrineType.ui(1,
                      size: 18, w: FontWeight.w500, c: _birthSet ? ShrineColor.fg : ShrineColor.faint)),
            ]),
          ),
        );
      default:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HourChip(label: '모름', selected: s.hour == null, onTap: () => _pickHour(null)),
            for (var i = 0; i < shrineHours.length; i++)
              _HourChip(
                label: '${shrineHours[i]} · ${shrineHourRanges[i]}',
                selected: s.hour == shrineHours[i],
                onTap: () => _pickHour(shrineHours[i]),
              ),
          ],
        );
    }
  }
}

class _HourChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _HourChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? const Color(0x38C9A368) : null,
          border: Border.all(color: selected ? ShrineColor.gold : ShrineColor.line),
        ),
        child: Text(label, style: ShrineType.ui(1, size: 12, c: selected ? ShrineColor.fg : ShrineColor.muted)),
      ));
}

class _BrushNamePreview extends StatelessWidget {
  final String name;
  const _BrushNamePreview({required this.name});
  @override
  Widget build(BuildContext context) {
    final chars = name.isEmpty ? const ['　'] : name.characters.take(4).toList();
    final size = (86 / (chars.length < 2 ? 2 : chars.length)).clamp(32.0, 72.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final ch in chars) Text(ch, style: ShrineType.brush(size).copyWith(height: .95))],
    );
  }
}

/// 사주 세로쓰기(명부 카드 좌측) — bujeok.dart의 VerticalText와 동일한
/// 규칙(한 글자씩 세로 나열)을 이 화면 전용으로 가볍게 재현했다.
class VerticalKanjiColumn extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  const VerticalKanjiColumn({super.key, required this.text, required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final ch in text.replaceAll(' ', '').characters)
            Padding(
              padding: EdgeInsets.only(bottom: size * .3),
              child: Text(ch,
                  style: ShrineType.display(size, w: FontWeight.w700, c: color).copyWith(height: 1)),
            ),
        ],
      );
}

/// 단계 점 표시 — shell.jsx Dots({n,i}) 포팅.
class _ShrineDots extends StatelessWidget {
  final int n, i;
  const _ShrineDots({required this.n, required this.i});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var k = 0; k < n; k++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: ShrineMotion.screen,
                width: k == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: k <= i ? ShrineColor.gold : const Color(0x33EFE4D2),
                ),
              ),
            ),
        ],
      );
}
