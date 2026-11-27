import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_provider.dart';
import '../data/real_name_hanja_store.dart';
import 'theme/mypage_minimal_theme.dart';
import 'theme/mypage_toast.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S14] "실명 등록" 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S14 실명 등록" 스펙
/// (히어로 타이틀 "풀이에 쓰일 / 이름을 알려 주세요", 리드 문단, 이름(한글)/
/// 이름(한자 · 선택, Noto Serif) 밑줄 입력 2개, CTA "저장하기")에 따른
/// 전면 신규 화면이다. 기존 `SettingsMinimalScreen._editRealName()`의
/// 작은 Dialog 팝업(S12 작업 당시 "S14 전용 화면이 아직 없어 임시로 기존
/// 진입점 재사용"이라고 명시했던 그 자리)을 이 화면으로 교체한다 —
/// S03/S05/S09/S11/S12/S13과 동일한 "신규 파일 + 호출부만 교체" 패턴이다.
///
/// [범위 결정 — 한글/한자 2개 입력의 서로 다른 저장 경로]
/// - 이름(한글): 기존 서버 필드 [UserModel.realName]
///   (`admin_web/prisma/schema.prisma` UserProfile.real_name, `PATCH
///   /api/.../profile`)에 이미 저장 경로가 있다 — [AuthProvider.updateProfile]
///   (realName:)을 그대로 호출한다("로직은 그대로, 스킨만 교체" 원칙).
/// - 이름(한자 · 선택): README 스펙상 선택 입력이지만, `UserModel`에도
///   admin_web 스키마에도 대응 서버 컬럼이 전혀 없다. 이 작업(flutter_app
///   저장소 한정 대화)은 백엔드 스키마를 변경할 범위가 아니므로(3개 저장소
///   커밋을 섞지 않는 운영 정책), 새 서버 필드를 임의로 추가하지 않는다 —
///   대신 로컬 전용 [RealNameHanjaStore](SharedPreferences 기반, 사용자별
///   키 분리)를 신설해 사용한다. 자세한 설계 근거는 해당 파일의 문서
///   주석을 참고. 추후 서버 컬럼이 기획 확정되면 이 화면의 저장 호출부만
///   `AuthProvider.updateProfile`로 교체하면 된다.
class RealNameMinimalScreen extends StatefulWidget {
  const RealNameMinimalScreen({super.key});

  @override
  State<RealNameMinimalScreen> createState() => _RealNameMinimalScreenState();
}

class _RealNameMinimalScreenState extends State<RealNameMinimalScreen> {
  final TextEditingController _koreanController = TextEditingController();
  final TextEditingController _hanjaController = TextEditingController();

  bool _submitting = false;
  bool _hanjaLoaded = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      _koreanController.text = user.realName?.trim() ?? '';
      _loadHanja(user.id);
    } else {
      _hanjaLoaded = true;
    }
  }

  Future<void> _loadHanja(String userId) async {
    final saved = await RealNameHanjaStore.get(userId);
    if (!mounted) return;
    setState(() {
      if (saved != null && saved.isNotEmpty) {
        _hanjaController.text = saved;
      }
      _hanjaLoaded = true;
    });
  }

  @override
  void dispose() {
    _koreanController.dispose();
    _hanjaController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    final korean = _koreanController.text.trim();
    if (korean.isEmpty) {
      showMyPageToast(context, '이름을 입력해주세요');
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final ok = await auth.updateProfile(realName: korean);
    if (!context.mounted) return;

    if (!ok) {
      setState(() => _submitting = false);
      showMyPageToast(
        context,
        auth.lastProfileUpdateError ?? '이름을 저장하지 못했습니다. 다시 시도해주세요.',
      );
      return;
    }

    // [범위 결정] 한자 이름은 로컬 전용 저장소에만 반영한다(서버 왕복
    // 불필요 — RealNameHanjaStore 문서 주석 참고).
    if (user != null) {
      await RealNameHanjaStore.save(user.id, _hanjaController.text);
    }
    if (!context.mounted) return;

    setState(() => _submitting = false);
    showMyPageToast(context, '이름을 저장했어요');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // README "서브화면 공통 셸" 상단바.
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 52, 12, 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 40,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: MyPageColors.ink,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            '실명 등록',
                            textAlign: TextAlign.center,
                            style: MyPageTextStyles.header,
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    MyPageSpacing.subX,
                    6,
                    MyPageSpacing.subX,
                    140,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const Text(
                        '풀이에 쓰일\n이름을 알려 주세요',
                        style: MyPageTextStyles.display,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '성명학 풀이와 궁합에 함께 쓰여요',
                        style: MyPageTextStyles.body,
                      ),
                      const SizedBox(height: 28),
                      const _FieldLabel('이름 (한글)'),
                      _UnderlineInput(
                        controller: _koreanController,
                        hintText: '이름을 입력해주세요',
                      ),
                      const SizedBox(height: 28),
                      const _FieldLabel('이름 (한자 · 선택)'),
                      _UnderlineInput(
                        controller: _hanjaController,
                        hintText: '金瑞娟',
                        fontFamily: MyPageFonts.hanja,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            // README ".dock" — 하단 고정 CTA(투명→paper 그라디언트 배경).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00F7EEDC),
                      MyPageColors.paper,
                    ],
                    stops: [0.0, 0.5],
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_submitting || !_hanjaLoaded)
                        ? null
                        : () => _submit(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyPageColors.red,
                      disabledBackgroundColor: MyPageColors.red.withValues(
                        alpha: 0.5,
                      ),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MyPageRadius.cta),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '저장하기',
                            style: TextStyle(
                              fontFamily: MyPageFonts.ui,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: MyPageFonts.ui,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: MyPageColors.ink3,
        ),
      ),
    );
  }
}

/// README ".inp" — 밑줄 전용 입력란. [fontFamily]를 지정하면 README의
/// "이름(한자 · 선택, Noto Serif)" 요구처럼 입력 글꼴만 바꿀 수 있다.
class _UnderlineInput extends StatelessWidget {
  const _UnderlineInput({
    required this.controller,
    required this.hintText,
    this.fontFamily = MyPageFonts.ui,
  });
  final TextEditingController controller;
  final String hintText;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: 12,
      style: TextStyle(
        fontFamily: fontFamily,
        fontWeight: fontFamily == MyPageFonts.hanja ? FontWeight.w900 : null,
        fontSize: 18,
        color: MyPageColors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        hintText: hintText,
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          color: MyPageColors.ink3,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0x3F2A1F14), width: 1.5),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: MyPageColors.red, width: 1.5),
        ),
      ),
    );
  }
}
