// 공개(비인증) AI 상담 채팅 "턴 처리" API — Flutter ConsultationRepository.streamReply() 대응.
//
// [설계] 사주/타로 route.ts와 동일한 패턴(활성 ai_prompt_templates 조회 →
// completeText() 호출 → 실패 시 폴백 → 짧은 DB 트랜잭션 기록)을 따르되, 상담은
// 멀티턴이라 다음 2가지가 추가된다:
//   ① checkTurnLimit()으로 세션당 20턴 한도를 매 요청마다 검사
//   ② buildTrimmedHistory()로 최근 3쌍(6개 메시지)만 히스토리로 재전송(비용 억제)
//
// [스트리밍 미지원] llm-client.ts의 completeText()는 스트리밍을 지원하지 않는다
// (streaming 대응은 향후 과제). 지금은 완성된 텍스트를 한 번에 반환하고,
// Flutter 쪽에서 어절 단위로 typewriter 애니메이션만 재현한다(기존 Mock의
// streamReply()가 하던 것과 동일한 UX를 유지하기 위함, 실제 네트워크 스트리밍은 아님).
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText, LlmClientError } from "@/lib/llm-client";
import {
  checkTurnLimit,
  buildTrimmedHistory,
  appendTurnAndIncrement,
  OpenConsultationServiceError,
  MAX_MESSAGE_LENGTH,
  MAX_TURNS_PER_SESSION,
} from "@/lib/open-consultation-service";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const FALLBACK_TEXT =
  "지금은 답변을 준비하는 데 어려움이 있었어요. 조금 이따 다시 한번 말씀해주시겠어요? 지금 겪고 계신 고민은 분명 잘 풀려나갈 거예요.";

interface MessageRequestBody {
  userId?: number;
  sessionId?: number;
  message?: string;
}

export async function POST(request: NextRequest) {
  let body: MessageRequestBody;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { success: false, error: "요청 본문이 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  const userId = Number(body.userId ?? 1);
  const sessionId = Number(body.sessionId);
  const message = body.message?.trim();

  if (!Number.isInteger(sessionId) || sessionId <= 0) {
    return NextResponse.json(
      { success: false, error: "sessionId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (!message) {
    return NextResponse.json(
      { success: false, error: "메시지 내용을 입력해 주세요." },
      { status: 400, headers: CORS_HEADERS }
    );
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return NextResponse.json(
      {
        success: false,
        error: `메시지는 최대 ${MAX_MESSAGE_LENGTH}자까지 입력할 수 있습니다.`,
        reason: "MESSAGE_TOO_LONG",
        maxLength: MAX_MESSAGE_LENGTH,
      },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    // 1) 세션 유효성 + 20턴 한도 검사
    const turnCheck = await checkTurnLimit(sessionId, userId);
    if (!turnCheck.allowed) {
      return NextResponse.json(
        {
          success: false,
          error: `오늘 상담 세션에서 이용 가능한 대화 횟수(${MAX_TURNS_PER_SESSION}회)를 모두 사용했습니다. 내일 새 세션으로 다시 만나요.`,
          reason: "TURN_LIMIT_REACHED",
          turnCount: turnCheck.turnCount,
          maxTurns: turnCheck.maxTurns,
        },
        { status: 403, headers: CORS_HEADERS }
      );
    }

    // 2) 세션 type에 대응하는 프롬프트 도메인의 활성 템플릿 조회
    //    (consultation 도메인 하나만 사용 — saju/tarot처럼 세부 도메인으로 나누지 않음)
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "consultation", isActive: true },
      select: { id: true, version: true, templateBody: true },
    });

    // 3) 컨텍스트 트리밍된 히스토리 구성(비용 억제 핵심)
    const history = await buildTrimmedHistory(sessionId);

    let aiText = FALLBACK_TEXT;
    if (template) {
      const systemPrompt = template.templateBody
        .replace("{{history}}", history)
        .replace("{{userMessage}}", message);
      try {
        aiText = await completeText({ systemPrompt, userPrompt: message });
      } catch (e) {
        if (e instanceof LlmClientError) {
          console.error("[POST /api/public/consultation/message] LLM 호출 실패:", e.message);
        } else {
          console.error("[POST /api/public/consultation/message] LLM 호출 실패:", e);
        }
        aiText = FALLBACK_TEXT;
      }
    }

    // 4) 유저 메시지 + AI 응답 저장, turnCount +1
    const { turnCount } = await appendTurnAndIncrement({
      sessionId,
      userMessage: message,
      aiMessage: aiText,
    });

    return NextResponse.json(
      {
        success: true,
        data: {
          reply: aiText,
          turnCount,
          maxTurns: MAX_TURNS_PER_SESSION,
          remainingTurns: Math.max(0, MAX_TURNS_PER_SESSION - turnCount),
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (e instanceof OpenConsultationServiceError) {
      const statusMap: Record<string, number> = {
        SESSION_NOT_FOUND: 404,
        SESSION_ENDED: 409,
      };
      return NextResponse.json(
        { success: false, error: e.message, code: e.code },
        { status: statusMap[e.code] ?? 400, headers: CORS_HEADERS }
      );
    }
    console.error("[POST /api/public/consultation/message] 실패:", e);
    return NextResponse.json(
      { success: false, error: "상담 응답 처리 중 오류가 발생했습니다." },
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
