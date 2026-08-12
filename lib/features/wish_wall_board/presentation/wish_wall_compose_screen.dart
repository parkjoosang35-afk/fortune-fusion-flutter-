import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/wish_wall_scroll.dart';
import '../widgets/wish_wall_seal.dart';
import '../widgets/wish_wall_sigil.dart';
import 'wish_wall_success_screen.dart';

/// 03. 소원 담기 — 옛 "신통방통 소원방"(wish_room) 작성 화면 구조 이식.
///
/// [디자인 히스토리] 옛 `WishRoomComposeScreen`은 5-step 위저드가 아니라
/// 한 화면 안에서 (1) 두루마리에 본문 입력 (2) 인장(印) 고르기 (3) 간절함
/// 별점 (4) 소원 봉인하기 버튼으로 구성됐다. 이 구조를 그대로 재현하되,
/// "인장 고르기"는 지금의 9개 [WishCategory]에 각각 매핑된 인장([WishWallSeal]
/// + [WishCategorySealX])으로 대체해 카테고리 선택과 인장 선택을 하나로
/// 합쳤다. 공개범위(익명/이름공개/나만보기)는 옛 화면엔 없던 개념이지만
/// 지금 시스템의 필수 정책이라 하단에 작은 토글로 추가했다.
class WishWallComposeScreen extends StatefulWidget {
  const WishWallComposeScreen({super.key});

  @override
  State<WishWallComposeScreen> createState() => _WishWallComposeScreenState();
}

class _WishWallComposeScreenState extends State<WishWallComposeScreen> {
  final _textController = TextEditingController();
  WishCategory _category = WishCategory.exam;
  int _intensity = 3;
  WishVisibility _visibility = WishVisibility.anonymous;
  bool _submitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _textController.text.trim().length >= 5 && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final wish = await context.read<WishWallProvider>().createWish(
          categoryId: _category,
          glassLevel: _intensity / 5,
          text: _textController.text.trim(),
          visibility: _visibility,
        );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WishWallSuccessScreen(wish: wish)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishWallColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.55),
              child: WishWallSigil(
                size: 320,
                color: WishWallColors.accent,
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
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: WishWallColors.ink,
                        ),
                      ),
                      Text('COMPOSE · 소원 봉인', style: WishWallText.mono()),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        Text(
                          '마음속 바람을\n두루마리에 적어요',
                          style: WishWallText.title1().copyWith(
                            fontSize: 22,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '적어둔 소원은 인장으로 봉인되어\n소원방에 밝혀집니다',
                          style: WishWallText.body(
                            color: WishWallColors.muted,
                          ).copyWith(height: 1.7, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        WishWallScroll(
                          child: TextField(
                            controller: _textController,
                            maxLength: 200,
                            maxLines: 5,
                            minLines: 4,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                              fontFamily: 'GowunBatangWish',
                              fontSize: 15,
                              height: 1.6,
                              color: Color(0xFF3A2515),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              counterStyle: TextStyle(color: Color(0x993A2515)),
                              hintText: '이루어지길 바라는 마음을 적어보세요 (최소 5자)',
                              hintStyle: TextStyle(color: Color(0x663A2515)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '인장 고르기',
                          style: WishWallText.body(
                            color: WishWallColors.muted,
                          ).copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: WishCategory.values.map((c) {
                            final selected = c == _category;
                            return GestureDetector(
                              onTap: () => setState(() => _category = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? WishWallColors.accent
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: WishWallColors.accent
                                                .withValues(alpha: 0.35),
                                            blurRadius: 12,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    WishWallSeal(
                                      text: c.sealChar,
                                      color: c.lightColor,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.sealName,
                                      style: WishWallText.mono(
                                        color: selected
                                            ? WishWallColors.accent
                                            : WishWallColors.muted,
                                      ).copyWith(fontSize: 9),
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
                          style: WishWallText.body(
                            color: WishWallColors.muted,
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
                                onTap: () => setState(() => _intensity = level),
                                child: Icon(
                                  on ? Icons.star_rounded : Icons.star_border_rounded,
                                  size: 26,
                                  color: on
                                      ? WishWallColors.accent
                                      : WishWallColors.muted,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '누구에게 보여줄까요?',
                          style: WishWallText.body(
                            color: WishWallColors.muted,
                          ).copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: WishVisibility.values.map((v) {
                            final active = v == _visibility;
                            return InkWell(
                              onTap: () => setState(() => _visibility = v),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? WishWallColors.accentSoft
                                      : WishWallColors.bg2,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: active
                                        ? WishWallColors.accent
                                        : WishWallColors.line,
                                  ),
                                ),
                                child: Text(
                                  v.shortLabel,
                                  style: TextStyle(
                                    fontFamily: WishWallText.family,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? WishWallColors.accent2
                                        : WishWallColors.ink2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WishWallColors.accent,
                        disabledBackgroundColor: WishWallColors.line2,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(
                              '❖ 소원 봉인하기',
                              style: WishWallText.label(color: Colors.white)
                                  .copyWith(fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
