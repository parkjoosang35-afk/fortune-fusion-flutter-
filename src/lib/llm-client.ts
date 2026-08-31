// Phase6 - AI운세 실LLM 연동: admin_web 서버(Next.js API Route)에서 LLM을
// 호출하는 공용 헬퍼.
//
// [Phase C, 전환 완료] 이전에는 젠스파크 샌드박스 전용 LLM Proxy(GSK_TOKEN +
// OPENAI_BASE_URL)를 사용했으나, 이는 샌드박스 세션에 종속된 임시 토큰이라
// 가비아 운영 서버(sintong.kr)에서는 영구적으로 사용할 수 없었다. 대신
// Anthropic 공식 API(https://api.anthropic.com)를 정식 구독하여 ANTHROPIC_API_KEY로
// 직접 호출하도록 전환한다. 이제 샌드박스 종료 여부와 무관하게 항상 동작한다.
//
// [API 스펙 차이 주의] Anthropic Messages API는 OpenAI 호환 형식과 다르다:
//   - 엔드포인트: /v1/messages (OpenAI의 /chat/completions 아님)
//   - 인증: x-api-key 헤더 + anthropic-version 헤더 (OpenAI의 Authorization: Bearer 아님)
//   - system 프롬프트: 최상위 `system` 필드로 분리 전달 (messages 배열 안에 넣지 않음)
//   - max_tokens: 필수 파라미터 (없으면 400 에러)
//   - 응답 구조: content[0].text 배열 (OpenAI의 choices[0].message.content 아님)
//   - 이미지 입력: content 배열 안에 { type: "image", source: { type: "base64",
//     media_type, data } } 형태 (OpenAI의 image_url 형태 아님)
//
// [설계 원칙] 이 헬퍼는 순수하게 "프롬프트 문자열 → 완성된 텍스트" 변환만 담당한다.
// 포인트 차감/환급, fortune_requests/results 기록, 미션 연동 등 비즈니스 로직은
// 호출하는 라우트(예: fortune/saju/route.ts) 쪽에서 그대로 처리한다(관심사 분리).
//
// [모델 선정 근거] `claude-haiku-4-5`는 저지연/저비용 모델로, 실시간 사용자 요청
// (운세 조회)에 적합하다. Anthropic 공식 모델명은 `claude-haiku-4-5`로 호출하면
// 서버가 최신 스냅샷(예: claude-haiku-4-5-20251001)으로 자동 매핑해준다.
//
// [실패 시 폴백 원칙] LLM 호출이 실패(네트워크 오류/타임아웃/비정상 응답)하면
// 예외를 던진다. 호출부에서 이를 잡아 규칙 기반(rule-based) 텍스트로 대체하거나,
// 사용자에게 실패를 알리고 포인트를 차감하지 않는 방식으로 처리해야 한다.

const ANTHROPIC_BASE_URL = "https://api.anthropic.com/v1";
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY ?? "";
const ANTHROPIC_VERSION = "2023-06-01";
const DEFAULT_MODEL = "claude-haiku-4-5";
const DEFAULT_MAX_TOKENS = 2000;
const DEFAULT_TIMEOUT_MS = 30_000;

export class LlmClientError extends Error {
  constructor(message: string, readonly statusCode?: number) {
    super(message);
    this.name = "LlmClientError";
  }
}

interface AnthropicContentBlock {
  type?: string;
  text?: string;
}

interface AnthropicMessageResponse {
  content?: AnthropicContentBlock[];
  error?: { type?: string; message?: string };
}

function extractTextFromAnthropicResponse(parsed: AnthropicMessageResponse): string | null {
  const blocks = parsed?.content;
  if (!Array.isArray(blocks)) return null;
  const textBlock = blocks.find((b) => b?.type === "text" && typeof b.text === "string");
  const text = textBlock?.text;
  if (!text || text.trim().length === 0) return null;
  return text.trim();
}

interface CompleteOptions {
  /** 시스템/역할 프롬프트(ai_prompt_templates.templateBody 등) */
  systemPrompt: string;
  /** 사용자 입력 컨텍스트(생년월일, 질문 등을 정리한 텍스트) */
  userPrompt: string;
  model?: string;
  timeoutMs?: number;
  maxTokens?: number;
}

/**
 * Anthropic Messages API(`/v1/messages`)를 호출해 완성된 텍스트를 반환한다.
 * 호출 실패 시 [LlmClientError]를 던진다(호출부가 catch해서 폴백 처리).
 */
export async function completeText({
  systemPrompt,
  userPrompt,
  model = DEFAULT_MODEL,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  maxTokens = DEFAULT_MAX_TOKENS,
}: CompleteOptions): Promise<string> {
  if (!ANTHROPIC_API_KEY) {
    throw new LlmClientError("ANTHROPIC_API_KEY 환경변수가 설정되어 있지 않습니다.");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(`${ANTHROPIC_BASE_URL}/messages`, {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        system: systemPrompt,
        messages: [{ role: "user", content: userPrompt }],
      }),
      signal: controller.signal,
    });

    const raw = await response.text();
    if (!response.ok) {
      throw new LlmClientError(`LLM 호출 실패(HTTP ${response.status}): ${raw.slice(0, 300)}`, response.status);
    }

    let parsed: AnthropicMessageResponse;
    try {
      parsed = JSON.parse(raw);
    } catch {
      throw new LlmClientError("LLM 응답을 JSON으로 해석할 수 없습니다.");
    }

    const content = extractTextFromAnthropicResponse(parsed);
    if (!content) {
      throw new LlmClientError("LLM 응답에 유효한 content가 없습니다.");
    }

    return content;
  } catch (e) {
    if (e instanceof LlmClientError) throw e;
    if (e instanceof Error && e.name === "AbortError") {
      throw new LlmClientError(`LLM 호출이 ${timeoutMs}ms 내에 완료되지 않았습니다(타임아웃).`);
    }
    throw new LlmClientError(`LLM 호출 중 알 수 없는 오류: ${e instanceof Error ? e.message : String(e)}`);
  } finally {
    clearTimeout(timer);
  }
}

// [관상/손금 실사진 분석 연동] 이미지(data URL, base64)를 함께 전송해 Vision 모델이
// 실제 업로드된 사진을 분석하고, 그 결과를 JSON 객체로만 응답하도록 요청하는 헬퍼.
// Anthropic Messages API의 이미지 입력 형식(content 배열: image + text 블록)을 사용한다.
// 모델 응답에 마크다운 코드펜스 등이 섞여 있어도 첫 번째 `{...}` 블록만 추출해 파싱한다.
interface VisionJsonOptions {
  /** 시스템/역할 프롬프트(검증 기준 + JSON 스키마 지시) */
  systemPrompt: string;
  /** 사용자 안내 문구(대부분 "이 사진을 분석해주세요." 정도의 짧은 텍스트) */
  userPrompt: string;
  /** data:image/jpeg;base64,... 형태의 이미지 데이터 URL */
  imageDataUrl: string;
  model?: string;
  timeoutMs?: number;
  maxTokens?: number;
}

/** `data:image/jpeg;base64,AAAA...` 형태의 문자열을 media_type/data로 분리한다. */
function parseDataUrl(dataUrl: string): { mediaType: string; data: string } {
  const match = dataUrl.match(/^data:([^;]+);base64,([\s\S]+)$/);
  if (!match) {
    throw new LlmClientError("이미지 데이터 URL 형식이 올바르지 않습니다(data:<mime>;base64,... 형태여야 함).");
  }
  return { mediaType: match[1], data: match[2] };
}

export async function completeVisionJson<T = Record<string, unknown>>({
  systemPrompt,
  userPrompt,
  imageDataUrl,
  model = DEFAULT_MODEL,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  maxTokens = DEFAULT_MAX_TOKENS,
}: VisionJsonOptions): Promise<T> {
  if (!ANTHROPIC_API_KEY) {
    throw new LlmClientError("ANTHROPIC_API_KEY 환경변수가 설정되어 있지 않습니다.");
  }

  const { mediaType, data } = parseDataUrl(imageDataUrl);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(`${ANTHROPIC_BASE_URL}/messages`, {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        system: systemPrompt,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: mediaType,
                  data,
                },
              },
              { type: "text", text: userPrompt },
            ],
          },
        ],
      }),
      signal: controller.signal,
    });

    const raw = await response.text();
    if (!response.ok) {
      throw new LlmClientError(
        `LLM 비전 호출 실패(HTTP ${response.status}): ${raw.slice(0, 300)}`,
        response.status
      );
    }

    let parsed: AnthropicMessageResponse;
    try {
      parsed = JSON.parse(raw);
    } catch {
      throw new LlmClientError("LLM 응답을 JSON으로 해석할 수 없습니다.");
    }

    const content = extractTextFromAnthropicResponse(parsed);
    if (!content) {
      throw new LlmClientError("LLM 응답에 유효한 content가 없습니다.");
    }

    // 모델이 코드펜스(```json ... ```)나 설명 문구를 덧붙이는 경우를 대비해
    // 첫 번째 `{...}` JSON 객체 블록만 추출한다.
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new LlmClientError(
        `LLM 응답에서 JSON 객체를 찾을 수 없습니다: ${content.slice(0, 200)}`
      );
    }

    try {
      return JSON.parse(jsonMatch[0]) as T;
    } catch (e) {
      throw new LlmClientError(
        `LLM이 반환한 JSON 파싱 실패: ${e instanceof Error ? e.message : String(e)}`
      );
    }
  } catch (e) {
    if (e instanceof LlmClientError) throw e;
    if (e instanceof Error && e.name === "AbortError") {
      throw new LlmClientError(`LLM 비전 호출이 ${timeoutMs}ms 내에 완료되지 않았습니다(타임아웃).`);
    }
    throw new LlmClientError(`LLM 비전 호출 중 알 수 없는 오류: ${e instanceof Error ? e.message : String(e)}`);
  } finally {
    clearTimeout(timer);
  }
}
