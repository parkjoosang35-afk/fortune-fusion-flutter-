import 'package:flutter/material.dart';
import '../../../core/util/safe_share.dart';
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
/// [PII 미포함 원칙 — 호출부 책임] [payload]에는 화면 표시에 필요한 값만
/// 담아야 하며, 원본 생년월일/실명/촬영 사진/전화번호/이메일/소원 원문
/// 등을 절대 포함하지 않는다(제안서 (h)절 보안 원칙).
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
  }) async {
    final result = await _api.createShareLink(
      resultType: resultType,
      title: title,
      description: description,
      payload: payload,
      imageUrl: imageUrl,
      sourceRefId: sourceRefId,
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

    final shareUrl = result.data!.shareUrl;
    final message = '$title\n$description\n$shareUrl';

    if (!context.mounted) return;
    await safeShareText(
      context,
      message,
      subject: subject ?? _defaultSubject(resultType),
      copiedMessage: '공유 링크를 복사했어요. 원하는 앱에 붙여넣어 전달해 주세요.',
      failedMessage: '공유 시트를 열 수 없어 링크를 복사했어요.',
    );
  }

  static String _defaultSubject(ShareResultType type) {
    switch (type) {
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
    }
  }
}
