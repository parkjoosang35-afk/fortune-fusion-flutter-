// ══════════════════════════════════════════════════════════════════
// OpenConsultationService — AI 상담 채팅(멀티턴) 어뷰징 방지 공용 로직의 단일 소스.
//
// [배경/설계 원칙] 사주/타로 등 단발성 AI 호출은 open-pass-service.ts의
// "절대 일일 상한(5회) + 카테고리별 카운터"로 방어하지만, 상담 채팅은 1세션이
// 여러 턴(유저 발화마다 LLM 재호출)으로 이어지고 매 턴 이전 히스토리를 함께
// 전송해야 하는 특성상 비용 패턴이 완전히 다르다(턴수^2로 증가 가능). 그래서
// 사주/타로 예산과 공유하지 않고 별도 예산으로 관리한다:
//
//   ① 유저당 하루 1세션만 허용(ConsultationSession.dateKey + @@unique([userId, dateKey]))
//   ② 세션 내부는 turnCount로 "세션당 최대 20턴"을 강제
//   ③ 세션 "생성"은 무료가 아니라 리워드 광고 시청 완료(OpenPassAdRewardLog)를
//      선결 조건으로 요구 — 비용 일부 상쇄 + 매크로성 세션 생성 억제
//   ④ 유저 메시지 최대 500자
//   ⑤ LLM에 보내는 히스토리는 최근 3쌍(6개 메시지)만 유지(컨텍스트 트리밍) —
//      비용을 선형으로 억제(트리밍 없으면 턴수^2로 증가)
//
// 사주/타로와 마찬가지로 이 파일 하나에만 판정 로직을 구현하고, 상담 관련
// 모든 API 라우트는 이 파일을 통해서만 판정한다(§15 정책 불일치 금지 원칙).
// ══════════════════════════════════════════════════════════════════
import { prisma } from "@/lib/db";

export class OpenConsultationServiceError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

/** KST(UTC+9) 기준 "오늘"의 날짜키("YYYY-MM-DD")를 반환한다. open-pass-service.ts의
 * todayKstKey()와 동일한 절단 규칙(§15 판정 기준 불일치 금지) — 별도 구현해 모듈 결합도를 낮춘다. */
function todayKstKey(): string {
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  return `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
}

/** 상담 세션당 허용되는 유저 발화(턴) 최대 횟수. */
export const MAX_TURNS_PER_SESSION = 20;

/** 유저 1회 발화(메시지) 최대 글자수. */
export const MAX_MESSAGE_LENGTH = 500;

/** LLM에 전송하는 히스토리로 유지할 최근 "쌍"(유저+AI) 개수. 그 이전 대화는 잘라낸다. */
export const CONTEXT_KEEP_PAIRS = 3;

export interface DailySessionCheckResult {
  /** 오늘 이미 생성된 세션(있으면 이걸 그대로 써야 함, 새로 만들면 안 됨). */
  existingSession: { id: number; type: string; turnCount: number; status: string } | null;
  /** 오늘 세션이 없어 새로 만들 수 있는지 여부. */
  canCreateNew: boolean;
}

/**
 * 오늘(KST) 이 유저에게 이미 발급된 상담 세션이 있는지 확인한다.
 * unique([userId, dateKey]) 제약이 최종 방어선이므로, 이 함수가 놓쳐도
 * DB 레벨에서 중복 생성은 막힌다(경쟁 상태 대비 2중 방어).
 */
export async function checkDailySession(userId: number): Promise<DailySessionCheckResult> {
  const dateKey = todayKstKey();
  const existing = await prisma.consultationSession.findUnique({
    where: { userId_dateKey: { userId, dateKey } },
  });
  if (!existing) {
    return { existingSession: null, canCreateNew: true };
  }
  return {
    existingSession: {
      id: existing.id,
      type: existing.type,
      turnCount: existing.turnCount,
      status: existing.status,
    },
    canCreateNew: false,
  };
}

/**
 * 리워드 광고 시청 완료 로그(OpenPassAdRewardLog)가 유효한지 검증한다.
 * - result="success", rewardGranted=true 여야 함
 * - 해당 유저 소유여야 함
 * - 이미 다른 세션에서 소비된 로그면 재사용 불가(1로그=1세션, idempotencyKey 중복지급
 *   방지와는 별개로 "세션 생성 게이트"로서의 소비 여부를 여기서 별도 체크)
 */
export async function verifyAdRewardLogForSession(
  userId: number,
  adRewardLogId: number
): Promise<{ ok: boolean; reason?: string }> {
  const log = await prisma.openPassAdRewardLog.findUnique({ where: { id: adRewardLogId } });
  if (!log) return { ok: false, reason: "AD_LOG_NOT_FOUND" };
  if (log.userId !== userId) return { ok: false, reason: "AD_LOG_USER_MISMATCH" };
  if (log.result !== "success" || !log.rewardGranted) {
    return { ok: false, reason: "AD_NOT_COMPLETED" };
  }
  const alreadyUsed = await prisma.consultationSession.findFirst({
    where: { adRewardLogId },
  });
  if (alreadyUsed) return { ok: false, reason: "AD_LOG_ALREADY_USED" };
  return { ok: true };
}

/**
 * 광고 시청 검증을 통과한 뒤 오늘의 상담 세션을 생성한다.
 * @@unique([userId, dateKey]) 제약과 부딪히면(P2002) 이미 오늘 세션이 있다는
 * 뜻이므로 그 세션을 그대로 반환한다(idempotent, 경쟁 상태 대비).
 */
export async function createSessionWithAdGate(params: {
  userId: number;
  type: string;
  adRewardLogId: number;
  welcomeText: string;
}): Promise<{ id: number; type: string; turnCount: number; welcomeMessageId: number }> {
  const dateKey = todayKstKey();
  try {
    const session = await prisma.$transaction(async (tx) => {
      const created = await tx.consultationSession.create({
        data: {
          userId: params.userId,
          type: params.type,
          dateKey,
          adRewardLogId: params.adRewardLogId,
        },
      });
      const welcome = await tx.consultationMessage.create({
        data: {
          sessionId: created.id,
          sender: "ai",
          content: params.welcomeText,
        },
      });
      return { id: created.id, type: created.type, turnCount: created.turnCount, welcomeMessageId: welcome.id };
    });
    return session;
  } catch (e) {
    // Prisma unique constraint violation → 이미 오늘 세션이 있음(경쟁 상태)
    if (e instanceof Error && e.message.includes("Unique constraint")) {
      const existing = await prisma.consultationSession.findUnique({
        where: { userId_dateKey: { userId: params.userId, dateKey } },
      });
      if (existing) {
        const firstMsg = await prisma.consultationMessage.findFirst({
          where: { sessionId: existing.id },
          orderBy: { createdAt: "asc" },
        });
        return {
          id: existing.id,
          type: existing.type,
          turnCount: existing.turnCount,
          welcomeMessageId: firstMsg?.id ?? 0,
        };
      }
    }
    throw e;
  }
}

export interface TurnLimitCheckResult {
  allowed: boolean;
  turnCount: number;
  maxTurns: number;
}

/** 세션이 유효(active, 소유자 일치)하고 턴 한도(20) 내인지 확인한다. */
export async function checkTurnLimit(
  sessionId: number,
  userId: number
): Promise<TurnLimitCheckResult & { session?: { id: number; status: string; userId: number } }> {
  const session = await prisma.consultationSession.findUnique({ where: { id: sessionId } });
  if (!session || session.userId !== userId) {
    throw new OpenConsultationServiceError("SESSION_NOT_FOUND", "상담 세션을 찾을 수 없습니다.");
  }
  if (session.status !== "active") {
    throw new OpenConsultationServiceError("SESSION_ENDED", "이미 종료된 상담 세션입니다.");
  }
  return {
    allowed: session.turnCount < MAX_TURNS_PER_SESSION,
    turnCount: session.turnCount,
    maxTurns: MAX_TURNS_PER_SESSION,
    session: { id: session.id, status: session.status, userId: session.userId },
  };
}

/**
 * 최근 [CONTEXT_KEEP_PAIRS]쌍(유저+AI)만 남기고 텍스트 히스토리를 만든다.
 * LLM 프롬프트 템플릿의 {{history}} 자리에 그대로 삽입한다.
 */
export async function buildTrimmedHistory(sessionId: number): Promise<string> {
  const messages = await prisma.consultationMessage.findMany({
    where: { sessionId },
    orderBy: { createdAt: "desc" },
    take: CONTEXT_KEEP_PAIRS * 2,
  });
  const ordered = messages.reverse();
  if (ordered.length === 0) return "(이전 대화 없음)";
  return ordered
    .map((m) => `${m.sender === "user" ? "사용자" : "상담사"}: ${m.content}`)
    .join("\n");
}

/**
 * 유저 발화 1건 + AI 응답 1건을 저장하고 turnCount를 1 증가시킨다.
 * 트랜잭션으로 묶어 턴 카운트와 메시지 저장이 항상 함께 반영되게 한다.
 */
export async function appendTurnAndIncrement(params: {
  sessionId: number;
  userMessage: string;
  aiMessage: string;
}): Promise<{ turnCount: number }> {
  const result = await prisma.$transaction(async (tx) => {
    await tx.consultationMessage.create({
      data: { sessionId: params.sessionId, sender: "user", content: params.userMessage },
    });
    await tx.consultationMessage.create({
      data: { sessionId: params.sessionId, sender: "ai", content: params.aiMessage },
    });
    const updated = await tx.consultationSession.update({
      where: { id: params.sessionId },
      data: { turnCount: { increment: 1 } },
    });
    return { turnCount: updated.turnCount };
  });
  return result;
}
