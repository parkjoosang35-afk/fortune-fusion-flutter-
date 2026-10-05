// [정통사주 리뉴얼 v1.0] Engine Client + Cache — 2025 진행 승인 지시 §4·§6·§7 구현.
//
// [§4 원칙 — 기존 사주 엔진은 수정하지 않음] 이 파일은 saju_engine(`/saju/v3/facts`,
// 기존 재사용)을 HTTP로 호출하는 소비자 코드일 뿐이다. saju_calculator.py/saju_facts.py
// 등 엔진 내부는 절대 수정하지 않는다:
//   기존 엔진 → 기존 FACT → (이 파일: Adapter/Cache) → 신규 Topic 구조
//
// [§6 핵심 — 캐시] 같은 출생정보라면 사용자가 다른 사주 이야기를 볼 때마다 사주 전체를
// 재계산하면 안 된다. 최초 계산 후 저장된 FACT를 계속 재사용한다.
//
// [§7 핵심 — 캐시 판정 기준 반드시 검증] 단순히 DB에 FACT가 존재한다는 이유만으로
// 재사용하지 않고, "현재 사용자의 사주 입력값"과 "캐시의 계산 기준"이 saju_engine이
// 실제로 계산에 쓰는 입력값 전체 기준으로 동일한지 확인한다. saju_engine
// (api/saju_api.py BirthInputV3, saju_calculator.py calculate_saju 시그니처)을 직접
// 확인한 결과, 클라이언트가 바꿀 수 있고 계산 결과에 영향을 주는 입력값은:
//   year, month, day, hour, minute, gender, is_lunar, zihour_policy
// 8개뿐이다(true_solar/longitude/dayun_method/current_year는 엔진 쪽 고정 기본값만
// 쓰고 이 클라이언트가 바꾸지 않으므로 캐시 키에 넣을 필요가 없다 — 바뀔 수 없는
// 값은 비교 대상에서 제외). birthKey는 이 8개 값 전체의 해시로 산출한다.

import crypto from "crypto";
import { prisma } from "@/lib/db";
import type { SajuV3Facts } from "./saju-facts-types";

/** saju_engine `api/saju_api.py BirthInputV3`와 1:1 대응하는 요청 입력.
 * [새 명칭 임의 생성 금지] 필드명은 엔진 Pydantic 모델(year/month/day/hour/minute/
 * gender/is_lunar/zihour_policy)과 동일한 의미를 유지하되, 이 레이어는 TypeScript
 * camelCase 관례를 따른다(실제 HTTP 전송 시점에만 snake_case로 변환). */
export interface SajuBirthInput {
  year: number;
  month: number;
  day: number;
  hour?: number; // 기본 12(엔진 기본값과 동일) — 시간 모름(timeUnknown) 케이스
  minute?: number; // 기본 0
  gender?: "male" | "female";
  isLunar?: boolean;
  /** 야자시 정책 — 엔진 기본값 "traditional"(23시 익일파). "legacy"는 기존 방식. */
  zihourPolicy?: "traditional" | "legacy";
}

export interface SajuEngineClientOptions {
  /** saju_engine base URL. 기본값은 사내 고정 포트(로컬 uvicorn, 외부 미노출). */
  baseUrl?: string;
  /** 환경변수가 없을 때도 호출이 막히지 않도록 하는 기본 타임아웃(ms). */
  timeoutMs?: number;
  /** 동일 userId로 캐시를 귀속시킬지 여부(비로그인 세션은 null로 호출). */
  userId?: number | null;
}

const DEFAULT_BASE_URL = process.env.SAJU_ENGINE_BASE_URL ?? "http://127.0.0.1:8000";
const DEFAULT_TIMEOUT_MS = 15_000; // docs/11_API_계약서.md §5 "facts | 03 전체 15s"
/** access_control/free_pass.py verify_free_pass_token() 데모 검증 규칙 — "STB-" 접두사
 * + 32자 이상만 통과. 실서비스 회원 인증과 무관한 "서버-서버 내부 호출용 고정 토큰"이며,
 * 엔진 코드를 수정하지 않고 기존 데모 규칙을 그대로 만족시키는 값일 뿐이다.
 * [운영 전환 시 필수 조치] 이 토큰은 .env의 SAJU_ENGINE_FREE_PASS_TOKEN으로 반드시
 * 교체해야 한다 — 코드에 고정값을 두는 것은 로컬 개발 전용이며, 실서비스 반영 전
 * 인프라팀 확인이 필요한 별도 사항이다(이 파일이 임의로 운영 보안을 결정하지 않음).
 */
const DEFAULT_FREE_PASS_TOKEN =
  process.env.SAJU_ENGINE_FREE_PASS_TOKEN ?? "STB-internal-server-call-00000000000000";

export class SajuEngineClientError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number
  ) {
    super(message);
    this.name = "SajuEngineClientError";
  }
}

function normalizeInput(input: SajuBirthInput): Required<SajuBirthInput> {
  return {
    year: input.year,
    month: input.month,
    day: input.day,
    hour: input.hour ?? 12,
    minute: input.minute ?? 0,
    gender: input.gender ?? "male",
    isLunar: input.isLunar ?? false,
    zihourPolicy: input.zihourPolicy ?? "traditional",
  };
}

/**
 * [§7 캐시 판정 기준] saju_engine 계산에 실제 영향을 주는 입력값 8개 전체를 직렬화해
 * sha256 해시로 만든다. 하나라도 다르면 다른 birthKey가 나와야 하므로, 값들을 구분자로
 * 고정 순서 결합한다(정렬이 아니라 고정 스키마 순서 — 필드 추가 시 반드시 이 순서 끝에
 * 덧붙이고 기존 순서를 바꾸지 않아야 과거 캐시와의 하위호환이 깨지지 않는다).
 */
export function computeBirthKey(input: SajuBirthInput): string {
  const n = normalizeInput(input);
  const raw = [n.year, n.month, n.day, n.hour, n.minute, n.gender, n.isLunar, n.zihourPolicy].join(
    "|"
  );
  return crypto.createHash("sha256").update(raw).digest("hex");
}

async function callSajuEngineFacts(
  input: Required<SajuBirthInput>,
  options: SajuEngineClientOptions
): Promise<SajuV3Facts> {
  const baseUrl = options.baseUrl ?? DEFAULT_BASE_URL;
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(`${baseUrl}/saju/v3/facts`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Free-Pass": DEFAULT_FREE_PASS_TOKEN,
      },
      body: JSON.stringify({
        year: input.year,
        month: input.month,
        day: input.day,
        hour: input.hour,
        minute: input.minute,
        gender: input.gender,
        is_lunar: input.isLunar,
        zihour_policy: input.zihourPolicy,
      }),
      signal: controller.signal,
    });

    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new SajuEngineClientError(
        `saju_engine /saju/v3/facts 호출 실패(status=${res.status}): ${body.slice(0, 200)}`,
        res.status
      );
    }
    return (await res.json()) as SajuV3Facts;
  } catch (e) {
    if (e instanceof SajuEngineClientError) throw e;
    if (e instanceof Error && e.name === "AbortError") {
      throw new SajuEngineClientError(`saju_engine 응답 타임아웃(${timeoutMs}ms 초과)`);
    }
    throw new SajuEngineClientError(
      `saju_engine 호출 중 알 수 없는 오류: ${e instanceof Error ? e.message : String(e)}`
    );
  } finally {
    clearTimeout(timer);
  }
}

export interface GetSajuFactsResult {
  facts: SajuV3Facts;
  birthKey: string;
  /** true면 SajuFactsCache 재사용(엔진 재호출 없음), false면 이번 호출에서 새로 계산. */
  fromCache: boolean;
}

/**
 * [메인 진입점] §6 "최초 계산 후 저장된 FACT를 계속 사용" + §7 "캐시 판정 기준 검증"을
 * 함께 구현한다:
 *   1) computeBirthKey()로 입력값 8개 전체 기준 birthKey 산출
 *   2) SajuFactsCache.birthKey로 조회 — 있으면(=입력값이 전부 동일했을 때만 같은 키가
 *      나옴) 엔진을 재호출하지 않고 저장된 facts_json을 그대로 반환
 *   3) 없으면 엔진을 1회 호출하고, 결과를 birthKey와 함께 저장(이후 재사용)
 * [재계산 금지 재확인] docs/05_데이터_API_상태.md "09 순환에서는 재계산 금지"와
 * 정확히 대응 — 09(더보기/추가 이야기) 화면이 topics/select를 다시 호출해도, 이
 * 함수가 같은 birthKey로 캐시 히트하므로 엔진 재계산이 일어나지 않는다.
 */
export async function getSajuFacts(
  input: SajuBirthInput,
  options: SajuEngineClientOptions = {}
): Promise<GetSajuFactsResult> {
  const normalized = normalizeInput(input);
  const birthKey = computeBirthKey(normalized);

  const cached = await prisma.sajuFactsCache.findUnique({ where: { birthKey } });
  if (cached && cached.status === "active" && !cached.deletedAt) {
    return {
      facts: JSON.parse(cached.factsJson) as SajuV3Facts,
      birthKey,
      fromCache: true,
    };
  }

  const facts = await callSajuEngineFacts(normalized, options);

  // [멱등 upsert] 동시 요청(레이스)으로 같은 birthKey가 두 번 계산되더라도 unique
  // 제약(birthKey)에 의해 저장은 1건으로 귀결된다 — upsert로 레이스 컨디션 자체를
  // 에러 없이 흡수한다(마지막 쓰기가 반영되지만 같은 입력이면 결과도 결정론적으로 동일).
  await prisma.sajuFactsCache.upsert({
    where: { birthKey },
    create: {
      userId: options.userId ?? null,
      birthKey,
      birthDate: `${normalized.year}-${String(normalized.month).padStart(2, "0")}-${String(normalized.day).padStart(2, "0")}`,
      birthTime: `${String(normalized.hour).padStart(2, "0")}:${String(normalized.minute).padStart(2, "0")}`,
      isLunar: normalized.isLunar,
      gender: normalized.gender,
      zihourPolicy: normalized.zihourPolicy,
      factsJson: JSON.stringify(facts),
    },
    update: {
      factsJson: JSON.stringify(facts),
      status: "active",
      deletedAt: null,
    },
  });

  return { facts, birthKey, fromCache: false };
}
