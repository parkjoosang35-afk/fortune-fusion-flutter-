// 소셜 로그인(카카오/구글) 토큰 검증 유틸 — [로드맵⑤]
//
// [설계 원칙 - 가짜 성공 처리 금지] 클라이언트(Flutter)가 보낸 accessToken을
// 무조건 신뢰하지 않는다. 반드시 카카오/구글의 "공식 서버"에 그 토큰을 다시
// 제시해서 "이 토큰이 진짜 유효한지, 누구의 것인지"를 재확인한다. 이 재확인이
// 실패하면 로그인은 절대 성립하지 않는다(과거 PG결제 시뮬레이션 금지와 동일 원칙).
import "server-only";

export interface VerifiedSocialUser {
  /** 카카오/구글이 발급한 그 사람만의 고유 ID(문자열). users.kakaoId/googleId에 매칭한다. */
  socialId: string;
  /** 있으면 사용(이메일 가입 회원과 동일 이메일이면 자동 연동에 사용 가능), 없으면 null. */
  email: string | null;
  /** 프로필 이미지 URL(있으면 신규가입 시 참고용, 필수 아님). */
  profileImage: string | null;
  /** 닉네임 후보(신규가입 시 초기값으로 사용, 중복이면 뒤에 숫자를 붙여 보정). */
  nicknameHint: string | null;
}

export class SocialVerifyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SocialVerifyError";
  }
}

/**
 * 구글 토큰 검증.
 * Google이 공개로 제공하는 tokeninfo 엔드포인트에 클라이언트가 보낸 토큰을
 * 그대로 던져서 검증한다. 응답의 `aud`(발급 대상 클라이언트 ID)가 우리 앱의
 * Web Client ID와 일치하는지까지 확인해야 "다른 앱용으로 발급된 토큰"을
 * 우리 서버가 잘못 신뢰하는 것을 막을 수 있다.
 *
 * [웹 소셜로그인 활성화] `tokenType`으로 두 가지 토큰 종류를 모두 지원한다:
 *   - 'id_token'(기본값, Android/APK 경로): tokeninfo?id_token=... — JWT를
 *     디코드한 클레임(sub/aud/email 등)을 그대로 반환한다.
 *   - 'access_token'(웹 경로): google_sign_in_web(GIS SDK)은 정책상 웹에서
 *     idToken을 안정적으로 반환하지 않으므로(공식 문서에 명시된 제약 —
 *     signIn()이 deprecated이고 synthetic 응답에는 idToken이 없음),
 *     대신 oauth2 accessToken을 서버로 보낸다. tokeninfo?access_token=...도
 *     동일하게 aud/sub(또는 user_id)/email 필드를 반환하므로 검증 로직은
 *     거의 동일하되, 엔드포인트 쿼리 파라미터만 다르다.
 * 두 경로 모두 최종적으로 Google 서버가 직접 응답한 값만 신뢰하므로
 * "가짜 성공 처리 금지" 원칙은 그대로 유지된다.
 */
export async function verifyGoogleIdToken(
  token: string,
  tokenType: "id_token" | "access_token" = "id_token"
): Promise<VerifiedSocialUser> {
  const expectedAudience = process.env.GOOGLE_OAUTH_WEB_CLIENT_ID;
  if (!expectedAudience) {
    throw new SocialVerifyError(
      "서버에 GOOGLE_OAUTH_WEB_CLIENT_ID 환경변수가 설정되지 않았습니다."
    );
  }

  const queryParam = tokenType === "access_token" ? "access_token" : "id_token";

  let response: Response;
  try {
    response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?${queryParam}=${encodeURIComponent(token)}`,
      { method: "GET" }
    );
  } catch (e) {
    throw new SocialVerifyError(`구글 인증 서버 요청 실패: ${e}`);
  }

  if (!response.ok) {
    throw new SocialVerifyError("구글 로그인 토큰이 유효하지 않습니다.");
  }

  const data = (await response.json()) as {
    sub?: string;
    user_id?: string; // access_token 응답은 sub 대신 user_id로 내려오는 경우가 있다(scope에 profile 포함 시).
    aud?: string;
    azp?: string; // access_token 응답의 "발급 대상"은 aud가 아니라 azp인 경우가 있다(요청한 클라이언트).
    email?: string;
    email_verified?: string | boolean;
    name?: string;
    picture?: string;
  };

  const socialId = data.sub ?? data.user_id;
  if (!socialId) {
    throw new SocialVerifyError("구글 인증 응답에서 사용자 ID를 찾을 수 없습니다.");
  }
  // access_token 응답은 필드가 'aud' 또는 'azp' 중 하나로 발급 클라이언트를 나타낼 수 있어
  // 둘 중 하나라도 우리 Web Client ID와 일치하면 통과시킨다(둘 다 없으면 거부).
  const audienceCandidates = [data.aud, data.azp].filter(Boolean);
  if (
    audienceCandidates.length === 0 ||
    !audienceCandidates.includes(expectedAudience)
  ) {
    throw new SocialVerifyError(
      "구글 로그인 토큰의 발급 대상이 이 앱과 일치하지 않습니다."
    );
  }

  return {
    socialId,
    email: data.email ?? null,
    profileImage: data.picture ?? null,
    nicknameHint: data.name ?? null,
  };
}

/**
 * 카카오 액세스 토큰 검증.
 * 카카오는 별도 tokeninfo가 아니라 "이 토큰으로 실제 사용자 정보 조회 API를
 * 호출해서 성공하면 유효한 토큰"이라는 방식을 취한다(공식 문서 권장 패턴).
 * https://kapi.kakao.com/v2/user/me
 */
export async function verifyKakaoAccessToken(
  accessToken: string
): Promise<VerifiedSocialUser> {
  let response: Response;
  try {
    response = await fetch("https://kapi.kakao.com/v2/user/me", {
      method: "GET",
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  } catch (e) {
    throw new SocialVerifyError(`카카오 인증 서버 요청 실패: ${e}`);
  }

  if (!response.ok) {
    throw new SocialVerifyError("카카오 로그인 토큰이 유효하지 않습니다.");
  }

  const data = (await response.json()) as {
    id?: number;
    kakao_account?: {
      email?: string;
      profile?: {
        nickname?: string;
        profile_image_url?: string;
      };
    };
  };

  if (data.id == null) {
    throw new SocialVerifyError("카카오 인증 응답에서 사용자 ID를 찾을 수 없습니다.");
  }

  return {
    socialId: String(data.id),
    email: data.kakao_account?.email ?? null,
    profileImage: data.kakao_account?.profile?.profile_image_url ?? null,
    nicknameHint: data.kakao_account?.profile?.nickname ?? null,
  };
}

/**
 * provider 문자열에 맞는 검증 함수를 골라 실행한다.
 * [웹 소셜로그인 활성화] `tokenType`은 구글에만 의미가 있다(카카오는 항상
 * accessToken 한 종류만 사용). Flutter 클라이언트는 플랫폼에 따라 구글
 * 토큰 종류를 다르게 보낸다 — Android(APK): idToken, Web: accessToken.
 */
export async function verifySocialToken(
  provider: string,
  accessToken: string,
  tokenType: "id_token" | "access_token" = "id_token"
): Promise<VerifiedSocialUser> {
  if (provider === "google") return verifyGoogleIdToken(accessToken, tokenType);
  if (provider === "kakao") return verifyKakaoAccessToken(accessToken);
  throw new SocialVerifyError(`지원하지 않는 로그인 방식입니다: ${provider}`);
}
