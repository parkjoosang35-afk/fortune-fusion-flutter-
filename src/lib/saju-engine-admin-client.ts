// [2026-11-12 사주엔진관리 신규] admin_web에서 saju_engine_deploy(별도 저장소,
// FastAPI/uvicorn, 운영서버 systemd "saju-engine.service"로 상시 구동)를 "조회 +
// 제한적 테스트"하기 위한 전용 클라이언트.
//
// [원칙 — OPERATIONS_POLICY §10 "운영 서버에는 어떠한 개발·검증 목적 요청도
// 보내지 않는다"] 이 파일의 testFacts()/testCategories69() 등 "실제 호출" 함수는
// 절대 운영 도메인(sintong.kr)이나 운영 엔진(systemd saju-engine.service, 포트
// 8000)을 가리키지 않는다. 관리자가 직접 baseUrl을 입력하게 하되 기본값은
// 샌드박스 로컬(127.0.0.1:8977 또는 .env SAJU_ENGINE_ADMIN_TEST_URL)만 사용한다.
// 운영 엔진 상태는 saju-engine-client.ts(src/lib/saju-renewal/)와 동일하게
// "환경변수 설정 여부"만 간접 표시하고 실제 네트워크 호출은 하지 않는다
// (src/app/(admin)/ops/page.tsx 17~18행과 동일한 설계 원칙 재사용).
//
// [엔진 코드 무수정 원칙] 이 파일은 saju_engine을 HTTP로 호출하는 소비자 코드일
// 뿐이며, saju_calculator.py/saju_facts.py/category69.py 등 엔진 내부는 전혀
// 건드리지 않는다.

import fs from "fs";
import path from "path";

/** 관리자 "라이브 테스트" 전용 기본 URL — 반드시 로컬/샌드박스만 가리킨다.
 * 운영 엔진 URL(SAJU_ENGINE_BASE_URL, 보통 운영에선 비공개 127.0.0.1:8000이지만
 * 혹시라도 외부 도메인으로 잘못 설정된 경우를 대비해 이 상수는 그 값을 절대
 * 참조하지 않고 완전히 분리된 값만 쓴다). */
export const SAJU_ENGINE_ADMIN_TEST_DEFAULT_URL =
  process.env.SAJU_ENGINE_ADMIN_TEST_URL ?? "http://127.0.0.1:8977";

const DEFAULT_TIMEOUT_MS = 10_000;

export class SajuEngineAdminError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number
  ) {
    super(message);
    this.name = "SajuEngineAdminError";
  }
}

function freePassTokenForAdminTest(): string {
  // [보안] 운영 프리패스 토큰(SAJU_ENGINE_FREE_PASS_TOKEN)을 그대로 재사용한다 —
  // 별도 관리자 전용 토큰을 새로 발급하지 않고 기존 saju-engine-client.ts와
  // 동일한 소스를 재사용(이중 관리 방지). 미설정 시 데모 규칙(STB- 접두사+32자)만
  // 만족하는 샌드박스 전용 값으로 폴백 — 로컬 테스트가 막히지 않게 한다.
  return process.env.SAJU_ENGINE_FREE_PASS_TOKEN ?? "STB-admin-ops-test-token-00000000000000";
}

async function fetchJson<T>(
  url: string,
  options: { method?: string; body?: unknown; timeoutMs?: number; gated?: boolean } = {}
): Promise<{ ok: true; data: T; latencyMs: number } | { ok: false; error: string; statusCode?: number }> {
  const controller = new AbortController();
  const timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const started = Date.now();
  try {
    const res = await fetch(url, {
      method: options.method ?? "GET",
      headers: {
        "Content-Type": "application/json",
        ...(options.gated ? { "X-Free-Pass": freePassTokenForAdminTest() } : {}),
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
      signal: controller.signal,
    });
    const latencyMs = Date.now() - started;
    const text = await res.text();
    let data: unknown = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = text;
    }
    if (!res.ok) {
      return {
        ok: false,
        error: typeof data === "object" && data && "detail" in (data as Record<string, unknown>)
          ? String((data as Record<string, unknown>).detail)
          : text.slice(0, 300),
        statusCode: res.status,
      };
    }
    return { ok: true, data: data as T, latencyMs };
  } catch (e) {
    if (e instanceof Error && e.name === "AbortError") {
      return { ok: false, error: `응답 타임아웃(${timeoutMs}ms 초과)` };
    }
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  } finally {
    clearTimeout(timer);
  }
}

export interface EngineHealthResult {
  reachable: boolean;
  status?: string;
  latencyMs?: number;
  error?: string;
}

/** GET /health — 가장 가벼운 생존 확인. */
export async function checkEngineHealth(baseUrl: string): Promise<EngineHealthResult> {
  const result = await fetchJson<{ status: string }>(`${baseUrl}/health`, { timeoutMs: 5000 });
  if (!result.ok) return { reachable: false, error: result.error };
  return { reachable: true, status: result.data.status, latencyMs: result.latencyMs };
}

export interface EngineRootInfo {
  service?: string;
  version?: string;
  policy?: Record<string, unknown>;
  public_endpoints?: string[];
  gated_endpoints?: string[];
}

/** GET / — 서비스명/버전/정책/엔드포인트 목록. */
export async function getEngineRootInfo(
  baseUrl: string
): Promise<{ ok: true; data: EngineRootInfo } | { ok: false; error: string }> {
  const result = await fetchJson<EngineRootInfo>(`${baseUrl}/`, { timeoutMs: 5000 });
  if (!result.ok) return { ok: false, error: result.error };
  return { ok: true, data: result.data };
}

export interface CategoryItem {
  code: string;
  name: string;
}

/** GET /saju/v3/categories — 정통사주 69종 전체 목록(공개 엔드포인트, 프리패스 불필요). */
export async function getCategories69(
  baseUrl: string
): Promise<{ ok: true; data: CategoryItem[] } | { ok: false; error: string }> {
  const result = await fetchJson<CategoryItem[]>(`${baseUrl}/saju/v3/categories`, { timeoutMs: 8000 });
  if (!result.ok) return { ok: false, error: result.error };
  return { ok: true, data: result.data };
}

export interface SajuTestBirthInput {
  year: number;
  month: number;
  day: number;
  hour?: number;
  minute?: number;
  gender?: "M" | "F";
  is_lunar?: boolean;
  is_leap_month?: boolean;
  zihour_policy?: "traditional" | "legacy";
}

/** POST /saju/v3/facts — 관리자가 직접 생년월일시를 넣어 엔진 실계산 결과를
 * 눈으로 확인하는 "라이브 테스트" 기능. 반드시 baseUrl이 샌드박스/로컬일 때만
 * 호출하도록 호출부(Server Action)에서 강제한다(운영 도메인 호출 차단은
 * 액션 레벨에서 재확인 — 방어적 이중 체크). */
export async function testEngineFacts(
  baseUrl: string,
  input: SajuTestBirthInput
): Promise<{ ok: true; data: unknown; latencyMs: number } | { ok: false; error: string; statusCode?: number }> {
  const result = await fetchJson(`${baseUrl}/saju/v3/facts`, {
    method: "POST",
    gated: true,
    timeoutMs: 15000,
    body: {
      year: input.year,
      month: input.month,
      day: input.day,
      hour: input.hour ?? 12,
      minute: input.minute ?? 0,
      gender: input.gender === "F" ? "female" : "male",
      is_lunar: input.is_lunar ?? false,
      is_leap_month: input.is_leap_month ?? false,
      zihour_policy: input.zihour_policy ?? "traditional",
    },
  });
  if (!result.ok) return result;
  return { ok: true, data: result.data, latencyMs: result.latencyMs };
}

/** POST /saju/v3/categories69 — 69종 전체 실계산(data+basis 구조) 1회 호출. */
export async function testEngineCategories69Full(
  baseUrl: string,
  input: SajuTestBirthInput
): Promise<{ ok: true; data: unknown; latencyMs: number } | { ok: false; error: string; statusCode?: number }> {
  const result = await fetchJson(`${baseUrl}/saju/v3/categories69`, {
    method: "POST",
    gated: true,
    timeoutMs: 20000,
    body: {
      year: input.year,
      month: input.month,
      day: input.day,
      hour: input.hour ?? 12,
      minute: input.minute ?? 0,
      gender: input.gender === "F" ? "female" : "male",
      is_lunar: input.is_lunar ?? false,
      is_leap_month: input.is_leap_month ?? false,
      zihour_policy: input.zihour_policy ?? "traditional",
    },
  });
  if (!result.ok) return result;
  return { ok: true, data: result.data, latencyMs: result.latencyMs };
}

// ════════════════════════════════════════════════════════════════
// 로컬 파일시스템 기반 "버전/구성/문서" 조회 — 엔진 서버를 호출하지 않고
// saju_engine_deploy 저장소(샌드박스에 함께 체크아웃된 참조 저장소)의
// 정적 파일을 읽어 표시한다. 엔진 코드를 전혀 수정하지 않는 순수 조회.
// ════════════════════════════════════════════════════════════════

const ENGINE_REPO_ROOT = "/home/user/saju_engine_deploy/saju_engine_v3.3_최종납품";
const ENGINE_SRC_ROOT = path.join(ENGINE_REPO_ROOT, "saju_engine");

export interface EngineRepoInfo {
  versionText: string | null;
  readmeExcerpt: string | null;
  ruleFiles: { name: string; sizeBytes: number }[];
  moduleFiles: { name: string; sizeBytes: number }[];
  testSuiteDirs: string[];
}

/** 파일시스템에서 직접 읽는 정적 정보 — 네트워크 호출 없음, 엔진 무수정 원칙과
 * 완전히 독립적(읽기 전용 조회이므로 실행 중인 엔진이 꺼져 있어도 동작한다). */
export function getEngineRepoInfo(): EngineRepoInfo {
  const safeReadDir = (dir: string): { name: string; sizeBytes: number }[] => {
    try {
      return fs
        .readdirSync(dir)
        .filter((f) => !f.startsWith("__") && !f.startsWith("."))
        .map((f) => {
          try {
            const stat = fs.statSync(path.join(dir, f));
            return { name: f, sizeBytes: stat.isFile() ? stat.size : 0 };
          } catch {
            return { name: f, sizeBytes: 0 };
          }
        });
    } catch {
      return [];
    }
  };

  let versionText: string | null = null;
  try {
    versionText = fs.readFileSync(path.join(ENGINE_REPO_ROOT, "VERSION_3.3.txt"), "utf-8");
  } catch {
    versionText = null;
  }

  let readmeExcerpt: string | null = null;
  try {
    const full = fs.readFileSync(path.join(ENGINE_SRC_ROOT, "README.md"), "utf-8");
    readmeExcerpt = full.slice(0, 2000);
  } catch {
    readmeExcerpt = null;
  }

  const ruleFiles = safeReadDir(path.join(ENGINE_SRC_ROOT, "rules")).filter((f) => f.name.endsWith(".json"));
  const moduleFiles = safeReadDir(path.join(ENGINE_SRC_ROOT, "modules")).filter((f) => f.name.endsWith(".py"));
  const testSuiteDirs = safeReadDir(path.join(ENGINE_SRC_ROOT, "tests"))
    .filter((f) => f.name.startsWith("test_"))
    .map((f) => f.name);

  return { versionText, readmeExcerpt, ruleFiles, moduleFiles, testSuiteDirs };
}

/** 운영 엔진(systemd saju-engine.service) "설정 여부"만 간접 판정 — 실제
 * 네트워크 호출은 절대 하지 않는다(ops/page.tsx와 동일한 안전 원칙). */
export function hasProductionEngineConfig(): boolean {
  return !!process.env.SAJU_ENGINE_BASE_URL;
}

export function getConfiguredProductionBaseUrl(): string | null {
  return process.env.SAJU_ENGINE_BASE_URL ?? null;
}
