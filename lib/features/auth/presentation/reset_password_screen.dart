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

/// [로그인 화면 "비밀번호 찾기" 버그수정 — 2026-09] 실제로 동작하는 비밀번호
/// 재설정 화면. 이메일+닉네임+생년월일 3중 본인확인 후 그 자리에서 즉시 새
/// 비밀번호를 설정한다.
///
/// [정직성 원칙] find_email_screen.dart와 동일한 배경 — 이 환경에는 이메일
/// 발송 인프라가 없어 "재설정 링크 메일 발송" 방식은 구현 불가능하다. 대신
/// 서버가 실제로 DB의 비밀번호 해시를 갱신하는 정공법으로 구현했다.
///
/// [신통도령 캐릭터 제거 원칙 - 2026-09] 사용자 지시로 이 신규 화면에는
/// IntroCharacter(신통도령)를 처음부터 넣지 않는다.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();
  DateTime? _birthDate;
  bool _isSubmitting = false;
  bool _resetSuccess = false;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
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
    final email = _emailController.text.trim();
    final nickname = _nicknameController.text.trim();
    final newPassword = _newPasswordController.text;
    final newPasswordConfirm = _newPasswordConfirmController.text;

    if (email.isEmpty || nickname.isEmpty) {
      AppToast.show(context, '이메일과 닉네임을 입력해 주세요.', isError: true);
      return;
    }
    if (_birthDate == null) {
      AppToast.show(context, '생년월일을 선택해 주세요.', isError: true);
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _passwordError = '비밀번호는 8자 이상이어야 합니다.');
      return;
    }
    if (newPassword != newPasswordConfirm) {
      setState(() => _passwordError = '비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() => _passwordError = null);

    final birthDateStr =
        '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';

    setState(() => _isSubmitting = true);
    final ok = await context.read<AuthProvider>().resetPassword(
      email: email,
      nickname: nickname,
      birthDate: birthDateStr,
      newPassword: newPassword,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      setState(() => _resetSuccess = true);
    } else {
      AppToast.show(
        context,
        context.read<AuthProvider>().lastError ?? '비밀번호 재설정에 실패했습니다.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resetSuccess) {
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
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: IntroPalette.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '비밀번호가 변경되었어요',
                        style: IntroTextStyles.formTitle(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '새 비밀번호로 다시 로그인해 주세요.',
                        style: IntroTextStyles.formSubtitle(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AuthPrimaryButton(
                        label: '로그인하러 가기',
                        onPressed: () =>
                            Navigator.of(context).popUntil((r) => r.isFirst),
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
                    eyebrow: 'RESET · 비밀번호 재설정',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 26, top: 12),
                    child: Column(
                      children: [
                        IntroTitleText(
                          '본인 확인 후\n새 비밀번호로 바꿔드려요',
                          style: IntroTextStyles.formTitle(),
                          highlight: '본인 확인',
                          highlightColors: const [
                            IntroPalette.gold,
                            IntroPalette.primary,
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '가입 시 정보와 일치해야 변경할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: IntroTextStyles.formSubtitle(),
                        ),
                      ],
                    ),
                  ),
                  AuthFormField(
                    controller: _emailController,
                    label: '이메일',
                    hintText: 'example@fortunefusion.app',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AuthFormField(
                    controller: _nicknameController,
                    label: '닉네임',
                    hintText: '가입 시 사용한 닉네임',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 2),
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
                  AuthFormField(
                    controller: _newPasswordController,
                    label: '새 비밀번호',
                    hintText: '8자 이상 입력해 주세요',
                    obscureText: true,
                    errorText: _passwordError,
                  ),
                  AuthFormField(
                    controller: _newPasswordConfirmController,
                    label: '새 비밀번호 확인',
                    hintText: '한 번 더 입력해 주세요',
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  AuthPrimaryButton(
                    label: '비밀번호 재설정',
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
