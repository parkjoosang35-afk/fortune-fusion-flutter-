import 'package:flutter/material.dart';
import '../../../core/config/env_config.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import '../../../core/util/original_result_capture.dart';
import '../presentation/full_result_sheet.dart';
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
    Uint8List? originalPng = preCapturedPng;
    if (originalPng == null && originalResultKey != null) {
      try {
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
    if (!context.mounted) return;
    // [앱·웹 공유 분리 — 2026-10-14 사용자 결정] 앱은 결과 원본 이미지를
    // 공유 시트로 직접 전송한다(서버 업로드·/r 링크 생성·공개 동의 팝업
    // 없음 — 이미지를 받는 상대는 공유 시트 수신자뿐). 웹은 기존대로
    // 업로드 후 /r/{id} 결과 페이지 링크로 공유한다. 앱 공유 문구 링크는
    // 스토어 등록 전까지 https://sintong.kr(등록 후 교체 예정).
    if (!kIsWeb) {
      if (originalPng == null) {
        AppToast.show(context, '결과 이미지가 준비되지 않았어요. 다시 시도해주세요.', isError: true);
        return;
      }
      await shareImageDirectly(context, title, originalPng);
      return;
    }
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

    final shareUri = Uri.parse(result.data!.shareUrl);
    final shareUrl = shareUri.replace(path: shareUri.path.replaceFirst(RegExp(r'^/r/'), '/web-result/'), query: null).toString();
    if (!context.mounted) return;
    await showFullResultSheet(
      context,
      title: title,
      shareUrl: shareUrl,
      payload: payload,
      originalPng: originalPng,
    );
  }

  /// [앱 전용 — 이미지 직접 공유] 원본 결과 이미지를 OS 공유 시트로 바로
  /// 전송한다. 미지원·실패는 오류로 알리며 텍스트 공유로 대체하지 않는다.
  /// 공유창 종료는 수신 앱의 실제 전달 완료를 보장하지 않는다.
  static final _imageSharing = Expando<bool>();
  static Future<void> shareImageDirectly(BuildContext context, String title, Uint8List png) async {
    if (_imageSharing[context] == true || !context.mounted) return;
    _imageSharing[context] = true;
    try { await _sendImage(context, title, png); }
    finally { _imageSharing[context] = false; }
  }

  static Future<void> _sendImage(
    BuildContext context,
    String title,
    Uint8List png,
  ) async {
    if (kIsWeb) {
      if (context.mounted) AppToast.show(context, '웹에서는 결과페이지 링크로 공유해주세요.', isError: true);
      return;
    }
    if (png.isEmpty) {
      AppToast.show(context, '결과 이미지가 비어 있어요. 다시 시도해주세요.', isError: true);
      return;
    }
    // 확정 기준: 앱 결과는 PNG, 웹 결과는 웹 결과 URL, 초대는 별도 링크.
    // 설치 안내는 확인된 Play Store 설정이 있을 때만 붙인다. 홈페이지로 대체하지 않는다.
    final store = Uri.tryParse(EnvConfig.appDownloadUrl);
    final storeReady = store?.scheme == 'https' && store?.host == 'play.google.com' && store?.path == '/store/apps/details' && store!.queryParameters['id']?.isNotEmpty == true;
    final shareText = '$title\n신통방통에서 확인했어요.${storeReady ? '\n앱 설치: $store' : ''}';
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
