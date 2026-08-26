// 공개(비인증) AI 상담 채팅 "세션 시작" API — Flutter ConsultationRepository.createSession() 대응.
//
// [배경] 지금까지 상담 채팅은 완전히 Mock(고정 3문장 순환)이었다. 이 라우트부터
// 실제 LLM(claude-haiku-4-5)과 연동하되, 사주/타로와는 별도의 어뷰징 방지 예산을
// 적용한다(open-consultation-service.ts 참고):
//   ① 유저당 하루 1세션만 생성 가능(ConsultationSession.dateKey + @@unique)
//   ② 세션 생성 자체를 리워드 광고 시청 완료(OpenPassAdRewardLog) 게이트로 막는다
//   ③ 세션 내부 20턴 대화 중에는 광고를 다시 요구하지 않는다(이 라우트는 세션
//      "생성" 1회만 담당, 턴 처리는 /api/public/consultation/message가 담당)
//
// [idempotent 설계] 오늘 이미 세션이 있으면(=하루 1세션을 이미 소진/사용 중) 광고
// 검증 없이 그 세션 그대로(+저장된 메시지 목록)를 반환한다 — 앱을 재시작하거나
// 화면을 나갔다 들어와도 오늘의 세션을 이어서 쓸 수 있어야 하기 때문이다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import {
  checkDailySession,
  verifyAdRewardLogForSession,
  createSessionWithAdGate,
  MAX_TURNS_PER_SESSION,
} from "@/lib/open-consultation-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

// Flutter ConsultationRepository의 기존 _welcomeTexts를 그대로 재사용한다(§15
// 원칙과 유사하게, 문구가 서버/클라이언트에서 갈라지지 않도록 서버가 단일 소스가 된다).
const WELCOME_TEXTS: Record<string, string> = {
  saju: "안녕하세요! 사주 전문 AI 상담사입니다. 사주와 관련해 궁금한 점을 편하게 물어보세요.",
  tarot: "안녕하세요! 타로 전문 AI 상담사입니다. 마음에 담고 있는 고민을 말씀해주시면 카드의 의미로 답해드릴게요.",
  general: "안녕하세요! AI 운세 상담사입니다. 오늘 어떤 이야기가 궁금하신가요?",
};

interface SessionRequestBody {
  userId?: number;
  type?: string;
  adRewardLogId?: number;
}

function serializeMessage(m: { id: number; sender: string; content: string; createdAt: Date }) {
  return {
    id: String(m.id),
    role: m.sender === "user" ? "user" : "ai",
    text: m.content,
    createdAt: m.createdAt.toISOString(),
  };
}

export async function POST(request: NextRequest) {
  let body: SessionRequestBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const type = body.type && ["saju", "tarot", "general"].includes(body.type) ? body.type : "general";

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 1) 오늘 이미 세션이 있으면 그대로 반환(광고 재검증 없음, idempotent)
    const dailyCheck = await checkDailySession(userId);
    if (!dailyCheck.canCreateNew && dailyCheck.existingSession) {
      const existing = dailyCheck.existingSession;
      const messages = await prisma.consultationMessage.findMany({
        where: { sessionId: existing.id },
        orderBy: { createdAt: "asc" },
      });
      return NextResponse.json(
        {
          success: true,
          data: {
            sessionId: existing.id,
            type: existing.type,
            turnCount: existing.turnCount,
            maxTurns: MAX_TURNS_PER_SESSION,
            status: existing.status,
            messages: messages.map(serializeMessage),
            isNew: false,
          },
        },
        { headers: CORS_HEADERS }
      );
    }

    // 2) 오늘 첫 세션 — 광고 시청 완료 로그가 반드시 필요하다.
    const adRewardLogId = Number(body.adRewardLogId ?? 0);
    if (!Number.isInteger(adRewardLogId) || adRewardLogId <= 0) {
      return NextResponse.json(
        {
          success: false,
          error: "상담 세션을 시작하려면 먼저 광고를 시청해야 합니다.",
          reason: "AD_REWARD_REQUIRED",
        },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    const adCheck = await verifyAdRewardLogForSession(userId, adRewardLogId);
    if (!adCheck.ok) {
      const reasonLabel: Record<string, string> = {
        AD_LOG_NOT_FOUND: "광고 시청 기록을 찾을 수 없습니다.",
        AD_LOG_USER_MISMATCH: "광고 시청 기록이 유효하지 않습니다.",
        AD_NOT_COMPLETED: "광고 시청이 완료되지 않았습니다.",
        AD_LOG_ALREADY_USED: "이미 사용된 광고 시청 기록입니다.",
      };
      return NextResponse.json(
        {
          success: false,
          error: reasonLabel[adCheck.reason ?? ""] ?? "광고 시청 확인에 실패했습니다.",
          reason: adCheck.reason,
        },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    const welcomeText = WELCOME_TEXTS[type] ?? WELCOME_TEXTS.general;
    const created = await createSessionWithAdGate({ userId, type, adRewardLogId, welcomeText });

    const messages = await prisma.consultationMessage.findMany({
      where: { sessionId: created.id },
      orderBy: { createdAt: "asc" },
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          sessionId: created.id,
          type: created.type,
          turnCount: created.turnCount,
          maxTurns: MAX_TURNS_PER_SESSION,
          status: "active",
          messages: messages.map(serializeMessage),
          isNew: true,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[POST /api/public/consultation/session] 실패:", e);
    return NextResponse.json(
      { success: false, error: "상담 세션 시작 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    },
  });
}
