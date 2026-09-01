import 'package:flutter/material.dart';

import '../domain/guinji_relation_meta.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_ui_kit.dart';

/// Y · Guest Result — `/g/:mapToken/result`
///
/// [design_handoff_guinji_web/Guinji Section.html] 2033~2122줄 마크업을
/// 재현한다. 바이럴 링크로 들어온 게스트가 자신의 사주를 입력한 뒤,
/// 호스트와의 관계 판정 결과를 확인하는 화면.
///
/// [절대 원칙 — 바이럴 게스트 플로우] 이 화면은:
///  (a) 회원가입 없이 도달 가능해야 하고,
///  (b) 결과를 완전히 확인할 수 있는 완결된 경험이어야 하며(추가 결제/
///      가입 장벽 없음),
///  (c) 하단의 "내 지도 만들기" CTA는 게스트가 **스스로 원할 때만** 누르는
///      선택적 전환 유도일 뿐, 이 화면에 도달하거나 머무는 동안 자동으로
///      회원가입/앱으로 리다이렉트되는 로직은 **절대 포함하지 않는다**.
///      (`Timer`/`Future.delayed` 등으로 자동 전환하는 코드를 추가하지
///      말 것 — 사용자가 과거에 이 문제로 강하게 항의한 바 있음.)
class GuinjiGuestResultScreen extends StatelessWidget {
  const GuinjiGuestResultScreen({
    super.key,
    required this.hostName,
    required this.relationKey,
    required this.score,
    this.evidenceSummary = '오행 보충도 +0.82 · 희신 일치 · 합 2',
    this.narratorText,
    this.onCreateOwnMap,
  });

  static const routeName = '/g/result';

  /// 지도 소유자(호스트) 이름 — HTML 예시의 "지민".
  final String hostName;
  final String relationKey;
  final int score;
  final String evidenceSummary;

  /// 결과 본문 서술(방통선녀 나레이션). null이면 [relationKey] 메타의
  /// description을 사용해 기본 문구를 생성한다.
  final String? narratorText;

  /// "내 지도 만들기" CTA — 게스트가 스스로 눌렀을 때만 호출된다(자동
  /// 트리거 금지).
  final VoidCallback? onCreateOwnMap;

  @override
  Widget build(BuildContext context) {
    final meta = guinjiRelationTypes[relationKey];
    final color = meta?.color ?? GuinjiColors.relationCheonGwii;
    final label = meta?.label ?? relationKey;
    final hanja = meta?.hanja ?? '?';
    final body =
        narratorText ??
        '$hostName님의 결을 강하게 살려주는 결이에요. '
            '두 분이 함께 있으면 서로의 부족한 흐름이 채워집니다.';

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        bgAlignment: const Alignment(0, -0.5),
        bgOpacity: 0.16,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GuinjiTopBar(
                breadcrumb: 'Y · GUEST RESULT',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: _BobbingSeonnyeo(),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '▸ 방통선녀 · RESULT',
                      style: TextStyle(
                        fontFamily: GuinjiFonts.mono,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 3,
                        color: GuinjiColors.relationKkeurida,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // [렌더 버그 수정 — L 화면과 동일한 패턴] 줄바꿈(`\n`)과
                    // 색상이 다른 TextSpan을 한 Text.rich 트리에 섞으면
                    // Flutter Web(CanvasKit)에서 첫 줄 글리프가 깨지는
                    // 문제가 있어, 줄바꿈이 들어가는 첫 줄을 별도 Text로
                    // 분리한다.
                    Text(
                      '당신은 $hostName에게',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: GuinjiFonts.display,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                        letterSpacing: -0.4,
                        color: GuinjiColors.textPrimary,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: label,
                            style: const TextStyle(
                              color: GuinjiColors.gold,
                            ),
                          ),
                          const TextSpan(text: '이에요'),
                        ],
                        style: const TextStyle(
                          fontFamily: GuinjiFonts.display,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                          letterSpacing: -0.4,
                          color: GuinjiColors.textPrimary,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _GuestResultCard(
                relationKey: relationKey,
                hanja: hanja,
                score: score,
                color: color,
                evidenceSummary: evidenceSummary,
                body: body,
              ),
              const SizedBox(height: 24),
              const Divider(color: GuinjiColors.surfaceCardBorder, height: 1),
              const SizedBox(height: 14),
              const Text(
                '당신의 지도에는 누가 있을까요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: GuinjiFonts.body,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: GuinjiColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              // [절대 원칙] 이 버튼은 게스트가 직접 탭했을 때만
              // onCreateOwnMap을 호출한다. 자동 실행되는 타이머/딜레이는
              // 존재하지 않는다.
              GuinjiPrimaryButton(
                label: '내 지도 만들기 · 무료',
                onPressed: onCreateOwnMap ??
                    () => Navigator.of(context).pushNamed('/guinji'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// 방통선녀 이미지의 char-pair-l 위상 단독 bob 애니메이션(3.6s).
class _BobbingSeonnyeo extends StatefulWidget {
  @override
  State<_BobbingSeonnyeo> createState() => _BobbingSeonnyeoState();
}

class _BobbingSeonnyeoState extends State<_BobbingSeonnyeo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
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

/// `.guest-result-card` — 관계색 그라디언트 배경 + eyebrow + 점수 +
/// 산출근거 요약 + 나레이션 본문.
class _GuestResultCard extends StatelessWidget {
  const _GuestResultCard({
    required this.relationKey,
    required this.hanja,
    required this.score,
    required this.color,
    required this.evidenceSummary,
    required this.body,
  });

  final String relationKey;
  final String hanja;
  final int score;
  final Color color;
  final String evidenceSummary;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: GuinjiColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.6),
          radius: 1.1,
          colors: [
            color.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            '$relationKey · $hanja人',
            style: TextStyle(
              fontFamily: GuinjiFonts.mono,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score점',
            style: TextStyle(
              fontFamily: GuinjiFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: GuinjiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            evidenceSummary,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontSize: 11,
              height: 1.5,
              color: GuinjiColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontSize: 12,
              height: 1.6,
              color: GuinjiColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
