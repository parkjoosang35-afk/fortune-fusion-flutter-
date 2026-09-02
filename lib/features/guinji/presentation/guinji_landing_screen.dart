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
///
/// [2026-09 흐름 정합성 수정] 기존 문구("나는 $hostName님에게 어떤 사람일까?")는
/// 아직 아무 관계도 생성되지 않은 신규 방문 시점에 마치 실존하는 "OO"라는
/// 상대와 이미 관계가 있는 것처럼 읽혀 사용자 혼란을 유발했다(리포트:
/// "귀인지도을 만들려면 일단 내가 어떤 사람인지 사주을보고... 지인에게
/// 링크을 보내는게 맞는것 아니야?"). 실제 정상 흐름은 정확히 사용자가
/// 말한 그대로다: 내 정보 입력 → 내 결과(귀인지도) 확인 → 그 결과를 근거로
/// 지인에게 링크 공유. 이 위젯의 문구를 그 순서에 맞춰 다시 쓰고, 3단계
/// 미니 가이드를 추가해 진행 순서를 명시적으로 보여준다.
class _GmInlineStartSection extends StatelessWidget {
  const _GmInlineStartSection({required this.hostName, required this.onSubmit});

  // ignore: unused_field
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
                const TextSpan(text: '내가 어떤 사람인지부터 확인해볼까요?', style: TextStyle(fontSize: 13, color: GmColors.inkSoft)),
                const TextSpan(text: ' ✦', style: TextStyle(color: GmColors.rose500)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            '정확한 사주 분석을 위해 내 정보를 입력해주세요.',
            style: TextStyle(fontSize: 11.5, color: GmColors.inkFaint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const _GmMiniStepsGuide(),
          const SizedBox(height: 20),
          GmPrimaryButton(label: '내 사주 확인하기', onPressed: onSubmit),
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

/// [2026-09 흐름 정합성 수정] 랜딩에서 CTA를 누르기 전에 전체 진행 순서
/// (내 정보 입력 → 내 귀인지도 확인 → 지인에게 공유)를 한눈에 보여주는
/// 3단계 미니 가이드. 새 디자인 zip의 `create_intro_screen.dart`(Y·만들기
/// 인트로, 이 프로젝트에는 별도 화면으로 이식하지 않았다)가 보여주던
/// 3-Step 안내를 화면 추가 없이 이 인라인 섹션에 축약해 반영한다.
class _GmMiniStepsGuide extends StatelessWidget {
  const _GmMiniStepsGuide();

  static const _steps = [
    ('01', '내 정보 입력', '이름·생년월일·태어난 시간'),
    ('02', '나의 귀인지도 확인', '내 사주 기반 관계 지도 확인'),
    ('03', '지인에게 공유', '링크로 보내면 관계가 채워져요'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, title, desc) in _steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: GmColors.rose50, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(index, style: const TextStyle(fontSize: 10, color: GmColors.rose700, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: GmColors.ink)),
                      Text(desc, style: const TextStyle(fontSize: 10.5, color: GmColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
