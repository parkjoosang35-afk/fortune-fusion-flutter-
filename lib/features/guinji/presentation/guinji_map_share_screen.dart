import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/util/safe_share.dart';
import '../../../core/widgets/app_toast.dart';
import '../application/guinji_provider.dart';
import '../share/guinji_share_kakao.dart' show guinjiInviteTemplate;
import '../theme/guinji_map_theme.dart';
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
  // [귀인지도 v2 리스킨 — 핸드오프 이식] 카카오톡 FeedTemplate 타이틀에
  // 쓸 지도 소유자 표시 이름(`guinjiInviteTemplate`의 `host` 인자). 호출부가
  // 넘겨주지 않으면(예: 기존 GuinjiShareScreen 경로) 안전한 기본값으로
  // 떨어진다 — 시그니처 변경 없이 하위 호환.
  String? hostName,
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
    } catch (e) {
      // [2026-12 버그수정 — guinji-invite-fix 지시서 R3] 이전에는 실패를
      // 완전히 무음으로 삼켜서 "왜 안 열리는지" 원인 추적이 불가능했다.
      // 디버그 빌드에서만 원인을 로그로 남긴다(릴리즈에는 영향 없음).
      if (kDebugMode) {
        debugPrint('[GuinjiShare] launchUrl($uri) 실패: $e');
      }
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
      // [귀인지도 v2 리스킨 — 핸드오프 이식, 죽은 코드 연결] `guinji_share_kakao.dart`의
      // [guinjiInviteTemplate]이 지금까지 정의만 되어 있고 실제로 호출되는
      // 곳이 없어("카카오톡으로 공유" 버튼을 눌러도 핸드오프가 의도한 OG
      // 카드형 FeedTemplate이 아니라 그냥 일반 공유 시트/클립보드로만
      // 동작) — 발견 즉시 연결한다.
      //
      // [웹 미지원] `kakao_flutter_sdk_share`의 web 플랫폼 구현은
      // 메서드 채널을 등록하지 않아(패키지 자체가 네이티브 전용 Talk
      // 공유만 지원) 웹에서 `ShareClient.instance.shareDefault()`를 호출하면
      // `MissingPluginException`이 발생한다. 따라서 네이티브(Android/iOS)
      // 에서만 시도하고, 실패하거나 웹이면 기존 폴백(아래 safeShareText)
      // 으로 떨어진다 — 기존 SMS/더보기 동작은 전혀 바꾸지 않는다.
      if (!kIsWeb) {
        try {
          final available = await ShareClient.instance
              .isKakaoTalkSharingAvailable();
          if (!available) {
            if (kDebugMode) {
              debugPrint('[GuinjiShare] 카카오톡 미설치/공유 불가 — 공통 폴백으로 전환');
            }
          } else {
            // [2026-12 카카오톡 공유 버튼 무반응 버그 — 근본 원인 수정]
            // `ShareClient.shareDefault()`는 카카오톡 SDK 공식 문서/예제가
            // 분명히 보여주듯 카카오톡을 직접 실행하지 않고, 카카오톡 앱
            // 실행용 `Uri`만 "생성해서 반환"하는 함수다(SDK 소스
            // `share_client.dart`의 `_talkWithResponse()`가 Uri를 만들어
            // return만 하고 끝 — 내부에서 아무 것도 실행하지 않음). 실제로
            // 카카오톡 앱을 여는 것은 그 Uri를 받아 별도로 호출하는
            // `ShareClient.instance.launchKakaoTalk(uri)` 몫이다. 이전
            // 코드는 `shareDefault()`가 반환한 Uri를 그냥 버리고 바로
            // `return`해버려 카카오톡이 전혀 실행되지 않았다 — 예외도 나지
            // 않으므로(Uri 생성 자체는 성공) catch 폴백도 타지 않고, 버튼을
            // 눌러도 조용히 아무 반응이 없는 증상으로 나타났다(사용자
            // 리포트: "카카오톡 공유도 좀 봐줘 공유가 안돼").
            final shareUri = await ShareClient.instance.shareDefault(
              template: guinjiInviteTemplate(
                host: hostName ?? '친구',
                token: token,
              ),
            );
            await ShareClient.instance.launchKakaoTalk(shareUri);
            return;
          }
        } catch (e) {
          // [2026-12 버그수정 — guinji-invite-fix 지시서 R3] "카카오톡
          // 공유 실패" 리포트의 원인 추적을 위해 디버그 빌드에서 예외를
          // 로그로 남긴다. 흔한 원인: JS 키 미등록/플랫폼 도메인 미등록,
          // SDK 미초기화(KakaoSdk.init 누락/중복 호출), FeedTemplate
          // 파라미터 오류(이미지 URL 접근 불가 등) — PDF 6단계 체크리스트
          // 참고. 사용자에게는 여전히 조용히 아래 공통 폴백(클립보드 복사
          // 등)으로 넘어간다 — UX는 바꾸지 않는다.
          if (kDebugMode) {
            debugPrint('[GuinjiShare] 카카오톡 공유 실패: $e — 공통 폴백으로 전환');
          }
          // 카카오톡 미설치/전송 실패 — 아래 공통 폴백으로 넘어간다.
        }
      }
      break;
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
///
/// [귀인지도 핸드오프 v4 — A12 재이식, 2026 최종개발 핸드오프] README
/// §3-1 A12 행이 명시한 `TpInviteSheet` 구조로 내부를 전면 교체했다:
/// "전체 화면 → **바텀시트**. 카카오 배너 + 더보기. 우상단 `⋯` → **링크
/// 관리 패널**. **마일스톤 배너·OG 미리보기 카드·문자/인스타 아이콘 줄
/// 삭제**". 라우트 자체(전체화면 PageRoute, `pushNamed` 3개 호출부,
/// 위젯 생성자 시그니처)는 그대로 둔 채 — 호출부/테스트 변경 없이 —
/// 화면을 투명 Scaffold + 하단 정렬 카드로 그려 시각적으로 바텀시트처럼
/// 보이게 한다(배경을 탭하면 `maybePop()`으로 닫힘, 핸들바+카드 자체를
/// 탭해도 닫히지 않도록 내부에서 탭을 흡수).
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
  // ── [귀인지도 초대링크 재발급 v1.1] 소유자 링크 관리 ────────────
  bool _linkActionLoading = false;

  /// [A12 핸드오프 재이식] 우상단 "⋯"로 토글하는 "링크 관리" 패널 노출
  /// 여부(`TpInviteSheet`의 `manage` 로컬 상태와 동일한 역할).
  bool _manageOpen = false;

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 현재 링크 상태(active/revoked)를 조회해 배지·버튼을
    // 채운다. 실패해도 화면 전체를 막지 않는다(provider가 조용히 무시).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<GuinjiProvider>().loadInviteStatus();
    });
  }

  /// "새 링크 만들기"(재발급) 확인 다이얼로그 — 옛 링크가 즉시 무효화됨을
  /// 반드시 먼저 확인시킨다(§08 API 응답의 warning 문구와 동일한 취지).
  Future<void> _confirmReissue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 링크를 만들까요?'),
        content: const Text(
          '이전 링크로 들어오던 사람은 더 이상 들어올 수 없어요.\n'
          '이미 지도에 합류한 친구는 그대로 남아있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('새 링크 만들기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _linkActionLoading = true);
    final provider = context.read<GuinjiProvider>();
    final data = await provider.reissueInviteLink();
    if (!mounted) return;
    setState(() => _linkActionLoading = false);
    if (data == null) {
      AppToast.show(context, provider.error ?? '링크 재발급에 실패했습니다.');
      return;
    }
    AppToast.show(context, '새 링크를 만들었어요.');
  }

  /// "링크 중단" 확인 다이얼로그.
  Future<void> _confirmRevoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('링크를 중단할까요?'),
        content: const Text(
          '이 링크로 더 이상 새로운 친구가 들어올 수 없어요.\n'
          '언제든 다시 열 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('중단하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _linkActionLoading = true);
    final provider = context.read<GuinjiProvider>();
    final ok = await provider.revokeInviteLink();
    if (!mounted) return;
    setState(() => _linkActionLoading = false);
    if (!ok) {
      AppToast.show(context, provider.error ?? '링크 중단에 실패했습니다.');
      return;
    }
    AppToast.show(context, '링크를 중단했어요.');
  }

  Future<void> _reactivate() async {
    setState(() => _linkActionLoading = true);
    final provider = context.read<GuinjiProvider>();
    final ok = await provider.reactivateInviteLink();
    if (!mounted) return;
    setState(() => _linkActionLoading = false);
    if (!ok) {
      AppToast.show(context, provider.error ?? '링크 중단 해제에 실패했습니다.');
      return;
    }
    AppToast.show(context, '링크를 다시 열었어요.');
  }

  @override
  Widget build(BuildContext context) {
    // [A12 핸드오프 재이식] 전체화면 라우트(guinjiPageRoute, opaque:
    // true)는 그대로 두되, 내부를 투명 Scaffold + 하단 정렬 카드로 그려
    // 시각적으로 "바텀시트"처럼 보이게 한다. 배경(카드 바깥)을 탭하면
    // 닫히고, 카드 자체를 탭해도 그 탭이 배경까지 전달되지 않도록
    // 안쪽 GestureDetector가 흡수한다.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: GmColors.sheet,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: GmColors.gold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: GmColors.line,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Text(
                                '귀인 초대하기',
                                style: TextStyle(
                                  fontFamily: GmText.display,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                  color: GmColors.fg,
                                ),
                              ),
                            ),
                            // [A12 §3-1 "우상단 ⋯ → 링크 관리 패널"] 새
                            // 화면으로 이동하지 않고 이 시트 안에서
                            // 토글한다 — _LinkManagementSection(재발급/
                            // 중단/다시켜기/상태)은 기존 로직을 그대로
                            // 재사용(변경 없음).
                            _GmSheetIconButton(
                              icon: Icons.more_horiz,
                              tooltip: '링크 관리',
                              selected: _manageOpen,
                              onTap: () =>
                                  setState(() => _manageOpen = !_manageOpen),
                            ),
                            const SizedBox(width: 6),
                            _GmSheetIconButton(
                              icon: Icons.close,
                              tooltip: '닫기',
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '링크를 받은 지인이 생년월일을 넣으면\n바로 지도에 별이 떠요',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: GmColors.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // [A12 "카카오 배너 + 더보기"] 마일스톤 배너·OG
                        // 미리보기 카드·문자(SMS)/인스타 아이콘 줄·링크
                        // 복사 줄은 핸드오프 §8 삭제 항목에 따라 전부
                        // 제거했다 — 공유 수단은 카카오톡과 "더보기"(OS
                        // 공유시트/클립보드 폴백) 두 가지로만 압축한다.
                        _ShareOption(
                          icon: Icons.chat_bubble,
                          iconColor: const Color(0xFF3A1D1D),
                          bg: const Color(0xFFFEE500),
                          title: '카카오톡으로 초대',
                          desc: '친구를 고르면 바로 보내져요',
                          onTap: widget.onKakaoShare,
                        ),
                        const SizedBox(height: 8),
                        _ShareOption(
                          icon: Icons.more_horiz,
                          title: '더보기',
                          desc: '다른 앱으로 초대장 보내기',
                          onTap: widget.onMoreShare,
                        ),
                        if (_manageOpen) ...[
                          const SizedBox(height: 18),
                          const _LinkManagementSectionDivider(),
                          const SizedBox(height: 12),
                          _LinkManagementSection(
                            loading: _linkActionLoading,
                            onReissue: _confirmReissue,
                            onRevoke: _confirmRevoke,
                            onReactivate: _reactivate,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [A12 핸드오프 재이식] 초대 시트 헤더의 "⋯"(링크 관리 토글)/"✕"(닫기)
/// 아이콘 버튼 — `TpIconBtn`(반투명 원형 배경) 스타일을 재현한다.
class _GmSheetIconButton extends StatelessWidget {
  const _GmSheetIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: selected
          ? GmColors.gold.withValues(alpha: 0.18)
          : GmColors.fg.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 17,
            color: selected ? GmColors.gold : GmColors.fg,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// [귀인지도 초대링크 재발급 v1.1 — §07-4] 공유 화면 하단 "링크 관리" 섹션.
/// 기존 화면(복사·카톡·SMS 공유)에 상태 배지 + 버튼 2개(재발급/중단·
/// 중단해제)만 얹는다 — 지시서가 명시한 대로 새 화면을 만들지 않는다.
class _LinkManagementSectionDivider extends StatelessWidget {
  const _LinkManagementSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: GmColors.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '링크 관리',
            style: TextStyle(
              fontSize: 11,
              color: GmColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: GmColors.line)),
      ],
    );
  }
}

class _LinkManagementSection extends StatelessWidget {
  const _LinkManagementSection({
    required this.loading,
    required this.onReissue,
    required this.onRevoke,
    required this.onReactivate,
  });

  final bool loading;
  final VoidCallback onReissue;
  final VoidCallback onRevoke;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuinjiProvider>();
    final inviteStatus = provider.inviteStatus;
    final isRevoked = provider.isInviteRevoked;
    final joinedMemberCount = provider.joinedMemberCount;

    // [상태 배지] "초대 링크 활성 · 지금까지 N명이 참여했어요 · 만료 없음"
    // (§07-4 카피 — 숫자를 쓰더라도 인원수일 뿐, 기간 숫자는 절대 넣지
    // 않는다. inviteStatus를 아직 조회하지 못했으면(null) 배지를 생략).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inviteStatus != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isRevoked
                  ? GmColors.muted.withValues(alpha: 0.08)
                  : GmColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  isRevoked ? Icons.link_off : Icons.link,
                  size: 16,
                  color: isRevoked ? GmColors.muted : GmColors.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isRevoked
                        ? '초대 링크 중단됨'
                        : joinedMemberCount != null
                        ? '초대 링크 활성 · 지금까지 $joinedMemberCount명이 참여했어요 · 만료 없음'
                        : '초대 링크 활성 · 만료 없음',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isRevoked ? GmColors.muted : GmColors.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: loading ? null : onReissue,
                icon: const Icon(Icons.autorenew, size: 16),
                label: const Text('새 링크 만들기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GmColors.fg,
                  side: BorderSide(color: GmColors.line),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                // [멱등 액션 전환] 이미 중단 상태면 버튼이 "중단 해제"로
                // 바뀐다(§05 #3 reactivate) — 별도 화면 없이 같은 자리에서
                // 토글.
                onPressed: loading
                    ? null
                    : (isRevoked ? onReactivate : onRevoke),
                icon: Icon(
                  isRevoked
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  size: 16,
                ),
                label: Text(isRevoked ? '중단 해제' : '링크 중단'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isRevoked ? GmColors.gold : GmColors.danger,
                  side: BorderSide(
                    color: isRevoked
                        ? GmColors.gold
                        : GmColors.danger.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
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
            // [2026-12 버그수정] 카카오(bg != null)는 기존처럼 전용 진한
            // 갈색(#3A1D1D)을 쓰고, SMS/더보기(bg == null, 흰 카드)는
            // 다크 배경 전용 `GmColors.fg`가 아니라 라이트 카드 전용
            // `fgOnLight`을 써야 대비가 확보된다.
            Icon(icon, size: 22, color: iconColor ?? GmColors.fgOnLight),
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
                      color: isKakao
                          ? const Color(0xFF3A1D1D)
                          : GmColors.fgOnLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isKakao
                          ? const Color(0xFF3A1D1D).withValues(alpha: 0.7)
                          : GmColors.mutedOnLight,
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

// [2026-12 버그수정 — guinji-invite-fix 지시서 R2, 완전 삭제]
// "N명 모으면 축하 이벤트가 열려요" 배너(`_RetentionBanner`)를 화면에서
// 완전히 제거했다. 이 배너는 공유 화면에만 존재하는 순수 표시용 위젯이고,
// 실제 마일스톤 보상 지급(복주머니 N개)은 `GuinjiProvider.milestoneReached`
// /`milestoneJustReached` → 결과 화면(`guinji_map_result_screen.dart`의
// `_maybeShowMilestoneCelebration()`) 경로로 완전히 분리되어 있어 이 배너
// 삭제와 무관하게 그대로 동작한다. 참여자 수 집계(`GuinjiProvider.people`,
// `joinedCount`)도 이 배너와 무관하게 계속 유지된다 — 지워진 것은 오직
// "모으는 중 / N명 더 필요해요" 안내 UI뿐이다.
