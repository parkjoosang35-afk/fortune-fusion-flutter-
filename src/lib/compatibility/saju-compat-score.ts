// [궁합 사주 팩터 개선 — 조건부 구현 승인 범위] 기존 Python saju_engine의 실제
// 궁합 계산 모듈(`modules/compatibility.py`, `/compatibility` 엔드포인트)을
// 호출해 "saju" 팩터 점수를 산출한다.
//
// [절대 원칙 재확인]
// - saju_engine 내부(saju_calculator.py, modules/compatibility.py 등)는 전혀
//   수정하지 않는다 — 이 파일은 기존 공개 엔드포인트의 소비자 코드일 뿐이다.
// - 엔진 호출이 실패/비정상이면 기존 해시 기반 점수로 폴백하되, 반드시
//   `scoreEngineVersion`으로 출처를 구분해 반환한다(호출부가 그대로 영속화).
// - 생년월일 등 개인정보는 로그에 남기지 않는다(에러 종류/상태코드만 기록).
//
// [saju-engine-client.ts와의 관계] 기존 `saju-engine-client.ts`는 `/saju/v3/facts`
// 전용이며 BirthInputV3(zihour_policy 포함) 스키마를 쓴다. `/compatibility`
// 엔드포인트는 saju_api.py상 `BirthInput`(zihour_policy 파라미터 없음, 엔진
// 기본값 "traditional" 그대로 적용)을 받으므로 별도의 경량 클라이언트를 둔다
// (기존 파일을 억지로 재사용하면 없는 필드를 끼워 맞추게 되어 오히려 계약을
// 왜곡한다 — 기존 파일 수정은 승인 범위 밖이기도 하다).

/** 출처 구분 값 — route.ts가 `detail.scoreEngineVersion`에 그대로 저장한다.
 * [운영 전 보완 — 오류코드 세분화] 기존 "hash-fallback-network" 하나로 묶여
 * 있던 "연결 실패"와 "타임아웃"을 errorCode 레벨에서 분리한다. 기존에는
 * message 자유텍스트로만 구분 가능해 ErrorLog 집계 쿼리(`GROUP BY errorCode`)
 * 에서 둘을 나눌 수 없었다 — 운영에서 "타임아웃이 반복되는가"와 "연결 자체가
 * 안 되는가"는 조치(타임아웃 값 조정 vs 네트워크/방화벽 점검)가 다르므로
 * 분리가 필요하다는 지적을 반영했다. */
export type ScoreEngineVersion =
  | "saju-v1" // 엔진 정상 응답
  | "hash-fallback-timeout" // 타임아웃(AbortError) — 엔진이 timeoutMs 내에 응답하지 않음
  | "hash-fallback-network" // 그 외 연결 실패/5xx 등 네트워크·서버 오류(타임아웃 제외)
  | "hash-fallback-unsupported-input" // 엔진 422(입력 스키마 거부, 예: 윤달)
  | "hash-fallback-invalid-response"; // 엔진이 200이지만 비정상 값(범위 밖/누락)

export interface SajuCompatInput {
  /** YYYY-MM-DD */
  birthDateA: string;
  /** YYYY-MM-DD */
  birthDateB: string;
}

export interface SajuCompatScoreResult {
  /** 0~100. 엔진 정상이면 final_score, 폴백이면 해시 기반 값. */
  score: number;
  engineVersion: ScoreEngineVersion;
}

export interface SajuCompatClientOptions {
  baseUrl?: string;
  timeoutMs?: number;
  /** 이번 요청에 한해 해시 폴백 계산기를 주입(테스트 전용). 생략 시 기본 구현 사용. */
  hashFallback?: (input: SajuCompatInput) => number;
}

const DEFAULT_BASE_URL = process.env.SAJU_ENGINE_BASE_URL ?? "http://127.0.0.1:8000";
// docs/11_API_계약서.md 기준 facts(15s)보다 짧게 — 궁합은 LLM 호출(최대 60s)과
// 별개로 "엔진 사칙 계산"이므로 느릴 이유가 없다. 과도하게 길게 잡아 전체
// 궁합 요청(현재도 LLM 때문에 수 초~수십 초)을 더 지연시키지 않는다.
const DEFAULT_TIMEOUT_MS = 8_000;
const DEFAULT_FREE_PASS_TOKEN =
  process.env.SAJU_ENGINE_FREE_PASS_TOKEN ?? "STB-internal-server-call-00000000000000";

/** saju_api.py BirthInput 1:1 대응(스키마 변경 없음, 이 파일에서 신규 필드 추가 안 함). */
interface EngineBirthInput {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  gender: "male" | "female";
  is_lunar: boolean;
}

/** `/compatibility` 응답 중 이 모듈이 실제로 쓰는 부분만 타입화(전체 재사용 안 함). */
interface EngineCompatResponse {
  final_score?: unknown;
}

function parseBirthDate(value: string): { year: number; month: number; day: number } | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!m) return null;
  return { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
}

/**
 * [1.2절 설계 그대로] 출생시간 미입력 — 정오(12:00) 고정.
 * 성별 미수집 — "male" 고정(1.2.1 근거: gender는 day_master/day_zhi에 영향
 * 없음, 대운 방향에만 영향하며 궁합 모듈은 대운을 쓰지 않음).
 * 음력 미수집 — is_lunar:false 고정(궁합 입력 UI가 애초에 양력만 받음, 코드
 * 확인 완료: BirthdayPickerValue에 isLunar 필드 없음).
 * 자시 정책 — 이번 작업에서 통일/변경하지 않음(엔진이 BirthInput 레벨에서
 * zihour_policy를 받지 않으므로 애초에 선택지가 없고, 엔진 내부 기본값
 * "traditional"이 그대로 적용된다 — 이 동작을 바꾸지 않는다).
 */
function toEngineInput(year: number, month: number, day: number): EngineBirthInput {
  return { year, month, day, hour: 12, minute: 0, gender: "male", is_lunar: false };
}

/** 기존 route.ts의 해시 로직과 완전히 동일한 saju 팩터 계산(회귀 방지 — U5).
 * [원본 유지] `(seed * 7) % 45 + 50` — route.ts 수정 시 이 식과 입력(seed)이
 * 동일하게 유지되는지 단위테스트(U2~U4)로 고정한다. */
function defaultHashFallback(input: SajuCompatInput, type: string): number {
  const seed = hashSeed(`${input.birthDateA}:${input.birthDateB}:${type}`);
  return 50 + ((seed * 7) % 45);
}

/** route.ts의 `hashSeed()`와 바이트 단위로 동일한 구현(복붙 — 별도 공유 모듈로
 * 추출하면 route.ts도 함께 수정해야 하므로, 승인 범위(해당 파일 내 saju 팩터
 * 계산 경로)를 벗어나지 않기 위해 이 파일 안에 동일 로직을 둔다). */
function hashSeed(input: string): number {
  let h = 0;
  for (let i = 0; i < input.length; i++) h = (h * 31 + input.charCodeAt(i)) & 0xffffffff;
  return Math.abs(h);
}

/** 엔진 호출 실패/비정상 사유를 PII 없이 로그로 남긴다(집계 가능한 지표 —
 * 2-6 "폴백이 반복적으로 발생할 때 원인을 파악할 수 있어야 한다"). 생년월일/
 * 이름 등은 절대 포함하지 않고, 실패 분류·상태코드·지연시간만 남긴다. */
function logFallback(reason: ScoreEngineVersion, detail: { status?: number; latencyMs?: number; message?: string }) {
  // ErrorLog(append-only, source/errorCode/severity로 집계 가능) 적재는 이
  // 함수를 호출하는 route.ts 쪽 트랜잭션 밖에서 best-effort로 수행한다 —
  // 로그 적재 실패가 궁합 응답 자체를 실패시키면 안 되므로 호출부에서 await
  // 하지 않고 fire-and-forget 하거나, 간단히 console만 쓰는 것으로 범위를
  // 좁힌다(ErrorLog 테이블 적재는 prisma 트랜잭션/스키마 변경 승인 범위가
  // 불명확하므로 이번 구현에서는 console 로그 + 호출부의 인메모리 카운터로
  // 한정한다 — 6장 "별도 승인 사항" 참고).
  console.warn(
    `[compatibility] saju 엔진 폴백 발생 — reason=${reason}` +
      (detail.status != null ? ` status=${detail.status}` : "") +
      (detail.latencyMs != null ? ` latencyMs=${detail.latencyMs}` : "") +
      (detail.message ? ` message=${detail.message.slice(0, 200)}` : "")
  );
}

/**
 * [메인 진입점] saju_engine `/compatibility`를 호출해 실제 사주 기반 점수를
 * 구하되, 실패 시 기존 해시 로직으로 폴백한다. 반환값의 `engineVersion`으로
 * 호출부(route.ts)가 `detail.scoreEngineVersion`에 그대로 저장한다.
 */
export async function getSajuCompatibilityScore(
  input: SajuCompatInput,
  type: string,
  options: SajuCompatClientOptions = {}
): Promise<SajuCompatScoreResult> {
  const hashFallback = options.hashFallback ?? ((i: SajuCompatInput) => defaultHashFallback(i, type));

  const a = parseBirthDate(input.birthDateA);
  const b = parseBirthDate(input.birthDateB);
  if (!a || !b) {
    // 상위(route.ts)에서 이미 validDate()로 걸러지므로 정상 경로에서는
    // 도달하지 않는다 — 방어적으로만 폴백 처리.
    logFallback("hash-fallback-invalid-response", { message: "생년월일 파싱 실패" });
    return { score: hashFallback(input), engineVersion: "hash-fallback-invalid-response" };
  }

  const baseUrl = options.baseUrl ?? DEFAULT_BASE_URL;
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const controller = new AbortController();
  const startedAt = Date.now();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(`${baseUrl}/compatibility`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Free-Pass": DEFAULT_FREE_PASS_TOKEN },
      body: JSON.stringify({
        person_a: toEngineInput(a.year, a.month, a.day),
        person_b: toEngineInput(b.year, b.month, b.day),
      }),
      signal: controller.signal,
    });
    const latencyMs = Date.now() - startedAt;

    if (res.status === 422) {
      logFallback("hash-fallback-unsupported-input", { status: 422, latencyMs });
      return { score: hashFallback(input), engineVersion: "hash-fallback-unsupported-input" };
    }
    if (!res.ok) {
      logFallback("hash-fallback-network", { status: res.status, latencyMs });
      return { score: hashFallback(input), engineVersion: "hash-fallback-network" };
    }

    const body = (await res.json()) as EngineCompatResponse;
    const score = body.final_score;
    if (typeof score !== "number" || !Number.isFinite(score) || score < 0 || score > 100) {
      logFallback("hash-fallback-invalid-response", {
        status: res.status,
        latencyMs,
        message: `final_score=${JSON.stringify(score)}`,
      });
      return { score: hashFallback(input), engineVersion: "hash-fallback-invalid-response" };
    }

    return { score: Math.round(score), engineVersion: "saju-v1" };
  } catch (e) {
    const latencyMs = Date.now() - startedAt;
    const isTimeout = e instanceof Error && e.name === "AbortError";
    const engineVersion: ScoreEngineVersion = isTimeout ? "hash-fallback-timeout" : "hash-fallback-network";
    logFallback(engineVersion, {
      latencyMs,
      message: isTimeout ? `타임아웃(${timeoutMs}ms 초과)` : e instanceof Error ? e.message : String(e),
    });
    return { score: hashFallback(input), engineVersion };
  } finally {
    clearTimeout(timer);
  }
}

// 테스트 전용 export(U1~U5에서 내부 식 회귀 검증에 사용).
export const __testables = { hashSeed, defaultHashFallback, parseBirthDate, toEngineInput };
