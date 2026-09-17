import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/util/safe_share.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/bangtong_seonyeo.dart';
import '../theme/guinji_map_theme.dart';
import '../widgets/guinji_map_widgets.dart';
import 'guinji_share_screen.dart' show buildGuinjiInviteLink;

/// [2026-09 버그수정] 공유 대상(카톡/SMS/더보기) 식별자.
///
/// [배경] 지금까지 여러 버튼이 모두 동일한 `shareGuinjiMapInvite()`를
/// 호출해서, 웹에서는 어떤 버튼을 눌러도 "카카오톡으로 공유" 버튼조차
/// 실제로 카카오톡을 열지 않고 그냥 클립보드 복사만 하는 결함이 있었다
/// (2026-09 실사용자 리포트: "카톡 sns인스타 열리지도 않고"). 이제 버튼별로
/// 실제 목적지 앱/공유 방식이 다르므로 대상을 구분한다.
///
/// [2026-09 인스타그램 옵션 제거] 인스타그램은 외부에서 텍스트를 직접
/// 주입해 공유를 여는 공개 API가 없어(클립보드 복사 + 앱 실행 시도만
/// 가능한 불완전한 구현이었다) 사용자 피드백("인스타그램 공유가 안돼면
/// 그냥 없애버려")에 따라 버튼 자체를 제거했다. enum 값은 다른 코드에서
/// 참조할 일이 없어 완전히 삭제한다.
enum GuinjiShareTarget { kakao, sms, more }

/// [2026-09 버그수정] 공유 버튼(카톡/SMS/인스타/더보기) 공통 핸들러.
///
/// [버그 수정 배경] 기존 구현은 웹에서 `kIsWeb`이면 무조건 클립보드 복사 +
/// 토스트로만 끝냈다("카카오톡으로 공유" 버튼을 눌러도 카카오톡이 전혀
/// 열리지 않음). 이제 대상별로 실제 앱이 열리도록 시도한 뒤, 그 방식이
/// 불가능한 환경에서만 클립보드 복사로 최종 폴백한다.
///
/// - **카카오톡**: `kakaolink://` 커스텀 스킴은 카카오 앱 등록(JS 키) 없이는
///   호출할 수 없으므로, 대신 `https://sharer.kakao.com/talk/friends/picker/link`
///   같은 인증이 필요한 API 대신 **가장 확실한 방법**인 공유 텍스트
///   클립보드 복사 후 카카오톡 웹/앱을 직접 열어주는 `tel:`류 스킴이 없어,
///   `navigator.share`(모바일 브라우저 공유 시트, 카카오톡이 대상 목록에
///   뜸)를 1차로 시도한다.
/// - **SMS**: `sms:?body=...` URI 스킴으로 문자 앱을 직접 연다(카톡 불필요,
///   모든 스마트폰이 기본 지원).
/// - **더보기**: `navigator.share`(웹) / `Share.share()`(네이티브)로 OS
///   표준 공유 시트를 연다.
/// - 모든 경로에서 최종 실패 시 클립보드 복사 + 안내 토스트로 폴백한다.
Future<void> shareGuinjiMapInvite(
  BuildContext context,
  String? token, {
  GuinjiShareTarget target = GuinjiShareTarget.more,
}) async {
  if (token == null || token.isEmpty) return;
  final link = buildGuinjiInviteLink(token);
  final message =
      '귀인지도에 당신을 초대했어요!\n'
      '링크를 열면 생일만 입력해도 관계가 채워져요.\n$link';

  Future<void> copyAndToast(String toastMessage) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    AppToast.show(context, toastMessage);
  }

  Future<bool> tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  switch (target) {
    case GuinjiShareTarget.sms:
      // [공유 페이지 net::ERR_UNKNOWN_URL_SCHEME 버그수정 — 2026-09]
      // `sms:` 커스텀 스킴은 네이티브(Android/iOS)에서는 launchUrl이 OS의
      // 문자 앱을 직접 여는 표준 방법이지만, Flutter Web(사용자가 실제로
      // 쓰는 `https://sintong.kr/app/` 웹 버전)에서는 url_launcher_web이
      // LaunchMode를 무시하고 항상 `window.open('sms:...')`으로 **새 탭**을
      // 열려고 시도한다. 삼성인터넷/카톡 인앱브라우저 등 새 탭에서
      // `sms:` 스킴을 처리할 수 없는 브라우저 컨텍스트에서는 그 새 탭이
      // "페이지 로드에 실패했습니다 / net::ERR_UNKNOWN_URL_SCHEME" 오류
      // 화면으로 뜬다(사용자 리포트: "공유 페이지가 다 이렇게 나오네" —
      // 실제 배포 서버(admin_web 프록시 뒤 nginx, /app 경로로 서빙되는
      // Flutter Web 빌드)에서 재현 확인). 웹에서는 애초에 이 스킴을 시도
      // 하지 않고 곧바로 클립보드 복사로 폴백해야 한다.
      if (!kIsWeb) {
        final smsUri = Uri(
          scheme: 'sms',
          path: '',
          queryParameters: {'body': message},
        );
        if (await tryLaunch(smsUri)) return;
      }
      await copyAndToast('문자 앱을 열 수 없어 링크를 복사했어요.');
      return;

    case GuinjiShareTarget.kakao:
    case GuinjiShareTarget.more:
      break;
  }

  // [카카오톡/더보기 · 근본 수정 — 2026-12] 이전에는 웹에서도
  // `Share.share()`를 직접 호출했는데, `share_plus_web.dart` 내부를 확인해
  // 보니 `navigator.canShare`가 없는 브라우저(카톡/삼성인터넷 인앱)에서는
  // 패키지가 **자체적으로** `mailto:` 스킴을 `window.open()`으로 새 탭에
  // 열려고 시도한다. 그 새 탭이 스킴을 처리하지 못해 `sms:` 버그와 똑같이
  // "페이지 로드에 실패했습니다 / net::ERR_UNKNOWN_URL_SCHEME" 에러 화면이
  // 뜬다(사용자 재리포트: "공유 페이지가 다 이렇게 나오네" — SMS 버튼만
  // 고쳐졌을 뿐 이 경로는 여전히 남아 있었다). 이제 공통 헬퍼
  // [safeShareText](core/util/safe_share.dart)를 사용해 웹에서는 아예
  // `Share.share()`를 시도하지 않고 곧바로 클립보드 복사로 확정 완료한다.
  if (!context.mounted) return;
  await safeShareText(
    context,
    message,
    subject: '귀인지도 초대 · 신통방통',
    copiedMessage: '초대 메시지를 복사했어요. 원하는 앱에 붙여넣어 전달해 주세요.',
    failedMessage: '공유 시트를 열 수 없어 링크를 복사했어요.',
  );
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
    this.onMoreShare,
    this.milestoneReached = false,
    this.milestoneRewardPoint = 0,
  });

  static const routeName = '/guinji-map/m/share';

  final String ownerName;
  final String mapToken;
  final int guinjiCount;
  final int joinedCount;
  final int retentionGoal;

  final VoidCallback? onKakaoShare;
  final VoidCallback? onSmsShare;
  final VoidCallback? onMoreShare;

  /// [친구 초대 마일스톤] 이미 목표 인원(기본 3명)에 도달했는지 —
  /// true면 배너 문구를 "모으는 중" 대신 "축하 이벤트가 열렸어요"로 전환.
  final bool milestoneReached;

  /// 마일스톤 달성 시 지급된(또는 지급될) 복주머니 보너스 개수(배너 문구용).
  final int milestoneRewardPoint;

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
                  reached: widget.milestoneReached,
                  rewardPoint: widget.milestoneRewardPoint,
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
                  // [친구 초대 캐릭터 삽입 — 재수정] 동그란 얼굴 클로즈업
                  // (증명사진처럼 작고 딱딱해 보인다는 피드백)을 걷어내고,
                  // 등롱을 든 반신 이미지(mainHalfBody)를 카드 우측 전체
                  // 높이에 걸쳐 크게 배치한다. 원본 이미지가 불투명 파스텔
                  // 배경이라 사각 이미지를 그대로 얹으면 카드의 다크
                  // 그라데이션과 색이 어긋나므로, ShaderMask로 좌측 경계의
                  // 알파를 서서히 지워 카드 배경이 자연스럽게 배어나오도록
                  // 만든다(사진을 잘라 붙인 듯한 경계선 없음).
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 140,
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, Colors.white, Colors.white],
                        stops: [0.0, 0.55, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        BangtongSeonyeoAssets.mainHalfBody,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
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
                        Padding(
                          // 우측 캐릭터 패널과 텍스트가 겹치지 않도록 우측에
                          // 여백을 확보한다(패널 폭 140 중 앞쪽 절반은
                          // 페이드로 비어 있으므로 100이면 충분히 안전).
                          padding: const EdgeInsets.only(right: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // [줄바꿈 고정] 자동 줄바꿈에 맡기면 카드 폭에
                              // 따라 "귀인지도"라는 한 단어가 "귀인 지"/"도"
                              // 처럼 어색하게 쪼개질 수 있어(사용자 리포트),
                              // 항상 "OO님의" / "귀인지도" 두 줄로 고정한다.
                              Text(
                                '$ownerName님의\n귀인지도',
                                style: const TextStyle(
                                  fontFamily: GmFonts.serif,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '귀인 $guinjiCount명이 밝히는 중',
                                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
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
                    '$ownerName님의 귀인지도',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// [친구 초대 마일스톤 실기능화] 기존에는 "N명 모으면 축하 이벤트가
/// 열려요"라는 문구만 있고 실제로 연결된 기능이 전혀 없던 순수 장식
/// 배너였다("3명 모이면 이벤트가 있어요는 도대체 뭐야?" 사용자 지적).
/// 이제 서버가 실제로 복주머니 30개를 지급하는 마일스톤과 연동해, 달성 여부에 따라
/// 문구와 아이콘이 전환된다.
class _RetentionBanner extends StatelessWidget {
  const _RetentionBanner({
    required this.goal,
    required this.joined,
    required this.remaining,
    this.reached = false,
    this.rewardPoint = 0,
  });

  final int goal;
  final int joined;
  final int remaining;

  /// 이미 목표 인원에 도달했는지(서버 `GuinjiProvider.milestoneReached`).
  final bool reached;

  /// 마일스톤 보너스 복주머니 개수(예: 30). 달성 문구에 노출.
  final int rewardPoint;

  @override
  Widget build(BuildContext context) {
    final displayPoint = rewardPoint > 0 ? rewardPoint : 30;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (reached ? GmColors.rose500 : GmColors.gold).withValues(alpha: 0.12),
        border: Border.all(
          color: (reached ? GmColors.rose500 : GmColors.gold).withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: reached ? GmColors.rose500 : GmColors.gold,
              shape: BoxShape.circle,
            ),
            child: reached
                ? const Icon(Icons.celebration, size: 16, color: Colors.white)
                : Text(
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
                  reached
                      ? '축하 이벤트가 열렸어요 · 복주머니 +$displayPoint개 지급'
                      : '$goal명 모으면 축하 이벤트가 열려요',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.3,
                    color: GmColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reached
                      ? '친구 $joined명이 함께해 주었어요. 고마운 마음을 담았어요.'
                      : '지금 $joined명 · $remaining명 더 필요해요',
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
