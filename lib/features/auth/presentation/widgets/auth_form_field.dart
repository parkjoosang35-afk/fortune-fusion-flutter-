import 'package:flutter/material.dart';
import '../../../intro/presentation/intro_palette.dart';
import '../../../intro/presentation/intro_text_styles.dart';

/// [Phase B - 02_SignUp_Login.html 반영] `.field` 블록(라벨+입력+힌트) 전체를
/// 재현하는 로그인/회원가입 전용 텍스트필드.
///
/// 기존 `core/widgets/app_text_field.dart`(앱 전역 화이트 톤)는 그대로 두고,
/// 이 위젯은 인트로 3화면과 동일한 "범위 격리 원칙"에 따라 auth 프레젠테이션
/// 레이어 전용으로 신설했다 — `IntroPalette`/`IntroTextStyles`만 참조하며
/// 앱 전역 메인 컬러(`core/theme/app_colors.dart` 등)는 참조하지 않는다.
class AuthFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool required;
  final String hintText;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  // [회원가입·본인 사주정보 통합 흐름 전면 검수 지시서 §4] 이메일 blur
  // 중복확인 — 호출부(SignupScreen)가 포커스 상실 시점을 직접 감지해야
  // 서버 조회를 트리거할 수 있도록, 기존 "내부 전용 FocusNode" 구조를 깨지
  // 않으면서 외부에서 주입할 수 있는 옵션을 추가한다. 넘기지 않으면 기존과
  // 동일하게 내부에서 자체 생성한다(다른 모든 AuthFormField 사용처는 변경 없음).
  final FocusNode? focusNode;
  // `hint`가 가변 상태 메시지(확인 중/사용 가능/중복됨)로 쓰일 때, 상태에
  // 따라 색을 바꿀 수 있도록 선택적 색상 오버라이드를 추가한다. 지정하지
  // 않으면 기존처럼 textSecondary 톤을 그대로 쓴다.
  final Color? hintColor;

  const AuthFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.required = false,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.focusNode,
    this.hintColor,
  });

  @override
  State<AuthFormField> createState() => _AuthFormFieldState();
}

class _AuthFormFieldState extends State<AuthFormField> {
  late bool _obscure = widget.obscureText;
  // 외부에서 focusNode를 주입하면 그것을 그대로 쓰고(소유권도 외부에 남겨둔다 —
  // dispose는 호출하지 않는다), 주입하지 않으면 기존과 동일하게 내부에서
  // 생성·관리한다.
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool get _ownsFocusNode => widget.focusNode == null;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = _focusNode.hasFocus;
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // `.field-label`
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: RichText(
              text: TextSpan(
                style: IntroTextStyles.fieldLabel(),
                children: [
                  TextSpan(text: widget.label),
                  if (widget.required)
                    TextSpan(
                      text: ' *',
                      style: IntroTextStyles.fieldLabel(
                        color: IntroPalette.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // `.field-input-wrap`
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _focused
                  ? IntroPalette.primary.withValues(alpha: 0.05)
                  : IntroPalette.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? IntroPalette.danger.withValues(alpha: 0.6)
                    : _focused
                    ? IntroPalette.primary.withValues(alpha: 0.6)
                    : IntroPalette.cardBorder,
                width: 1,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: IntroPalette.primary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: widget.obscureText && _obscure,
                    keyboardType: widget.keyboardType,
                    style: IntroTextStyles.fieldInput(),
                    cursorColor: IntroPalette.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: IntroTextStyles.fieldPlaceholder(),
                    ),
                  ),
                ),
                if (widget.obscureText)
                  GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: IntroPalette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // `.field-hint` — 에러가 있으면 danger 톤으로, 없으면 기본 힌트 문구.
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                widget.errorText!,
                style: IntroTextStyles.fieldHint(color: IntroPalette.danger),
              ),
            )
          else if (widget.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                widget.hint!,
                style: IntroTextStyles.fieldHint(color: widget.hintColor),
              ),
            ),
        ],
      ),
    );
  }
}
