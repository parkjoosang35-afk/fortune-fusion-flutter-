// [귀인지도 v2 — 성장 퍼널 측정 2026-10-13] 익명 퍼널 이벤트 수집 단일 엔드포인트.
//
// 기획서(guinji-map-v2-spec §7): 귀인지도는 "공유→후킹→참가→재공유→설치→
// 수익화" 6단 루프의 성장 엔진이며, 그 성과(초대 1건당 설치 수)를 처음으로
// 측정 가능하게 하는 최소 장치다. 웹 랜딩(게스트, 로그인 없음)과 앱 양쪽에서
// 호출하므로 인증을 요구하지 않는다.
//
// [개인정보 원칙] eventName + 클라 생성 익명ID + 선택적 mapToken만 받는다.
// 생년월일·이름·사주 등 어떤 개인정보도 필드로 받지 않고(스키마에 없음),
// 받더라도 무시한다. 이벤트명은 아래 허용 목록으로 고정한다.
//
// [어뷰짱 방어] 익명 엔드포인트라 감가되는 위험은 "로그 더미 테이트"뿐이다.
// (1) 이벤트명 허용 목록 검증, (2) ID/토큰 길이·문자집합 검증,
// (3) 프로세스 내 슬라이딩 윈도우 IP 레이트 리밋(분 60건) — 인메모리라
// 인스턴스별로만 유효하지만, 분석 데이터 오염 방지 목적에는 충분하다.

import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { CORS_HEADERS, jsonOk, jsonError } from "@/lib/page-config-helpers";

const FUNNEL_EVENTS = [
  "share_og_open", // ① 초대 링크(OG)가 열림
  "preview_done", // ② 게스트 웹 미리보기 완료
  "join_done", // ③ 게스트 정식 참가 완료
  "guest_reshare", // ④ 게스트가 결과를 재공유
  "app_cta_click", // ⑤ 앱 설치 CTA 클릭
  "unlock_ad_watched", // ⑥ 심화 해금 리워드 광고 시청 완료
  "milestone_reached", // ⑥ 소유자 마일스톤(3명) 달성
] as const;

type FunnelEventName = (typeof FUNNEL_EVENTS)[number];
const EVENT_SET: ReadonlySet<string> = new Set(FUNNEL_EVENTS);

const ANON_ID_RE = /^[A-Za-z0-9_-]{8,128}$/;
const MAP_TOKEN_RE = /^[A-Za-z0-9_-]{8,128}$/;

// [IP 레이트 리밋] 분 60건 — 단순 슬라이딩 윈도우.
const WINDOW_MS = 60_000;
const WINDOW_MAX = 60;
const hits = new Map<string, number[]>();
let lastSweep = Date.now();

function rateLimited(ip: string): boolean {
  const now = Date.now();
  if (now - lastSweep > WINDOW_MS) {
    // 주기적으로 오래된 키 정리(메모리 상한 방지).
    for (const [k, arr] of hits) {
      const alive = arr.filter((t) => now - t < WINDOW_MS);
      if (alive.length === 0) hits.delete(k);
      else hits.set(k, alive);
    }
    lastSweep = now;
  }
  const arr = (hits.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (arr.length >= WINDOW_MAX) {
    hits.set(ip, arr);
    return true;
  }
  arr.push(now);
  hits.set(ip, arr);
  return false;
}

function clientIp(req: NextRequest): string {
  const fwd = req.headers.get("x-forwarded-for");
  return fwd?.split(",")[0]?.trim() || req.headers.get("x-real-ip") || "unknown";
}

export async function POST(request: NextRequest) {
  const ip = clientIp(request);
  if (rateLimited(ip)) {
    return jsonError("요청이 너무 많아요. 잠시 후 다시 시도해 주세요.", 429);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonError("잘못된 요청이에요.", 400);
  }
  if (!body || typeof body !== "object") return jsonError("잘못된 요청이에요.", 400);
  const o = body as Record<string, unknown>;

  // 이벤트명 — 허용 목록 고정.
  if (typeof o.eventName !== "string" || !EVENT_SET.has(o.eventName)) {
    return jsonError("알 수 없는 이벤트예요.", 400);
  }
  const eventName = o.eventName as FunnelEventName;

  // 익명ID — 클라가 생성한 랜덤 식별자. 형식 밖이면 이벤트를 버린다(저장하지
  // 않고 400. 클라가 ID를 못 만드는 상황은 이벤트 수집 대상이 아니므로).
  if (typeof o.anonymousId !== "string" || !ANON_ID_RE.test(o.anonymousId)) {
    return jsonError("익명 ID 형식이 올바르지 않아요.", 400);
  }

  // mapToken — 있을 때만, 형식 검증 후 저장. 초대 링크 단위 성과 집계용.
  let mapToken: string | null = null;
  if (o.mapToken != null) {
    if (typeof o.mapToken !== "string" || !MAP_TOKEN_RE.test(o.mapToken)) {
      return jsonError("링크 토큰 형식이 올바르지 않아요.", 400);
    }
    mapToken = o.mapToken;
  }

  try {
    await prisma.funnelEvent.create({
      data: { eventName, anonymousId: o.anonymousId, mapToken },
    });
  } catch (e) {
    console.error("[POST /api/public/events] 실패:", e);
    return jsonError("이벤트 저장 중 오류가 발생했어요.", 500);
  }

  return jsonOk({ recorded: true });
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: CORS_HEADERS });
}
