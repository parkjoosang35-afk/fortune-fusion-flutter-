// 귀인지도 공유 링크 OG(Open Graph) 이미지 서빙 API — 구버전(캐시버스팅 코드
// 없는) 링크 호환용.
// [신통방통_귀인지도_최종_개발계획서_v2.0.md §6-8] `GET /og/guinji/{token}.png`.
//
// [결정 매모 D1/D6 — 2026-08-31] 이 라우트는 `?v=` 캐시버스팅 코드가 아직
// 이미지 **경로**에 반영되기 전(1-1 이전)에 이미 카톡 등으로 퍼진 구버전
// 링크를 위해 유지한다. 신규로 생성되는 링크는 모두
// `../[token]/[shareCode]/route.ts`(경로에 캐시버스팅 코드 포함) 쪽을 쓴다 —
// `/g/[token]/page.tsx`의 `generateMetadata()`가 그쪽 URL을 만들어 낸다.
//
// [URL 형태] 파일 확장자(.png)가 경로 세그먼트에 포함되므로({token}.png 전체가
// 하나의 동적 세그먼트로 매칭됨), 라우트 핸들러 내부에서 ".png" 접미사를 제거해
// 순수 토큰 문자열을 얻는다.
//
// [만료/미존재 토큰 처리] SNS 크롤러(카카오톡/트위터 등)가 OG 이미지를 미리
// 가져갈 때 404를 반환하면 링크 미리보기 자체가 깨지는 사례가 있어, 존재하지
// 않거나 만료된 토큰이어도 동일한 폴백 이미지를 200으로 반환한다.
import { NextRequest } from "next/server";
import { serveStaticGuinjiOgImage, ogCorsOptionsResponse } from "../_shared";

export const dynamic = "force-dynamic";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ token: string }> }
) {
  const { token: tokenParam } = await params;
  const token = tokenParam.endsWith(".png") ? tokenParam.slice(0, -4) : tokenParam;
  return serveStaticGuinjiOgImage(token || null);
}

export async function OPTIONS() {
  return ogCorsOptionsResponse();
}
