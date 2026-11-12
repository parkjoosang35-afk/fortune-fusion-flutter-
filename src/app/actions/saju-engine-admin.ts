"use server";

// [2026-11-12 사주엔진관리 신규] 관리자가 생년월일시를 직접 입력해 saju_engine의
// 실계산 결과(/saju/v3/facts, /saju/v3/categories69)를 눈으로 확인하는 "라이브
// 테스트" 기능의 Server Action.
//
// [안전장치 — OPERATIONS_POLICY §10 이중 방어] 이 액션은 호출 대상 baseUrl이
// "로컬/샌드박스로 보이는 주소"가 아니면 즉시 거부한다. sintong.kr 등 운영
// 도메인으로는 어떠한 테스트 요청도 보낼 수 없도록 코드 레벨에서 강제한다
// (1차 방어: 클라이언트 폼이 기본값만 제공, 2차 방어: 이 서버 액션이 최종 검증).

import { z } from "zod";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { prisma } from "@/lib/db";
import {
  testEngineFacts,
  testEngineCategories69Full,
  checkEngineHealth,
  SAJU_ENGINE_ADMIN_TEST_DEFAULT_URL,
  type SajuTestBirthInput,
} from "@/lib/saju-engine-admin-client";

function assertLocalTestUrl(baseUrl: string) {
  const isLocal =
    baseUrl.includes("127.0.0.1") ||
    baseUrl.includes("localhost") ||
    baseUrl.includes("0.0.0.0");
  if (!isLocal) {
    throw new Error(
      "[안전장치] 사주엔진 라이브 테스트는 로컬/샌드박스 주소(127.0.0.1, localhost)로만 호출할 수 있습니다. " +
        "운영 서버(sintong.kr) 등 외부 도메인으로는 테스트 요청을 보낼 수 없습니다(OPERATIONS_POLICY §10)."
    );
  }
}

const BirthInputSchema = z.object({
  baseUrl: z.string().min(1).default(SAJU_ENGINE_ADMIN_TEST_DEFAULT_URL),
  year: z.coerce.number().int().min(1900).max(2100),
  month: z.coerce.number().int().min(1).max(12),
  day: z.coerce.number().int().min(1).max(31),
  hour: z.coerce.number().int().min(0).max(23).optional(),
  minute: z.coerce.number().int().min(0).max(59).optional(),
  gender: z.enum(["M", "F"]).default("M"),
  isLunar: z.coerce.boolean().default(false),
  isLeapMonth: z.coerce.boolean().default(false),
  zihourPolicy: z.enum(["traditional", "legacy"]).default("traditional"),
});

export interface SajuEngineTestState {
  error?: string;
  success?: boolean;
  resultJson?: string;
  latencyMs?: number;
  mode?: "facts" | "categories69";
}

async function runTest(
  mode: "facts" | "categories69",
  _prevState: SajuEngineTestState,
  formData: FormData
): Promise<SajuEngineTestState> {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_system")) {
    return { error: "권한이 없습니다(ops_system 접근 권한 필요)." };
  }

  const parsed = BirthInputSchema.safeParse({
    baseUrl: formData.get("baseUrl") || SAJU_ENGINE_ADMIN_TEST_DEFAULT_URL,
    year: formData.get("year"),
    month: formData.get("month"),
    day: formData.get("day"),
    hour: formData.get("hour") || undefined,
    minute: formData.get("minute") || undefined,
    gender: formData.get("gender") || "M",
    isLunar: formData.get("isLunar") === "on" || formData.get("isLunar") === "true",
    isLeapMonth: formData.get("isLeapMonth") === "on" || formData.get("isLeapMonth") === "true",
    zihourPolicy: formData.get("zihourPolicy") || "traditional",
  });

  if (!parsed.success) {
    return { error: `입력값 오류: ${parsed.error.issues.map((i) => i.message).join(", ")}` };
  }

  const v = parsed.data;

  try {
    assertLocalTestUrl(v.baseUrl);
  } catch (e) {
    return { error: e instanceof Error ? e.message : String(e) };
  }

  const input: SajuTestBirthInput = {
    year: v.year,
    month: v.month,
    day: v.day,
    hour: v.hour,
    minute: v.minute,
    gender: v.gender,
    is_lunar: v.isLunar,
    is_leap_month: v.isLeapMonth,
    zihour_policy: v.zihourPolicy,
  };

  const result =
    mode === "facts"
      ? await testEngineFacts(v.baseUrl, input)
      : await testEngineCategories69Full(v.baseUrl, input);

  if (!result.ok) {
    return { error: `엔진 호출 실패${result.statusCode ? `(HTTP ${result.statusCode})` : ""}: ${result.error}` };
  }

  // [감사 로그] 관리자의 라이브 테스트 호출도 OperationLog에 남긴다 — "누가 언제
  // 어떤 생년월일시로 테스트했는지" 추적 가능하게(실제 운영 데이터 변경은 없지만
  // 엔진 호출 자체를 투명하게 기록).
  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: `saju_engine_test_${mode}`,
      targetType: "saju_engine",
      targetId: null,
      after: JSON.stringify({ baseUrl: v.baseUrl, input }),
    },
  });

  return {
    success: true,
    resultJson: JSON.stringify(result.data, null, 2),
    latencyMs: result.latencyMs,
    mode,
  };
}

export async function testSajuEngineFactsAction(
  prevState: SajuEngineTestState,
  formData: FormData
): Promise<SajuEngineTestState> {
  return runTest("facts", prevState, formData);
}

export async function testSajuEngineCategories69Action(
  prevState: SajuEngineTestState,
  formData: FormData
): Promise<SajuEngineTestState> {
  return runTest("categories69", prevState, formData);
}

export interface EngineHealthCheckState {
  error?: string;
  success?: boolean;
  reachable?: boolean;
  status?: string;
  latencyMs?: number;
}

export async function checkSajuEngineHealthAction(
  _prevState: EngineHealthCheckState,
  formData: FormData
): Promise<EngineHealthCheckState> {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_system")) {
    return { error: "권한이 없습니다." };
  }
  const baseUrl = (formData.get("baseUrl") as string) || SAJU_ENGINE_ADMIN_TEST_DEFAULT_URL;
  try {
    assertLocalTestUrl(baseUrl);
  } catch (e) {
    return { error: e instanceof Error ? e.message : String(e) };
  }
  const result = await checkEngineHealth(baseUrl);
  if (!result.reachable) {
    return { error: result.error ?? "엔진에 연결할 수 없습니다.", success: false, reachable: false };
  }
  return { success: true, reachable: true, status: result.status, latencyMs: result.latencyMs };
}
