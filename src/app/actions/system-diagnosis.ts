"use server";

// [관리자 2.0 전면 재설계 - Task 11] AI시스템관리 - 3단계 자동진단 Server Actions.
//
// [RBAC] rbac.ts 주석 결정에 따라 "ops_system" 코드 재사용(ops_security+
// system_settings 미러링 — super_admin만 write 가능, RBAC_MATRIX.ops_system
// = { super_admin: RWD, operator: R, cs: X, content_manager: X }).
//
// [3단계 원칙 — 재확인] 이 파일은 실제 서버 명령을 실행하지 않는다:
//   1) runDetection: ErrorLog(critical, 최근 24h)를 스캔해 SystemDiagnosis에
//      status=detected로 기록(이미 동일 미해결 건이 있으면 중복 생성 안 함).
//   2) runDiagnosis: 탐지된 레코드를 Anthropic LLM(llm-client.ts, 기존
//      ANTHROPIC_APP_API_KEY 재사용)에 보내 원인 분석/권장 조치 텍스트를 받아
//      status=diagnosed로 갱신. LLM 호출 실패 시 규칙기반 문구로 폴백(기존
//      llm-client.ts 사용처와 동일 원칙 — 사용자 요청 흐름이 아니므로 폴백
//      실패해도 에러만 표시).
//   3) approveAction/rejectAction: 운영자가 권장 조치를 검토해 승인/반려만
//      기록한다. 실제 서버 조치(재시작/백업 등)는 운영자가 SSH로 직접 수행 —
//      이 앱은 프로덕션 서버에 명령을 실행하는 경로를 애초에 갖지 않는다
//      (OPERATIONS_POLICY §3 승인 없는 프로덕션 변경 금지 원칙과 정합).
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, canWriteMenu } from "@/lib/rbac";
import { completeText, LlmClientError } from "@/lib/llm-client";

export interface DiagnosisFormState {
  error?: string;
  success?: boolean;
}

const LIST_PATH = "/ai-system/diagnosis";

function canWriteDiagnosis(roleCode: string): boolean {
  return canWriteMenu(roleCode, "ops_system");
}

// ══════════════════════════════════════════════════════════
// 1단계: 탐지 — ErrorLog(critical, 최근 24h)를 스캔.
// [중복 방지] 동일 severity="critical" 탐지가 이미 detected/diagnosed 상태로
// 미해결(승인/반려 전) 대기 중이면 새로 만들지 않고 그 레코드를 그대로 둔다.
// ══════════════════════════════════════════════════════════
export async function runDetection(
  _prevState: DiagnosisFormState,
  _formData: FormData
): Promise<DiagnosisFormState> {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_system")) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const dayAgo = new Date();
  dayAgo.setDate(dayAgo.getDate() - 1);

  const criticalErrors = await prisma.errorLog.findMany({
    where: { severity: "critical", createdAt: { gte: dayAgo } },
    orderBy: { createdAt: "desc" },
    take: 20,
  });

  if (criticalErrors.length === 0) {
    return { error: "최근 24시간 내 critical 에러가 없어 탐지할 이상 징후가 없습니다." };
  }

  const existingOpen = await prisma.systemDiagnosis.findFirst({
    where: { category: "server", status: { in: ["detected", "diagnosed"] } },
    orderBy: { createdAt: "desc" },
  });
  if (existingOpen) {
    return { error: "이미 미해결 상태의 탐지 건이 있습니다. 먼저 해당 건을 진단/승인/반려 처리하세요." };
  }

  const summary = criticalErrors
    .map((e) => `[${e.source}] ${e.errorCode ?? "-"}: ${e.message}`)
    .join("\n");

  await prisma.systemDiagnosis.create({
    data: {
      category: "server",
      detectedIssue: `최근 24시간 내 critical 에러 ${criticalErrors.length}건 탐지:\n${summary.slice(0, 1000)}`,
      severity: "critical",
      status: "detected",
    },
  });

  revalidatePath(LIST_PATH);
  revalidatePath("/ops");
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 2단계: 진단 — LLM에 탐지 원문을 보내 원인 분석/권장 조치 텍스트 수신.
// ══════════════════════════════════════════════════════════
const IdSchema = z.object({ id: z.coerce.number().int().positive() });

export async function runDiagnosis(
  _prevState: DiagnosisFormState,
  formData: FormData
): Promise<DiagnosisFormState> {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "ops_system")) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.systemDiagnosis.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 진단 건입니다." };
  }
  if (before.status !== "detected") {
    return { error: "탐지(detected) 상태의 건만 진단할 수 있습니다." };
  }

  let diagnosisText: string;
  let suggestedAction: string;
  try {
    const text = await completeText({
      systemPrompt:
        "당신은 운세 서비스(Fortune Fusion)의 서버 운영 보조 진단가입니다. 전달받은 critical 에러 로그 요약을 보고, " +
        "(1) 가능성 높은 원인을 한국어로 2~3문장으로 설명하고, (2) 운영자가 SSH로 직접 수행할 수 있는 구체적인 " +
        "권장 조치를 한국어로 2~3문장 제안하세요. 절대 실제 명령을 자동 실행하라고 말하지 말고, 운영자가 직접 " +
        "검토 후 수행할 '제안'임을 전제로 작성하세요. 출력 형식: '원인: ...' 줄바꿈 '권장 조치: ...' 두 줄로만 답하세요.",
      userPrompt: before.detectedIssue,
      maxTokens: 500,
    });
    const causeMatch = text.match(/원인\s*:\s*([\s\S]*?)(?=권장\s*조치\s*:|$)/);
    const actionMatch = text.match(/권장\s*조치\s*:\s*([\s\S]*)$/);
    diagnosisText = causeMatch?.[1]?.trim() || text.trim();
    suggestedAction = actionMatch?.[1]?.trim() || "로그를 확인해 수동으로 원인을 분석해주세요.";
  } catch (e) {
    // [llm-client.ts 기존 원칙] LLM 실패 시 규칙기반 문구로 폴백.
    diagnosisText =
      "AI 자동진단 호출에 실패했습니다" +
      (e instanceof LlmClientError ? `(${e.message})` : "") +
      ". 탐지된 에러 로그를 /system-settings/logs 에서 직접 확인해주세요.";
    suggestedAction = "PM2 로그(pm2 logs) 및 /system-settings/logs 확인 후 수동 조치가 필요합니다.";
  }

  await prisma.systemDiagnosis.update({
    where: { id },
    data: { status: "diagnosed", diagnosisText, suggestedAction },
  });

  revalidatePath(LIST_PATH);
  revalidatePath("/ops");
  return { success: true };
}

// ══════════════════════════════════════════════════════════
// 3단계: 승인게이트 조치 — 승인/반려만 기록(실제 서버 조치는 운영자가 직접 수행).
// ══════════════════════════════════════════════════════════
export async function approveDiagnosisAction(
  _prevState: DiagnosisFormState,
  formData: FormData
): Promise<DiagnosisFormState> {
  const session = await verifyAdminSession();
  if (!canWriteDiagnosis(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다(super_admin만 승인 가능)." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.systemDiagnosis.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 진단 건입니다." };
  }
  if (before.status !== "diagnosed") {
    return { error: "진단(diagnosed) 상태의 건만 승인할 수 있습니다." };
  }

  await prisma.systemDiagnosis.update({
    where: { id },
    data: { status: "approved", approvedAdminId: session.adminUserId, approvedAt: new Date() },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "system_diagnosis",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "approved" }),
    },
  });

  revalidatePath(LIST_PATH);
  revalidatePath("/ops");
  return { success: true };
}

export async function rejectDiagnosisAction(
  _prevState: DiagnosisFormState,
  formData: FormData
): Promise<DiagnosisFormState> {
  const session = await verifyAdminSession();
  if (!canWriteDiagnosis(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다(super_admin만 반려 가능)." };
  }

  const parsed = IdSchema.safeParse({ id: formData.get("id") });
  if (!parsed.success) {
    return { error: "입력값이 올바르지 않습니다." };
  }
  const { id } = parsed.data;

  const before = await prisma.systemDiagnosis.findUnique({ where: { id } });
  if (!before) {
    return { error: "존재하지 않는 진단 건입니다." };
  }
  if (before.status !== "diagnosed") {
    return { error: "진단(diagnosed) 상태의 건만 반려할 수 있습니다." };
  }

  await prisma.systemDiagnosis.update({
    where: { id },
    data: { status: "rejected" },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "system_diagnosis",
      targetId: id,
      before: JSON.stringify({ status: before.status }),
      after: JSON.stringify({ status: "rejected" }),
    },
  });

  revalidatePath(LIST_PATH);
  revalidatePath("/ops");
  return { success: true };
}
