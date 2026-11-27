import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';
import '../../intro/presentation/widgets/intro_title_text.dart';
import '../application/auth_provider.dart';
import 'widgets/auth_form_field.dart';
import 'widgets/auth_form_header.dart';
import 'widgets/auth_primary_button.dart';

/// [로그인 화면 "아이디 찾기" 버그수정 — 2026-09] 실제로 동작하는 아이디(이메일)
/// 찾기 화면. 닉네임 + 생년월일로 본인확인 후 마스킹된 이메일을 보여준다.
///
/// [정직성 원칙] 이 환경에는 이메일/SMS 발송 인프라가 없어(admin_web `.env`에
/// SMTP/SMS 키 없음) "메일로 전송" 방식은 실제로 구현할 수 없다. 대신 서버가
/// 보유한 데이터(닉네임 UNIQUE + UserProfile.birthDate)만으로 본인확인을
/// 수행해, 확인되면 그 자리에서 즉시 마스킹된 이메일을 보여주는 정공법으로
/// 구현했다(가짜 성공 안내 금지 — login_screen.dart의 기존 정직성 원칙과 동일).
///
/// [신통도령 캐릭터 제거 원칙 - 2026-09] 사용자 지시로 이 신규 화면에는
/// IntroCharacter(신통도령)를 처음부터 넣지 않는다.
class FindEmailScreen extends StatefulWidget {
  const FindEmailScreen({super.key});

  @override
  State<FindEmailScreen> createState() => _FindEmailScreenState();
}

class _FindEmailScreenState extends State<FindEmailScreen> {
  final _nicknameController = TextEditingController();
  DateTime? _birthDate;
  bool _isSubmitting = false;
  String? _resultMaskedEmail;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      AppToast.show(context, '닉네임을 입력해 주세요.', isError: true);
      return;
    }
    if (_birthDate == null) {
      AppToast.show(context, '생년월일을 선택해 주세요.', isError: true);
      return;
    }
    final birthDateStr =
        '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';

    setState(() {
      _isSubmitting = true;
      _resultMaskedEmail = null;
    });
    final maskedEmail = await context.read<AuthProvider>().findEmail(
      nickname: nickname,
      birthDate: birthDateStr,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (maskedEmail != null) {
      setState(() => _resultMaskedEmail = maskedEmail);
    } else {
      AppToast.show(
        context,
        context.read<AuthProvider>().lastError ?? '아이디를 찾을 수 없습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    IntroPalette.backgroundTop,
                    IntroPalette.backgroundBottom,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthFormHeader(
                    eyebrow: 'FIND · 아이디 찾기',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 26, top: 12),
                    child: Column(
                      children: [
                        IntroTitleText(
                          '가입할 때 쓴\n닉네임과 생년월일을 알려주세요',
                          style: IntroTextStyles.formTitle(),
                          highlight: '닉네임과 생년월일',
                          highlightColors: const [
                            IntroPalette.gold,
                            IntroPalette.primary,
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '본인 확인 후 가입하신 이메일을 알려드려요.',
                          textAlign: TextAlign.center,
                          style: IntroTextStyles.formSubtitle(),
                        ),
                      ],
                    ),
                  ),
                  AuthFormField(
                    controller: _nicknameController,
                    label: '닉네임',
                    hintText: '가입 시 사용한 닉네임',
                  ),
                  // 생년월일 선택 필드 — signup_screen.dart와 동일한 톤으로 직접 구현
                  // (AuthFormField는 텍스트 입력 전용이라 날짜 선택엔 재사용하지 않는다).
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8,
                            left: 2,
                          ),
                          child: Text(
                            '생년월일',
                            style: IntroTextStyles.fieldLabel(),
                          ),
                        ),
                        InkWell(
                          onTap: _pickBirthDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: IntroPalette.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: IntroPalette.cardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: IntroPalette.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _birthDate == null
                                      ? '생년월일 선택'
                                      : '${_birthDate!.year}년 ${_birthDate!.month}월 ${_birthDate!.day}일',
                                  style: _birthDate == null
                                      ? IntroTextStyles.fieldPlaceholder()
                                      : IntroTextStyles.fieldInput(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_resultMaskedEmail != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: IntroPalette.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: IntroPalette.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '가입하신 이메일이에요',
                            style: IntroTextStyles.fieldHint(),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _resultMaskedEmail!,
                            style: IntroTextStyles.formTitle().copyWith(
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  AuthPrimaryButton(
                    label: '아이디 찾기',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Text(
                        '로그인으로 돌아가기',
                        style: IntroTextStyles.bottomLink().copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: IntroPalette.textSecondary,
                        ),
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
