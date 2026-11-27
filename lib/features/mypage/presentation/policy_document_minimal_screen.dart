import 'package:flutter/material.dart';

import '../../../core/config/env_config.dart';
import '../../guinji/presentation/guinji_policy_webview.dart';
import 'theme/mypage_minimal_theme.dart';

/// [마이페이지 리뉴얼 · DEV 2026-11-06 §S15] "약관 및 정책" 문서 화면.
///
/// design_handoff_mypage_minimal.zip README §4 "S15 약관 문서" 스펙에
/// 따른 전면 신규 화면이다. README는 조항 타이포(제목 15px/800, 본문
/// 13px/1.8)를 명시하면서도 "실제 약관 원문은 CMS/웹뷰로 불러옵니다"라고
/// 분명히 밝히고 있다 — 즉 조항 본문 자체를 Flutter 위젯으로 하드코딩해
/// 다시 그리는 것이 아니라, admin_web이 서빙하는 실제 약관 페이지를
/// 그대로 불러와 보여주는 것이 README가 의도한 구현이다.
///
/// [로직 재사용, 스킨만 교체] 이 화면은 새 조항 렌더러를 만들지 않고,
/// `guinji`에서 이미 쓰고 있는 [PolicyWebView](`guinji_policy_webview.dart`
/// 조건부 export — 모바일은 `webview_flutter` 네이티브 WebView, Web은
/// `dart:ui_web` 기반 `<iframe>`)를 그대로 재사용한다. 기존
/// `SettingsMinimalScreen`에서 이 3개 행(이용약관/개인정보처리방침/
/// 계정삭제 안내)은 외부 브라우저(`launchUrl(... externalApplication)`)로
/// 여는 임시 구현이었는데, 이 화면으로 교체해 "앱 안에서 스크롤해 보는"
/// README의 서브화면 경험을 제공한다. admin_web 쪽 `/terms`,
/// `/privacy-policy`, `/account-deletion` 페이지 자체(조항 제목/본문
/// 스타일 포함)는 변경하지 않는다 — 이 작업은 flutter_app 저장소 한정
/// 대화라 admin_web 코드는 건드리지 않는다.
class PolicyDocumentMinimalScreen extends StatelessWidget {
  const PolicyDocumentMinimalScreen({
    super.key,
    required this.title,
    required this.path,
  });

  /// 상단바에 표시할 제목(예: "이용약관", "개인정보처리방침", "계정삭제 안내").
  final String title;

  /// admin_web 기준 상대 경로(예: "/terms", "/privacy-policy",
  /// "/account-deletion").
  final String path;

  @override
  Widget build(BuildContext context) {
    final url = '${EnvConfig.adminApiBaseUrl}$path';
    return Scaffold(
      backgroundColor: MyPageColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // README "서브화면 공통 셸" 상단바.
            Padding(
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
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: MyPageTextStyles.header,
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            // 실제 약관 원문은 CMS/웹뷰(admin_web)로 불러온다.
            Expanded(
              child: Container(
                color: Colors.white,
                child: PolicyWebView(url: url),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
