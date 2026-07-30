// 공개(비인증) 소원성(Wish Castle) CMS 설정 조회 API — 신규.
// Flutter 앱이 부팅 시(또는 커뮤니티 탭 진입 시) 1회 호출해 촛불 레벨 임계값,
// 댓글 보상량, 복주머니 선택 단위, AI 응원 문구, 애니메이션 ON/OFF를 로드한다.
// wish_config(key-value) 테이블 전체를 그대로 내려주고, 파싱은 클라이언트에서
// wish-config-meta.ts와 동일한 키 목록을 기준으로 수행한다.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET() {
  try {
    const rows = await prisma.wishConfig.findMany();
    const data: Record<string, string> = {};
    for (const row of rows) {
      data[row.key] = row.value;
    }
    return NextResponse.json({ success: true, data }, { headers: CORS_HEADERS });
  } catch (e) {
    console.error("[GET /api/public/wish-config] 실패:", e);
    return NextResponse.json(
      { success: false, error: "설정을 불러오지 못했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
