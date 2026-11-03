// [궁합지도 Flutter 화면 개발 — §2②] 궁합지도 전용 카카오톡 공유.
//
// guinji_share_kakao.dart / guinji_map_share_screen.dart의 shareGuinjiMapInvite
// 패턴을 그대로 재사용한다(§6 "기존 귀인지도 엔진의 검증된 기능을 분석하여
// 재사용한다" 원칙) — 새로운 공유 메커니즘을 발명하지 않는다. 차이점은 오직
// 링크 경로(`/gh/{token}` vs `/g/{token}`)와 안내 문구뿐이다.
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env_config.dart';
import '../../../core/util/safe_share.dart';

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
Future<void> shareGunghapInvite(
  BuildContext context,
  String? token, {
  String? ownerName,
}) async {
  if (token == null || token.isEmpty) return;
  final link = buildGunghapInviteLink(token);
  final message =
      '${ownerName ?? '친구'}님이 궁합지도에 당신을 초대했어요!\n'
      '링크를 열고 생년월일만 입력하면 두 사람의 궁합을 바로 볼 수 있어요.\n$link';

  if (!kIsWeb) {
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
