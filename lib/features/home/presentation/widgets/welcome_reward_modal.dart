import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/presentation/widgets/auth_primary_button.dart';
import '../../../intro/presentation/intro_palette.dart';
import '../../../intro/presentation/intro_text_styles.dart';
import '../../../intro/presentation/widgets/intro_gradient_text.dart';
import '../../../intro/presentation/widgets/intro_title_text.dart';
import 'welcome_reward_effects.dart';
import 'welcome_reward_pouch.dart';

/// [Phase C - 03_Welcome_Reward.html 반영] 회원가입 웰컴 리워드 팝업(STATE 1).
///
/// 핸드오프 문서의 `.backdrop`(blur14+voidBlack72%) + `.modal-sigil`×2(회전
/// 마법진) + `.burst .ray`×12(빛줄기) + `.confetti-piece`×22(색종이) +
/// `.modal`(신통도령 캐릭터+말풍선꼬리+카드) 전체 구성을 1:1로 재현한다.
/// 카드 내부는 `.modal-eyebrow`/`.modal-title`/`.pouch-hero`/
/// `.reward-counter`/`.modal-body`/`.divider`/`.info-list`/`.btn-primary`/
/// `.modal-note` 순서를 그대로 따른다.
///
/// [범위 격리 원칙] 색상/스타일은 `IntroPalette`/`IntroTextStyles`(격리된
/// 핸드오프 전용 팔레트)만 참조하고 앱 전역 메인 컬러 파일은 참조하지 않는다.
///
/// [통합 지점 - 기존 로직과의 관계] 과거에는 회원가입 성공 직후
/// `LuckPouchToastController.showSignupReward()` 토스트가 별도로 떴지만,
/// 이 모달이 동일 정보를 더 풍성하게 보여주므로 해당 토스트 호출은
/// signup_screen.dart에서 제거했다(중복 알림 방지, 커밋 "Phase C 서버 연동"
/// 참고). CTA("복주머니 받기") 탭 시에는 `AuthProvider.claimWelcomeGift()`를
/// 호출해 서버 `users.welcome_gift_claimed`를 true로 갱신한 뒤 fade-out으로
/// 닫는다. 홈 상단의 복주머니 잔액 배지는 이미 WalletProvider가 실 잔액을
/// 반영하고 있어 별도 카운터 tick 애니메이션 없이도 최신값이 보인다.
class WelcomeRewardModal extends StatefulWidget {
  final int amount;
  final VoidCallback onClaim;

  const WelcomeRewardModal({
    super.key,
    required this.amount,
    required this.onClaim,
  });

  /// 팝업을 표시한다. `barrierColor`는 투명으로 두고 위젯 내부에서 자체
  /// backdrop(blur+색상 fade-in)을 그리므로, 라우트 자체의 전환 애니메이션은
  /// 사용하지 않는다(내부 `_entry` 컨트롤러가 등장/퇴장을 전담).
  static Future<void> show(
    BuildContext context, {
    required int amount,
    required VoidCallback onClaim,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 1),
      pageBuilder: (context, animation, secondaryAnimation) =>
          WelcomeRewardModal(amount: amount, onClaim: onClaim),
    );
  }

  @override
  State<WelcomeRewardModal> createState() => _WelcomeRewardModalState();
}

class _WelcomeRewardModalState extends State<WelcomeRewardModal>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _sparkle;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // `.backdrop`(fade-in 0.4s) + `.modal`(modal-rise 0.6s)를 하나의
    // 타임라인으로 근사 — backdrop은 앞쪽 67%(≈0.4s/0.6s) 구간에서 완료.
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    // `.modal-card::before/::after`(spark 3s) 코너 장식 회전/반짝임 전용.
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _entry.dispose();
    _sparkle.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    if (_closing) return;
    _closing = true;
    widget.onClaim();
    await _entry.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final backdropOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.67, curve: Curves.easeOut),
    );
    final riseScale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutBack));

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // `.backdrop` — voidBlack 72% + blur 14.
          AnimatedBuilder(
            animation: backdropOpacity,
            builder: (context, _) => Opacity(
              opacity: backdropOpacity.value,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  color: IntroPalette.voidBlack.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
          // `.modal-sigil` + `.modal-sigil-2` — 회전 마법진 2겹.
          Positioned.fill(
            child: FadeTransition(
              opacity: backdropOpacity,
              child: const Align(
                alignment: Alignment(0, -0.2),
                child: WelcomeRewardSigils(),
              ),
            ),
          ),
          // `.burst .ray`×12 — 빛줄기.
          Positioned.fill(
            child: FadeTransition(
              opacity: backdropOpacity,
              child: const WelcomeRewardBurstRays(),
            ),
          ),
          // `.confetti-piece`×22 — 색종이 낙하.
          Positioned.fill(
            child: FadeTransition(
              opacity: backdropOpacity,
              child: const WelcomeRewardConfetti(),
            ),
          ),
          // `.modal` — 캐릭터+말풍선꼬리+카드.
          Center(
            child: FadeTransition(
              opacity: _entry,
              child: ScaleTransition(
                scale: riseScale,
                child: _ModalCard(
                  amount: widget.amount,
                  sparkle: _sparkle,
                  onClaim: _handleClaim,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalCard extends StatefulWidget {
  final int amount;
  final AnimationController sparkle;
  final VoidCallback onClaim;

  const _ModalCard({
    required this.amount,
    required this.sparkle,
    required this.onClaim,
  });

  @override
  State<_ModalCard> createState() => _ModalCardState();
}

class _ModalCardState extends State<_ModalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    // `.modal-char`(char-float 3.4s) — 상하 bob + 좌우 rotate 왕복.
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const cardTopGap = 70.0; // 캐릭터(130)+말풍선꼬리(14) 노출 영역 확보.

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: cardTopGap),
              child: _buildCard(context),
            ),
            Positioned(
              top: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_buildCharacter(), _buildSpeechTail()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacter() {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_float.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.rotate(angle: (-2 + 4 * t) * pi / 180, child: child),
        );
      },
      child: SizedBox(
        width: 130,
        height: 130,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/home/doryeong/celebrating.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildSpeechTail() {
    return ClipPath(
      clipper: _TriangleClipper(),
      child: Container(
        width: 22,
        height: 14,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                IntroPalette.backgroundTop,
                IntroPalette.primary,
                0.12,
              )!,
              IntroPalette.backgroundTop,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(IntroPalette.backgroundTop, IntroPalette.primary, 0.10)!,
            IntroPalette.backgroundTop,
            IntroPalette.backgroundBottom,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: Color.lerp(
            IntroPalette.cardBorder,
            IntroPalette.primary,
            0.25,
          )!,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
          BoxShadow(color: IntroPalette.glowShadow, blurRadius: 40),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEyebrow(),
              const SizedBox(height: 16),
              IntroTitleText(
                '신통방통에\n오신 걸 환영합니다',
                style: IntroTextStyles.modalTitle(),
                highlight: '환영합니다',
                highlightColors: const [
                  IntroPalette.gold,
                  IntroPalette.primary,
                ],
              ),
              const SizedBox(height: 4),
              const WelcomeRewardPouchHero(size: 130),
              const SizedBox(height: 6),
              _buildRewardCounter(),
              const SizedBox(height: 20),
              _buildBody(),
              const SizedBox(height: 14),
              _buildDivider(),
              const SizedBox(height: 14),
              _buildInfoList(),
              const SizedBox(height: 22),
              AuthPrimaryButton(label: '복주머니 받기', onPressed: widget.onClaim),
              const SizedBox(height: 12),
              _buildNote(),
            ],
          ),
          _buildCornerSparkle(alignment: Alignment.topLeft, phase: 0.0),
          _buildCornerSparkle(alignment: Alignment.topRight, phase: 0.5),
        ],
      ),
    );
  }

  Widget _buildEyebrow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, IntroPalette.primary],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('WELCOME · GIFT', style: IntroTextStyles.modalEyebrow()),
        const SizedBox(width: 6),
        Container(
          width: 20,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [IntroPalette.primary, Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRewardCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: IntroPalette.gold.withValues(alpha: 0.15),
        border: Border.all(color: IntroPalette.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '+',
            style: GoogleFonts.nanumMyeongjo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: IntroPalette.gold,
            ),
          ),
          const SizedBox(width: 6),
          IntroGradientText(
            '${widget.amount}',
            style: GoogleFonts.nanumMyeongjo(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.64,
            ),
            colors: const [IntroPalette.gold, IntroPalette.primary],
          ),
          const SizedBox(width: 6),
          Text('복주머니', style: IntroTextStyles.rewardUnit()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: IntroTextStyles.modalBody(),
        children: [
          const TextSpan(text: '첫 걸음을 축하드립니다.\n'),
          TextSpan(
            text: '복주머니 ${widget.amount}개',
            style: IntroTextStyles.modalBodyStrong(),
          ),
          const TextSpan(text: '를 신통도령이 준비했어요.'),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, IntroPalette.cardBorder],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '◈',
          style: TextStyle(fontSize: 10, color: IntroPalette.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [IntroPalette.cardBorder, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: IntroPalette.primary.withValues(alpha: 0.04),
        border: Border.all(color: IntroPalette.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          _InfoRow(label: '소원방 사용'),
          SizedBox(height: 8),
          _InfoRow(label: '각종 소원 아이템 구매'),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: IntroTextStyles.modalNote(),
        children: [
          const TextSpan(text: '받은 복주머니는 '),
          TextSpan(text: '마이 · 복주머니', style: IntroTextStyles.modalNoteStrong()),
          const TextSpan(text: '에서 확인할 수 있어요'),
        ],
      ),
    );
  }

  /// `.modal-card::before/::after`(spark 3s linear infinite) — 코너 반짝임.
  /// [phase]는 0.5(1.5s 딜레이)를 주면 두 코너가 서로 엇갈려 반짝인다.
  Widget _buildCornerSparkle({
    required Alignment alignment,
    required double phase,
  }) {
    return Positioned(
      top: 12,
      left: alignment == Alignment.topLeft ? 14 : null,
      right: alignment == Alignment.topRight ? 14 : null,
      child: AnimatedBuilder(
        animation: widget.sparkle,
        builder: (context, _) {
          final x = (widget.sparkle.value + phase) % 1.0;
          final opacity = 0.4 + 0.5 * (0.5 + 0.5 * sin(2 * pi * x));
          final scale = 1.0 + 0.2 * (0.5 + 0.5 * sin(2 * pi * x));
          return Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: x * 2 * pi,
              child: Transform.scale(
                scale: scale,
                child: Text(
                  '✧',
                  style: TextStyle(color: IntroPalette.primary, fontSize: 14),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  const _InfoRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          child: Text(
            '✧',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: IntroPalette.gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: IntroTextStyles.infoRow())),
      ],
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
