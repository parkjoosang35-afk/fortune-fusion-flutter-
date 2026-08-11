// Phase6 - AI운세 실LLM 연동: admin_web 서버(Next.js API Route)에서 LLM Proxy를
// 호출하는 공용 헬퍼.
//
// [배경/조사 결과] 이 샌드박스에서 `OPENAI_API_KEY` 환경변수는 호출마다 랜덤하게
// 바뀌며 실제로는 사용할 수 없는 값(401 Invalid or expired token)이다. 대신
// `GSK_TOKEN`(고정값) + `OPENAI_BASE_URL`(LLM Proxy 주소)을 사용해야 정상 동작한다.
// 모델명도 OpenAI 표준명(gpt-4o-mini 등)이 아니라 Proxy가 허용하는 목록 중 하나를
// 써야 하며, 이번 연동에는 `gpt-5-mini`를 기본값으로 사용한다(비용/속도 균형).
//
// [설계 원칙] 이 헬퍼는 순수하게 "프롬프트 문자열 → 완성된 텍스트" 변환만 담당한다.
// 포인트 차감/환급, fortune_requests/results 기록, 미션 연동 등 비즈니스 로직은
// 호출하는 라우트(예: fortune/saju/route.ts) 쪽에서 그대로 처리한다(관심사 분리).
//
// [모델 선정 근거] `gpt-5-mini`/`gpt-5-nano`는 추론형(reasoning) 모델이라
// 같은 요청에도 reasoning_tokens가 수천 개씩 소모되며 60초를 넘겨 타임아웃되는
// 경우가 실측됐다. `claude-haiku-4-5`는 동일 프롬프트에서 5~6초 내로 응답을
// 완료하고 reasoning_tokens=0으로 비용도 낮아, 실시간 사용자 요청(운세 조회)에
// 적합한 기본 모델로 채택했다.
//
// [실패 시 폴백 원칙] LLM 호출이 실패(네트워크 오류/타임아웃/비정상 응답)하면
// 예외를 던진다. 호출부에서 이를 잡아 규칙 기반(rule-based) 텍스트로 대체하거나,
// 사용자에게 실패를 알리고 포인트를 차감하지 않는 방식으로 처리해야 한다.

const LLM_BASE_URL = process.env.OPENAI_BASE_URL ?? "https://www.genspark.ai/api/llm_proxy/v1";
const LLM_TOKEN = process.env.GSK_TOKEN ?? "";
const DEFAULT_MODEL = "claude-haiku-4-5";
const DEFAULT_TIMEOUT_MS = 30_000;

export class LlmClientError extends Error {
  constructor(message: string, readonly statusCode?: number) {
    super(message);
    this.name = "LlmClientError";
  }
}

interface CompleteOptions {
  /** 시스템/역할 프롬프트(ai_prompt_templates.templateBody 등) */
  systemPrompt: string;
  /** 사용자 입력 컨텍스트(생년월일, 질문 등을 정리한 텍스트) */
  userPrompt: string;
  model?: string;
  timeoutMs?: number;
}

/**
 * LLM Proxy(`/chat/completions`)를 호출해 완성된 텍스트를 반환한다.
 * 호출 실패 시 [LlmClientError]를 던진다(호출부가 catch해서 폴백 처리).
 */
export async function completeText({
  systemPrompt,
  userPrompt,
  model = DEFAULT_MODEL,
  timeoutMs = DEFAULT_TIMEOUT_MS,
}: CompleteOptions): Promise<string> {
  if (!LLM_TOKEN) {
    throw new LlmClientError("GSK_TOKEN 환경변수가 설정되어 있지 않습니다.");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LLM_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
      }),
      signal: controller.signal,
    });

    const raw = await response.text();
    if (!response.ok) {
      throw new LlmClientError(`LLM 호출 실패(HTTP ${response.status}): ${raw.slice(0, 300)}`, response.status);
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      throw new LlmClientError("LLM 응답을 JSON으로 해석할 수 없습니다.");
    }

    const content = (parsed as { choices?: { message?: { content?: string } }[] })
      ?.choices?.[0]?.message?.content;
    if (!content || typeof content !== "string" || content.trim().length === 0) {
      throw new LlmClientError("LLM 응답에 유효한 content가 없습니다.");
    }

    return content.trim();
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
// completeText()와 달리 멀티모달 메시지(content 배열: text + image_url)를 사용한다.
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
}

export async function completeVisionJson<T = Record<string, unknown>>({
  systemPrompt,
  userPrompt,
  imageDataUrl,
  model = DEFAULT_MODEL,
  timeoutMs = DEFAULT_TIMEOUT_MS,
}: VisionJsonOptions): Promise<T> {
  if (!LLM_TOKEN) {
    throw new LlmClientError("GSK_TOKEN 환경변수가 설정되어 있지 않습니다.");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(`${LLM_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${LLM_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: "system", content: systemPrompt },
          {
            role: "user",
            content: [
              { type: "text", text: userPrompt },
              { type: "image_url", image_url: { url: imageDataUrl } },
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

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      throw new LlmClientError("LLM 응답을 JSON으로 해석할 수 없습니다.");
    }

    const content = (parsed as { choices?: { message?: { content?: string } }[] })
      ?.choices?.[0]?.message?.content;
    if (!content || typeof content !== "string" || content.trim().length === 0) {
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
