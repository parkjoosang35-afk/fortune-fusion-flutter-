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
String ogInviteUrl(String token) =>
    '${_webOrigin(token)}/og/guinji/$token/${generateGuinjiShareCode()}.png';

/// 결과 카드 OG 이미지 URL(관계 상세 공유용).
String ogResultUrl(String token) =>
    '${_webOrigin(token)}/og/guinji/$token/result.png';

String playStoreUrl(String token) =>
    'https://play.google.com/store/apps/details?id=$playPackage&referrer=g_$token'; // Install Referrer로 token 복원

String _webOrigin(String token) {
  final link = inviteUrl(token);
  final uri = Uri.parse(link);
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
}

FeedTemplate guinjiInviteTemplate({
  required String host,
  required String token,
}) => FeedTemplate(
  content: Content(
    title: '$host님이 당신과의 인연을 궁금해해요', // K-1 ≤24자
    description: '생년월일만 넣으면 두 사람이 어떤 인연인지 30초 만에 알려드려요', // K-2 ≤40자
    imageUrl: Uri.parse(ogInviteUrl(token)),
    imageWidth: 1200,
    imageHeight: 630,
    link: Link(
      webUrl: Uri.parse(inviteUrl(token)),
      mobileWebUrl: Uri.parse(inviteUrl(token)),
    ),
  ),
  buttons: [
    Button(
      title: '내 인연 확인하기', // K-3
      link: Link(
        webUrl: Uri.parse(inviteUrl(token)),
        mobileWebUrl: Uri.parse(inviteUrl(token)),
      ),
    ),
    Button(
      title: '앱에서 열기', // K-4 · 미설치 시 카카오가 마켓으로 이동
      link: Link(androidExecutionParams: {'g': token}),
    ),
  ],
);

/// [귀인지도 핸드오프 v4 — L2 "카카오 결과 공유 피드"] README §12-1 L2 /
/// §12-3 슬롯표 1:1 이식. `guinji-loop.jsx`의 `LpFeed({kind:'result'})`가
/// 쓰는 문구 템플릿과 동일하게: 제목 "{host}님의 귀인 지도", 설명은
/// 관계유형별 인원수를 "{유형} N명 · {유형} N명 외 M명과 연결되어
/// 있어요" 형태로 요약, 이미지는 L4 OG(비식별 — 이름/얼굴 없이 유형별
/// 인원수만), 버튼은 "나도 지도 만들기"(웹 랜딩) / "앱에서 열기"(딥링크).
///
/// [비식별 원칙 — `guinji_result_card_screen.dart`와 동일] 이 템플릿은
/// 이름·생년월일 등 개인정보를 전혀 담지 않는다 — [relationCounts]는
/// 관계유형별 집계(정수)만 받는다(호출부는 `guinjiRelationOrder`로 이미
/// 집계된 Map을 넘겨야 한다 — 이 파일은 집계 로직을 갖지 않는다).
///
/// [링크 목적지 — "나도 지도 만들기"] L1(초대)과 달리 L2는 받는 사람을
/// 호스트의 기존 지도에 "참여자"로 등록시키는 것이 아니라, 받는 사람이
/// 스스로 "자신의" 귀인지도를 새로 만들도록 유도하는 공유다. 그러나
/// 현재 백엔드에는 "지도 생성 랜딩"과 "초대 참여" URL이 분리되어 있지
/// 않으므로([buildGuinjiInviteLink]가 유일한 공개 랜딩), 받는 사람이 그
/// 링크를 열면 기존 참여 흐름(W1)으로 들어가되 CTA 문구만 "나도 지도
/// 만들기"로 달리 표현한다 — 클릭 시 동작은 동일(W1 → 자기 생년월일
/// 입력 → 본인 지도 시작), 서버 신규 엔드포인트를 요구하지 않는다.
FeedTemplate guinjiResultTemplate({
  required String host,
  required String token,
  required Map<String, int> relationCounts,
}) => FeedTemplate(
  content: Content(
    title: '$host님의 귀인 지도', // L2 제목 — guinji-loop.jsx LpFeed kind=result와 동일
    description: _resultDescription(relationCounts), // L2 설명
    imageUrl: Uri.parse(ogResultUrl(token)),
    imageWidth: 1200,
    imageHeight: 630,
    link: Link(
      webUrl: Uri.parse(inviteUrl(token)),
      mobileWebUrl: Uri.parse(inviteUrl(token)),
    ),
  ),
  buttons: [
    Button(
      title: '나도 지도 만들기', // L2 버튼1
      link: Link(
        webUrl: Uri.parse(inviteUrl(token)),
        mobileWebUrl: Uri.parse(inviteUrl(token)),
      ),
    ),
    Button(
      title: '앱에서 열기', // L2 버튼2 · 미설치 시 카카오가 마켓으로 이동
      link: Link(androidExecutionParams: {'g': token}),
    ),
  ],
);

/// [G-5/L2 설명 슬롯] `guinji-loop.jsx`의
/// `'귀인 2명 · 인연 2명 · 상생 1명 외 3명과 연결되어 있어요'` 패턴을
/// 그대로 따른다: 인원이 있는 유형 상위 2개를 "{라벨} N명"으로 나열하고,
/// 나머지 인원 합계가 있으면 "외 M명과 연결되어 있어요"를 덧붙인다.
/// 인원이 아예 없으면(신규 지도) 안내 문구로 대체한다.
String _resultDescription(Map<String, int> relationCounts) {
  final ordered = relationCounts.entries.where((e) => e.value > 0).toList();
  if (ordered.isEmpty) {
    return '생년월일만 넣으면 나와 어떤 인연인지 바로 알 수 있어요';
  }
  final total = ordered.fold<int>(0, (sum, e) => sum + e.value);
  final top = ordered.take(2);
  final rest = total - top.fold<int>(0, (sum, e) => sum + e.value);
  final topLabel = top
      .map((e) => '${_relationShortLabel(e.key)} ${e.value}명')
      .join(' · ');
  return rest > 0 ? '$topLabel 외 $rest명과 연결되어 있어요' : '$topLabel과 연결되어 있어요';
}

/// [순환 의존 회피] `guinji_relation_meta.dart`를 직접 import하면 이
/// 공유 유틸이 도메인 레이어에 의존하게 되어 호출부(화면)가 이미 알고
/// 있는 라벨을 다시 매핑해야 하는 비효율이 생긴다 — 가장 자주 쓰이는
/// 2종만 로컬 상수로 복제한다(값 자체는 `guinjiRelationTypes`와 100%
/// 동일, README §12-3 예시 "귀인/인연/상생"과도 일치).
String _relationShortLabel(String key) => const {
  'CHEON_GWII': '귀인',
  'HAP': '인연',
  'SANG_SAENG': '상생',
  'SANG_GEUK': '상극',
  'BI_HWA': '동류',
  'CHUNG': '충돌',
}[key] ?? key;

// 공유 시트 버튼 (앱 · !kIsWeb): 카카오톡 · 문자(sms:) · 더보기(OS 공유) + 링크 복사
//   (인스타그램 버튼은 공개 공유 API 부재로 기존 프로젝트에서 이미 제거됨
//   — guinji_map_share_screen.dart의 GuinjiShareTarget 참고)
// 공유 시트 버튼 (웹 · kIsWeb): 링크 복사 · QR(qr_flutter, 미설치 — 추가 필요) · 카카오 JS SDK · navigator.share — 문자 버튼 숨김
// 링크 관리: 새 링크 만들기 POST /maps/{id}/reissue · 공유 중단 POST /maps/{id}/revoke · 다시 켜기 POST /maps/{id}/reactivate
//   (모두 GuinjiProvider.reissueInviteLink/revokeInviteLink/reactivateInviteLink로 이미 연동됨)
// 남은 기간·상태: GET /maps/{id}/invite-status (GuinjiProvider.loadInviteStatus)
