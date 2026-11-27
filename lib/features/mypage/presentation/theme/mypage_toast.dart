import 'package:flutter/material.dart';
import 'mypage_minimal_theme.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S09~] design_handoff_mypage_minimal
/// .zip README §4 "토스트" 공통 스펙(하단 탭 위 bottom 108, pill, bg
/// rgba(42,31,20,.92), fg #f8f2e6, translateY 20→0 500ms, 1.6초 뒤 소멸)을
/// Minimal 테마 서브화면들(S05 이후)에서 공용으로 쓰기 위한 헬퍼.
///
/// S05에서는 아직 이 헬퍼가 없어 기본 [SnackBar]를 그대로 썼지만(전역 다크
/// 테마 바탕이라도 플로팅 방식이라 큰 위화감은 없었다), S09부터는 서브화면
/// 자체가 Minimal 배경이므로 토스트도 같은 톤으로 맞춘다. 기존 S05 호출부는
/// 동작에 문제가 없으므로 그대로 두고(회귀 방지), 이후 신규 화면부터
/// 이 헬퍼를 사용한다.
void showMyPageToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEB2A1F14), // rgba(42,31,20,.92)
        margin: const EdgeInsets.fromLTRB(40, 0, 40, 108),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MyPageRadius.pill),
        ),
        duration: const Duration(milliseconds: 1600),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: MyPageFonts.ui,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFFF8F2E6),
          ),
        ),
      ),
    );
}
