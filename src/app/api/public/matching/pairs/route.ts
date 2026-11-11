// [2026-11-11 긴급 보안조치 ②] 비활성화됨 — 상세 사유는 src/lib/disabled-route.ts 참조.
// 원래 구현: 매칭 성사 목록 조회 API. Flutter 앱/admin_web 어디에서도 호출하지
// 않는 죽은 API로 확인되어(rbac.ts 전수조사 주석 참조) 410으로 비활성화한다.
import { disabledResponse, disabledOptionsResponse } from "@/lib/disabled-route";

export const dynamic = "force-dynamic";

export async function GET() {
  return disabledResponse();
}

export async function OPTIONS() {
  return disabledOptionsResponse("GET, OPTIONS");
}
