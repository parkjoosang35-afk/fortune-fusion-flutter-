import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/app_toast.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_share_screen.dart' show buildGuinjiInviteLink;

/// [2026 디자인 핸드오프 — `/guinji-map/*` 신규 8화면] S(Share) 화면 4개
/// 공유 버튼(카톡/SMS/인스타/더보기) 공통 핸들러.
///
/// 기존 프로덕션 `guinji_share_screen.dart`(`GuinjiShareScreen`,
/// `/guinji/share`)의 `_shareInvite` 구현과 동일한 패턴을 그대로 재사용한다:
/// - 웹: `navigator.share`가 브라우저/OS에 따라 미지원이거나 조용히
///   실패하는 결함이 있어(2026-08 실사용자 리포트), 항상 클립보드 복사 +
///   토스트로 확실하게 완료한다.
/// - 네이티브(Android): `share_plus`의 `Share.share()`로 OS 표준 공유
///   시트(`Intent.ACTION_SEND`)를 연다. 실패/미지원 시 클립보드 복사로
///   폴백한다.
Future<void> shareGuinjiMapInvite(BuildContext context, String? token) async {
  if (token == null || token.isEmpty) return;
  final link = buildGuinjiInviteLink(token);
  final message =
      '귀인지도에 당신을 초대했어요!\n'
      '링크를 열면 생일만 입력해도 관계가 채워져요.\n$link';

  if (kIsWeb) {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    AppToast.show(context, '초대 메시지를 복사했어요. 원하는 앱에 붙여넣어 전달해 주세요.');
    return;
  }

  try {
    final result = await Share.share(message, subject: '귀인지도 초대 · 신통방통');
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

/// S · Share — `/guinji-map/m/share`
///
/// [2026-09 새 디자인 리스킨] 새 디자인 zip
/// `lib/guiindo/screens/share_sheet.dart`의 바텀시트 UI(핸들바+LabelMini+
/// 제목+카카오 OG미리보기+공유옵션 리스트+Tip배너)를 이식했다. 라우팅은
/// L/M화면이 `pushNamed('/guinji-map/m/share')`로 접근하는 기존 방식을
/// 그대로 유지하므로, 화면 자체는 별도 라우트(전체화면)로 두고 내부
/// 디자인만 바텀시트 스타일(상단 라운드+핸들바)로 재현한다.
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

  static const routeName = '/guinji-map/m/share';

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
  String? _displayLink;
  String? _displayLinkToken;

  /// [귀인지도 실구현] 실존하지 않는 하드코딩 도메인 대신
  /// `guinji_share_screen.dart`의 [buildGuinjiInviteLink]를 재사용해 실제
  /// `EnvConfig.adminApiBaseUrl` 기반 링크를 만든다. 화면 진입 후 토큰이
  /// 바뀌지 않는 한 1회만 생성해 고정한다.
  String get _link {
    final token = widget.mapToken;
    if (token.isEmpty) return '지도를 여는 중…';
    if (_displayLinkToken != token) {
      _displayLinkToken = token;
      _displayLink = buildGuinjiInviteLink(token);
    }
    return _displayLink!;
  }

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
    final remaining = (widget.retentionGoal - widget.joinedCount).clamp(0, widget.retentionGoal);

    return Scaffold(
      backgroundColor: GmColors.bgIvory,
      appBar: GmTopBar(back: true, title: '친구 초대'),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 바텀시트 느낌의 장식용 핸들바
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: GmColors.line,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                const GmLabelMini('SHARE'),
                const SizedBox(height: 4),
                const Text(
                  '친구를 초대해\n지도를 완성해보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GmFonts.serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: GmColors.ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '더 많은 친구가 참여할수록\n내 관계 지도가 선명해져요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: GmColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 20),

                // 카카오 OG 미리보기
                _KakaoOgPreview(ownerName: widget.ownerName, guinjiCount: widget.guinjiCount),
                const SizedBox(height: 16),

                // 실제 초대 링크 복사 행
                _ShareLinkRow(link: _link, copied: _copied, onCopy: _copyLink),
                const SizedBox(height: 20),

                _ShareOption(
                  icon: Icons.chat_bubble,
                  iconColor: const Color(0xFF3A1D1D),
                  bg: const Color(0xFFFEE500),
                  title: '카카오톡으로 공유',
                  desc: '친구/그룹 채팅으로 바로 초대',
                  onTap: widget.onKakaoShare,
                ),
                const SizedBox(height: 8),
                _ShareOption(
                  icon: Icons.sms_outlined,
                  title: '문자(SMS)로 공유',
                  desc: '메시지 앱으로 링크 전달',
                  onTap: widget.onSmsShare,
                ),
                const SizedBox(height: 8),
                _ShareOption(
                  icon: Icons.camera_alt_outlined,
                  title: '인스타그램에 공유',
                  desc: '스토리에 초대 이미지 올리기',
                  onTap: widget.onInstagramShare,
                ),
                const SizedBox(height: 8),
                _ShareOption(
                  icon: Icons.more_horiz,
                  title: '더보기',
                  desc: '다른 앱으로 공유하기',
                  onTap: widget.onMoreShare,
                ),

                const SizedBox(height: 16),
                _RetentionBanner(
                  goal: widget.retentionGoal,
                  joined: widget.joinedCount,
                  remaining: remaining,
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GmColors.bgCream.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 11, color: GmColors.inkSoft, height: 1.5),
                      children: [
                        TextSpan(text: 'Tip. ', style: TextStyle(fontWeight: FontWeight.w700, color: GmColors.ink)),
                        TextSpan(text: '링크는 30일간 유효해요. 이후에는 지도가 자동으로 마감돼요.'),
                      ],
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

/// 새 디자인 `_KakaoOgPreview` 이식 — OG standard aspect ratio(1200:630)
/// 미리보기 카드. [GmStarsBackground] + [GmColors.gradientDark] 사용.
class _KakaoOgPreview extends StatelessWidget {
  const _KakaoOgPreview({required this.ownerName, required this.guinjiCount});

  final String ownerName;
  final int guinjiCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFB),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1200 / 630,
              child: Stack(
                children: [
                  Container(decoration: const BoxDecoration(gradient: GmColors.gradientDark)),
                  const Positioned.fill(child: GmStarsBackground(opacity: 0.7)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '신통방통 · 귀인지도',
                          style: TextStyle(
                            fontSize: 10,
                            color: GmColors.gold,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$ownerName님의 귀인 지도',
                              style: const TextStyle(
                                fontFamily: GmFonts.serif,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              '귀인 $guinjiCount명이 밝히는 중',
                              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$ownerName님의 귀인 지도',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '나는 이 사람에게 어떤 사람일까?',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey),
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

/// 실제 초대 링크 복사 행 — 기존 [buildGuinjiInviteLink] 기반 실링크를
/// 그대로 보여주고 복사한다.
class _ShareLinkRow extends StatelessWidget {
  const _ShareLinkRow({required this.link, required this.copied, required this.onCopy});

  final String link;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: GmColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              link,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, letterSpacing: 0.2, color: GmColors.ink),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: GmColors.rose500,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  copied ? '복사됨' : '복사',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 새 디자인 `_ShareOption` 이식 — 아이콘+제목+설명 리스트 행.
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    this.iconColor,
    this.bg,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  final IconData icon;
  final Color? iconColor, bg;
  final String title, desc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isKakao = bg != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          border: bg == null ? Border.all(color: GmColors.line) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? GmColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isKakao ? const Color(0xFF3A1D1D) : GmColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isKakao ? const Color(0xFF3A1D1D).withValues(alpha: 0.7) : GmColors.inkSoft,
                    ),
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

class _RetentionBanner extends StatelessWidget {
  const _RetentionBanner({required this.goal, required this.joined, required this.remaining});

  final int goal;
  final int joined;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: GmColors.gold.withValues(alpha: 0.12),
        border: Border.all(color: GmColors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: GmColors.gold, shape: BoxShape.circle),
            child: Text(
              '$goal',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.3,
                    color: GmColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '지금 $joined명 · $remaining명 더 필요해요',
                  style: const TextStyle(fontSize: 10, height: 1.3, color: GmColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
