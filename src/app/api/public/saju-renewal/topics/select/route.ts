// [정통사주 리뉴얼 v1.0 — STEP 3] POST /v1/saju/topics/select
//
// [핵심 파이프라인 — 2025 진행 승인 지시 §1 고정]
//   사용자 → saju-engine-client(캐시) → SajuFactsCache → 기존 Topic Engine →
//   Topic 후보 선정 → 미확정 Scene 제거 → Topic Card 변환 → API 응답
//
// [LLM 호출 절대 금지 — §2] 이 라우트는 아래 모듈만 호출한다:
//   getSajuFacts()(캐시 경유, saju_engine 재계산 없음) → selectTopics()(순수
//   스코어링, LLM 미사용) → toTopicCard()/extractKeyFacts()(단순 변환). LLM
//   클라이언트(@/lib/llm-client 등)는 이 파일에서 import조차 하지 않는다 —
//   코드 자체로 "LLM 호출 0회"가 구조적으로 보장된다(테스트로도 검증).
//
// [PERSONALITY_001 — §3] topic-contract-adapter.ts의 SCENE_UNRESOLVED_TOPIC_IDS를
// Topic Engine의 selectTopics() 호출 시 excludeTopicIds로 전달해 "선정 단계에서부터"
// 제외한다(§4 권장). topic-evidence.ts의 evalPERSONALITY_001 evaluator나
// topic-catalog-data.ts의 PERSONALITY_001 레코드는 삭제하지 않았으므로, 디자인팀이
// scene을 확정해 SCENE_UNRESOLVED_TOPIC_IDS에서 제거하는 순간 이 라우트는 코드 수정
//없이 자동으로 재활성화된다.
//
// [69종 비노출 — §7] 응답에는 TopicCard(topic_id/scene/title/is_timing/
// evidence_fact_keys)만 내려간다. 내부 score/condition/evaluator/DB id/
// categoryGroup(29종 분류)은 toTopicCard()가 애초에 옮기지 않으므로 응답에
// 등장하지 않는다.
//
// [인증/공통 패턴 — §9] wishes/_shared.ts의 requireUser/unauthorizedResponse/
// CORS_HEADERS를 그대로 재사용한다. 새 인증 구조를 만들지 않는다.
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import { requireUser, unauthorizedResponse } from "../../../wishes/_shared";
import {
  getSajuFacts,
  SajuEngineClientError,
  type SajuBirthInput,
} from "@/lib/saju-renewal/saju-engine-client";
import { selectTopics, type ExposureRecord } from "@/lib/saju-renewal/topic-engine";
import {
  toTopicCard,
  extractKeyFacts,
  SCENE_UNRESOLVED_TOPIC_IDS,
  type TopicCard,
} from "@/lib/saju-renewal/topic-contract-adapter";
import { NEXT_CANDIDATES_MAX } from "@/lib/saju-renewal/topic-scoring-config";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** [§9 ResultAccessError 패턴 재사용] 이 라우트 전용 에러코드 — 서버 500이 아니라
 * 명확한 에러 응답(§10)을 내리기 위해 result-access-service.ts의 ResultAccessError와
 * 동일한 설계(코드+메시지, route에서 status 매핑)를 따른다. */
class TopicsSelectError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

const ERROR_STATUS: Record<string, number> = {
  INVALID_REQUEST_BODY: 400,
  PROFILE_ID_REQUIRED: 400,
  PROFILE_ID_MISMATCH: 400,
  INVALID_EXCLUDE_TOPIC_IDS: 400,
  INVALID_LIMIT: 400,
  BIRTH_INFO_REQUIRED: 400,
  FACT_ENGINE_UNAVAILABLE: 503,
};

const ERROR_MESSAGE: Record<string, string> = {
  INVALID_REQUEST_BODY: "요청 본문이 올바르지 않습니다.",
  PROFILE_ID_REQUIRED: "profile_id는 필수입니다.",
  PROFILE_ID_MISMATCH: "profile_id가 로그인 사용자와 일치하지 않습니다.",
  INVALID_EXCLUDE_TOPIC_IDS: "exclude_topic_ids는 문자열 배열이어야 합니다.",
  INVALID_LIMIT: "limit은 1 이상의 숫자여야 합니다.",
  BIRTH_INFO_REQUIRED: "출생정보가 등록되어 있지 않습니다. 프로필을 먼저 입력해주세요.",
  FACT_ENGINE_UNAVAILABLE: "사주 계산 결과를 가져오는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
};

interface RequestBody {
  profile_id?: unknown;
  exclude_topic_ids?: unknown;
  limit?: unknown;
}

/** [요청값 검증 — §10] body 구조/타입을 전부 검증하고, 실패 시 명확한 코드로 던진다. */
function validateBody(body: RequestBody, authenticatedUserId: number): {
  excludeTopicIds: string[];
  limit: number;
} {
  if (body.profile_id === undefined || body.profile_id === null) {
    throw new TopicsSelectError("PROFILE_ID_REQUIRED", ERROR_MESSAGE.PROFILE_ID_REQUIRED);
  }
  // [profile_id 처리 — UserProfile은 1:1이라 다중 프로필 모델이 없음] profile_id는
  // 인증된 userId를 문자열화한 것과 반드시 같아야 한다(다른 사용자의 프로필을
  // 지정할 수 없음). 새 프로필 개념을 만들지 않고 기존 1:1 관계만 사용한다.
  if (String(body.profile_id) !== String(authenticatedUserId)) {
    throw new TopicsSelectError("PROFILE_ID_MISMATCH", ERROR_MESSAGE.PROFILE_ID_MISMATCH);
  }

  let excludeTopicIds: string[] = [];
  if (body.exclude_topic_ids !== undefined) {
    if (
      !Array.isArray(body.exclude_topic_ids) ||
      !body.exclude_topic_ids.every((v) => typeof v === "string")
    ) {
      throw new TopicsSelectError(
        "INVALID_EXCLUDE_TOPIC_IDS",
        ERROR_MESSAGE.INVALID_EXCLUDE_TOPIC_IDS
      );
    }
    excludeTopicIds = body.exclude_topic_ids;
  }

  // [limit — docs/11 §2 "기본 4 (first 제외 후보 수)"] 지정되지 않으면 엔진의
  // 다음 후보 최대치(NEXT_CANDIDATES_MAX=4)를 그대로 쓴다. 엔진 최대치보다 큰
  // 값을 요청해도 엔진이 애초에 4개까지만 만들어내므로 clamp만 하면 충분하다
  // (억지로 더 많은 후보를 만들어내지 않음 — §6 "임의 Topic 생성 금지"와 동일 원칙).
  let limit = NEXT_CANDIDATES_MAX;
  if (body.limit !== undefined) {
    if (typeof body.limit !== "number" || !Number.isFinite(body.limit) || body.limit < 1) {
      throw new TopicsSelectError("INVALID_LIMIT", ERROR_MESSAGE.INVALID_LIMIT);
    }
    limit = Math.min(Math.floor(body.limit), NEXT_CANDIDATES_MAX);
  }

  return { excludeTopicIds, limit };
}

/** "YYYY-MM-DD" → {year,month,day}. 형식이 올바르지 않으면 null(= 출생정보 없음과 동일 취급). */
function parseBirthDate(birthDate: string): { year: number; month: number; day: number } | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(birthDate);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) return null;
  return { year, month, day };
}

/** "HH:MM" → {hour,minute}. birthTimeUnknown이거나 값이 없거나 파싱 불가하면 {} 반환
 * (saju-engine-client.ts의 normalizeInput()이 기본값 12:00으로 처리 — 계산 로직은
 * 그대로, 이 라우트에서 임의로 다른 기본값을 만들지 않는다). */
function parseBirthTime(
  birthTime: string | null | undefined,
  birthTimeUnknown: boolean
): { hour?: number; minute?: number } {
  if (birthTimeUnknown || !birthTime) return {};
  const match = /^(\d{1,2}):(\d{1,2})$/.exec(birthTime);
  if (!match) {
    console.warn(`[topics/select] birthTime 파싱 실패(값="${birthTime}") — 기본값(12:00)으로 처리합니다.`);
    return {};
  }
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    console.warn(`[topics/select] birthTime 범위 밖(값="${birthTime}") — 기본값(12:00)으로 처리합니다.`);
    return {};
  }
  return { hour, minute };
}

/** User.gender(문자열, "male"|"female"|"unspecified"|null) → SajuBirthInput.gender.
 * saju_engine BirthInputV3.gender 기본값은 "male"이다 — "unspecified"/null인 경우
 * 임의로 추정하지 않고 undefined를 반환해 엔진 기본값에 위임한다(이 라우트가 새로운
 * 판단을 추가하지 않음). */
function toEngineGender(gender: string | null | undefined): "male" | "female" | undefined {
  if (gender === "male" || gender === "female") return gender;
  return undefined;
}

export async function POST(request: NextRequest) {
  try {
    const auth = await requireUser(request);
    if (!auth) return unauthorizedResponse();
    const userId = auth.userId;

    let rawBody: RequestBody;
    try {
      rawBody = await request.json();
    } catch {
      throw new TopicsSelectError("INVALID_REQUEST_BODY", ERROR_MESSAGE.INVALID_REQUEST_BODY);
    }

    const { excludeTopicIds: requestedExcludeIds, limit } = validateBody(rawBody, userId);

    // [§10 요청값 검증 — profile/birth 정보] 기존 fortune/daily/route.ts와 동일한
    // user.profile 조회 패턴을 재사용한다.
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user || !user.profile?.birthDate) {
      throw new TopicsSelectError("BIRTH_INFO_REQUIRED", ERROR_MESSAGE.BIRTH_INFO_REQUIRED);
    }

    const parsedDate = parseBirthDate(user.profile.birthDate);
    if (!parsedDate) {
      throw new TopicsSelectError("BIRTH_INFO_REQUIRED", ERROR_MESSAGE.BIRTH_INFO_REQUIRED);
    }
    const { hour, minute } = parseBirthTime(user.profile.birthTime, user.profile.birthTimeUnknown);

    const birthInput: SajuBirthInput = {
      year: parsedDate.year,
      month: parsedDate.month,
      day: parsedDate.day,
      hour,
      minute,
      gender: toEngineGender(user.gender),
      isLunar: user.profile.isLunar,
      // zihourPolicy: UserProfile에 저장 필드가 없어 엔진 기본값("traditional")을
      // 그대로 사용한다(§11 "캐시 사용 원칙"과 무관 — 이 값은 saju-engine-client.ts의
      // normalizeInput()이 기본값을 채워준다).
    };

    // [§11 캐시 사용 원칙] /saju/v3/facts를 직접 재호출하지 않고 STEP 2의
    // getSajuFacts()(SajuFactsCache 경유)만 사용한다.
    let facts;
    let birthKey: string;
    try {
      const result = await getSajuFacts(birthInput, { userId });
      facts = result.facts;
      birthKey = result.birthKey;
    } catch (e) {
      if (e instanceof SajuEngineClientError) {
        console.error("[POST /api/public/saju-renewal/topics/select] FACT 조회 실패:", e.message);
        throw new TopicsSelectError("FACT_ENGINE_UNAVAILABLE", ERROR_MESSAGE.FACT_ENGINE_UNAVAILABLE);
      }
      throw e;
    }

    // [§5 TopicExposureHistory 반영] 이 사용자가 이 birthKey로 이미 본 주제 이력을
    // 조회한다. orderBy 없이 단순 where만 사용(복합 인덱스 필요 없는 안전한 쿼리 —
    // 위 가이드라인 "Firestore 쿼리 최적화"와 동일 원칙을 Prisma에도 적용).
    const exposureRows = await prisma.topicExposureHistory.findMany({
      where: { userId, birthKey },
      select: { topicId: true, viewedAt: true },
    });
    const exposureHistory: ExposureRecord[] = exposureRows.map((r) => ({
      topicId: r.topicId,
      viewedAt: r.viewedAt,
    }));

    // [§3·§4 PERSONALITY_001 등 scene 미확정 Topic을 선정 단계에서부터 제외]
    // SCENE_UNRESOLVED_TOPIC_IDS(현재 PERSONALITY_001)를 요청의 exclude_topic_ids
    // (08 재호출 시 이미 노출된 주제)와 병합한다.
    const excludeTopicIds = Array.from(
      new Set([...SCENE_UNRESOLVED_TOPIC_IDS, ...requestedExcludeIds])
    );

    // [§2 LLM 호출 0회] selectTopics()는 순수 함수이며 내부에 LLM 호출이 전혀 없다.
    const selection = selectTopics({ facts, exposureHistory, excludeTopicIds });

    // [§7·§8 Scene 변환 + fail-fast] toTopicCard()는 scene이 미확정이면 throw한다.
    // 위에서 SCENE_UNRESOLVED_TOPIC_IDS를 이미 제외했으므로 정상 흐름에서는 발생하지
    // 않아야 하며, 혹시 발생하면(신규 topic 추가 시 scene 매핑을 빠뜨린 버그) 아래
    // catch에서 500으로 fail-fast한다 — "life 같은 임시값으로 조용히 통과"시키지 않는다.
    const firstTopic: TopicCard = toTopicCard(selection.todayTopic);
    const candidates: TopicCard[] = selection.nextCandidates
      .slice(0, limit)
      .map((c) => toTopicCard(c));

    const keyFacts = extractKeyFacts(facts);

    // [STEP 4 승인 지시 §1 재검토 결론 — first_topic 기록 시점 변경]
    // 과거(STEP 3)에는 이 API 호출 시점에 first_topic을 즉시 ExposureHistory에
    // 기록했으나, 이는 "실제로 사용자 화면에 노출된 시점"과 일치하지 않는다 — 화면
    // 흐름상 04(분석 완료)에서는 아직 제목만 보여줄 뿐, 실제 이야기 내용(summary)은
    // 05(이야기 미리보기)에서 POST /v1/saju/interpret을 호출해야 비로소 열린다.
    // 즉 first_topic도 candidates와 동일하게 "아직 본 것이 아니라 후보로 제시된 것"
    // 일 뿐이다. 따라서 이 API에서는 어떤 topic도 기록하지 않고, interpret
    // route.ts가 실제 해석에 성공했을 때만 그 topic_id를 기록한다(STEP4 §16 "실제
    // 첫 이야기 화면이 노출된 경우 기록" 요건을 interpret 성공 시점으로 통일).

    return NextResponse.json(
      {
        success: true,
        data: {
          first_topic: firstTopic,
          candidates,
          key_facts: keyFacts,
          fact_schema_version: selection.factSchemaVersion,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    if (e instanceof TopicsSelectError) {
      return NextResponse.json(
        { success: false, error: ERROR_MESSAGE[e.code] ?? e.message, reason: e.code },
        { status: ERROR_STATUS[e.code] ?? 400, headers: CORS_HEADERS }
      );
    }
    // [Scene 미확정 fail-fast 등 예상치 못한 내부 오류] 사용자에게 내부 세부사항을
    // 노출하지 않되, 서버 로그에는 전체 내용을 남겨 즉시 원인을 추적할 수 있게 한다.
    console.error("[POST /api/public/saju-renewal/topics/select] 처리 중 오류:", e);
    return NextResponse.json(
      { success: false, error: "주제를 불러오는 중 오류가 발생했습니다." },
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
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
