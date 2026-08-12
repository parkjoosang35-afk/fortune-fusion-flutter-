import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_wall_theme.dart';
import '../widgets/bottle_widget.dart';
import 'wish_wall_success_screen.dart';

/// 03. 소원 담기 — 5-step 작성 플로우.
///
/// [handoff.zip] design/wb3-compose.jsx `BottleCompose`를 Flutter로 이식.
/// Step1 카테고리 선택 → Step2 밝기(정성) → Step3 본문(200자+PII경고) →
/// Step4 공개범위 → Step5 미리보기+봉인. 상단 3px 앰버 진행바.
class WishWallComposeScreen extends StatefulWidget {
  const WishWallComposeScreen({super.key});

  @override
  State<WishWallComposeScreen> createState() => _WishWallComposeScreenState();
}

class _WishWallComposeScreenState extends State<WishWallComposeScreen> {
  int _step = 1;
  WishCategory? _categoryId;
  double _glassLevel = 0;
  final _textController = TextEditingController();
  WishVisibility _visibility = WishVisibility.anonymous;
  bool _submitting = false;

  static const List<String> _brightnessLabels = [
    '조용히',
    '차분히',
    '따스히',
    '밝게',
    '가장 밝게',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canNext {
    switch (_step) {
      case 1:
        return _categoryId != null;
      case 2:
        return _glassLevel > 0;
      case 3:
        return _textController.text.trim().length >= 5;
      case 4:
        return true;
      case 5:
        return true;
      default:
        return false;
    }
  }

  void _next() {
    if (!_canNext) return;
    if (_step < 5) {
      setState(() => _step += 1);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step -= 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (_categoryId == null || _submitting) return;
    setState(() => _submitting = true);
    final wish = await context.read<WishWallProvider>().createWish(
          categoryId: _categoryId!,
          glassLevel: _glassLevel,
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
      body: SafeArea(
        child: Column(
          children: [
            // 진행바
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  Expanded(
                    child: Row(
                      children: List.generate(5, (i) {
                        final idx = i + 1;
                        final active = idx <= _step;
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: active
                                  ? WishWallColors.accent
                                  : WishWallColors.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$_step/5', style: WishWallText.caption()),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _buildStep(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_canNext && !_submitting) ? _next : null,
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
                          _step < 5 ? '다음' : '소원 봉인하기',
                          style: WishWallText.label(color: Colors.white)
                              .copyWith(fontSize: 15),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _Step1(
          key: const ValueKey('s1'),
          selected: _categoryId,
          onSelect: (c) => setState(() => _categoryId = c),
        );
      case 2:
        return _Step2(
          key: const ValueKey('s2'),
          value: _glassLevel,
          labels: _brightnessLabels,
          category: _categoryId ?? WishCategory.etc,
          onChanged: (v) => setState(() => _glassLevel = v),
        );
      case 3:
        return _Step3(
          key: const ValueKey('s3'),
          controller: _textController,
          onChanged: (_) => setState(() {}),
        );
      case 4:
        return _Step4(
          key: const ValueKey('s4'),
          value: _visibility,
          onChanged: (v) => setState(() => _visibility = v),
        );
      case 5:
        return _Step5(
          key: const ValueKey('s5'),
          category: _categoryId ?? WishCategory.etc,
          glassLevel: _glassLevel,
          text: _textController.text.trim(),
          visibility: _visibility,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepPrompt extends StatelessWidget {
  const _StepPrompt({required this.eyebrow, required this.title, this.sub});
  final String eyebrow;
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: WishWallText.mono()),
        const SizedBox(height: 6),
        Text(title, style: WishWallText.title1().copyWith(fontSize: 24)),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub!, style: WishWallText.body(color: WishWallColors.muted)),
        ],
      ],
    );
  }
}

/// Step1 — 9개 카테고리 3x3 그리드.
class _Step1 extends StatelessWidget {
  const _Step1({super.key, required this.selected, required this.onSelect});
  final WishCategory? selected;
  final ValueChanged<WishCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepPrompt(
            eyebrow: 'STEP 1',
            title: '어떤 소원을 담을까요?',
            sub: '가장 가까운 마음의 카테고리를 골라주세요',
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.92,
            children: WishCategory.values.map((c) {
              final active = selected == c;
              return InkWell(
                onTap: () => onSelect(c),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? WishWallColors.ink : WishWallColors.bg2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? WishWallColors.ink : WishWallColors.line,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? c.lightColor.withValues(alpha: 0.9)
                              : c.glassColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: WishWallText.family,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : WishWallColors.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Step2 — 밝기(정성) 슬라이더.
class _Step2 extends StatelessWidget {
  const _Step2({
    super.key,
    required this.value,
    required this.labels,
    required this.category,
    required this.onChanged,
  });
  final double value;
  final List<String> labels;
  final WishCategory category;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final idx = (value * 4).round().clamp(0, 4);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepPrompt(
            eyebrow: 'STEP 2',
            title: '얼마나 밝게 빌어볼까요?',
            sub: '병 속 불빛의 밝기로 마음의 정성을 표현해요',
          ),
          const SizedBox(height: 28),
          Center(
            child: BottleWidget(
              category: category,
              size: 130,
              glow: value,
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: WishWallColors.accent,
              inactiveTrackColor: WishWallColors.line,
              thumbColor: WishWallColors.accent,
              overlayColor: WishWallColors.accent.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              min: 0,
              max: 1,
            ),
          ),
          Center(
            child: Text(
              labels[idx],
              style: WishWallText.label(color: WishWallColors.accent2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step3 — 본문 입력(200자 제한 + PII 경고).
class _Step3 extends StatelessWidget {
  const _Step3({super.key, required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepPrompt(
            eyebrow: 'STEP 3',
            title: '어떤 소원인가요?',
            sub: '짧게라도 마음을 적어주세요 (최소 5자)',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: WishWallColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: WishWallColors.line),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLength: 200,
              maxLines: 6,
              style: WishWallText.body().copyWith(height: 1.5),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '이번엔 이런 마음을 담아봐요...',
                counterText: '',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length}/200',
              style: WishWallText.caption(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WishWallColors.bg3,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 15, color: WishWallColors.dim),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '이름, 연락처, 계좌번호 등 개인정보는 적지 말아주세요. 모두가 함께 보는 공간이에요.',
                    style: WishWallText.caption(color: WishWallColors.dim),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Step4 — 공개범위 선택.
class _Step4 extends StatelessWidget {
  const _Step4({super.key, required this.value, required this.onChanged});
  final WishVisibility value;
  final ValueChanged<WishVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepPrompt(
            eyebrow: 'STEP 4',
            title: '누구에게 보여줄까요?',
          ),
          const SizedBox(height: 20),
          ...WishVisibility.values.map((v) {
            final active = value == v;
            final desc = switch (v) {
              WishVisibility.anonymous => '이름 없이 소원벽에 공개돼요',
              WishVisibility.public => '내 이름과 함께 소원벽에 공개돼요',
              WishVisibility.private => '나만 볼 수 있어요 (소원벽에는 안 보여요)',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onChanged(v),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: active ? WishWallColors.accentSoft : WishWallColors.bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? WishWallColors.accent : WishWallColors.line,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: active ? WishWallColors.accent2 : WishWallColors.dim,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.label,
                              style: WishWallText.body().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(desc, style: WishWallText.caption()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Step5 — 미리보기.
class _Step5 extends StatelessWidget {
  const _Step5({
    super.key,
    required this.category,
    required this.glassLevel,
    required this.text,
    required this.visibility,
  });
  final WishCategory category;
  final double glassLevel;
  final String text;
  final WishVisibility visibility;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepPrompt(
            eyebrow: 'STEP 5',
            title: '이대로 병을 봉인할까요?',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: WishWallColors.bg2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                BottleWidget(category: category, size: 130, glow: glassLevel),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: WishWallColors.bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: WishWallColors.line),
                  ),
                  child: Text(
                    '#${category.label}',
                    style: WishWallText.caption().copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    text.isEmpty ? '(내용 없음)' : text,
                    textAlign: TextAlign.center,
                    style: WishWallText.bodyLarge(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _MetaRow(label: '공개범위', value: visibility.shortLabel),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WishWallColors.bg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: WishWallText.caption()),
          const Spacer(),
          Text(
            value,
            style: WishWallText.body().copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
