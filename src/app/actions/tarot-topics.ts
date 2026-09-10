"use server";

// [신통방통 타로 65종 주제 연동 지시서 - ④ 관리자 CMS: 65개 주제/포지션 관리]
// tarot_topics(65개, topicKey 고정) / tarot_positions(topic×spreadType별 고정 구성) 관리.
// 65개 주제는 Flutter TarotCategoryData.id(topicKey)와 강하게 결합되어 있고,
// tarot_positions는 unique(topicId, spreadType, positionIndex) 구조를 갖는 고정
// 스켈레톤이므로, 신규 생성/삭제는 지원하지 않고 "기존 65개 레코드의 내용 편집"만
// 지원한다(topic-cards.ts와 달리 CRUD 전체를 열지 않는 이유).
// 기존 fortune-categories.ts / tarot-cards.ts Server Actions 패턴을 그대로 재사용:
// zod 검증 → RBAC(ai_content) 쓰기 권한 확인 → prisma 갱신 → operationLog 기록
// → revalidatePath.
import { z } from "zod";
import { revalidatePath } from "next/cache";
import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu, RBAC_MATRIX } from "@/lib/rbac";

function canWriteAiContent(roleCode: string): boolean {
  if (!canAccessMenu(roleCode, "ai_content")) return false;
  return !!RBAC_MATRIX.ai_content[roleCode as keyof typeof RBAC_MATRIX.ai_content]?.write;
}

export interface TarotTopicActionState {
  error?: string;
  success?: boolean;
}

// route.ts / narrative-engine.ts가 실제로 분기 처리하는 스프레드 종류만 허용한다.
const ALL_SPREADS = ["one_card", "three_card", "five_card", "yes_no", "choice_ab"] as const;

// ── 주제 메타 편집(주제명/설명/질문유형/허용스프레드/YESNO/AB/프롬프트도메인/상태) ──
const UpdateTopicSchema = z.object({
  topicKey: z.string().min(1),
  topicName: z.string().min(1, "주제명을 입력해주세요."),
  description: z.string().optional(),
  questionType: z.enum(["open", "yes_no", "choice_ab"]),
  allowedSpreads: z.array(z.enum(ALL_SPREADS)).min(1, "허용 스프레드를 1개 이상 선택해주세요."),
  yesNoEnabled: z.coerce.boolean(),
  isChoiceAb: z.coerce.boolean(),
  promptDomain: z.string().min(1, "프롬프트 도메인을 입력해주세요."),
  status: z.enum(["active", "inactive"]),
});

export async function updateTarotTopic(
  _prevState: TarotTopicActionState,
  formData: FormData
): Promise<TarotTopicActionState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const raw = {
    topicKey: formData.get("topicKey"),
    topicName: formData.get("topicName"),
    description: formData.get("description") || undefined,
    questionType: formData.get("questionType"),
    allowedSpreads: formData.getAll("allowedSpreads"),
    yesNoEnabled: formData.get("yesNoEnabled") === "on",
    isChoiceAb: formData.get("isChoiceAb") === "on",
    promptDomain: formData.get("promptDomain"),
    status: formData.get("status"),
  };
  const parsed = UpdateTopicSchema.safeParse(raw);
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { topicKey, allowedSpreads, ...rest } = parsed.data;
  const target = await prisma.tarotTopic.findUnique({ where: { topicKey } });
  if (!target) return { error: "대상 주제를 찾을 수 없습니다." };

  // yes_no/choice_ab 플래그와 allowedSpreads 간 정합성을 서버에서도 한 번 더 강제한다
  // (route.ts가 spreadType==='yes_no' && !yesNoEnabled 또는
  //  spreadType==='choice_ab' && !isChoiceAb일 때 400을 반환하므로, 관리자가
  //  실수로 불일치 상태를 저장하면 앱에서 바로 에러가 나기 때문).
  if (rest.yesNoEnabled && !allowedSpreads.includes("yes_no")) {
    return { error: "YES/NO 사용을 켜려면 허용 스프레드에 yes_no를 포함해야 합니다." };
  }
  if (rest.isChoiceAb && !allowedSpreads.includes("choice_ab")) {
    return { error: "A/B 양자택일을 켜려면 허용 스프레드에 choice_ab를 포함해야 합니다." };
  }

  await prisma.tarotTopic.update({
    where: { topicKey },
    data: {
      topicName: rest.topicName,
      description: rest.description ?? null,
      questionType: rest.questionType,
      allowedSpreads: JSON.stringify(allowedSpreads),
      yesNoEnabled: rest.yesNoEnabled,
      isChoiceAb: rest.isChoiceAb,
      promptDomain: rest.promptDomain,
      status: rest.status,
      updatedBy: session.email,
    },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "tarot_topic",
      targetId: target.id,
      before: JSON.stringify(target),
      after: JSON.stringify({ ...rest, allowedSpreads }),
    },
  });

  revalidatePath("/ai-content/tarot-topics");
  revalidatePath(`/ai-content/tarot-topics/${topicKey}`);
  return { success: true };
}

// ── 포지션 편집(포지션명/해석목적) — topicId/spreadType/positionIndex는 불변(unique key) ──
const UpdatePositionSchema = z.object({
  id: z.coerce.number().int(),
  topicKey: z.string().min(1),
  positionName: z.string().min(1, "포지션명을 입력해주세요."),
  positionPurpose: z.string().min(1, "해석 목적을 입력해주세요."),
});

export async function updateTarotPosition(
  _prevState: TarotTopicActionState,
  formData: FormData
): Promise<TarotTopicActionState> {
  const session = await verifyAdminSession();
  if (!canWriteAiContent(session.roleCode)) {
    return { error: "이 작업을 수행할 권한이 없습니다." };
  }

  const parsed = UpdatePositionSchema.safeParse({
    id: formData.get("id"),
    topicKey: formData.get("topicKey"),
    positionName: formData.get("positionName"),
    positionPurpose: formData.get("positionPurpose"),
  });
  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? "입력값이 올바르지 않습니다." };
  }

  const { id, topicKey, positionName, positionPurpose } = parsed.data;
  const target = await prisma.tarotPosition.findUnique({ where: { id } });
  if (!target) return { error: "대상 포지션을 찾을 수 없습니다." };

  await prisma.tarotPosition.update({
    where: { id },
    data: { positionName, positionPurpose },
  });

  await prisma.operationLog.create({
    data: {
      actorType: "admin",
      actorId: session.adminUserId,
      action: "update",
      targetType: "tarot_position",
      targetId: target.id,
      before: JSON.stringify(target),
      after: JSON.stringify({ positionName, positionPurpose }),
    },
  });

  revalidatePath(`/ai-content/tarot-topics/${topicKey}`);
  return { success: true };
}
