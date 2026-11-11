// [2026-11-11 긴급 보안조치 ②] 비활성화됨 — 상세 사유는 src/lib/disabled-route.ts 참조.
// 원래 구현: 공개(비인증 GET) 커뮤니티 게시글 댓글 조회/작성 API. Flutter 앱/admin_web
// 어디에서도 호출하지 않는 죽은 API로 확인되어(rbac.ts 전수조사 주석 참조) 410으로
// 비활성화한다. 특히 GET은 인증 없이 외부에서 호출 가능한 상태였다(보안 공백).
import { disabledResponse, disabledOptionsResponse } from "@/lib/disabled-route";

export const dynamic = "force-dynamic";

export async function GET() {
  return disabledResponse();
}

export async function POST() {
  return disabledResponse();
}

export async function OPTIONS() {
  return disabledOptionsResponse("GET, POST, OPTIONS");
}
