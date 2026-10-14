import 'package:flutter/material.dart';
import '../../../core/config/env_config.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import '../../../core/util/original_result_capture.dart';
import '../presentation/full_result_sheet.dart';
import '../../../core/widgets/app_toast.dart';
import '../data/share_api_service.dart';
import '../domain/share_result_model.dart';


/// 결과 공유(Share Result) — 5개 결과 화면(운세/타로/관상/손금/소원성)이
/// 공통으로 호출하는 공유 트리거 헬퍼.
///
/// [흐름] ①서버에 공유 링크 생성 요청(`POST /api/public/share`) → ②성공하면
/// `https://sintong.kr/r/{shareId}` 링크가 포함된 문구를 [safeShareText]로
/// 전달(OS 공유 시트/클립보드 복사 — 카카오톡·SMS·더보기 모두 이 표준
/// 경로로 처리됨, guinji_map_share_screen.dart와 동일한 최종 폴백 전략).
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

  /// 공유 링크를 생성하고 곧바로 OS 공유 시트/클립보드로 전달한다.
  ///
  /// [subject]는 카카오톡 등 일부 타깃에서 부제목으로 쓰일 수 있는 값이며,
  /// 생략 시 결과 타입별 기본값을 사용한다.
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
  static Future<void> shareImageDirectly(
    BuildContext context,
    String title,
    Uint8List png,
  ) async {
    final shareText = '$title\n신통방통에서 확인했어요. 앱 다운로드: ${EnvConfig.appDownloadUrl}';
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
