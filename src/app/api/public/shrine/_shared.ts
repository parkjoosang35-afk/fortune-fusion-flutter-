// 신당(THE SHRINE) U12 어뷰징 방지 공용 헬퍼 — ledger 조회/기록 + 서명.
//
// [포팅 원본] /tmp/shrine_v3/merged/prototype/shrine-engine.js의
// identity()/canIssue()/recordIssue()/sign()/verifyShare()/RULES를
// 서버(admin_web)로 그대로 옮긴다. 클라이언트(Flutter)는 이 API들을
// 호출만 하고, 판정/서명/원장 기록은 전부 여기서 수행한다 — "SECRET·
// 원장·서명은 반드시 서버"라는 JS 원본 개발 메모를 실제로 지킨 구현.
//
// [RULES] perStory=1(이야기 1편당 부적 1장), perDay=2(하루 2장 상한).
// 기존 wishes/_shared.ts의 requireUser/CORS_HEADERS 패턴을 그대로 재사용한다.
import { createHmac } from "crypto";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { authenticateRequest } from "@/lib/user-auth";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export const RULES = { perStory: 1, perDay: 2 } as const;

/** `Authorization: Bearer <JWT>` 로 로그인 사용자를 확정한다(wishes/_shared.ts와 동일 패턴). */
export async function requireUser(
  request: Request
): Promise<{ userId: number; nickname: string } | null> {
  const payload = await authenticateRequest(request);
  if (!payload) return null;
  return { userId: payload.userId, nickname: payload.nickname };
}

export function unauthorizedResponse() {
  return NextResponse.json(
    { success: false, error: "로그인이 필요합니다." },
    { status: 401, headers: CORS_HEADERS }
  );
}

/** KST(UTC+9) 기준 'YYYY-MM-DD'. 자정 초기화 기준을 서버가 일관되게 계산한다. */
export function kstDateString(d: Date = new Date()): string {
  const kst = new Date(d.getTime() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10);
}

const SECRET = () => {
  const base = process.env.SESSION_SECRET;
  if (!base) throw new Error("SESSION_SECRET 환경변수가 설정되지 않았습니다.");
  // 세션 JWT 서명 키와 같은 값을 그대로 쓰지 않도록 도메인 접두사를 섞는다
  // (한쪽 유출이 다른 쪽 위조로 바로 이어지지 않게 하는 최소한의 격리).
  return `shrine:${base}`;
};

/** 공유 payload에 대한 HMAC-SHA256 서명(hex). 신당 공유 링크 위조 방지용. */
export function sign(payload: string): string {
  return createHmac("sha256", SECRET()).update(payload).digest("hex").slice(0, 32);
}

export function verifyShare(payload: string, sig: string): boolean {
  return sig === sign(payload);
}

/**
 * 발급 가능 여부 판정 — identity(로그인+fp 존재) → perStory → perDay 순으로 검사.
 * [서버 재검증 원칙] 클라이언트가 보낸 어떤 값도 신뢰하지 않고, 전부 ledger를
 * 직접 조회해 다시 계산한다.
 */
export async function canIssue(params: {
  userId: number;
  sajuFp: string | null;
  storyId: string;
}): Promise<{ ok: boolean; reason?: string; code?: string }> {
  const { userId, sajuFp, storyId } = params;

  if (!sajuFp) {
    return {
      ok: false,
      code: "NO_SAJU",
      reason: "정통사주 풀이를 먼저 받아야 부적을 받을 수 있습니다.",
    };
  }

  // perStory: 이 이야기로 이미 발급받았으면(재방문) 부적함에서 다시 펼치도록 안내.
  const existing = await prisma.shrineIssueLedger.findUnique({
    where: { userId_storyId: { userId, storyId } },
  });
  if (existing) {
    return {
      ok: false,
      code: "ALREADY_ISSUED",
      reason: "이미 이 이야기로 받은 부적이 있습니다. 부적함에서 다시 펼쳐 보세요.",
    };
  }

  // perDay: 오늘(KST) 발급 건수 집계.
  const today = kstDateString();
  const todayCount = await prisma.shrineIssueLedger.count({
    where: { userId, issuedDate: today },
  });
  if (todayCount >= RULES.perDay) {
    return {
      ok: false,
      code: "DAILY_LIMIT",
      reason: `하루에 받을 수 있는 부적은 ${RULES.perDay}장까지입니다. 내일 다시 찾아 주세요.`,
    };
  }

  return { ok: true };
}

/** 일련번호 생성 — SHR-{서명 앞 8자, 대문자}. */
function genSerial(composeKey: string): string {
  return `SHR-${sign(composeKey).slice(0, 8).toUpperCase()}`;
}

/**
 * 발급 기록 — canIssue() 통과 후에만 호출해야 한다(라우트가 재검증 후 호출).
 * unique 제약([userId, storyId])이 동시 요청 경쟁 상태의 최종 방어선 역할도 한다.
 */
export async function recordIssue(params: {
  userId: number;
  sajuFp: string;
  storyId: string;
  composeKey: string;
}): Promise<{ serial: string }> {
  const { userId, sajuFp, storyId, composeKey } = params;
  const serial = genSerial(`${userId}|${composeKey}|${Date.now()}`);
  await prisma.shrineIssueLedger.create({
    data: {
      userId,
      sajuFp,
      storyId,
      composeKey,
      serial,
      issuedDate: kstDateString(),
    },
  });
  return { serial };
}
