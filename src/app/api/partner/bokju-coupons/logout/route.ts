// [복주머니 마케팅 쿠폰] POST /api/partner/bokju-coupons/logout
import { NextResponse } from "next/server";
import { deletePartnerSession } from "@/lib/partner-session";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function POST() {
  await deletePartnerSession();
  return NextResponse.json({ success: true }, { headers: CORS_HEADERS });
}
