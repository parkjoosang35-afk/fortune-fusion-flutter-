import 'package:flutter/material.dart';

import '../../../core/widgets/app_toast.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';

/// 귀인지도(Guinji Map) — 08. 공유 화면.
///
/// [Phase G-6] `GUINJI_SCREENS.md` "08 · 공유" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `ShareScreen`): 초대 링크 복사 + SNS 공유 그리드 +
/// "아직 안 들어온 친구 N명" 리마인더 카드.
///
/// [Phase G-6 범위 — 절대 원칙 준수] 서브카피에 노출되는 "1명 참여 = 복주머니
/// 20P" 문구는 원본 디자인 스펙을 그대로 옮긴 **안내 텍스트**일 뿐이며, 실제
/// 지급 로직은 아직 만들지 않는다. 실제 참여 이벤트 발생 시점의 재화 지급은
/// 반드시 서버 최종판단 + PointPolicy 등록 + Wallet/PointHistory 원장
/// 트랜잭션을 거쳐야 하므로(절대 원칙), 이 화면의 "복사"/SNS 공유 버튼은
/// 실제 초대 링크 생성·전송 없이 토스트로 대체한다. 링크 텍스트도 아직
/// share_event 테이블/API가 없어 정적 placeholder를 표시한다.
class GuinjiShareScreen extends StatelessWidget {
  const GuinjiShareScreen({super.key});

  static const int _notYet = 4;
  static const String _placeholderLink = 'sintong.app/g/jm-92kf3';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: GuinjiBgAtmosphere()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      const _MonoLabel('SHARE · INVITE'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      'assets/images/home/doryeong/celebrating.png',
                      width: 130,
                      height: 130,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '지인을 지도에\n초대해보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.display,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      height: 1.2,
                      letterSpacing: -0.4,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontSize: 12,
                          height: 1.5,
                          color: GuinjiColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: '링크를 보내면 상대는 생일만 입력해도 관계가 채워져요.\n'),
                          TextSpan(
                            text: '1명 참여 = 복주머니 20P',
                            style: TextStyle(color: GuinjiColors.lavender),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LinkBox(
                    link: _placeholderLink,
                    onCopy: () {
                      // [Phase G-6 범위] 실제 초대 링크 생성/클립보드 복사
                      // 로직은 백엔드 share_event API 완성 후 연결한다.
                      AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏');
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ShareOption(
                          label: '카톡',
                          icon: Icons.chat_bubble,
                          color: const Color(0xFFFEE500),
                          onTap: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ShareOption(
                          label: '인스타',
                          icon: Icons.camera_alt,
                          color: const Color(0xFFE4405F),
                          onTap: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ShareOption(
                          label: '스레드',
                          icon: Icons.alternate_email,
                          color: GuinjiColors.textPrimary,
                          onTap: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ShareOption(
                          label: '더보기',
                          icon: Icons.more_horiz,
                          color: GuinjiColors.textPrimary,
                          onTap: () =>
                              AppToast.show(context, '곧 만나볼 수 있어요! 준비 중이에요 🙏'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _ReminderCard(notYet: _notYet),
                  const SizedBox(height: 20),
                  const Text(
                    '상대방의 개인정보는 동의 없이 입력하지 말아 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: GuinjiFonts.ui,
                      fontSize: 10,
                      color: GuinjiColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      shape: const CircleBorder(
        side: BorderSide(color: GuinjiColors.surfaceCardBorder),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: GuinjiColors.textPrimary),
        ),
      ),
    );
  }
}

class _MonoLabel extends StatelessWidget {
  const _MonoLabel(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: 10,
        letterSpacing: 3.0,
        fontWeight: FontWeight.w500,
        color: color ?? GuinjiColors.textSecondary,
      ),
    );
  }
}

/// 링크 박스 — mono 링크 텍스트 + 복사 버튼(glow).
class _LinkBox extends StatelessWidget {
  const _LinkBox({required this.link, required this.onCopy});

  final String link;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: GuinjiColors.surfaceCard,
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              link,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: GuinjiFonts.mono,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                letterSpacing: 0.5,
                color: GuinjiColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: GuinjiColors.lavender,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: const Text(
                  '복사',
                  style: TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: GuinjiColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SNS 공유 그리드 옵션 1개(32px 원 아이콘 + 라벨).
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.25),
                  border: Border.all(color: color),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: GuinjiFonts.ui,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  color: GuinjiColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 리마인더 카드 — accent glow + 스택된 물음표 아바타.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.notYet});

  final int notYet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        gradient: RadialGradient(
          center: const Alignment(1.0, -1.0),
          radius: 1.2,
          colors: [
            GuinjiColors.aqua.withValues(alpha: 0.15),
            GuinjiColors.surfaceCard,
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonoLabel('REMINDER', color: GuinjiColors.aqua),
          const SizedBox(height: 4),
          Text(
            '아직 안 들어온 친구 $notYet명',
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: GuinjiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 28.0 + (notYet - 1) * 20.0,
                height: 28,
                child: Stack(
                  children: [
                    for (var i = 0; i < notYet; i++)
                      Positioned(
                        left: i * 20.0,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GuinjiColors.backgroundDeep,
                            border: Border.all(
                              color: GuinjiColors.surfaceCardBorder,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Text(
                            '?',
                            style: TextStyle(
                              fontFamily: GuinjiFonts.body,
                              fontSize: 12,
                              color: GuinjiColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '초대한 지인이 참여하면 여기에 표시돼요.',
                  style: TextStyle(
                    fontFamily: GuinjiFonts.ui,
                    fontSize: 11,
                    height: 1.4,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
