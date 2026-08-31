// 귀인지도 공유 링크 OG(Open Graph) 이미지 — 공용 서빙 헬퍼.
//
// [결정 매모 D1/D2/D6 — 2026-08-31] 두 라우트가 이 헬퍼를 공유한다:
//   - `[token]/route.ts`      : 구버전 링크(캐시버스팅 코드 없는 링크) 호환용.
//     예전에 카톡 등으로 이미 퍼진 링크가 여전히 열리도록 남겨둔다.
//   - `[token]/[shareCode]/route.ts` : 신규 링크(`buildGuinjiInviteLink()`가
//     `?v=`로 만든 캐시버스팅 코드가 여기서는 **경로 세그먼트**로 들어온다).
//     카톡이 쿼리스트링 변경만으론 캐시를 갱신하지 않는 경우에도, 이미지
//     경로 자체가 매번 달라지므로 새로 크롤링하게 만드는 것이 핵심 목적
//     (2단 캐시버스팅 중 "경로" 축 — 나머지 축은 `/g/[token]` 페이지의
//     `?v=` 쿼리스트링이 og:image URL 안으로 그대로 실려 담당한다).
//
// [현재 단계] shareCode는 아직 이미지 내용에 영향을 주지 않는다(2단계에서
// `buildOgPng()`로 대체되기 전까지는 항상 동일한 정적 PNG를 반환) — 오직
// "URL을 다르게 만들어 캐시를 무효화"하는 역할만 한다. 존재하지 않는
// shareCode를 받아도 에러 없이 그냥 같은 이미지를 반환한다(자유 형식 문자열,
// DB에 저장/검증하지 않음 — 2단계에서 GuinjiShareEvent와 연결되면 검증 로직이
// 추가될 수 있다).
import { NextResponse } from "next/server";
import { readFile } from "fs/promises";
import path from "path";
import { prisma } from "@/lib/db";

export const OG_IMAGE_PATH = path.join(
  process.cwd(),
  "public",
  "guinji",
  "og-guinji-1200x630.png"
);
export const OG_CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/**
 * 정적 OG 이미지를 읽어 응답으로 반환한다. `token`이 주어지면 존재/만료
 * 여부를 로깅 목적으로만 조회한다(응답 자체는 항상 동일 이미지 — [M8 확정]
 * 정적 PNG, 2단계에서 동적 생성으로 전환 예정).
 *
 * [캐시 헤더 — 결정 매모 2-2 예고] 아직은 `max-age=3600`(1시간)을 유지한다.
 * 2단계에서 `buildOgPng()`로 실제 동적 생성이 들어가면 그때
 * `public, max-age=0, must-revalidate`로 낮춘다 — 지금은 항상 동일한 정적
 * 파일이라 길게 캐시해도 문제없다.
 */
export async function serveStaticGuinjiOgImage(token: string | null): Promise<NextResponse> {
  try {
    if (token) {
      await prisma.guinjiMap.findUnique({ where: { token }, select: { id: true } });
    }
    const imageBuffer = await readFile(OG_IMAGE_PATH);
    return new NextResponse(imageBuffer as unknown as BodyInit, {
      status: 200,
      headers: {
        ...OG_CORS_HEADERS,
        "Content-Type": "image/png",
        "Cache-Control": "public, max-age=3600, immutable",
      },
    });
  } catch (e) {
    console.error("[og/guinji] 이미지 서빙 실패:", e);
    return NextResponse.json(
      { success: false, error: "OG 이미지를 불러오지 못했습니다." },
      { status: 500, headers: OG_CORS_HEADERS }
    );
  }
}

/**
 * [화이트리스트 원칙 — D2 조건 1] token으로 조회하는 값은 딱 이것 하나,
 * "지도 소유자 닉네임"뿐이다. 다른 필드(사주 파싱 결과·생년월일 등)는 이
 * 함수가 절대 반환하지 않는다 — 동적 OG 카드(`buildOgPng`)에 흘러들어갈 수
 * 있는 값의 범위를 여기서부터 원천 차단한다.
 *
 * 지도가 없거나 만료됐어도 null을 반환할 뿐 예외를 던지지 않는다(호출부가
 * null이면 정적 PNG 폴백으로 자연스럽게 이어지도록).
 */
export async function findGuinjiMapOwnerNickname(token: string): Promise<string | null> {
  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { token },
      select: {
        deletedAt: true,
        status: true,
        owner: { select: { nickname: true } },
      },
    });
    if (!map || map.deletedAt != null || map.status !== "active") return null;
    return map.owner.nickname;
  } catch (e) {
    console.error("[og/guinji] 닉네임 조회 실패:", e);
    return null;
  }
}

export function ogCorsOptionsResponse(): NextResponse {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
