import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/guinji_theme.dart';
import '../widgets/guinji_char_pair.dart';
import '../widgets/guinji_ui_kit.dart';

/// S · Share — `/guinji/m/:mapId/share`
///
/// [design_handoff_guinji_web/Guinji Section.html] 1784~1912줄 마크업을
/// 재현한다. OG 미리보기(1.91:1) + 링크 복사 + 4개 공유 버튼(카톡/SMS/
/// 인스타/더보기) + 3명 리텐션 이벤트 배너.
///
/// [주의] 이 파일은 기존에 이미 실 API(카톡 SDK/share_plus) 연동까지
/// 완료된 `guinji_share_screen.dart`(`GuinjiShareScreen`, 라우트
/// `/guinji/share`)와는 **별개의 화면/클래스**다. 파일명·클래스명이 겹치면
/// 기존 프로덕션 코드를 덮어쓰는 사고가 나므로(이전 턴에서 실제로 발생),
/// 8화면 디자인 핸드오프 재구현 전용으로 `GuinjiMapShareScreen`이라는
/// 새 이름을 사용한다. 실제 카톡 SDK 연동은 [onKakaoShare] 콜백을 상위
/// 라우팅에서 지정해 기존 `guinji_share_screen.dart`의 구현을 재사용하는
/// 방식으로 연결할 것(후속 작업, 아직 미착수).
class GuinjiMapShareScreen extends StatefulWidget {
  const GuinjiMapShareScreen({
    super.key,
    required this.ownerName,
    required this.mapToken,
    this.guinjiCount = 8,
    this.joinedCount = 1,
    this.retentionGoal = 3,
    this.onKakaoShare,
    this.onSmsShare,
    this.onInstagramShare,
    this.onMoreShare,
  });

  static const routeName = '/guinji/m/share';

  final String ownerName;
  final String mapToken;
  final int guinjiCount;
  final int joinedCount;
  final int retentionGoal;

  final VoidCallback? onKakaoShare;
  final VoidCallback? onSmsShare;
  final VoidCallback? onInstagramShare;
  final VoidCallback? onMoreShare;

  @override
  State<GuinjiMapShareScreen> createState() => _GuinjiMapShareScreenState();
}

class _GuinjiMapShareScreenState extends State<GuinjiMapShareScreen> {
  bool _copied = false;

  String get _link => 'sintong.app/g/${widget.mapToken}';

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.retentionGoal - widget.joinedCount).clamp(
      0,
      widget.retentionGoal,
    );

    return Scaffold(
      backgroundColor: GuinjiColors.backgroundDarker,
      body: GuinjiScreenScaffold(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GuinjiTopBar(
                breadcrumb: 'S · SHARE',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Center(
                child: Column(
                  children: [
                    const GuinjiCharPair(
                      leftAsset: 'assets/images/guinji/doryeong/celebrating.png',
                      rightAsset: 'assets/images/guinji/seonnyeo/celebrating.png',
                      imageSize: 84,
                    ),
                    const SizedBox(height: 4),
                    const _EyebrowLabel('▸ INVITE'),
                    const SizedBox(height: 8),
                    const Text(
                      '친구를 지도에\n초대해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: GuinjiFonts.display,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                        letterSpacing: -0.4,
                        color: GuinjiColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '링크를 보내면 상대는 생일만 입력해도\n관계가 자동으로 채워져요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GuinjiFonts.body,
                          fontSize: 12,
                          height: 1.6,
                          color: GuinjiColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _OgPreview(
                ownerName: widget.ownerName,
                guinjiCount: widget.guinjiCount,
              ),
              const SizedBox(height: 16),
              _ShareLinkRow(link: _link, copied: _copied, onCopy: _copyLink),
              const SizedBox(height: 14),
              _ShareButtonsGrid(
                onKakao: widget.onKakaoShare,
                onSms: widget.onSmsShare,
                onInstagram: widget.onInstagramShare,
                onMore: widget.onMoreShare,
              ),
              _RetentionBanner(
                goal: widget.retentionGoal,
                joined: widget.joinedCount,
                remaining: remaining,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EyebrowLabel extends StatelessWidget {
  const _EyebrowLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: GuinjiFonts.mono,
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 3,
        color: GuinjiColors.lavender,
      ),
    );
  }
}

/// `.share-og-preview` — OG standard aspect ratio(1.91:1) 미리보기 카드.
class _OgPreview extends StatelessWidget {
  const _OgPreview({required this.ownerName, required this.guinjiCount});

  final String ownerName;
  final int guinjiCount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.91,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: GuinjiColors.lavender.withValues(alpha: 0.25),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GuinjiColors.backgroundSoft.withValues(alpha: 0.85),
              GuinjiColors.backgroundDeep,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 1.0),
                    radius: 0.9,
                    colors: [
                      GuinjiColors.lavender.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SINTONG · 貴人地圖',
                  style: TextStyle(
                    fontFamily: GuinjiFonts.mono,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: GuinjiColors.lavender,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$ownerName의 지도에\n'),
                      TextSpan(
                        text: '귀인 $guinjiCount명',
                        style: const TextStyle(color: GuinjiColors.gold),
                      ),
                      const TextSpan(text: '이 밝히는 중'),
                    ],
                    style: const TextStyle(
                      fontFamily: GuinjiFonts.display,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: -0.3,
                      color: GuinjiColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '당신도 $ownerName의 지도에 이름을 올려보세요',
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontSize: 10,
                    color: GuinjiColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareLinkRow extends StatelessWidget {
  const _ShareLinkRow({
    required this.link,
    required this.copied,
    required this.onCopy,
  });

  final String link;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: GuinjiColors.surfaceCard,
        border: Border.all(color: GuinjiColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              link,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: GuinjiFonts.mono,
                fontSize: 11,
                letterSpacing: 0.4,
                color: GuinjiColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: GuinjiColors.lavender,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  copied ? '복사됨' : '복사',
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Color(0xFF2A1A3A),
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

class _ShareButtonsGrid extends StatelessWidget {
  const _ShareButtonsGrid({
    this.onKakao,
    this.onSms,
    this.onInstagram,
    this.onMore,
  });

  final VoidCallback? onKakao;
  final VoidCallback? onSms;
  final VoidCallback? onInstagram;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShareBtn(
            icon: 'K',
            label: '카톡',
            iconBg: const Color(0xFFFEE500),
            iconColor: const Color(0xFF3A2F00),
            onTap: onKakao,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShareBtn(icon: '✉', label: 'SMS', onTap: onSms),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShareBtn(icon: '📷', label: '인스타', onTap: onInstagram),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ShareBtn(icon: '⋯', label: '더보기', onTap: onMore),
        ),
      ],
    );
  }
}

class _ShareBtn extends StatelessWidget {
  const _ShareBtn({
    required this.icon,
    required this.label,
    this.iconBg,
    this.iconColor,
    this.onTap,
  });

  final String icon;
  final String label;
  final Color? iconBg;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GuinjiColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: GuinjiColors.surfaceCardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg ?? GuinjiColors.backgroundDeep,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 14,
                    color: iconColor ?? GuinjiColors.lavender,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
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

class _RetentionBanner extends StatelessWidget {
  const _RetentionBanner({
    required this.goal,
    required this.joined,
    required this.remaining,
  });

  final int goal;
  final int joined;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: GuinjiColors.gold.withValues(alpha: 0.1),
        border: Border.all(
          color: GuinjiColors.gold.withValues(alpha: 0.3),
          // dashed 근사 — Flutter 기본 Border는 dash 미지원이므로 solid로 대체
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: GuinjiColors.gold,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$goal',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Color(0xFF2A1A08),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$goal명 모으면 축하 이벤트가 열려요',
                  style: const TextStyle(
                    fontFamily: GuinjiFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.3,
                    color: GuinjiColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '지금 $joined명 · $remaining명 더 필요해요',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10,
                    height: 1.3,
                    color: GuinjiColors.textSecondary,
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
