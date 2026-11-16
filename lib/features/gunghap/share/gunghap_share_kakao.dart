// [궁합지도 Flutter 화면 개발 — §2②] 궁합지도 전용 카카오톡 공유.
//
// guinji_share_kakao.dart / guinji_map_share_screen.dart의 shareGuinjiMapInvite
// 패턴을 그대로 재사용한다(§6 "기존 귀인지도 엔진의 검증된 기능을 분석하여
// 재사용한다" 원칙) — 새로운 공유 메커니즘을 발명하지 않는다. 차이점은 오직
// 링크 경로(`/gh/{token}` vs `/g/{token}`)와 안내 문구뿐이다.
//
// [v4 핸드오프 반영 — S13] 00_DEV_MAPPING.md §5 S13 "Footer 3분할: 카카오톡 ·
// 문자 · 링크 복사"를 지원하기 위해 [GunghapShareTarget]을 추가했다.
// guinji_map_share_screen.dart의 GuinjiShareTarget(sms/kakao/more) 분기
// 패턴을 그대로 이식했다(웹에서 sms: 스킴이 net::ERR_UNKNOWN_URL_SCHEME로
// 깨지는 문제를 이미 그쪽에서 해결해 둔 로직을 재사용).
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env_config.dart';
import '../../../core/util/safe_share.dart';
import '../../../core/widgets/app_toast.dart';

/// [v4 핸드오프 S13] 공유 Footer 3분할 버튼이 가리키는 대상.
enum GunghapShareTarget { kakao, sms, more }

/// 궁합지도 초대 링크. 서버 랜딩페이지(`/gh/{token}`, admin_web 측)가 초대
/// 내용을 보여주고 앱으로 열기를 지원한다는 전제(귀인지도 `/g/{token}`과
/// 동일 패턴). 캐시버스팅 쿼리스트링은 궁합지도에는 OG 동적 이미지가 아직
/// 없으므로(이번 단계 범위 밖) 붙이지 않는다 — 추후 필요 시 guinji 패턴 그대로
/// 추가 가능.
String buildGunghapInviteLink(String token) =>
    '${EnvConfig.adminApiBaseUrl}/gh/$token';

/// 카카오톡 FeedTemplate 없이, 텍스트 기반 공유로 단순화한다(이번 단계
/// 범위: OG 이미지 동적 생성 서버 라우트는 미구현 — 정식 지시서 범위 밖).
/// 카카오톡 설치 시 `ShareClient.shareDefault(template: TextTemplate(...))`로
/// 카카오톡 공유 시트를 직접 띄우고, 실패/미설치/웹이면 `safeShareText`로
/// 폴백한다(귀인지도와 동일한 폴백 원칙).
///
/// [2026-11 궁합 주제 반영 지시서 — Section 1] [topicLabel]은 사용자가
/// 고른 궁합 분야/세부 카테고리 표시 문구(예: "연애 궁합 · 썸 단계
/// 궁합")다. null이면(주제 미선택 — 레거시 흐름) 기존 일반 문구를 그대로
/// 쓴다. 지정되면 메시지에 주제를 명시해, 받는 사람이 "무슨 궁합으로
/// 초대됐는지" 바로 알 수 있게 한다.
Future<void> shareGunghapInvite(
  BuildContext context,
  String? token, {
  String? ownerName,
  String? topicLabel,
  // [v4 핸드오프 S13] 기본값 kakao — 기존 호출부(카카오톡 버튼/자동 공유)는
  // 동작을 전혀 바꾸지 않는다. S13 Footer의 문자/더보기 버튼만 새 값을 넘긴다.
  GunghapShareTarget target = GunghapShareTarget.kakao,
}) async {
  if (token == null || token.isEmpty) return;
  final link = buildGunghapInviteLink(token);
  final message = topicLabel == null
      ? '${ownerName ?? '친구'}님이 궁합지도에 당신을 초대했어요!\n'
            '링크를 열고 생년월일만 입력하면 두 사람의 궁합을 바로 볼 수 있어요.\n$link'
      : '${ownerName ?? '친구'}님이 "$topicLabel" 궁합지도에 당신을 초대했어요!\n'
            '링크를 열고 생년월일만 입력하면 두 사람의 $topicLabel 궁합을 바로 볼 수 있어요.\n$link';

  Future<void> copyAndToast(String toastMessage) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    AppToast.show(context, toastMessage);
  }

  // [v4 핸드오프 S13 — 문자 버튼] guinji_map_share_screen.dart와 동일하게,
  // 웹에서는 `sms:` 스킴이 새 탭에서 처리되지 못해 오류 화면이 뜨는 문제를
  // 피하려고 네이티브에서만 시도하고 웹은 바로 클립보드 폴백으로 넘어간다.
  if (target == GunghapShareTarget.sms) {
    if (!kIsWeb) {
      final smsUri = Uri(
        scheme: 'sms',
        path: '',
        queryParameters: {'body': message},
      );
      try {
        if (await launchUrl(smsUri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[GunghapShare] sms 실행 실패: $e');
      }
    }
    await copyAndToast('문자 앱을 열 수 없어 메시지를 복사했어요.');
    return;
  }

  if (target == GunghapShareTarget.kakao && !kIsWeb) {
    try {
      final available = await ShareClient.instance
          .isKakaoTalkSharingAvailable();
      if (available) {
        final shareUri = await ShareClient.instance.shareDefault(
          template: TextTemplate(
            text: message,
            link: Link(
              webUrl: Uri.parse(link),
              mobileWebUrl: Uri.parse(link),
            ),
          ),
        );
        await ShareClient.instance.launchKakaoTalk(shareUri);
        return;
      } else if (kDebugMode) {
        debugPrint('[GunghapShare] 카카오톡 미설치/공유 불가 — 공통 폴백으로 전환');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GunghapShare] 카카오톡 공유 실패: $e — 공통 폴백으로 전환');
      }
    }
  }

  if (!context.mounted) return;
  await safeShareText(
    context,
    message,
    subject: '궁합지도 초대 · 신통방통',
    copiedMessage: '초대 메시지를 복사했어요. 카카오톡 등 원하는 앱에 붙여넣어 전달해 주세요.',
    failedMessage: '공유 시트를 열 수 없어 링크를 복사했어요.',
  );
}

/// [v4 핸드오프 S13] 「⧉ 메시지 복사」/「⧉ 링크 복사」 전용 — 공유 시트를
/// 거치지 않고 바로 클립보드에 넣는다.
Future<void> copyGunghapInviteLink(
  BuildContext context,
  String? token, {
  bool fullMessage = false,
  String? ownerName,
  String? topicLabel,
}) async {
  if (token == null || token.isEmpty) return;
  final link = buildGunghapInviteLink(token);
  final text = fullMessage
      ? (topicLabel == null
            ? '${ownerName ?? '친구'}님이 궁합지도 초대장을 보냈어요.\n'
                  '"나와 당신의 궁합이 궁금하지 않으세요?"\n'
                  '생년월일만 입력하면 바로 확인할 수 있어요.\n$link'
            : '${ownerName ?? '친구'}님이 "$topicLabel" 궁합지도 초대장을 보냈어요.\n'
                  '"나와 당신의 궁합이 궁금하지 않으세요?"\n'
                  '생년월일만 입력하면 바로 확인할 수 있어요.\n$link')
      : link;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  AppToast.show(
    context,
    fullMessage ? '초대 메시지를 복사했어요.' : '링크를 복사했어요.',
  );
}

/// [미사용 예비] 네이티브에서 직접 URL을 여는 경우가 필요할 때를 대비한
/// 헬퍼(현재 호출부 없음 — lint 무시 목적 아님, 추후 "앱에서 보기" 버튼 등에
/// 재사용 가능하도록 남겨둔다).
Future<bool> tryOpenGunghapInviteLink(String token) async {
  final uri = Uri.parse(buildGunghapInviteLink(token));
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
