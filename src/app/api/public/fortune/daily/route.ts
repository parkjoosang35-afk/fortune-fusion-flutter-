// 공개(비인증) "오늘의 운세" 조회/생성 API — Flutter DailyFortuneRepository.getToday() 대응.
//
// [Phase22 - Mock→실API 연동] 지금까지 Flutter는 로컬 Mock(날짜 해시 기반 가짜 데이터)으로만
// 동작했다. 이 라우트를 신설하여 실제 DB(fortune_requests/fortune_results)에 결과를 저장한다.
//
// [무료 광고형 구조 재정비 §신규발견] "오늘의 운세"는 복주머니(포인트)를 소비하지 않는다.
// 과거에는 point_policies(ai_daily_request)로 매 조회마다 차감→즉시환급을 반복했으나,
// 이는 "복주머니는 소원게시판/소원성에서만 쓰는 유일한 재화" 원칙과 충돌하는 레거시
// 구조였다(차감과 환급이 항상 쌍으로 발생해 실질 순변화가 없었음에도 코드/데이터가
// 복잡했다). 열람 자체는 완전 무료이며, 프리패스 상태와도 무관하다.
// 단, "오늘의 운세 첫 열람 보너스"(+5, sourceType=fortune_first_view)와 미션 진행률
// 갱신(view_daily_fortune)은 "광고/활동으로 복주머니를 적립"하는 정당한 로직이므로 그대로 유지한다.
//
// [1일 1회 보너스 원칙] 같은 날(자정 기준) 이미 조회한 적이 있으면 재적립 없이 기존 결과를
// 그대로 반환한다(멱등성 보장, 새로고침/화면 재방문 시 첫열람보너스 중복 지급 방지).
//
// [Phase - AI프롬프트 실연동] 카테고리별 점수(categoryScores)/행운색/행운숫자는 여전히
// 결정론적 규칙(사용자 생년월일+오늘 날짜 시드)으로 계산한다(사주 라우트와 동일한
// 범위 결정 원칙 — 수치 산출은 규칙 기반, 해석 텍스트만 AI로 교체). "오늘의 총평
// (summaryText)" 한 줄만 daily 도메인 활성 프롬프트 템플릿 + completeText()로 실제
// LLM 생성 텍스트로 교체한다. 템플릿이 없거나 LLM 호출이 실패하면 기존 SUMMARIES
// 하드코딩 풀로 폴백하며, 이 경우 ai_model은 "rule-based-v1"로 그대로 기록한다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { incrementMissionProgress } from "@/lib/mission-progress";
import { earnLuckPouch } from "@/lib/luck-pouch-engine";
import { completeText, LlmClientError } from "@/lib/llm-client";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

const SUMMARIES = [
  "오늘은 새로운 인연이 다가올 좋은 기운이 감돌고 있어요. 평소보다 적극적인 태도가 행운을 부릅니다.",
  "작은 실수에 주의가 필요한 날입니다. 서두르지 않고 차분하게 하루를 보내면 무난하게 지나갈 거예요.",
  "재물운이 상승하는 하루! 뜻밖의 좋은 소식이 있을 수 있으니 기대해도 좋습니다.",
  "몸과 마음의 휴식이 필요한 시기입니다. 무리한 일정보다는 컨디션 관리에 집중하세요.",
];
const LUCKY_COLORS = ["보라", "골드", "블루", "그린"];

function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) {
    h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  }
  return Math.abs(h);
}

function generateFortune(userId: number, birthDate: string | null, todayKey: string) {
  const seed = hashSeed(`${userId}:${birthDate ?? "unknown"}:${todayKey}`);
  const categoryScores = {
    총운: 60 + (seed * 7) % 40,
    애정: 55 + (seed * 3) % 40,
    재물: 50 + (seed * 11) % 45,
    건강: 65 + (seed * 5) % 30,
  };
  const luckyColor = LUCKY_COLORS[seed % LUCKY_COLORS.length];
  const luckyNumber = (seed % 9) + 1;
  const summaryTextFallback = SUMMARIES[seed % SUMMARIES.length];
  return { categoryScores, luckyColor, luckyNumber, summaryTextFallback };
}

function todayRangeUtcKST(): { start: Date; end: Date; key: string } {
  // KST(UTC+9) 기준 "오늘" 하루의 시작/끝을 UTC로 환산한다.
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const y = kstNow.getUTCFullYear();
  const m = kstNow.getUTCMonth();
  const d = kstNow.getUTCDate();
  const startKst = new Date(Date.UTC(y, m, d, 0, 0, 0));
  const endKst = new Date(Date.UTC(y, m, d + 1, 0, 0, 0));
  // KST → UTC 변환(9시간 빼기)
  const start = new Date(startKst.getTime() - 9 * 60 * 60 * 1000);
  const end = new Date(endKst.getTime() - 9 * 60 * 60 * 1000);
  const key = `${y}-${String(m + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
  return { start, end, key };
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const userId = Number(searchParams.get("userId") ?? "1");

  if (!Number.isInteger(userId) || userId <= 0) {
    return NextResponse.json(
      { success: false, error: "userId가 올바르지 않습니다." },
      { status: 400, headers: CORS_HEADERS }
    );
  }

  try {
    const { start, end, key } = todayRangeUtcKST();

    // 1) 오늘 이미 생성된 결과가 있으면 그대로 반환(재차감 없음, 멱등성).
    // [Phase - AI프롬프트 실연동] 이 체크를 짧은 조회로 먼저 끝내 두면, 캐시 히트인 경우
    // 아래의 completeText() 호출(네트워크 I/O)을 아예 건너뛸 수 있다(saju/name 라우트와
    // 동일한 원칙 -- LLM 호출은 트랜잭션 밖에서, 그리고 정말 필요한 경우에만 수행한다).
    const existingRequest = await prisma.fortuneRequest.findFirst({
      where: {
        userId,
        fortuneType: "daily",
        status: "success",
        deletedAt: null,
        createdAt: { gte: start, lt: end },
      },
      include: { result: true },
      orderBy: { createdAt: "desc" },
    });

    let outcome: {
      alreadyGenerated: boolean;
      request: { id: number; createdAt: Date };
      result: { resultText: string; resultMeta: string | null } | null;
      refundAmount: number;
      balance: number | null;
      fortune?: ReturnType<typeof generateFortune> & { summaryText: string };
      missionUpdates: Awaited<ReturnType<typeof incrementMissionProgress>>;
      firstViewBonus: number;
    };

    if (existingRequest && existingRequest.result) {
      outcome = {
        alreadyGenerated: true,
        request: existingRequest,
        result: existingRequest.result,
        refundAmount: 0,
        balance: null,
        missionUpdates: [],
        firstViewBonus: 0,
      };
    } else {
      // 2) 사용자/지갑 확인 (birthDate는 UserProfile에 별도 보관)
      const user = await prisma.user.findUnique({
        where: { id: userId },
        include: { profile: true },
      });
      if (!user) throw new Error("USER_NOT_FOUND");
      const birthDate = user.profile?.birthDate ?? null;

      const wallet = await prisma.wallet.findFirst({
        where: { userId, currencyType: "POINT", deletedAt: null },
      });
      if (!wallet) throw new Error("WALLET_NOT_FOUND");

      // [무료 광고형 구조 재정비 §신규발견] "오늘의 운세"는 완전 무료 --
      // 포인트 차감/환급 로직 없음. cost/refundAmount는 응답 스키마 하위호환을
      // 위해 항상 0으로 유지한다.
      const cost = 0;
      const refundAmount = 0;

      // 3) 카테고리별 점수/행운색/행운숫자는 결정론적 규칙으로 산출(변경 없음)
      const fortune = generateFortune(userId, birthDate, key);

      // 4) 활성 daily 프롬프트 템플릿 조회 + completeText() 호출(트랜잭션 밖, saju/route.ts와
      //    동일 패턴). 템플릿이 없거나 LLM 호출이 실패하면 기존 SUMMARIES 하드코딩 풀로 폴백.
      const template = await prisma.aiPromptTemplate.findFirst({
        where: { fortuneTypeOrDomain: "daily", isActive: true },
        select: { id: true, version: true, templateBody: true },
      });

      let summaryText = fortune.summaryTextFallback;
      let usedAi = false;
      if (template) {
        const userPrompt = [
          `사용자 생년월일: ${birthDate ?? "미상"}`,
          `오늘 날짜: ${key}`,
          `오늘의 카테고리별 점수(100점 만점): 총운 ${fortune.categoryScores.총운}, 애정 ${fortune.categoryScores.애정}, 재물 ${fortune.categoryScores.재물}, 건강 ${fortune.categoryScores.건강}`,
          `요청 주제: 오늘의 총운`,
          "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 이 사람의 오늘 하루 총운을 한 문단으로 작성해주세요.",
        ].join("\n");
        try {
          summaryText = await completeText({ systemPrompt: template.templateBody, userPrompt });
          usedAi = true;
        } catch (e) {
          if (e instanceof LlmClientError) {
            console.error("[GET /api/public/fortune/daily] LLM 호출 실패:", e.message);
          } else {
            console.error("[GET /api/public/fortune/daily] LLM 호출 실패:", e);
          }
          summaryText = fortune.summaryTextFallback;
        }
      }

      // 5) 짧은 트랜잭션: fortune_requests + fortune_results 기록 + 미션/복주머니 적립
      const txOutcome = await prisma.$transaction(async (tx) => {
        let balance = wallet.balance;

        const fortuneRequest = await tx.fortuneRequest.create({
          data: {
            userId,
            fortuneType: "daily",
            inputPayload: JSON.stringify({ birthDate, today: key }),
            sourceType: "ai_generated",
            pointSpent: cost,
            status: "success",
          },
        });

        const fortuneResult = template
          ? await tx.fortuneResult.create({
              data: {
                requestId: fortuneRequest.id,
                resultText: summaryText,
                resultMeta: JSON.stringify({ ...fortune, summaryText }),
                aiModel: usedAi ? "claude-haiku-4-5" : "rule-based-v1",
                promptTemplateId: template.id,
                promptVersion: template.version,
                status: "active",
              },
            })
          : null;

        // [Phase5 - 게임화 최소연동] "오늘의 운세 확인" 행동을 관련 미션(view_daily_fortune)에
        //    반영한다. 1일 1회 과금 원칙과 동일하게, 새로 생성될 때만(재조회 캐시 반환 시는 제외)
        //    미션 진행률을 올려 중복 카운트를 방지한다.
        const missionUpdates = await incrementMissionProgress(tx, userId, "view_daily_fortune");
        const missionRewardTotal = missionUpdates.reduce((sum, m) => sum + m.rewardPoint, 0);
        if (missionRewardTotal > 0) {
          balance += missionRewardTotal;
        }

        // [재화 구조 정리 §복주머니 적립 구간표] "오늘의 운세" 하루 첫 열람 보너스(+5).
        // 같은 날 재조회(캐시 반환, alreadyGenerated=true)는 이 지점에 도달하지 않으므로
        // 자연히 1일 1회만 지급된다. 일일 총 적립 상한(daily_earn_cap_*)과 활동 점수
        // 구간 보너스(ACTIVITY_SCORE_WEIGHTS.fortune_first_view)는 earnLuckPouch가
        // 자동으로 함께 처리한다(§ 단일 소스 원칙 -- 이 파일에서 직접 계산하지 않는다).
        const firstViewBonus = await earnLuckPouch(tx, {
          userId,
          amount: 5,
          sourceType: "fortune_first_view",
          sourceId: fortuneRequest.id,
          memo: "오늘의 운세 첫 열람 보너스",
        });
        if (firstViewBonus.grantedAmount > 0 && firstViewBonus.balanceAfter != null) {
          balance = firstViewBonus.balanceAfter;
        }

        return {
          request: fortuneRequest,
          result: fortuneResult,
          balance,
          missionUpdates,
          firstViewBonus: firstViewBonus.grantedAmount,
        };
      });

      outcome = {
        alreadyGenerated: false,
        request: txOutcome.request,
        result: txOutcome.result,
        refundAmount,
        balance: txOutcome.balance,
        fortune: { ...fortune, summaryText },
        missionUpdates: txOutcome.missionUpdates,
        firstViewBonus: txOutcome.firstViewBonus,
      };
    }

    const meta = outcome.result?.resultMeta
      ? JSON.parse(outcome.result.resultMeta)
      : outcome.fortune ?? null;

    return NextResponse.json(
      {
        success: true,
        data: {
          id: `df_${outcome.request.id}`,
          date: outcome.request.createdAt.toISOString(),
          categoryScores: meta?.categoryScores ?? {},
          luckyColor: meta?.luckyColor ?? "골드",
          luckyNumber: meta?.luckyNumber ?? 7,
          summaryText: outcome.result?.resultText ?? "",
          alreadyGenerated: outcome.alreadyGenerated,
          refundAmount: outcome.refundAmount,
          balance: outcome.balance,
          missionUpdates: outcome.missionUpdates,
          firstViewBonus: outcome.firstViewBonus,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    const message = e instanceof Error ? e.message : "UNKNOWN";
    if (message === "WALLET_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "지갑을 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    if (message === "USER_NOT_FOUND") {
      return NextResponse.json(
        { success: false, error: "사용자를 찾을 수 없습니다." },
        { status: 404, headers: CORS_HEADERS }
      );
    }
    console.error("[GET /api/public/fortune/daily] 실패:", e);
    return NextResponse.json(
      { success: false, error: "오늘의 운세 조회 중 오류가 발생했습니다." },
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
