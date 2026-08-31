// 귀인지도 카톡 공유 OG 카드 — 동적 PNG 생성기.
//
// [결정 매모 D2/D6 — 2026-08-31, 2단계 2-1] `next/og`(내장 @vercel/og,
// satori+resvg 기반)로 "닉네임 + 캐릭터 일러스트 + 짧은 카피"만 담은 카드를
// 만든다. 사주도령(`doryeong.app`) OG 카드 레이아웃 참고: 좌측 텍스트(브랜드명
// + 큰 타이틀 + 설명 + 작은 CTA) / 우측 캐릭터 일러스트 / 크림색 배경.
//
// [D2 조건 — 반드시 지킬 것, 절대 원칙]
//   1. 이미지 안에는 닉네임 + 일러스트 + 카드 카피만 넣는다. 사주 한자·
//      오행 카운터·참여 인원수 등은 **절대 넣지 않는다**(화이트리스트 원칙 —
//      아래 [OgCardData] 타입에 선언된 필드 외에는 이 함수에 어떤 값도
//      전달할 수 없는 구조로 강제한다).
//   2. 생년월일·이메일·전화번호는 절대 노출하지 않는다(자동 OCR 회귀 테스트로
//      검증 — `scripts/og-ocr-regression.mjs` 참고).
//   3. 이 함수가 던지는 예외는 호출부([token]/[shareCode]/route.ts)가
//      catch해 정적 PNG로 폴백한다 — 이 파일 안에서 실패를 숨기지 않는다.
//
// [닉네임 안전성] 초대받는 사람은 아직 로그인/가입 전일 수 있으므로, 카드에
// 노출되는 닉네임은 "지도를 만든 사람의 실제 닉네임"이며 이미 앱 안에서도
// (`g/[token]/page.tsx`) 동일하게 노출하고 있는 값과 같다(신규 유출 아님).
import { ImageResponse } from "next/og";
import { readFile } from "fs/promises";
import path from "path";

/** [화이트리스트] 이 카드에 그릴 수 있는 값은 이 3개뿐이다. */
export type OgCardData = {
  /** 지도를 만든 사람의 닉네임. 25자를 넘으면 호출부에서 미리 잘라 전달할 것. */
  ownerNickname: string;
  /** 한 줄 카피(기본값 있음, 필요시 교체 가능하되 25자 이내 유지). */
  tagline?: string;
};

const FONTS_DIR = path.join(process.cwd(), "public", "fonts");
const ILLUSTRATION_PATH = path.join(process.cwd(), "public", "guinji", "bangtong_fairy.png");

let cachedFonts: { name: string; data: Buffer; weight: 400 | 700; style: "normal" }[] | null = null;
let cachedIllustrationDataUri: string | null = null;

async function loadFonts() {
  if (cachedFonts) return cachedFonts;
  const [gowunRegular, gowunBold] = await Promise.all([
    readFile(path.join(FONTS_DIR, "GowunBatang-Regular.ttf")),
    readFile(path.join(FONTS_DIR, "GowunBatang-Bold.ttf")),
  ]);
  cachedFonts = [
    { name: "GowunBatang", data: gowunRegular, weight: 400, style: "normal" },
    { name: "GowunBatang", data: gowunBold, weight: 700, style: "normal" },
  ];
  return cachedFonts;
}

async function loadIllustrationDataUri() {
  if (cachedIllustrationDataUri) return cachedIllustrationDataUri;
  const buffer = await readFile(ILLUSTRATION_PATH);
  // [주의] 원본 파일명은 `.png`이지만 실제 바이트는 JPEG다(매직넘버
  // `ffd8ffe0`). data URI의 MIME 타입을 실제 콘텐츠에 맞춰야 디코더가
  // 정상적으로 이미지를 읽는다(잘못된 MIME 선언 시 조용히 빈 이미지로
  // 렌더링되는 문제가 있었음).
  const isJpeg = buffer[0] === 0xff && buffer[1] === 0xd8;
  const mime = isJpeg ? "image/jpeg" : "image/png";
  cachedIllustrationDataUri = `data:${mime};base64,${buffer.toString("base64")}`;
  return cachedIllustrationDataUri;
}

// [카톡 카드 텍스트 잘림 방지 — 함정표] 애초에 25자 이내로 쓴다(말줄임표로
// 어색하게 끊기지 않도록 — clampLine은 최후 안전망일 뿐, 기본값은 이미
// 여유 있게 짧다).
const DEFAULT_TAGLINE = "생일만 넣으면 바로 관계가 나와요";

/** 카톡 카드 한 줄 텍스트 잘림 방지 — 완료 판정: 25자 이내. */
function clampLine(text: string, maxLength = 25): string {
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1)}…`;
}

/**
 * 귀인지도 초대 OG 카드 PNG를 생성한다(1200x630).
 *
 * [실패 시] 이 함수는 폰트/이미지 파일을 못 읽거나 렌더링 중 에러가 나면
 * 그대로 throw한다 — 호출부가 정적 PNG로 폴백하는 것을 전제로 한다(D2 조건 3).
 */
export async function buildOgPng(data: OgCardData): Promise<ImageResponse> {
  const [fonts, illustrationDataUri] = await Promise.all([
    loadFonts(),
    loadIllustrationDataUri(),
  ]);

  // [화이트리스트 원칙] 여기서 실제로 화면에 그리는 텍스트는 아래 2줄뿐이다.
  const title = clampLine(`${data.ownerNickname}님의 귀인 지도`);
  const tagline = clampLine(data.tagline ?? DEFAULT_TAGLINE);

  return new ImageResponse(
    (
      <div
        style={{
          width: "1200px",
          height: "630px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          backgroundColor: "#FAF3E0",
          padding: "72px 64px",
          fontFamily: "GowunBatang",
        }}
      >
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            maxWidth: "620px",
          }}
        >
          <div
            style={{
              fontSize: "28px",
              fontWeight: 700,
              letterSpacing: "4px",
              color: "#D97941",
              marginBottom: "28px",
            }}
          >
            신통방통 · 귀인지도
          </div>
          <div
            style={{
              fontSize: "72px",
              fontWeight: 700,
              lineHeight: 1.25,
              color: "#2A1F14",
              marginBottom: "24px",
              wordBreak: "keep-all",
            }}
          >
            {title}
          </div>
          <div
            style={{
              fontSize: "30px",
              fontWeight: 400,
              lineHeight: 1.5,
              color: "#5A4A38",
            }}
          >
            {tagline}
          </div>
        </div>
        <img
          src={illustrationDataUri}
          width={380}
          height={380}
          style={{ display: "flex", objectFit: "contain" }}
        />
      </div>
    ),
    {
      width: 1200,
      height: 630,
      fonts,
    }
  );
}
