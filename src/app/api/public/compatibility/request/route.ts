// 궁합 결과 생성: 공용 결과보기 거래로 1회 소비하고 기존 궁합 테이블에 저장한다.
// 점수의 관리자 가중치/결정론적 산출은 유지한다. AI 실패를 고정 문구 성공으로 대체하지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { completeText } from "@/lib/llm-client";
import { checkCategoryUsage, checkDailyAbsoluteLimit, consumeCategoryUsage } from "@/lib/open-pass-service";
import { beginResultAccess, reserveResultGeneration, failAndRefundResultAccess, recoverExpiredCompatibilityTransactions, COMPATIBILITY_PENDING_TIMEOUT_MS, ResultAccessError, type ResultAccessPaymentMethod } from "@/lib/result-access-service";
import { requireUser, unauthorizedResponse } from "../../wishes/_shared";
// [궁합 사주 팩터 개선 — 조건부 구현 승인 범위] saju_engine의 실제 궁합 계산
// 모듈(/compatibility)을 재사용한다. 실패 시 아래 hashSeed 기반 폴백으로
// 안전하게 대체되며, 어떤 경로였는지는 scoreEngineVersion으로 구분한다.
import { getSajuCompatibilityScore } from "@/lib/compatibility/saju-compat-score";

export const dynamic = "force-dynamic";
const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };
const TYPE_LABEL: Record<string, string> = { love: "연인/짝사랑", friend: "친구", business: "동업/사업 파트너", family: "가족" };
const TOPICS = ["애정", "성격", "미래"];
const GENERATING = "compatibility:generating";
function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  return Math.abs(h);
}
function validDate(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value && date <= new Date();
}
function reply(error: string, reason: string, status: number) {
  return NextResponse.json({ success: false, error, reason }, { status, headers: CORS_HEADERS });
}

export async function POST(request: NextRequest) {
  let body: { type?: string; nameA?: string; nameB?: string; birthDateA?: string; birthDateB?: string; paymentMethod?: string; transactionId?: string; adSessionId?: string };
  try { body = await request.json(); } catch { return reply("요청 본문이 올바르지 않습니다.", "INVALID_INPUT", 400); }
  const auth = await requireUser(request);
  if (!auth) return unauthorizedResponse();
  const userId = auth.userId;
  const transactionId = typeof body.transactionId === "string" ? body.transactionId.trim() : "";
  const paymentMethod = body.paymentMethod as ResultAccessPaymentMethod | undefined;
  const useResultAccess = Boolean(transactionId || paymentMethod);
  let ownsGeneration = false;
  // 게이트 선차감 후 입력/설정/한도 오류도 복구한다. 다른 진행 중 생성은 환불하지 않는다.
  const reject = async (error: string, reason: string, status: number) => {
    if (transactionId) {
      const claimed = await prisma.resultAccessTransaction.updateMany({
        where: { transactionId, userId, contentType: "compatibility", paymentMethod, status: "pending", contentId: null },
        data: { contentId: GENERATING },
      });
      if (claimed.count === 1) await failAndRefundResultAccess(transactionId);
    }
    return reply(error, reason, status);
  };
  try {
    if (useResultAccess && (!transactionId || !paymentMethod || !["FREEPASS", "POUCH", "AD"].includes(paymentMethod))) {
      return reply("결과보기 거래와 결제수단을 확인해주세요.", "INVALID_PAYMENT_METHOD", 400);
    }
    if (useResultAccess) {
      await recoverExpiredCompatibilityTransactions(userId);
      const existing = await prisma.resultAccessTransaction.findUnique({ where: { transactionId } });
      if (existing) {
        if (existing.userId !== userId || existing.contentType !== "compatibility" || existing.paymentMethod !== paymentMethod) {
          return reply("다른 사용자·콘텐츠·결제수단의 거래를 사용할 수 없습니다.", "TRANSACTION_CONTEXT_MISMATCH", 400);
        }
        // 성공 재열람은 입력/당일 한도/현재 프롬프트 설정과 무관하게 저장 결과를 반환한다.
        if (existing.status === "success") {
          const match = /^compat_(\d+)$/.exec(existing.contentId ?? "");
          const saved = match ? await prisma.compatibilityRequest.findFirst({
            where: { id: Number(match[1]), requesterUserId: userId, deletedAt: null }, include: { result: true },
          }) : null;
          if (!saved?.result || saved.result.deletedAt) return reply("저장된 궁합 결과를 찾을 수 없습니다.", "RESULT_NOT_FOUND", 404);
          const input = JSON.parse(saved.targetInput ?? "{}");
          const detail = JSON.parse(saved.result.detail);
          return NextResponse.json({ success: true, data: {
            id: `compat_${saved.id}`, nameA: input.nameA ?? "나", nameB: input.nameB ?? "상대방", type: saved.type,
            score: saved.result.score, topicResults: detail.topicResults ?? {}, summary: detail.summary ?? "",
            createdAt: saved.createdAt.toISOString(), balanceAfter: null,
            resultAccess: { transactionId, paymentMethod, amount: existing.amount, idempotent: true },
          } }, { headers: CORS_HEADERS });
        }
        if (existing.status !== "pending") return reply("이 거래는 종료되었습니다. 결과보기에서 다시 선택해주세요.", "TRANSACTION_ALREADY_PROCESSED", 409);
        if (existing.contentId != null) return reply("궁합 분석이 진행 중입니다. 잠시 후 다시 확인해주세요.", "GENERATION_IN_PROGRESS", 409);
      }
    }
    const type = body.type ?? "love";
    const nameA = typeof body.nameA === "string" ? body.nameA.trim() : "나";
    const nameB = typeof body.nameB === "string" ? body.nameB.trim() : "상대방";
    const birthDateA = body.birthDateA;
    const birthDateB = body.birthDateB;
    if (!Object.hasOwn(TYPE_LABEL, type) || !nameA || !nameB || nameA.length > 100 || nameB.length > 100 || !validDate(birthDateA) || !validDate(birthDateB)) {
      return await reject("궁합 유형·이름·생년월일을 확인해주세요.", "INVALID_INPUT", 400);
    }
    const daily = await checkDailyAbsoluteLimit(userId);
    if (!daily.allowed) return await reject(`하루 이용 가능한 AI 운세 횟수(${daily.maxUsage}회)를 모두 사용했습니다.`, "DAILY_ABSOLUTE_LIMIT_REACHED", 403);
    const usageCheck = useResultAccess ? null : await checkCategoryUsage(userId, "compatibility");
    if (usageCheck && !usageCheck.allowed) return reply("공용 결과보기로 이용권을 선택해주세요.", usageCheck.reason ?? "NO_ACTIVE_PASS", 403);
    const template = await prisma.aiPromptTemplate.findFirst({
      where: { fortuneTypeOrDomain: "compatibility", isActive: true, deletedAt: null },
      orderBy: { version: "desc" }, select: { id: true, version: true, templateBody: true },
    });
    if (!template) return await reject("궁합 해석 설정이 준비되지 않았습니다.", "PROMPT_NOT_CONFIGURED", 503);
    if (useResultAccess) {
      const begun = await beginResultAccess({ userId, transactionId, contentType: "compatibility", categoryKey: "compatibility", paymentMethod: paymentMethod!, adSessionId: body.adSessionId });
      if (begun.status !== "pending") return reply("이미 종료된 거래입니다. 다시 확인해주세요.", "TRANSACTION_ALREADY_PROCESSED", 409);
      const claimed = await reserveResultGeneration(userId, transactionId, "compatibility");
      if (!claimed) return reply("궁합 분석이 진행 중입니다. 잠시 후 다시 확인해주세요.", "GENERATION_IN_PROGRESS", 409);
      ownsGeneration = true;
    }
    const seed = hashSeed(`${birthDateA}:${birthDateB}:${type}`);
    const weights = await prisma.compatibilityFactorWeight.findMany({ where: { isActive: true, deletedAt: null } });
    const weightMap = new Map(weights.map(w => [w.factorType, w.weight]));
    // [궁합 사주 팩터 개선] saju 팩터만 saju_engine 실제 계산으로 교체한다.
    // mbti/interest/value/activity_pattern 4개는 실 입력 데이터가 없으므로
    // 이번 작업에서 계산 방식을 변경하지 않고 기존 해시 로직을 그대로 둔다
    // (승인 조건 §1 "비사주 4개 요소는 계산 방식을 임의로 변경하지 않는다").
    const sajuCompat = await getSajuCompatibilityScore({ birthDateA, birthDateB }, type);
    const factorScores: Record<string, number> = {
      saju: sajuCompat.score, mbti: 50 + ((seed * 3) % 45), interest: 50 + ((seed * 11) % 45),
      value: 50 + ((seed * 5) % 45), activity_pattern: 50 + ((seed * 13) % 45),
    };
    let weightedSum = 0;
    let weightTotal = 0;
    for (const [factor, val] of Object.entries(factorScores)) {
      const w = weightMap.get(factor) ?? 0.2;
      weightedSum += val * w;
      weightTotal += w;
    }
    const score = Math.round(weightTotal > 0 ? weightedSum / weightTotal : 70);
    // 모든 요청이 끝난 뒤 실패 판정: 일부 실패를 성공으로 저장하지 않는다.
    const settled = await Promise.allSettled(TOPICS.map(topic => completeText({
      systemPrompt: template.templateBody, timeoutMs: 60_000,
      userPrompt: [`궁합 유형: ${TYPE_LABEL[type]}`, `사람A: ${nameA}(생년월일 ${birthDateA})`,
        `사람B: ${nameB}(생년월일 ${birthDateB})`, `종합 궁합 점수: ${score}점(100점 만점)`, `요청 주제: ${topic}`,
        "위 [기본 규칙]과 [출력 형식]을 그대로 지켜서 두 사람의 궁합을 주제에 맞춰 해석해주세요."].join("\n"),
    })));
    const topicResults: Record<string, string> = {};
    settled.forEach((result, index) => {
      if (result.status !== "fulfilled" || !result.value.trim()) throw new Error("COMPATIBILITY_GENERATION_FAILED");
      topicResults[TOPICS[index]] = result.value;
    });
    const summary = topicResults[TOPICS[0]];
    const outcome = await prisma.$transaction(async tx => {
      // 레거시 요청도 저장 시 다시 검사한다. 생성 예약이 없는 타 콘텐츠와의 경합은 별도 잔여.
      const finalLimit = await checkDailyAbsoluteLimit(userId, tx, useResultAccess ? transactionId : undefined);
      if (!finalLimit.allowed) throw new ResultAccessError("DAILY_ABSOLUTE_LIMIT_REACHED", "오늘 이용 가능한 AI 운세 횟수를 모두 사용했습니다.");
      const compatRequest = await tx.compatibilityRequest.create({ data: {
        requesterUserId: userId, type, targetInput: JSON.stringify({ nameA, nameB, birthDateA, birthDateB }),
      } });
      // scoreEngineVersion은 기존 detail 키(factorScores/topicResults/summary)에
      // 추가되는 부가(additive) 필드다 — history/result 조회 경로는 이 필드를
      // 읽지 않으므로 과거 레코드(필드 없음)와 호환된다(코드로 확인 완료).
      await tx.compatibilityResult.create({ data: { requestId: compatRequest.id, score, detail: JSON.stringify({ factorScores, topicResults, summary, scoreEngineVersion: sajuCompat.engineVersion }) } });
      await tx.aiRequestLog.create({ data: { domain: "compatibility", requestRefId: compatRequest.id, aiModel: "claude-haiku-4-5", status: "success" } });
      if (useResultAccess) {
        // 별도 FK 추가 없이 기존 contentId를 사용한다. 결과 저장과 성공 확정은 같은 DB 거래다.
        const finalized = await tx.resultAccessTransaction.updateMany({
          where: { transactionId, userId, status: "pending", contentId: GENERATING,
            updatedAt: { gt: new Date(Date.now() - COMPATIBILITY_PENDING_TIMEOUT_MS) } },
          data: { status: "success", contentId: `compat_${compatRequest.id}` },
        });
        if (finalized.count !== 1) throw new Error("TRANSACTION_FINALIZATION_FAILED");
      }
      return compatRequest;
    });
    ownsGeneration = false;
    if (usageCheck?.userPassId != null) await consumeCategoryUsage(usageCheck.userPassId, userId, "compatibility");
    // [궁합 사주 팩터 개선 — 승인 조건 §2-5/§2-6] 해시 폴백이 발생했다는 사실을
    // "성공적인 사주 분석"으로 내부 집계하지 않는다: 위 aiRequestLog(LLM 텍스트
    // 생성 성공 여부)와는 별개로, saju 엔진 폴백 자체는 append-only ErrorLog에
    // source/errorCode/severity로 집계 가능하게 기록한다(생년월일 등 PII는
    // 남기지 않음). 로그 적재 실패가 이미 완료된 궁합 응답을 실패시키면 안
    // 되므로 트랜잭션 밖에서 best-effort로 수행한다.
    if (sajuCompat.engineVersion !== "saju-v1") {
      prisma.errorLog.create({
        data: {
          source: "api:compatibility:saju-engine",
          errorCode: sajuCompat.engineVersion,
          message: `saju 엔진 폴백(compat_${outcome.id}) — scoreEngineVersion=${sajuCompat.engineVersion}`,
          severity: "warning",
        },
      }).catch((e) => console.error("[compatibility] ErrorLog 적재 실패(폴백 집계 누락 가능):", e));
    }
    return NextResponse.json({ success: true, data: {
      id: `compat_${outcome.id}`, nameA, nameB, type, score, topicResults, summary,
      createdAt: outcome.createdAt.toISOString(), balanceAfter: null,
      ...(useResultAccess ? { resultAccess: { transactionId, paymentMethod, idempotent: false } } : {}),
    } }, { headers: CORS_HEADERS });
  } catch (error) {
    if (ownsGeneration) await failAndRefundResultAccess(transactionId);
    if (error instanceof ResultAccessError) {
      if (error.code === "DAILY_ABSOLUTE_LIMIT_REACHED") return await reject(error.message, error.code, 403);
      return reply(error.message, error.code, 409);
    }
    console.error("[POST /api/public/compatibility/request] 실패:", error);
    return reply("궁합 분석에 실패했습니다. 차감된 이용권은 복구됩니다.", "GENERATION_FAILED", 500);
  }
}
export async function OPTIONS() {
  return new NextResponse(null, { status: 200, headers: { ...CORS_HEADERS, "Access-Control-Allow-Methods": "POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type, Authorization" } });
}
