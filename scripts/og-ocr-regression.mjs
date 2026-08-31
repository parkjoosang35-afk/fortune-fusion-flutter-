// [결정 매모 D2 조건 2 / Phase 2-4] 귀인지도 OG 카드 이미지에 개인정보
// (생년월일·이메일·전화번호·주민번호 패턴 등)가 노출되지 않는지 자동으로
// 검증하는 OCR 회귀 테스트.
//
// 동작:
//   1. DB에서 실제 활성 GuinjiMap 토큰들을 몇 개 가져와 동적 OG 카드
//      (`/api/public/og/guinji/{token}/{shareCode}.png`)를 실제로 요청한다.
//   2. 존재하지 않는 토큰으로도 1회 요청해 정적 폴백 이미지도 함께 검증한다.
//   3. 각 이미지를 tesseract(kor+eng)로 OCR한 뒤, PII 패턴(이메일/전화번호/
//      생년월일/주민번호 형태)이 텍스트에서 검출되는지 정규식으로 검사한다.
//   4. 하나라도 검출되면 실패(exit 1)로 종료한다 — "검출 0건"이 완료 판정.
//
// 실행:
//   cd /home/user/admin_web && node scripts/og-ocr-regression.mjs
//   (사전 조건: next dev 서버가 로컬에서 실행 중이어야 함 — 기본 포트 3000,
//    다른 포트를 쓰면 OG_BASE_URL 환경변수로 지정)
//
// 필요 패키지: tesseract-ocr(+kor 언어팩), 시스템에 이미 설치되어 있음.

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { writeFile, unlink, mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { randomBytes } from "node:crypto";
import Database from "better-sqlite3";

const execFileAsync = promisify(execFile);

const BASE_URL = process.env.OG_BASE_URL ?? "http://localhost:3000";
const DB_PATH = path.join(process.cwd(), "prisma", "dev.db");

/** [PII 검출 패턴] 하나라도 매치되면 실패. */
const PII_PATTERNS = [
  { name: "email", regex: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/ },
  // 한국 휴대폰 번호 (010-1234-5678, 01012345678, OCR 공백/구두점 변형 포함)
  { name: "phone_mobile", regex: /01[016789][-.\s]?\d{3,4}[-.\s]?\d{4}/ },
  // 주민등록번호 형태 (앞6자리-뒤7자리)
  { name: "resident_id", regex: /\d{6}[-\s]?[1-4]\d{6}/ },
  // 생년월일 형태 (1990-01-01, 1990.01.01, 1990/01/01)
  { name: "birthdate_ymd", regex: /(19|20)\d{2}[-./]\s?\d{1,2}[-./]\s?\d{1,2}/ },
  // 생년월일 형태 (1990년 1월 1일)
  { name: "birthdate_kr", regex: /(19|20)\d{2}\s?년\s?\d{1,2}\s?월\s?\d{1,2}\s?일/ },
];

function generateShareCode(length = 6) {
  const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789";
  const bytes = randomBytes(length);
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join("");
}

function loadActiveTokens(limit = 3) {
  const db = new Database(DB_PATH, { readonly: true });
  try {
    const rows = db
      .prepare(
        `SELECT gm.token AS token, u.nickname AS nickname
         FROM guinji_map gm
         JOIN users u ON u.id = gm.owner_id
         WHERE gm.deleted_at IS NULL AND gm.status = 'active'
         LIMIT ?`
      )
      .all(limit);
    return rows;
  } finally {
    db.close();
  }
}

async function fetchOgImage(token, shareCode) {
  const url = `${BASE_URL}/api/public/og/guinji/${token}/${shareCode}.png`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`OG 이미지 요청 실패: ${url} -> HTTP ${res.status}`);
  }
  const buffer = Buffer.from(await res.arrayBuffer());
  return { url, buffer };
}

async function ocrImage(buffer) {
  const dir = await mkdtemp(path.join(tmpdir(), "og-ocr-"));
  const pngPath = path.join(dir, "card.png");
  await writeFile(pngPath, buffer);
  try {
    // tesseract는 RGBA PNG도 처리 가능하지만, 안정성을 위해 그대로 전달.
    const { stdout } = await execFileAsync("tesseract", [
      pngPath,
      "stdout",
      "-l",
      "kor+eng",
      "--psm",
      "3",
    ]);
    return stdout;
  } finally {
    await unlink(pngPath).catch(() => {});
  }
}

function checkPii(text, label) {
  const hits = [];
  for (const { name, regex } of PII_PATTERNS) {
    const match = text.match(regex);
    if (match) {
      hits.push({ pattern: name, matched: match[0] });
    }
  }
  if (hits.length > 0) {
    console.error(`❌ [${label}] PII 패턴 검출됨:`);
    for (const hit of hits) {
      console.error(`   - ${hit.pattern}: "${hit.matched}"`);
    }
    return false;
  }
  console.log(`✅ [${label}] PII 패턴 검출 0건 (OCR 텍스트 길이: ${text.trim().length}자)`);
  return true;
}

async function main() {
  console.log(`[og-ocr-regression] BASE_URL=${BASE_URL}`);
  let allPassed = true;

  // 1) 실제 활성 토큰들 — 동적 카드 검증
  const tokens = loadActiveTokens(3);
  if (tokens.length === 0) {
    console.warn("⚠️ 활성 GuinjiMap 토큰이 없어 동적 카드 검증을 건너뜁니다.");
  }
  for (const { token, nickname } of tokens) {
    const shareCode = generateShareCode();
    const label = `동적카드 token=${token} nickname="${nickname}"`;
    try {
      const { buffer } = await fetchOgImage(token, shareCode);
      const text = await ocrImage(buffer);
      const ok = checkPii(text, label);
      allPassed = allPassed && ok;
    } catch (e) {
      console.error(`❌ [${label}] 검증 중 에러:`, e);
      allPassed = false;
    }
  }

  // 2) 존재하지 않는 토큰 — 정적 폴백 검증
  {
    const fakeToken = `nonexistent-${randomBytes(4).toString("hex")}`;
    const shareCode = generateShareCode();
    const label = `정적폴백 token=${fakeToken}`;
    try {
      const { buffer } = await fetchOgImage(fakeToken, shareCode);
      const text = await ocrImage(buffer);
      const ok = checkPii(text, label);
      allPassed = allPassed && ok;
    } catch (e) {
      console.error(`❌ [${label}] 검증 중 에러:`, e);
      allPassed = false;
    }
  }

  if (!allPassed) {
    console.error("\n[og-ocr-regression] 실패 — PII 노출 가능성이 검출되었습니다.");
    process.exit(1);
  }
  console.log("\n[og-ocr-regression] 전체 통과 — PII 패턴 검출 0건.");
}

main().catch((e) => {
  console.error("[og-ocr-regression] 실행 실패:", e);
  process.exit(1);
});
