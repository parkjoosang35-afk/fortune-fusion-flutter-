import 'package:flutter/material.dart';

import '../../../core/router/main_bottom_nav_bar.dart';
import '../domain/guinji_person.dart';
import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_animated_graph.dart';
import '../widgets/guinji_map_widgets.dart';

/// Y · Guest Result — 바이럴 링크로 들어온 게스트가 자신의 사주를 입력한 뒤,
/// 호스트와의 관계 판정 결과를 확인하는 화면.
///
/// [2026-09 새 디자인 리스킨] 새 디자인 zip에는 이 화면과 1:1 대응하는
/// 화면이 없다(`create_intro_screen.dart`는 "만들기 인트로"로 목적이 다름).
/// 따라서 새 디자인의 아이보리+로즈골드 팔레트·타이포그래피·공용 위젯
/// (`GmTopBar`/`GmChip`/`GmLabelMini`/`GmRoseButton`)만 재사용해 이 화면
/// 고유의 레이아웃(방통선녀 bobbing 캐릭터 + 결과 카드 + CTA)을 재도색했다.
/// [주의] 새 디자인의 `ResultAppHandoff`는 위젯 주석에 "결과 화면(M/N)에서만
/// 사용, 다른 화면엔 절대 넣지 말 것"이라 명시되어 있어 이 화면에는 사용하지
/// 않는다.
///
/// [절대 원칙 — 바이럴 게스트 플로우] 이 화면은:
///  (a) 회원가입 없이 도달 가능해야 하고,
///  (b) 결과를 완전히 확인할 수 있는 완결된 경험이어야 하며(추가 결제/
///      가입 장벽 없음),
///  (c) 하단의 "내 지도 만들기" CTA는 게스트가 **스스로 원할 때만** 누르는
///      선택적 전환 유도일 뿐, 이 화면에 도달하거나 머무는 동안 자동으로
///      회원가입/앱으로 리다이렉트되는 로직은 **절대 포함하지 않는다**.
///      (`Timer`/`Future.delayed` 등으로 자동 전환하는 코드를 추가하지
///      말 것 — 사용자가 과거에 이 문제로 강하게 항의한 바 있음. 리스킨
///      이후에도 이 원칙은 그대로 유지된다.)
class GuinjiGuestResultScreen extends StatelessWidget {
  const GuinjiGuestResultScreen({
    super.key,
    required this.hostName,
    required this.relationKey,
    required this.score,
    this.evidenceSummary = '오행 보충도 +0.82 · 희신 일치 · 합 2',
    this.narratorText,
    this.onCreateOwnMap,
    this.guestName,
    this.mapTotal,
  });

  static const routeName = '/guinji-map/guest/result';

  /// 지도 소유자(호스트) 이름.
  final String hostName;
  final String relationKey;
  final int score;
  final String evidenceSummary;

  /// 결과 본문 서술(방통선녀 나레이션). null이면 [relationKey] 메타의
  /// long 설명을 사용해 기본 문구를 생성한다.
  final String? narratorText;

  /// "내 지도 만들기" CTA — 게스트가 스스로 눌렀을 때만 호출된다(자동
  /// 트리거 금지).
  final VoidCallback? onCreateOwnMap;

  /// [바이럴 페이지 개편] 게스트가 참여 화면에서 직접 입력한 이름(닉네임).
  /// null이면 애니메이션 지도 중앙 라벨을 "나"로 대체한다.
  final String? guestName;

  /// [바이럴 페이지 개편] `joinAnonymous` 응답의 `mapSummary.total`(호스트
  /// 지도에 참여 중인 전체 인원 수) — "지금 N명이 함께해요" 안내에 사용.
  /// null이면 안내 문구 자체를 숨긴다.
  final int? mapTotal;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[relationKey];
    final category = meta?.category ?? 'boost';
    final color = GmColors.categoryColor(category);
    final label = meta?.label ?? relationKey;
    final hanja = meta?.hanja ?? '?';
    final body =
        narratorText ??
        meta?.long ??
        '$hostName님의 결을 강하게 살려주는 결이에요. '
            '두 분이 함께 있으면 서로의 부족한 흐름이 채워집니다.';

    // [바이럴 페이지 개편 — "메인귀인지도 기능들이 다 나옴"] 게스트 본인을
    // 중심(center)에 두고, 초대한 호스트를 관계 노드 1개로 표시하는 미니
    // 애니메이션 지도. M(My Map)화면과 동일한 [GuinjiAnimatedRelationGraph]
    // 위젯을 그대로 재사용해 회원가입한 사용자가 보는 지도와 동일한 시각
    // 언어(회전 궤도 링·레이더 펄스·호흡하는 노드·에너지 흐름)를 로그인
    // 없이도 그 자리에서 체험할 수 있게 한다.
    final hostNode = GuinjiPerson(
      id: 'host',
      name: hostName,
      birth: '',
      ohaeng: 'to',
      relation: relationKey,
      score: score,
      note: evidenceSummary,
    );
    final centerName = (guestName == null || guestName!.isEmpty) ? '나' : guestName!;

    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(
        back: true,
        title: '게스트 결과',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      // [바이럴 페이지 개편 — 하단바] 바이럴 웹페이지는 신통방통과 같은
      // 도메인(Flutter Web 빌드)에서 서빙되므로, 하단바 탭을 누르면 곧바로
      // 신통방통 메인 앱(홈/운세/소원방/복주머니/마이)으로 연결된다. 이것이
      // "바이럴 페이지는 웹이고 신통방통은 도메인으로 움직이기에 가능하다"는
      // 사용자 설명의 실제 구현이다.
      bottomNavigationBar: const MainBottomNavBar(currentIndex: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          children: [
            const SizedBox(
              width: 120,
              height: 120,
              child: _BobbingSeonnyeo(),
            ),
            const SizedBox(height: 4),
            const GmLabelMini('▸ 방통선녀 · RESULT'),
            const SizedBox(height: 10),
            // [렌더 버그 방지] 줄바꿈이 들어가는 첫 줄과 색상이 다른
            // TextSpan을 한 Text.rich 트리에 섞으면 Flutter Web(CanvasKit)
            // 에서 첫 줄 글리프가 깨지는 문제가 있어, 줄바꿈이 들어가는
            // 첫 줄을 별도 Text로 분리한다.
            Text(
              '당신은 $hostName에게',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GmFonts.serif,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: GmColors.ink,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '이에요'),
                ],
                style: const TextStyle(
                  fontFamily: GmFonts.serif,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: GmColors.ink,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _GuestResultCard(
              label: label,
              hanja: hanja,
              score: score,
              color: color,
              evidenceSummary: evidenceSummary,
              body: body,
            ),
            const SizedBox(height: 24),
            const Divider(color: GmColors.line, height: 1),
            const SizedBox(height: 16),
            Text(
              mapTotal != null
                  ? '$hostName님의 지도에 지금 $mapTotal명이 함께해요'
                  : '당신의 지도에는 누가 있을까요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: GmFonts.sans,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: GmColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '노드를 눌러 관계 상세를 확인하세요',
              style: TextStyle(fontSize: 10.5, color: GmColors.inkFaint),
            ),
            const SizedBox(height: 12),
            // [바이럴 페이지 개편] 회원가입한 사용자의 "내 귀인지도"(M화면)와
            // 동일한 애니메이션 관계 그래프. 게스트 본인이 중심, 호스트가
            // 관계 노드 1개로 표시된다.
            GuinjiAnimatedRelationGraph(
              centerTitle: '$centerName님',
              centerSubtitle: '나',
              people: [hostNode],
              interactive: true,
              showControls: false,
              height: 260,
            ),
            const SizedBox(height: 24),
            // [절대 원칙] 이 버튼은 게스트가 직접 탭했을 때만
            // onCreateOwnMap을 호출한다. 자동 실행되는 타이머/딜레이는
            // 존재하지 않는다.
            GmRoseButton(
              label: '내 지도 만들기 · 무료',
              icon: Icons.arrow_forward,
              onPressed:
                  onCreateOwnMap ?? () => Navigator.of(context).pushNamed('/guinji-map'),
            ),
            const SizedBox(height: 24),
            // [바이럴 페이지 개편 — "신통방통과 연결"] 사용자가 명시적으로
            // 요구한 CTA: 게스트가 결과를 다 본 뒤, 신통방통 메인 앱(오늘의
            // 운세·타로·사주 등)으로 자연스럽게 넘어갈 수 있는 통로. M화면
            // 전용이라던 `ResultAppHandoff` 재현(`GmDarkCtaShell`)을 여기서도
            // 동일하게 사용한다 — Y화면 역시 결과 화면이므로 그 제약 범위
            // 안에 있다.
            GmDarkCtaShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GmFreeBadge(label: '신통방통에서 계속'),
                  const SizedBox(height: 12),
                  const Text(
                    '신통방통에서\n더 많은 운세를 만나보세요',
                    style: TextStyle(
                      fontFamily: GmFonts.serif,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: GmColors.ivory,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GmRoseButton(
                    label: '신통방통 메인으로 가기',
                    icon: Icons.arrow_forward,
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/home', (route) => false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 방통선녀 이미지의 위상 단독 bob 애니메이션(3.6s). [2026-09 새 디자인
/// 리스킨] 애니메이션 로직은 그대로 유지, 에셋 경로도 동일하다.
class _BobbingSeonnyeo extends StatefulWidget {
  const _BobbingSeonnyeo();

  @override
  State<_BobbingSeonnyeo> createState() => _BobbingSeonnyeoState();
}

class _BobbingSeonnyeoState extends State<_BobbingSeonnyeo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        double bob({required double from, required double mid}) {
          if (t <= 0.5) return from + (mid - from) * (t / 0.5);
          return mid + (from - mid) * ((t - 0.5) / 0.5);
        }

        final y = bob(from: 0, mid: -4);
        final rot = bob(from: -1.5, mid: 1.0);
        return Transform.translate(
          offset: Offset(0, y),
          child: Transform.rotate(
            angle: rot * (3.14159265 / 180),
            child: Image.asset(
              'assets/images/guinji/seonnyeo/celebrating.png',
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}

/// 관계색 그라디언트 배경 + chip + 점수 + 산출근거 요약 + 나레이션 본문.
/// [2026-09 새 디자인 리스킨] 새 디자인 `GmChip`/아이보리 카드 스타일로
/// 재도색했다.
class _GuestResultCard extends StatelessWidget {
  const _GuestResultCard({
    required this.label,
    required this.hanja,
    required this.score,
    required this.color,
    required this.evidenceSummary,
    required this.body,
  });

  final String label;
  final String hanja;
  final int score;
  final Color color;
  final String evidenceSummary;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.6),
          radius: 1.1,
          colors: [
            color.withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          GmChip(
            label: '$label · $hanja人',
            background: color.withValues(alpha: 0.12),
            foreground: color,
            borderColor: color.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: GmFonts.serif,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: GmColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '관계 케미 점수',
            style: TextStyle(fontSize: 10.5, color: GmColors.inkFaint),
          ),
          const SizedBox(height: 14),
          Text(
            evidenceSummary,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: GmColors.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.65,
              color: GmColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
