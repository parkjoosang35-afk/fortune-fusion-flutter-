import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';
import 'guinji_onboarding_screen.dart';

/// 귀인지도(Guinji Map) — 09. 지인 참여(Guest Join) 화면.
///
/// [Phase G-7] `GUINJI_SCREENS.md` "09 · 지인 참여" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `JoinScreen`): 공유(S8)에서 받은 링크로 들어온
/// 지인이 이름·생년월일을 입력해 관계를 확인하는 폼 화면.
///
/// [Phase G-7 범위 — 절대 원칙 준수] 실제 "관계 확인" 로직(사주 계산 →
/// 5유형 판정 → 지도에 반영)은 백엔드 신규 테이블(guinji_map_member 등,
/// §5)이 아직 없어 구현하지 않는다. "✧ 관계 확인하기" 버튼은 입력값을
/// 받기만 하고 토스트로 대체하며, 어떤 재화 지급(초대자 20P 등)도 이
/// 화면에서는 발생하지 않는다(참여 이벤트 판정은 서버 최종판단 몫).
/// "나도 내 지도 만들기" Ghost 버튼은 이미 존재하는 온보딩(S2) 화면으로
/// 실제 이동한다(회원가입 유도 목적, 신규 로직 불필요).
class GuinjiJoinScreen extends StatefulWidget {
  const GuinjiJoinScreen({super.key, this.inviterName = '지민'});

  final String inviterName;

  @override
  State<GuinjiJoinScreen> createState() => _GuinjiJoinScreenState();
}

class _GuinjiJoinScreenState extends State<GuinjiJoinScreen> {
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  bool _noTime = false;

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    // [Phase G-7 범위] 실제 사주 계산·관계 판정·guinji_map_member 저장은
    // 백엔드 §5 완성 후 연결한다. 현재는 입력 여부만 안내한다.
    AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: _MonoLabel("INVITE · YOU'RE JOINING"),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Image.asset(
                            'assets/images/home/doryeong/greeting.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: GuinjiColors.surfaceCard,
                              border: Border.all(
                                color: GuinjiColors.surfaceCardBorder,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: widget.inviterName,
                                    style: const TextStyle(
                                      color: GuinjiColors.lavender,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(text: '님이\n당신을 귀인지도에 초대했어요'),
                                ],
                                style: const TextStyle(
                                  fontFamily: GuinjiFonts.body,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  height: 1.5,
                                  color: GuinjiColors.textPrimary,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: _MonoLabel('당신의 사주', fontSize: 9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _JoinFormCard(
                            nameController: _nameController,
                            yearController: _yearController,
                            monthController: _monthController,
                            dayController: _dayController,
                            noTime: _noTime,
                            onNoTimeChanged: (v) => setState(() => _noTime = v),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  _PrimaryCta(label: '관계 확인하기', onPressed: _handleSubmit),
                  const SizedBox(height: 6),
                  _GhostCta(
                    label: '나도 내 지도 만들기',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuinjiOnboardingScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '입력한 정보는 지도 소유자에게만 공유돼요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.ui,
                      fontSize: 10,
                      color: GuinjiColors.textSecondary,
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

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.fontSize = 10});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: fontSize,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: GuinjiColors.textSecondary,
      ),
    );
  }
}

/// 입력 폼 카드 — 이름/닉네임 + 생년월일 3칸 + "시간 몰라요" 체크박스.
class _JoinFormCard extends StatelessWidget {
  const _JoinFormCard({
    required this.nameController,
    required this.yearController,
    required this.monthController,
    required this.dayController,
    required this.noTime,
    required this.onNoTimeChanged,
  });

  final TextEditingController nameController;
  final TextEditingController yearController;
  final TextEditingController monthController;
  final TextEditingController dayController;
  final bool noTime;
  final ValueChanged<bool> onNoTimeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GuinjiColors.backgroundDeep.withValues(alpha: 0.75),
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonoLabel('이름 · 닉네임', fontSize: 8),
          const SizedBox(height: 4),
          _UnderlineTextField(
            controller: nameController,
            hintText: '어떻게 불릴까요',
            textAlign: TextAlign.left,
            fontFamily: GuinjiFonts.body,
          ),
          const SizedBox(height: 12),
          const _MonoLabel('생년월일 · 양력', fontSize: 8),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: _UnderlineTextField(
                  controller: yearController,
                  hintText: '2003',
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  fontFamily: GuinjiFonts.mono,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: _UnderlineTextField(
                  controller: monthController,
                  hintText: '05',
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  fontFamily: GuinjiFonts.mono,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: _UnderlineTextField(
                  controller: dayController,
                  hintText: '14',
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  fontFamily: GuinjiFonts.mono,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => onNoTimeChanged(!noTime),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: GuinjiColors.backgroundDeep.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: GuinjiColors.textSecondary,
                          width: 1.5,
                        ),
                        color: noTime
                            ? GuinjiColors.lavender
                            : Colors.transparent,
                      ),
                      child: noTime
                          ? const Icon(
                              Icons.check,
                              size: 13,
                              color: GuinjiColors.ink,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '태어난 시간을 몰라요',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.body,
                        fontSize: 12,
                        color: GuinjiColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 밑줄만 있는 투명 입력창(디자인 스펙의 `borderBottom` 스타일 재현).
class _UnderlineTextField extends StatelessWidget {
  const _UnderlineTextField({
    required this.controller,
    required this.hintText,
    required this.textAlign,
    required this.fontFamily,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hintText;
  final TextAlign textAlign;
  final String fontFamily;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: textAlign,
      maxLength: maxLength,
      keyboardType: maxLength != null
          ? TextInputType.number
          : TextInputType.text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontWeight: maxLength != null ? FontWeight.w500 : FontWeight.w400,
        fontSize: 15,
        letterSpacing: maxLength != null ? 1.5 : 0,
        color: GuinjiColors.textPrimary,
      ),
      cursorColor: GuinjiColors.lavender,
      decoration: InputDecoration(
        hintText: hintText,
        counterText: '',
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          color: GuinjiColors.textSecondary.withValues(alpha: 0.5),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: GuinjiColors.surfaceCardBorder),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: GuinjiColors.lavender),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: GuinjiColors.lavender,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: GuinjiColors.glowShadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '✧ ',
                  style: TextStyle(fontSize: 15, color: GuinjiColors.ink),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: GuinjiColors.ink,
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

class _GhostCta extends StatelessWidget {
  const _GhostCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: GuinjiColors.surfaceCardBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: GuinjiFonts.ui,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: GuinjiColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
