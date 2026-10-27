// 신당(THE SHRINE) U12 어뷰징 방지 공용 헬퍼 — ledger 조회/기록 + 서명.
//
// [포팅 원본] /tmp/shrine_v3/merged/prototype/shrine-engine.js의
// identity()/canIssue()/recordIssue()/sign()/verifyShare()/RULES를
// 서버(admin_web)로 그대로 옮긴다. 클라이언트(Flutter)는 이 API들을
// 호출만 하고, 판정/서명/원장 기록은 전부 여기서 수행한다 — "SECRET·
// 원장·서명은 반드시 서버"라는 JS 원본 개발 메모를 실제로 지킨 구현.
//
// [RULES — 2026-11 완화, 사용자 확정 "C안: 둘 다 완화"] 기존
// perStory=1(이야기 1편당 평생 1장)·perDay=2(하루 2장) 제한이 지나치게
// 엄격해 재방문 사용자가 "버그 아니냐"는 문의를 반복적으로 남겼다.
// perStory 제약은 완전히 제거(같은 이야기도 매번 다시 받을 수 있음 —
// 선택 경로가 달라지면 어차피 composeKey가 달라 다른 부적이 나오고,
// 같은 경로라면 같은 부적을 또 받는 것도 "재구매" 성격이라 막을 이유가
// 없다고 판단). perDay는 완전 무제한으로 풀면 과금/어뷰징 방어 자체가
// 무의미해지므로, 기존 2장 → 20장으로만 대폭 완화한다(일반 사용자는
// 하루 2~3번도 잘 안 하므로 사실상 거의 걸리지 않지만, 봇 스크립트 같은
// 극단적 반복 호출에는 여전히 하한선 역할을 한다).
// 기존 wishes/_shared.ts의 requireUser/CORS_HEADERS 패턴을 그대로 재사용한다.
import { createHmac } from "crypto";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { authenticateRequest } from "@/lib/user-auth";

export const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export const RULES = { perDay: 20 } as const;

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
 * 발급 가능 여부 판정 — identity(로그인+fp 존재) → perDay 순으로 검사.
 * [2026-11 완화] perStory(이야기당 1장) 검사를 제거했다 — 같은 이야기를
 * 다시 겪고 다시 부적을 받는 것 자체를 막을 이유가 없다는 사용자 확정에
 * 따른 것. ALREADY_ISSUED 코드/문구는 더 이상 발생하지 않지만, 과거 발급
 * 이력 조회(부적함 등) 호환을 위해 ledger 테이블 자체는 그대로 둔다.
 * [서버 재검증 원칙] 클라이언트가 보낸 어떤 값도 신뢰하지 않고, 전부 ledger를
 * 직접 조회해 다시 계산한다.
 */
export async function canIssue(params: {
  userId: number;
  sajuFp: string | null;
  storyId: string;
}): Promise<{ ok: boolean; reason?: string; code?: string }> {
  const { userId, sajuFp, storyId: _storyId } = params;

  if (!sajuFp) {
    return {
      ok: false,
      code: "NO_SAJU",
      reason: "정통사주 풀이를 먼저 받아야 부적을 받을 수 있습니다.",
    };
  }

  // perDay: 오늘(KST) 발급 건수 집계(완화된 상한 20장 — 사실상 일반
  // 사용량에서는 걸리지 않고, 비정상적 반복 호출만 막는 하한선).
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
 * [2026-11 완화] 기존에는 (userId, storyId) unique 제약이 "같은 이야기
 * 재발급 방지"와 "동시 요청 경쟁 상태 방어" 두 역할을 겸했다. perStory
 * 제한을 없앴으므로 같은 이야기를 여러 번 기록할 수 있어야 하는데, DB의
 * unique 인덱스가 여전히 (userId, storyId) 조합을 막고 있어 매번 다른
 * storyKey를 만들어 우회한다(실제 storyId는 그대로 두고, 저장용 키에만
 * 매 발급 고유 접미사를 붙임) — 스키마 자체를 손대는 마이그레이션 없이
 * 안전하게 "같은 이야기 재발급"을 허용하는 방식.
 */
export async function recordIssue(params: {
  userId: number;
  sajuFp: string;
  storyId: string;
  composeKey: string;
}): Promise<{ serial: string }> {
  const { userId, sajuFp, storyId, composeKey } = params;
  const serial = genSerial(`${userId}|${composeKey}|${Date.now()}`);
  // [perStory 제한 제거에 따른 unique 제약 우회] (userId, storyId) unique
  // 인덱스는 스키마 레벨에 남아 있으므로, 저장되는 storyId에 발급 시각
  // 기반 고유 접미사를 붙여 매번 새 레코드로 기록한다. 실제 "어떤
  // 이야기였는지"는 접미사 이전 부분으로 그대로 식별 가능하고, 일일
  // 한도 집계(issuedDate 기준 count)에는 영향 없다.
  const storageStoryId = `${storyId}#${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  await prisma.shrineIssueLedger.create({
    data: {
      userId,
      sajuFp,
      storyId: storageStoryId,
      composeKey,
      serial,
      issuedDate: kstDateString(),
    },
  });
  return { serial };
}
