// ══════════════════════════════════════════════════════════════════
// BokjuCouponAiBackgroundClient — [신통방통 AI 쿠폰 디자인 표시·숨김 기능 §4]
// 관리자가 텍스트로 요청한 쿠폰 "배경 이미지"를 AI 이미지 생성 API로 만든다.
//
// [설계 원칙 — llm-client.ts와 동일한 교훈 반영]
//   이 프로젝트의 운영 서버(sintong.kr)는 젠스파크 샌드박스 밖(가비아 등)에
//   영구 배포되므로, 샌드박스 전용 프록시 토큰(OPENAI_API_KEY=gsk-...,
//   OPENAI_BASE_URL=.../llm_proxy/v1)은 세션 종료와 함께 무효화된다 —
//   llm-client.ts가 겪었던 것과 똑같은 함정이다. 따라서 이 클라이언트는
//   운영 환경에서 실제로 영구 동작해야 하는 "정식 경로"로 OpenAI 공식
//   Images API(https://api.openai.com/v1/images/generations)를 호출하고,
//   전용 환경변수(BOKJU_AI_IMAGE_API_KEY)가 없으면 "성공한 척" 하지 않고
//   명확한 설정 오류를 던진다(§4 "AI가 요청한 배경을 생성하는가?" 검수
//   항목을 거짓으로 통과시키지 않기 위함 — 카카오 공유 기능 때와 동일한
//   "정직한 실패" 원칙).
//
// [AI가 글자/QR을 직접 그리지 않도록 — §4 핵심 요구]
//   buildSafePrompt()가 사용자 프롬프트 뒤에 항상 "글자·숫자·QR코드·바코드가
//   전혀 없는 순수 배경 질감/패턴"을 강제하는 고정 지시문을 덧붙인다.
//   실제 텍스트/QR/번호는 전부 렌더링 단계(bokju-coupon-image-service.ts)에서
//   서버가 SVG로 합성하므로, AI 배경에 글자가 섞이면 겹침·오타·보안 문제가
//   생길 수 있어 반드시 분리한다.
// ══════════════════════════════════════════════════════════════════
import { mkdir, writeFile } from "fs/promises";
import path from "path";
import sharp from "sharp";

const PUBLIC_DIR = path.join(process.cwd(), "public");
const DESIGN_ASSETS_DIR = path.join(PUBLIC_DIR, "uploads", "bokju-coupons", "design-assets");

// 모바일 쿠폰 이미지와 동일한 캔버스 크기(bokju-coupon-image-service.ts의
// IMG_WIDTH/IMG_HEIGHT와 반드시 일치해야 합성 시 크롭/여백이 생기지 않는다).
const BG_WIDTH = 720;
const BG_HEIGHT = 1280;

export class AiBackgroundError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

/** [§4 "AI가 이미지 안에 쿠폰번호나 QR코드를 직접 그리게 하지 마세요"]
 * 관리자 입력 프롬프트에 "글자 없는 배경"을 강제하는 고정 지시문을 덧붙인다. */
function buildSafePrompt(userPrompt: string): string {
  return (
    `${userPrompt.trim()}. ` +
    "Pure background texture/pattern only, portrait mobile coupon card background, " +
    "720x1280 vertical aspect ratio. " +
    "IMPORTANT: absolutely no text, no letters, no numbers, no words, no logos, " +
    "no QR codes, no barcodes, no readable symbols anywhere in the image — " +
    "only abstract decorative background suitable for overlaying text and a QR code later. " +
    "High quality, clean, no watermark."
  );
}

function resolveApiConfig(): { apiKey: string; baseUrl: string; model: string } {
  // 운영 전용 변수명(BOKJU_AI_IMAGE_*)을 최우선으로 쓴다 — llm-client.ts가
  // 겪은 "샌드박스 전용 OPENAI_API_KEY와 이름이 겹쳐 잘못된 토큰으로 운영
  // 서버가 호출되는" 사고를 원천 차단하기 위함(의도적으로 OPENAI_API_KEY를
  // 폴백으로도 사용하지 않는다 — 그 변수는 이 프로젝트에서 공식적으로
  // "샌드박스 도구용"이라고 문서화되어 있으므로 운영 기능이 암묵적으로
  // 의존하면 안 된다).
  const apiKey = process.env.BOKJU_AI_IMAGE_API_KEY || "";
  const baseUrl = process.env.BOKJU_AI_IMAGE_BASE_URL || "https://api.openai.com/v1";
  const model = process.env.BOKJU_AI_IMAGE_MODEL || "gpt-image-1";
  return { apiKey, baseUrl, model };
}

export interface GenerateBackgroundResult {
  imagePath: string; // /uploads/bokju-coupons/design-assets/{id}.png
}

/**
 * 관리자가 입력한 프롬프트로 배경 이미지를 생성해 PNG로 저장하고, 공개
 * 정적 경로를 반환한다. 운영 전용 API 키가 설정되지 않은 경우 즉시
 * [AiBackgroundError]("AI_NOT_CONFIGURED")를 던진다 — 성공한 척하지 않는다.
 */
export async function generateCouponBackground(
  assetId: number,
  prompt: string
): Promise<GenerateBackgroundResult> {
  const trimmed = prompt.trim();
  if (!trimmed) {
    throw new AiBackgroundError("INVALID_PROMPT", "배경 요청 문구를 입력해 주세요.");
  }

  const { apiKey, baseUrl, model } = resolveApiConfig();
  if (!apiKey) {
    throw new AiBackgroundError(
      "AI_NOT_CONFIGURED",
      "AI 배경 생성 기능이 아직 설정되지 않았습니다. 서버 환경변수 BOKJU_AI_IMAGE_API_KEY(OpenAI Images API 키)를 설정한 뒤 다시 시도해 주세요."
    );
  }

  const safePrompt = buildSafePrompt(trimmed);

  // [2026-10-16 운영 배포 후 실측] gpt-image-1은 고품질 1024x1536 이미지 생성 시
  // 60초를 초과하는 경우가 흔해(운영 서버 실측 60초 타임아웃 재현), 기존 60초는
  // 너무 짧았다. 120초로 늘리고, nginx proxy_read_timeout도 동일하게 맞춘다
  // (nginx가 먼저 끊으면 이 AbortController가 뭘 하든 504로 끊기므로 반드시
  // 같이 늘려야 함 — /etc/nginx/sites-enabled/sintong.kr 참고).
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 120_000);
  let imageBuffer: Buffer;
  try {
    const response = await fetch(`${baseUrl.replace(/\/$/, "")}/images/generations`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        prompt: safePrompt,
        size: "1024x1536", // gpt-image-1 지원 세로 비율 중 720:1280(9:16)에 가장 가까운 값 — 합성 단계에서 720x1280으로 정확히 리사이즈한다.
        n: 1,
      }),
      signal: controller.signal,
    });

    const raw = await response.text();
    if (!response.ok) {
      throw new AiBackgroundError(
        "AI_CALL_FAILED",
        `AI 배경 생성 호출 실패(HTTP ${response.status}): ${raw.slice(0, 300)}`
      );
    }

    let parsed: { data?: { b64_json?: string; url?: string }[] };
    try {
      parsed = JSON.parse(raw);
    } catch {
      throw new AiBackgroundError("AI_BAD_RESPONSE", "AI 응답을 해석할 수 없습니다.");
    }

    const first = parsed.data?.[0];
    if (!first) {
      throw new AiBackgroundError("AI_BAD_RESPONSE", "AI 응답에 이미지 데이터가 없습니다.");
    }

    if (first.b64_json) {
      imageBuffer = Buffer.from(first.b64_json, "base64");
    } else if (first.url) {
      const imgRes = await fetch(first.url);
      if (!imgRes.ok) throw new AiBackgroundError("AI_BAD_RESPONSE", "AI가 반환한 이미지 URL을 가져오지 못했습니다.");
      imageBuffer = Buffer.from(await imgRes.arrayBuffer());
    } else {
      throw new AiBackgroundError("AI_BAD_RESPONSE", "AI 응답에 b64_json/url 중 어느 것도 없습니다.");
    }
  } catch (e) {
    if (e instanceof AiBackgroundError) throw e;
    if (e instanceof Error && e.name === "AbortError") {
      throw new AiBackgroundError("AI_TIMEOUT", "AI 배경 생성이 120초 내에 완료되지 않았습니다(타임아웃).");
    }
    throw new AiBackgroundError(
      "AI_CALL_FAILED",
      `AI 배경 생성 중 알 수 없는 오류: ${e instanceof Error ? e.message : String(e)}`
    );
  } finally {
    clearTimeout(timer);
  }

  // 쿠폰 이미지 캔버스 크기(720x1280)로 정확히 리사이즈+크롭해 저장 —
  // AI 원본 해상도가 어떻든 합성 단계(renderCustomCouponImage)는 항상
  // 같은 크기를 기대하므로 여기서 미리 정규화한다.
  const normalized = await sharp(imageBuffer)
    .resize(BG_WIDTH, BG_HEIGHT, { fit: "cover", position: "centre" })
    .png()
    .toBuffer();

  await mkdir(DESIGN_ASSETS_DIR, { recursive: true });
  const fileName = `${assetId}.png`;
  await writeFile(path.join(DESIGN_ASSETS_DIR, fileName), normalized);

  return { imagePath: `/uploads/bokju-coupons/design-assets/${fileName}` };
}

export { BG_WIDTH, BG_HEIGHT };
