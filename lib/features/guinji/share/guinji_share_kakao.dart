// lib/features/guinji/share/guinji_share_kakao.dart
// [귀인지도 v2 리스킨 — 핸드오프 이식] 카카오톡 FeedTemplate 공유.
// `귀인지도_최종_핸드오프.html` `window.GJ_CODE_FILES`의
// `lib/features/guinji_map/share/guinji_share_kakao.dart`를 이식하되,
// 다음 두 가지는 기존 프로젝트의 실제 백엔드/버그수정 이력에 맞춰 조정했다
// (핸드오프 원본 그대로 쓰면 과거에 수정된 버그가 재발한다):
//
// 1) 초대 링크/OG 이미지 URL은 핸드오프 원본의 하드코딩 `sintong.kr`
//    대신, 기존 `guinji_share_screen.dart`의 [buildGuinjiInviteLink]/
//    [generateGuinjiShareCode](절대 변경 금지 API)를 그대로 재사용한다.
//    과거 `sintong.app/g/{token}`(미등록 도메인) 하드코딩이 카톡 인앱
//    브라우저에서 404를 유발한 버그가 있었음(guinji_share_screen.dart
//    상단 주석 참고) — `EnvConfig.adminApiBaseUrl` 기반 동적 URL만 사용.
// 2) Play 스토어 패키지명은 `AppInfo`/앱 설정에서 가져온다(핸드오프의
//    `TODO.package.name` 자리표시자를 실제 값으로 치환).
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';

import '../presentation/guinji_share_screen.dart'
    show buildGuinjiInviteLink, generateGuinjiShareCode;

/// [확인 필요] 실제 Google Play 등록 패키지명으로 교체할 것
/// (`android/app/build.gradle.kts`의 `applicationId`와 동일해야 함).
const playPackage = 'com.fortunefusion.fortune';

/// 초대 링크 — 절대 변경 금지 API([buildGuinjiInviteLink])를 그대로 재사용.
/// 호출할 때마다 새 캐시버스팅 코드(`?v=`)가 붙는다(카톡 OG 이미지 캐시 우회).
String inviteUrl(String token) => buildGuinjiInviteLink(token);

/// OG 공유 이미지 URL. 서버(admin_web) `/g/[token]/page.tsx`가 생성하는
/// 동적 OG 이미지 경로를 그대로 따른다(가로 1200×630).
String ogInviteUrl(String token) => '${_webOrigin(token)}/og/guinji/$token/${generateGuinjiShareCode()}.png';

/// 결과 카드 OG 이미지 URL(관계 상세 공유용).
String ogResultUrl(String token) => '${_webOrigin(token)}/og/guinji/$token/result.png';

String playStoreUrl(String token) =>
    'https://play.google.com/store/apps/details?id=$playPackage&referrer=g_$token'; // Install Referrer로 token 복원

String _webOrigin(String token) {
  final link = inviteUrl(token);
  final uri = Uri.parse(link);
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
}

FeedTemplate guinjiInviteTemplate({required String host, required String token}) => FeedTemplate(
      content: Content(
        title: '$host님이 당신과의 인연을 궁금해해요', // K-1 ≤24자
        description: '생년월일만 넣으면 두 사람이 어떤 인연인지 30초 만에 알려드려요', // K-2 ≤40자
        imageUrl: Uri.parse(ogInviteUrl(token)),
        imageWidth: 1200,
        imageHeight: 630,
        link: Link(webUrl: Uri.parse(inviteUrl(token)), mobileWebUrl: Uri.parse(inviteUrl(token))),
      ),
      buttons: [
        Button(
          title: '내 인연 확인하기', // K-3
          link: Link(webUrl: Uri.parse(inviteUrl(token)), mobileWebUrl: Uri.parse(inviteUrl(token))),
        ),
        Button(
          title: '앱에서 열기', // K-4 · 미설치 시 카카오가 마켓으로 이동
          link: Link(androidExecutionParams: {'g': token}),
        ),
      ],
    );

// 공유 시트 버튼 (앱 · !kIsWeb): 카카오톡 · 문자(sms:) · 더보기(OS 공유) + 링크 복사
//   (인스타그램 버튼은 공개 공유 API 부재로 기존 프로젝트에서 이미 제거됨
//   — guinji_map_share_screen.dart의 GuinjiShareTarget 참고)
// 공유 시트 버튼 (웹 · kIsWeb): 링크 복사 · QR(qr_flutter, 미설치 — 추가 필요) · 카카오 JS SDK · navigator.share — 문자 버튼 숨김
// 링크 관리: 새 링크 만들기 POST /maps/{id}/reissue · 공유 중단 POST /maps/{id}/revoke · 다시 켜기 POST /maps/{id}/reactivate
//   (모두 GuinjiProvider.reissueInviteLink/revokeInviteLink/reactivateInviteLink로 이미 연동됨)
// 남은 기간·상태: GET /maps/{id}/invite-status (GuinjiProvider.loadInviteStatus)
