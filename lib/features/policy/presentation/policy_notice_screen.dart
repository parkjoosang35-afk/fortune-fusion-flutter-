import 'package:flutter/material.dart';
import '../../intro/presentation/intro_palette.dart';
import '../../intro/presentation/intro_text_styles.dart';

/// [핸드오프 콘텐츠 반영 - 신규] 인트로 페이지4 CTA의 링크
/// `"재미·참고용" 콘텐츠 안내`(`onDisclaimerTap() → router.push('/policy/notice')`)
/// 대상 화면. 핸드오프 문서에는 이 화면 자체의 상세 디자인(HTML)이 포함되어
/// 있지 않아, 프로젝트에 이미 존재하는 면책 문구 표준안
/// (`core/widgets/fortune/disclaimer_banner.dart`의 공통 문구)을 인트로
/// 팔레트 톤(Moonlit Crystal)으로 감싸 단순 안내 화면으로 구성했다.
///
/// [범위 격리 원칙] 이 화면은 인트로 진입 흐름에서만 연결되므로 인트로 전용
/// 팔레트/폰트를 그대로 재사용하고 앱 전역 UnifiedColors는 참조하지 않는다.
class PolicyNoticeScreen extends StatelessWidget {
  const PolicyNoticeScreen({super.key});

  static const _body =
      '신통방통의 모든 콘텐츠(사주·타로·궁합·관상·손금 등)는 전통 해석을 바탕으로 '
      '재미와 참고를 위해 제공되는 콘텐츠예요.\n\n'
      '실제 중요한 결정(건강·금전·법적 효력이 필요한 일정 등)은 이 내용만으로 '
      '판단하지 말고, 본인의 상황과 관련 전문가의 의견을 함께 고려해주세요.\n\n'
      '신통도령과 함께하는 모든 풀이는 여러분의 하루를 즐겁게 채워드리기 위한 '
      '이야기이며, 미래를 확정적으로 예측하지 않습니다.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [IntroPalette.backgroundTop, IntroPalette.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: IntroPalette.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"재미·참고용"\n콘텐츠 안내',
                        style: IntroTextStyles.title(fontSize: 26),
                      ),
                      const SizedBox(height: 20),
                      Text(_body, style: IntroTextStyles.sub()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
