import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/app_toast.dart';
import '../application/guinji_provider.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';

/// 귀인지도(Guinji Map) — 08. 공유 화면.
///
/// [Phase G-6] `GUINJI_SCREENS.md` "08 · 공유" 스펙 재구현(원본
/// `GuinjiScreens.jsx` → `ShareScreen`): 초대 링크 복사 + SNS 공유 그리드 +
/// 참여 현황 카드.
///
/// [귀인지도 실구현] 초대 링크는 `GuinjiProvider.mapToken`(서버가
/// `POST /guinji/maps`에서 발급한 실제 토큰)을 그대로 사용한다. "복사" 버튼은
/// 실제 `Clipboard.setData`로 클립보드에 복사한다.
///
/// [SNS 공유 그리드 실연동] 앱 라우터(`AppRouter.onGenerateRoute`)가 이미
/// `/g/{token}` 딥링크를 `GuinjiJoinScreen`으로 직접 파싱하도록 완성되어
/// 있으므로(카톡 등에서 링크를 열면 바로 참여 화면으로 진입), 카톡/인스타/
/// 스레드/더보기 4개 버튼은 모두 `tarot_result_screen`·`guinji_result_card_screen`
/// 에서 이미 검증된 `share_plus` 네이티브 공유 시트 패턴을 그대로 재사용해
/// 실제 공유 텍스트(초대 링크 포함)를 전달한다. 특정 앱(카톡 전용 SDK 등)으로
/// 직행하는 딥링크 스킴은 지원하지 않고, OS 표준 공유 시트를 띄워 사용자가
/// 원하는 앱을 선택하게 한다(다른 화면들과 동일한 원칙).
///
/// [절대 원칙] "1명 참여 = 복주머니 20P" 안내 문구는 원본 디자인 스펙을 그대로
/// 옮긴 **안내 텍스트**일 뿐이며, 실제 지급은 서버(`guinji/maps/{id}/members`
/// 트랜잭션 내부, PointPolicy 등록됨)에서만 발생한다.
class GuinjiShareScreen extends StatelessWidget {
  const GuinjiShareScreen({super.key});

  Future<void> _shareInvite(BuildContext context, String? token) async {
    if (token == null) return;
    final link = 'sintong.app/g/$token';
    try {
      await Share.share(
        '별빛나그네님이 귀인지도에 당신을 초대했어요!\n'
        '링크를 열면 생일만 입력해도 관계가 채워져요.\n$link',
        subject: '귀인지도 초대 · 신통방통',
      );
    } catch (_) {
      if (!context.mounted) return;
      AppToast.show(context, '공유 시트를 열 수 없어요. 링크를 복사해 전달해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuinjiProvider>();
    final token = provider.mapToken;
    final link = token != null ? 'sintong.app/g/$token' : '지도를 여는 중…';
    final joinedCount = provider.people.length;

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
                    link: link,
                    onCopy: token == null
                        ? () {}
                        : () {
                            Clipboard.setData(ClipboardData(text: link));
                            AppToast.show(context, '링크를 복사했어요.');
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
                          onTap: () => _shareInvite(context, token),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ShareOption(
                          label: '인스타',
                          icon: Icons.camera_alt,
                          color: const Color(0xFFE4405F),
                          onTap: () => _shareInvite(context, token),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ShareOption(
                          label: '스레드',
                          icon: Icons.alternate_email,
                          color: GuinjiColors.textPrimary,
                          onTap: () => _shareInvite(context, token),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ShareOption(
                          label: '더보기',
                          icon: Icons.more_horiz,
                          color: GuinjiColors.textPrimary,
                          onTap: () => _shareInvite(context, token),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ReminderCard(joinedCount: joinedCount),
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

/// 참여 현황 카드 — accent glow + 지금까지 실제로 참여한 지인 수.
///
/// [귀인지도 실구현] 서버에는 "초대 발송" 자체를 추적하는 테이블이 없어
/// "아직 안 들어온 친구 N명" 같은 예측 수치는 만들어낼 수 없다(허위 데이터
/// 표시 금지). 대신 [GuinjiProvider.people]에서 얻은 **실제로 참여를
/// 완료한 지인 수**만 정직하게 보여준다.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.joinedCount});

  final int joinedCount;

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
          const _MonoLabel('STATUS', color: GuinjiColors.aqua),
          const SizedBox(height: 4),
          Text(
            joinedCount == 0 ? '아직 참여한 지인이 없어요' : '지금까지 $joinedCount명이 참여했어요',
            style: const TextStyle(
              fontFamily: GuinjiFonts.body,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: GuinjiColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '초대한 지인이 링크로 들어와 참여하면 여기 숫자가 올라가요.',
            style: TextStyle(
              fontFamily: GuinjiFonts.ui,
              fontSize: 11,
              height: 1.4,
              color: GuinjiColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
