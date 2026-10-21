import 'package:flutter/material.dart';
import '../../../core/config/env_config.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import '../../../core/util/original_result_capture.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/share_api_service.dart';
import '../domain/share_result_model.dart';
import '../../../core/util/safe_share.dart';


/// 결과 공유(Share Result) — 5개 결과 화면(운세/타로/관상/손금/소원성)이
/// 공통으로 호출하는 공유 트리거 헬퍼.
///
/// 확정된 공유·저장 계약:
/// 앱 결과 = 전체 PNG를 OS 공유창으로 전달. 설치 안내는 확인된 Play Store만.
/// 웹 결과 = 공개 동의 후 /web-result/{id} 웹 결과페이지 링크 전달.
/// 홈페이지 = 홈페이지 URL. 초대 = 기존 참여 토큰 링크(결과와 혼동 금지).
/// 저장 = 앱 갤러리 / 웹 파일 다운로드. 취소·실패를 성공으로 표시하지 않는다.
///
/// [카카오 SDK 미탑재 안내] `kakao_flutter_sdk_share` 패키지가 설치되어
/// 있지 않고(Flutter 3.35.4/Dart 3.9.2 락 환경과의 호환성 확인 전이라 임의
/// 추가하지 않음) 카카오 JS 키도 코드베이스에 없어(웹 폴백 불가), "카카오톡
/// 공유" 전용 네이티브 카드 공유는 아직 구현하지 않는다. 대신 표준 OS
/// 공유 시트(안드로이드에서는 카카오톡이 대상 목록에 자연히 노출됨)로
/// 동일한 목적을 달성한다 — 이 한계는 사용자에게 별도 고지가 필요하다.
///
/// 구조화 payload에는 불필요한 원본 개인정보를 추가하지 않는다.
/// 원본 이미지 공유는 화면에 보이는 정보를 포함하므로 업로드 전에
/// 공개 안내와 별도 동의를 받는다.
class ShareService {
  ShareService._();

  static final ShareApiService _api = ShareApiService();

  /// 홈페이지·이미 존재하는 공개 웹 결과는 그 페이지 주소를 공유한다.
  /// 초대 토큰 링크는 기존 초대 서비스가 담당하며 이 경로로 생성하지 않는다.
  static Future<void> shareWebPage(BuildContext context, {required String title, required String url}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty) {
      if (context.mounted) AppToast.show(context, '공유할 페이지 주소가 올바르지 않아요.', isError: true);
      return;
    }
    await safeShareText(context, '$title\n$uri', subject: title);
  }

  /// 공유 링크를 생성하고 곧바로 OS 공유 시트/클립보드로 전달한다.
  ///
  /// [subject]는 카카오톡 등 일부 타깃에서 부제목으로 쓰일 수 있는 값이며,
  /// 생략 시 결과 타입별 기본값을 사용한다.
  static final _resultSharing = Expando<bool>();
  static Future<void> shareResult(
    BuildContext context, {
    required ShareResultType resultType,
    required String title,
    required String description,
    required Map<String, dynamic> payload,
    String? imageUrl,
    String? sourceRefId,
    String? subject,
    GlobalKey? originalResultKey,
    List<GlobalKey> originalLeadingKeys = const [],
    List<GlobalKey> originalTrailingKeys = const [],
    List<GlobalKey> originalOverlayKeys = const [],
    Uint8List? preCapturedPng,
  }) async {
    if (!context.mounted || _resultSharing[context] == true) return;
    _resultSharing[context] = true;
    try {
      await _shareResult(context, resultType: resultType, title: title, description: description,
        payload: payload, imageUrl: imageUrl, sourceRefId: sourceRefId, subject: subject,
        originalResultKey: originalResultKey, originalLeadingKeys: originalLeadingKeys,
        originalTrailingKeys: originalTrailingKeys, originalOverlayKeys: originalOverlayKeys,
        preCapturedPng: preCapturedPng);
    } catch (_) {
      if (context.mounted) AppToast.show(context, '결과 공유에 실패했어요. 다시 시도해주세요.', isError: true);
    } finally { _resultSharing[context] = false; }
  }

  static Future<void> _shareResult(
    BuildContext context, {
    required ShareResultType resultType,
    required String title,
    required String description,
    required Map<String, dynamic> payload,
    String? imageUrl,
    String? sourceRefId,
    String? subject,
    GlobalKey? originalResultKey,
    List<GlobalKey> originalLeadingKeys = const [],
    List<GlobalKey> originalTrailingKeys = const [],
    List<GlobalKey> originalOverlayKeys = const [],
    Uint8List? preCapturedPng,
  }) async {
    // [웹·앱 공유 캡처 경로 정상화 — 2026-12] 과거(2026-11)에는 웹에서
    // `LateInitializationError`가 재발해 캡처 자체를 생략했으나, 실제 근본
    // 원인은 `d62af35`에서 확인된 AdSense `HtmlElementView`(플랫폼뷰)와
    // Skia 캔버스 간 합성 타이밍 경쟁이었고, 이는 `WebAdService.isCapturing`
    // 가드(`captureOriginalResult` 내부, 캡처 중 광고 플랫폼뷰 생성을
    // 구조적으로 차단)로 이미 해결되었다 — "이미지로 저장" 경로(예:
    // story_detail_screen.dart)는 플랫폼 분기 없이 웹에서도 이 가드 덕분에
    // 안전하게 캡처 중임이 확인됐다. 공유 경로만 과거 생략 로직이 남아
    // 비일관 상태였으므로, 동일하게 웹에서도 캡처를 시도하도록 정상화한다.
    // 캡처가 끝내 실패하면(네트워크·위젯 초기화 지연 등) 오류를 명확히
    // 안내하고 중단한다 — 임의 디자인으로 대체하거나 조용히 넘어가지 않는다.
    Uint8List? originalPng = preCapturedPng;
    if (originalPng == null && originalResultKey != null) {
      // 캡처 1회 실패 시 짧은 지연 후 1회 자동 재시도 — 두 번째 시도까지
      // 실패할 때만 실제 오류로 간주해 안내한다. (앱·웹 공통 동작)
      try {
        originalPng = await captureOriginalResult(
          originalResultKey,
          leadingKeys: originalLeadingKeys,
          trailingKeys: originalTrailingKeys,
          overlayKeys: originalOverlayKeys,
        );
      } catch (_) {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (!context.mounted) return;
          originalPng = await captureOriginalResult(
            originalResultKey,
            leadingKeys: originalLeadingKeys,
            trailingKeys: originalTrailingKeys,
            overlayKeys: originalOverlayKeys,
          );
        } catch (error) {
          if (context.mounted) {
            AppToast.show(context, '원래 결과 준비 실패: $error', isError: true);
          }
          return;
        }
      }
    }
    if (!context.mounted) return;
    // [신통방통 앱·웹 공유 근본 정상화 — 2026-11] 공유 링크는 플랫폼 공통으로
    // 서버(POST /api/public/share, 원칙 3: 기존 백엔드 재사용)에 생성한다.
    // 과거에는 !kIsWeb 분기가 여기서 바로 return 하며 createShareLink()를
    // 전혀 호출하지 않아 앱 공유에는 공유 링크 자체가 없었다(핵심 버그).
    // 이제 앱도 원본 이미지를 함께 업로드해 /r/{id} 딥링크를 만들고,
    // 웹은 지금처럼 /web-result/{id}만 사용한다 — 동의 절차도 플랫폼
    // 공통으로 적용해 앱에서도 서버 업로드 전 동일한 공개 동의를 받는다.
    if (originalPng != null) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('이 결과 그대로 공개할까요?'),
          content: const Text(
            '공유 링크를 가진 사람은 결과 화면에 보이는 이름·질문·사진·본문을 모두 볼 수 있어요. 공개하고 싶지 않은 내용이 있다면 취소해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('그대로 공유'),
            ),
          ],
        ),
      );
      if (approved != true || !context.mounted) return;
    }
    final result = await _api.createShareLink(
      resultType: resultType,
      title: title,
      description: description,
      payload: payload,
      imageUrl: imageUrl,
      sourceRefId: sourceRefId,
      originalPng: originalPng,
    );

    if (!result.success || result.data == null) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        result.errorMessage ?? '공유 링크 생성에 실패했습니다.',
        isError: true,
      );
      return;
    }

    final shareId = result.data!.shareId;

    if (!kIsWeb) {
      // [앱 전용 — §3-A] /r/{id}는 Android App Links 대상 주소다. 받는 사람
      // 기기에 신통방통 앱이 설치·검증되어 있으면 OS가 바로 앱의
      // SharedResultScreen으로 연결하고, 그렇지 않으면 동일 경로의 웹 결과
      // 페이지(/r/[id] SSR)로 자연스럽게 폴백한다(AndroidManifest.xml
      // pathPrefix="/r" 참고). 절대 /web-result로 바꿔치기하지 않는다 —
      // 그러면 App Links 인터셉트가 발생하지 않아 앱 설치자도 웹으로만
      // 빠지게 된다.
      final deepLinkUrl = EnvConfig.resultDeepLinkUrl(shareId);
      if (!context.mounted) return;
      if (originalPng != null) {
        await _sendImage(context, title, originalPng, shareUrl: deepLinkUrl);
      } else {
        await safeShareText(context, '$title\n$deepLinkUrl', subject: subject ?? title);
      }
      return;
    }

    // [웹 전용 — §3-B, 2027-02 중복 단계 제거] 받는 사람이 열어볼 완전한
    // 결과 페이지(/web-result/{id})는 서버가 이미 만들어뒀다 — 공유
    // 버튼을 누른 행위 자체가 이미 "이 링크를 보는 사람에게 보여주겠다"는
    // 동의이므로, 그 위에 또 "이 결과 그대로 공개할까요?" 확인 팝업이나
    // 결과를 다시 렌더링해 보여주는 바텀시트(FullResultSheet)를 거치게
    // 하는 건 의미 없는 2중 작업이다("공유하기 눌렀는데 왜 또 한 번
    // '전송' 버튼을 눌러야 하냐" — 사용자 명시 지적). 링크 생성 즉시
    // OS 공유 시트(또는 클립보드 폴백)로 바로 넘긴다 — 결과 페이지
    // 자체를 재구성해서 보여줄 필요가 전혀 없다. 받는 사람은 그 주소를
    // 열면 완전한 결과를 바로 본다(한 번만 보면 되는 열람자 — 중간에
    // 거쳐야 할 단계가 없어야 한다).
    final shareUrl = EnvConfig.webResultUrl(shareId);
    if (!context.mounted) return;
    await safeShareText(context, '$title\n$shareUrl', subject: subject ?? title);
  }

  /// [앱 전용 — 이미지 직접 공유] 원본 결과 이미지를 OS 공유 시트로 바로
  /// 전송한다. 미지원·실패는 오류로 알리며 텍스트 공유로 대체하지 않는다.
  /// 공유창 종료는 수신 앱의 실제 전달 완료를 보장하지 않는다.
  static final _imageSharing = Expando<bool>();
  static Future<void> shareImageDirectly(BuildContext context, String title, Uint8List png, {String? shareUrl}) async {
    if (_imageSharing[context] == true || !context.mounted) return;
    _imageSharing[context] = true;
    try { await _sendImage(context, title, png, shareUrl: shareUrl); }
    finally { _imageSharing[context] = false; }
  }

  static Future<void> _sendImage(
    BuildContext context,
    String title,
    Uint8List png, {
    String? shareUrl,
  }) async {
    if (kIsWeb) {
      if (context.mounted) AppToast.show(context, '웹에서는 결과페이지 링크로 공유해주세요.', isError: true);
      return;
    }
    if (png.isEmpty) {
      AppToast.show(context, '결과 이미지가 비어 있어요. 다시 시도해주세요.', isError: true);
      return;
    }
    // 확정 기준: 앱 결과는 PNG+공유링크, 웹 결과는 웹 결과 URL, 초대는 별도 링크.
    // 설치 안내는 확인된 Play Store 설정이 있을 때만 붙인다. 홈페이지로 대체하지 않는다.
    final store = Uri.tryParse(EnvConfig.appDownloadUrl);
    final storeReady = store?.scheme == 'https' && store?.host == 'play.google.com' && store?.path == '/store/apps/details' && store!.queryParameters['id']?.isNotEmpty == true;
    // [신통방통 공유 근본 정상화] 공유 링크(shareUrl)가 있으면 이미지와 함께
    // 반드시 본문에 포함한다 — 링크가 없으면 받는 사람이 특정 결과로
    // 돌아올 방법이 없어 §3-A 요구사항(해당 결과로 연결)을 만족하지 못한다.
    final linkLine = shareUrl != null ? '\n$shareUrl' : '';
    final shareText = '$title$linkLine\n신통방통에서 확인했어요.${storeReady ? '\n앱 설치: $store' : ''}';
    void reportFailure() {
      if (!context.mounted) return;
      AppToast.show(context, '결과 이미지를 공유하지 못했어요. 이미지를 저장한 뒤 첨부하거나 다시 시도해주세요.', isError: true);
    }

    try {
      final result = await Share.shareXFiles(
        [
          XFile.fromData(
            png,
            name: 'sintong_result_${DateTime.now().millisecondsSinceEpoch}.png',
            mimeType: 'image/png',
          ),
        ],
        text: shareText,
        subject: '신통방통 결과',
      );
      if (result.status == ShareResultStatus.unavailable) {
        reportFailure();
      }
    } catch (_) {
      reportFailure();
    }
  }

  // ignore: unused_element
  static String _defaultSubject(ShareResultType type) {
    switch (type) {
      // ignore: deprecated_member_use_from_same_package
      case ShareResultType.fortune:
        return '오늘의 운세 · 신통방통';
      case ShareResultType.tarot:
        return '타로 결과 · 신통방통';
      case ShareResultType.face:
        return '관상 결과 · 신통방통';
      case ShareResultType.palm:
        return '손금 결과 · 신통방통';
      case ShareResultType.wish:
        return '소원 성취 · 신통방통';
      case ShareResultType.saju:
        return '정통사주 결과 · 신통방통';
      case ShareResultType.relationship:
        return '귀인지도 결과 · 신통방통';
    }
  }
}
