import 'package:flutter/material.dart';

import '../character/guinji_character.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';

/// G3 · 새 호스트 환영 — `design_handoff_guinji_map_v5/SPEC.md` §6 G3
/// "(신규) 새 호스트 환영" + `COPY.md` "G3 새 호스트 환영" + `design_files/
/// guinji-loop.jsx`의 `LpGift` 함수(145~173줄) 1:1 이식.
///
/// [노출 조건 — SPEC "게스트가 `나도 내 귀인지도 만들기`로 처음 들어올 때
/// 1회"] 이 화면은 자체적으로 "처음 1회" 여부를 판단하지 않는다 — 호출부
/// (G2 `guinji_guest_result_screen.dart`의 `onCreateOwnMap`)가 이미
/// "게스트가 지금 막 자기 지도를 만들려는 순간"이라는 맥락을 알고 있으므로,
/// 그 호출부에서 이 화면으로 보낼지 바로 H2(`guinji_input_screen.dart`)로
/// 보낼지를 결정한다. 이 화면 자체는 순수 표시 위젯이다(멱등하게 여러 번
/// 보여줘도 안전 — 서버/로컬 상태를 변경하지 않음).
///
/// [정책 — 선물 카드] SPEC "정책: 첫 지도 선물을 주지 않으면 선물 카드만
/// 숨깁니다." / design_files 주석 "선물 카드는 [확인 필요: 프리패스 지급
/// 정책] — 정책 없으면 카드만 숨김". 2026-12 현재 admin_web
/// `PassPolicy`(ad/partner/subscription/event 4종 `passType`)에도,
/// `PointPolicy`에도 "게스트의 첫 지도 생성 시 프리패스 1회 자동 지급"에
/// 해당하는 정책이 전혀 존재하지 않는다(검색 결과 0건) — 즉 "정책 없음"
/// 상태가 확정이므로, [showGift]는 기본값 false로 두고 실제 정책이
/// 생기기 전까지는 호출부에서 true로 바꾸지 않는다(사실과 다른 혜택을
/// 암시하지 않기 위함 — G1/G2에서 이미 사용자가 결정한 "백엔드 사실이
/// 모든 문서보다 우선한다" 원칙과 동일하게 적용).
class GuinjiHostWelcomeScreen extends StatelessWidget {
  const GuinjiHostWelcomeScreen({
    super.key,
    required this.guestName,
    required this.hostName,
    this.showGift = false,
    this.onCreateMap,
    this.onLater,
  });

  static const routeName = '/guinji-map/host-welcome';

  /// 방금 G2에서 "나도 내 귀인지도 만들기"를 누른 게스트 본인 이름.
  final String guestName;

  /// 이 게스트를 초대했던 호스트 이름 — sub 문구("{호스트}님 지도에 별을
  /// 띄운 것처럼…")에 사용.
  final String hostName;

  /// [위 클래스 주석 참고] 프리패스 지급 정책이 실제로 생기기 전까지는
  /// 기본값 false(선물 카드 숨김)를 유지한다.
  final bool showGift;

  /// `내 귀인지도 만들기` → SPEC "H2"(`guinji_input_screen.dart`)로 이동.
  final VoidCallback? onCreateMap;

  /// `나중에 할게요` → SPEC "H1"(`guinji_landing_screen.dart`)로 이동.
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final char = GuinjiCharacter.of(
      // [손쉬운 자동 캐릭터 배정] 이 화면은 게스트의 실제 생년월일을 모른다
      // (G2는 생년월일을 서버에만 전달하고 클라이언트에 되돌려주지 않음) —
      // `GuinjiCharacter.of`는 연령대(band)가 필수이므로, 표시 목적의
      // 중립값(30대)으로 고정하고 성별은 이름 해시로 자동 분기한다(기존
      // `GuinjiCharacter.of`의 폴백 로직과 동일한 패턴).
      birth: DateTime(DateTime.now().year - 30),
      stableKey: guestName,
    );

    return Scaffold(
      backgroundColor: GmColors.bg,
      // [2026-12 보강 — SPEC §2 `bgGlow` 전역 배경] `design_files/
      // guinji-loop.jsx`의 `LpGift`(145~173줄)는 `<TpBg />`(151줄)를 화면
      // 최상단에 깐다 — 기존에 쓰던 `GmStarsBackground`(별 24개, 반짝임
      // 없음)는 TpBg의 일부(별 44개 + 반짝임)만 흉내 낸 불완전한 대체였다.
      // [GmTempleBg]로 교체해 글로우 3겹 + 정확한 별 스펙을 모두 적용한다.
      body: GmTempleBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 16),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const GmLabelMini('WELCOME · 첫 방문'),
                        const SizedBox(height: 12),
                        Text(
                          '$guestName님, 반가워요\n'
                          '이제 내 곁의 귀인을\n'
                          '찾아볼 차례예요',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: GmText.display,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            height: 1.4,
                            letterSpacing: -0.03,
                            color: GmColors.fg,
                          ),
                        ),
                        const SizedBox(height: 26),
                        _GiPulsingCharacter(facePath: char.face),
                        const SizedBox(height: 16),
                        Text(
                          '$hostName님 지도에 별을 띄운 것처럼\n'
                          '내 지도에도 인연을 하나씩 채울 수 있어요',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: GmText.ui,
                            fontSize: 13.5,
                            height: 1.6,
                            color: GmColors.muted,
                          ),
                        ),
                        // [정책 없음 — 클래스 주석 참고] showGift가
                        // true일 때만 노출한다. 기본값(false)에서는
                        // SPEC 정책("정책 없으면 카드만 숨깁니다")에
                        // 따라 이 카드 전체를 생략한다.
                        if (showGift) ...[
                          const SizedBox(height: 22),
                          const _GiGiftCard(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GmRoseButton(label: '내 귀인지도 만들기', onPressed: onCreateMap),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onLater,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GmColors.line),
                      foregroundColor: GmColors.muted,
                      minimumSize: const Size.fromHeight(46),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '나중에 할게요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// SPEC §6 G3-2 "내 캐릭터 120(금 링 + 펄스)" — `design_files/guinji-loop.jsx`
/// `LpGift`의 `tp-pulse 2.6s` 링 애니메이션 1:1.
class _GiPulsingCharacter extends StatefulWidget {
  const _GiPulsingCharacter({required this.facePath});

  final String facePath;

  @override
  State<_GiPulsingCharacter> createState() => _GiPulsingCharacterState();
}

class _GiPulsingCharacterState extends State<_GiPulsingCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 144,
      height: 144,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // ease-out 느낌의 펄스: 0→1로 커지며 서서히 사라짐.
          final scale = 1.0 + t * 0.22;
          final opacity = (1 - t).clamp(0.0, 1.0) * 0.5;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: GmColors.gold.withValues(alpha: opacity),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A1D40),
            image: DecorationImage(
              image: AssetImage(widget.facePath),
              fit: BoxFit.cover,
              onError: (_, __) {},
            ),
            boxShadow: const [
              BoxShadow(color: GmColors.gold, blurRadius: 0, spreadRadius: 2.5),
              BoxShadow(color: GmColors.goldShadow, blurRadius: 40),
            ],
          ),
        ),
      ),
    );
  }
}

/// SPEC §6 G3-4 "선물 카드: 禮 인장 52(금, 적색 글자, -6°, stamp 애니) +
/// 제목 16 금 + 본문 12.5" — `design_files/guinji-loop.jsx` `LpGift`의
/// `data-slot="W-1"` 선물 카드 1:1.
///
/// [위 화면 클래스 주석 참고] 현재 프리패스 자동지급 정책이 없어 기본
/// 노출되지 않는다 — 정책이 생기면 [GuinjiHostWelcomeScreen.showGift]를
/// true로 바꿔 사용한다(이 위젯 자체는 디자인 완성본으로 미리 준비해 둠).
class _GiGiftCard extends StatelessWidget {
  const _GiGiftCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GmColors.gold.withValues(alpha: 0.5)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GmColors.gold.withValues(alpha: 0.18),
            const Color(0xFF8C50C8).withValues(alpha: 0.12),
            const Color(0xFF0A0716).withValues(alpha: 0.4),
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.rotate(
            angle: -6 * 3.14159265 / 180,
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GmColors.gold,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: GmColors.goldShadow,
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                '禮',
                style: TextStyle(
                  fontFamily: GmText.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  height: 1,
                  color: Color(0xFF5E1A1E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '첫 지도 선물 · 프리패스 1회',
                  style: TextStyle(
                    fontFamily: GmText.ui,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: GmColors.gold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '지도를 만들면 인연 한 명의 10장 풀이를 무료로 열 수 있어요',
                  style: TextStyle(
                    fontFamily: GmText.ui,
                    fontSize: 12.5,
                    height: 1.55,
                    color: GmColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
