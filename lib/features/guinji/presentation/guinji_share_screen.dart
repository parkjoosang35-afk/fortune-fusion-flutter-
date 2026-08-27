import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/env_config.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/guinji_provider.dart';
import '../theme/guinji_theme.dart';
import '../widgets/guinji_bg_atmosphere.dart';

/// [귀인지도 딥링크 버그수정 — Phase A] 초대 링크 생성 헬퍼.
///
/// [배경] 지금까지 하드코딩돼 있던 `sintong.app/g/{token}`은 실존하지 않는
/// (미등록) 도메인이라, 카톡 등에서 이 링크를 열면 카카오톡 인앱 브라우저가
/// DNS 조회부터 실패해 "해당 페이지를 찾을 수 없습니다" 404를 표시했다
/// (2026-08 실사용자 리포트로 발견). 실제로 요청·응답이 가능한
/// `EnvConfig.adminApiBaseUrl`(admin_web 서버) 아래에 신설한 웹 랜딩페이지
/// (`/g/{token}`, admin_web `src/app/g/[token]/page.tsx`)로 교체한다 — 이
/// 페이지는 초대 내용을 보여주고 "앱에서 열기" 버튼으로 커스텀 스킴
/// (`fortunefusion://g/{token}`)을 호출해 앱을 실행시킨다.
///
/// [주의] 이 base URL은 샌드박스 프리뷰마다 바뀌는 임시 도메인이다. 실제
/// 운영 배포 시에는 `EnvConfig.adminApiBaseUrl`을 진짜 도메인으로 교체하는
/// 것만으로 이 함수가 자동으로 올바른 링크를 생성한다(Phase B, 아직 미착수).
String buildGuinjiInviteLink(String token) {
  return '${EnvConfig.adminApiBaseUrl}/g/$token';
}

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
/// 스레드/더보기 4개 버튼은 플랫폼별로 분기한다.
///
/// - **Android(네이티브)**: `share_plus`의 `Share.share()`가
///   `Intent.ACTION_SEND`(OS 표준 공유 시트)를 호출한다.
/// - **Web**: `navigator.share` Web Share API는 브라우저·OS·설정에 따라
///   지원 여부가 제각각이고, 미지원 시 `share_plus`가 내부적으로
///   `mailto:` 링크로 폴백하는데 기본 메일 클라이언트가 없는 환경에서는
///   **아무 반응도 없이 조용히 실패**하는 심각한 UX 결함이 있었다(2026-08
///   실사용자 리포트로 발견·수정). 따라서 웹에서는 신뢰할 수 없는
///   `Share.share()`를 시도하지 않고, 항상 클립보드 복사 + 명확한 안내
///   토스트로 확실하게 완료되는 동작을 제공한다.
///
/// [절대 원칙] "1명 참여 = 복주머니 20P" 안내 문구는 원본 디자인 스펙을 그대로
/// 옮긴 **안내 텍스트**일 뿐이며, 실제 지급은 서버(`guinji/maps/{id}/members`
/// 트랜잭션 내부, PointPolicy 등록됨)에서만 발생한다.
class GuinjiShareScreen extends StatelessWidget {
  const GuinjiShareScreen({super.key});

  Future<void> _shareInvite(BuildContext context, String? token) async {
    if (token == null) return;
    final link = buildGuinjiInviteLink(token);
    final message =
        '별빛나그네님이 귀인지도에 당신을 초대했어요!\n'
        '링크를 열면 생일만 입력해도 관계가 채워져요.\n$link';

    // [웹 결함 수정] navigator.share 미지원/설정 부재 환경에서
    // Share.share()가 아무 피드백 없이 실패하는 문제가 있어, 웹에서는
    // 항상 클립보드 복사로 확실하게 동작을 보장한다.
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: message));
      if (!context.mounted) return;
      AppToast.show(context, '초대 메시지를 복사했어요. 원하는 앱에 붙여넣어 전달해 주세요.');
      return;
    }

    try {
      final result = await Share.share(message, subject: '귀인지도 초대 · 신통방통');
      // 사용자가 공유 시트를 그냥 닫은 경우(dismissed)는 실패가 아니므로
      // 별도 안내 없이 넘어간다.
      if (result.status == ShareResultStatus.unavailable) {
        if (!context.mounted) return;
        await Clipboard.setData(ClipboardData(text: message));
        if (!context.mounted) return;
        AppToast.show(context, '공유 시트를 열 수 없어 링크를 복사했어요.');
      }
    } catch (_) {
      if (!context.mounted) return;
      await Clipboard.setData(ClipboardData(text: message));
      if (!context.mounted) return;
      AppToast.show(context, '공유 시트를 열 수 없어 링크를 복사했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuinjiProvider>();
    final token = provider.mapToken;
    final link = token != null ? buildGuinjiInviteLink(token) : '지도를 여는 중…';
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
