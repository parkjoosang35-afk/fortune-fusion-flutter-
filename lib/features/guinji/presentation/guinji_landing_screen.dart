import 'package:flutter/material.dart';

import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_landing_widgets.dart';
import '../widgets/guinji_map_widgets.dart';

/// L · Landing — `/guinji-map`
///
/// [2026-09 새 디자인 리스킨] 사용자 지시("그냥다 새디자인")에 따라 새
/// 디자인 zip `lib/guiindo/screens/landing_screen.dart`의 아이보리+로즈골드
/// 긴 스크롤 레이아웃으로 전면 교체했다. 데이터 흐름·라우팅은 기존 그대로
/// 유지한다: CTA는 여전히 I(Input) 화면(`/guinji-map/new`)으로 이동하며,
/// 회원가입/로그인 없이 누구나 접근 가능한 첫 진입 페이지라는 성격도
/// 그대로다.
class GuinjiLandingScreen extends StatelessWidget {
  const GuinjiLandingScreen({super.key});

  static const routeName = '/guinji-map';

  @override
  Widget build(BuildContext context) {
    const hostName = 'OO';

    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(
        onShare: () => _openShareSheet(context),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GmHeroSection(variant: GmHeroVariant.host, hostName: hostName),
              const GmPreviewCard(hostName: hostName),
              _GmInlineStartSection(
                hostName: hostName,
                onSubmit: () => Navigator.of(context).pushNamed('/guinji-map/new'),
              ),
              const GmRelationOverview(hostName: hostName),
              const GmNodeMapPreview(hostName: hostName),
              const GmLabelCategoriesSection(),
              GmUpsellCta(
                onStart: () => Navigator.of(context).pushNamed('/guinji-map/new'),
              ),
              const GmServiceGrid(),
              const GmFooterSection(),
            ],
          ),
        ),
      ),
    );
  }

  void _openShareSheet(BuildContext context) {
    Navigator.of(context).pushNamed('/guinji-map/m/share');
  }
}

/// 새 디자인 `InputFormSection`(랜딩 인라인 축약 폼) 대응 — 이 프로젝트는
/// 실제 입력을 I(Input) 화면에서만 받으므로, 랜딩에서는 시각적 안내만
/// 보여주고 탭하면 곧바로 I 화면으로 이동한다.
class _GmInlineStartSection extends StatelessWidget {
  const _GmInlineStartSection({required this.hostName, required this.onSubmit});

  final String hostName;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        border: const Border(
          top: BorderSide(color: GmColors.line),
          bottom: BorderSide(color: GmColors.line),
        ),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '✦ ', style: TextStyle(color: GmColors.rose500)),
                TextSpan(text: '나는 $hostName님에게 어떤 사람일까?', style: const TextStyle(fontSize: 13, color: GmColors.inkSoft)),
                const TextSpan(text: ' ✦', style: TextStyle(color: GmColors.rose500)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            '정확한 궁합의 분석을 위해 정보를 입력해주세요.',
            style: TextStyle(fontSize: 11.5, color: GmColors.inkFaint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GmPrimaryButton(label: '관계 결과 확인하기', onPressed: onSubmit),
          const SizedBox(height: 10),
          const Text(
            '입력 정보는 분석 후 다른 용도로 사용되지 않아요.',
            style: TextStyle(fontSize: 11, color: GmColors.inkFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
