import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/wish_room_provider.dart';
import '../../theme/wish_room_colors.dart';
import '../../theme/wish_room_text_styles.dart';
import '../../widgets/wish_room_sigils.dart';
import '../../widgets/wish_room_pouch_widgets.dart';
import '../pouch/wish_room_earn_moment_screen.dart';

/// 02 · 소원 작성 (Wish Compose) — dev-spec §1 재제작 대상, JSX 미커업.
///
/// 두루마리([WishRoomScroll])에 소원을 적고 인장([WishRoomSeal] 7종 중 하나)으로
/// 봉인한다는 브랜드 서사를 그대로 구현했다. 완성 시 `provider.addWish(...)`가
/// 내부에서 `earnCompose`를 자동 호출해 조각 +5를 지급하므로, 제출 후에는
/// [WishRoomEarnMomentScreen] 풀스크린 오버레이로 그 정성을 알린다.
///
/// 절대 원칙 준수: 결제/충전 버튼 없음, 느낌표 미사용, 애니메이션은 화면 전환
/// 기본 트랜지션(≥1s 아님이지만 이 화면 자체에 커스텀 애니메이션은 없음 —
/// 원칙 5는 "새로 만든 애니메이션"에 적용되며 기본 push 트랜지션은 대상 아님).
class WishRoomComposeScreen extends StatefulWidget {
  const WishRoomComposeScreen({super.key});

  @override
  State<WishRoomComposeScreen> createState() => _WishRoomComposeScreenState();
}

class _WishRoomComposeScreenState extends State<WishRoomComposeScreen> {
  static const _seals = ['願', '合', '康', '福', '緣', '財', '成'];
  static const _sealNames = {
    '願': '바람',
    '合': '화합',
    '康': '건강',
    '福': '복',
    '緣': '인연',
    '財': '재물',
    '成': '성취',
  };

  final _textCtrl = TextEditingController();
  String _seal = '願';
  int _intensity = 3;
  bool _submitting = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final provider = context.read<WishRoomProvider>();
    await provider.addWish(text: text, seal: _seal, intensity: _intensity);
    if (!mounted) return;
    final result = provider.lastEarnResult;
    if (result != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WishRoomEarnMomentScreen(result: result),
        ),
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = WishRoomColors.crystal;
    final canSubmit = _textCtrl.text.trim().isNotEmpty && !_submitting;

    return WishRoomPouchBg(
      palette: palette,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.55),
                child: WishRoomSigil(
                  size: 320,
                  color: palette.sigil,
                  opacity: 0.18,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WishRoomPouchIconButton(
                          icon: Icons.arrow_back,
                          palette: palette,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        WishRoomPouchMonoLabel(
                          text: 'COMPOSE · 소원 봉인',
                          palette: palette,
                        ),
                        const SizedBox(width: 34),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        children: [
                          Text(
                            '마음속 바람을\n두루마리에 적어요',
                            style: WishRoomText.h1(
                              palette.fg,
                            ).copyWith(fontSize: 22, height: 1.3),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '적어둔 소원은 인장으로 봉인되어\n촛불로 밝혀집니다',
                            style: WishRoomText.body(
                              palette.muted,
                            ).copyWith(height: 1.7, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          WishRoomScroll(
                            child: TextField(
                              controller: _textCtrl,
                              maxLength: 140,
                              maxLines: 5,
                              minLines: 4,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontFamily: WishRoomText.fontBody,
                                fontSize: 15,
                                height: 1.6,
                                color: Color(0xFF3A2515),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                counterStyle: TextStyle(
                                  color: Color(0x993A2515),
                                ),
                                hintText: '이루어지길 바라는 마음을 적어보세요',
                                hintStyle: TextStyle(color: Color(0x663A2515)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '인장 고르기',
                            style: WishRoomText.body(
                              palette.muted,
                            ).copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _seals.map((s) {
                              final selected = s == _seal;
                              return GestureDetector(
                                onTap: () => setState(() => _seal = s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? palette.glow
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: palette.glowShadow,
                                              blurRadius: 12,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      WishRoomSeal(text: s, size: 40),
                                      const SizedBox(height: 4),
                                      Text(
                                        _sealNames[s] ?? '',
                                        style: WishRoomText.monoSm(
                                          selected
                                              ? palette.glow
                                              : palette.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '간절함',
                            style: WishRoomText.body(
                              palette.muted,
                            ).copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (i) {
                              final level = i + 1;
                              final on = level <= _intensity;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _intensity = level),
                                  child: Icon(
                                    on
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 26,
                                    color: on ? palette.glow : palette.muted,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    WishRoomPouchButton(
                      label: _submitting ? '봉인하는 중' : '❖ 소원 봉인하기',
                      primary: true,
                      palette: palette,
                      expand: true,
                      onPressed: canSubmit ? _submit : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
