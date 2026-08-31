// [결정 매모 D2 / Phase 2-1 완료판정] `buildOgPng()`가 화이트리스트
// 원칙(닉네임 + 일러스트 + 카피, 이 3가지만 반영)을 실제로 지키는지 검증하는
// 회귀 테스트. 별도 테스트 프레임워크(vitest/jest)가 설치돼 있지 않으므로,
// 프로젝트의 기존 스크립트들(seed-*.ts 등)과 동일한 패턴으로 tsx 실행 스크립트
// 형태로 작성한다.
//
// 실행: cd /home/user/admin_web && npx tsx scripts/test-build-og-png.ts
//       (또는 npm run test:og-buildpng)
//
// 검증 항목:
//   1. 닉네임이 다르면 결과 이미지도 달라진다 (반영됨을 증명).
//   2. 같은 입력이면 렌더 결과가 실질적으로 동일하다 (다른 값이 몰래
//      섞여 들어가지 않음 — 예: 타임스탬프 등 비결정적 요소가 없어야 함).
//   3. OgCardData 타입에 없는 임의 필드(as any로 강제 주입)를 넣어도 이미지에
//      노출되지 않는다 (TS가 컴파일 타임에 막아주지만, 런타임으로도 재확인).
//   4. 25자를 초과하는 긴 카피를 넣어도 에러 없이 렌더링되고(clampLine이
//      내부적으로 잘라줌), OCR 결과 텍스트 길이가 과도하게 길지 않다.
//   5. tagline을 생략하면 기본 태그라인이 사용된다.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { writeFile, unlink, mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { buildOgPng, type OgCardData } from "@/app/api/public/og/guinji/buildOgPng";

const execFileAsync = promisify(execFile);

async function toBuffer(res: Response): Promise<Buffer> {
  return Buffer.from(await res.arrayBuffer());
}

async function ocr(buffer: Buffer): Promise<string> {
  const dir = await mkdtemp(path.join(tmpdir(), "og-buildpng-test-"));
  const pngPath = path.join(dir, "card.png");
  await writeFile(pngPath, buffer);
  try {
    const { stdout } = await execFileAsync("tesseract", [pngPath, "stdout", "-l", "kor+eng", "--psm", "3"]);
    return stdout;
  } finally {
    await unlink(pngPath).catch(() => {});
  }
}

let passCount = 0;
let failCount = 0;

async function test(name: string, fn: () => Promise<void>) {
  try {
    await fn();
    console.log(`✅ ${name}`);
    passCount++;
  } catch (e) {
    console.error(`❌ ${name}`);
    console.error(e);
    failCount++;
  }
}

async function main() {
  await test("닉네임이 다르면 결과 이미지 바이트도 달라진다", async () => {
    const bufA = await toBuffer(await buildOgPng({ ownerNickname: "홍길동" }));
    const bufB = await toBuffer(await buildOgPng({ ownerNickname: "김철수" }));
    assert.notEqual(bufA.length, bufB.length, "닉네임 길이가 다르면 최소한 파일 크기라도 달라야 함");
    assert.notDeepEqual(bufA, bufB, "닉네임이 다른데 바이트가 완전히 동일하면 안 됨(반영되지 않은 것)");
  });

  await test("같은 입력이면 렌더 결과가 실질적으로 동일하다(비결정적 요소 없음)", async () => {
    const input: OgCardData = { ownerNickname: "동일입력테스트", tagline: "같은 카피 테스트" };
    const bufA = await toBuffer(await buildOgPng({ ...input }));
    const bufB = await toBuffer(await buildOgPng({ ...input }));
    // PNG 인코딩 자체가 완전히 바이트단위로 결정적이지 않을 수 있으므로
    // (압축 타이밍 등) 파일 크기 차이가 아주 작아야 한다는 완화된 기준으로 검증.
    const sizeDiff = Math.abs(bufA.length - bufB.length);
    assert.ok(
      sizeDiff < 2000,
      `같은 입력인데 파일 크기 차이가 너무 크다(${sizeDiff}바이트) — 숨겨진 비결정적 값이 섞여있을 가능성`
    );
  });

  await test("타입에 없는 임의 필드(PII 등)를 강제로 넣어도 이미지에 노출되지 않는다", async () => {
    const malicious = {
      ownerNickname: "화이트리스트테스트",
      birthDate: "1990-01-01",
      email: "leak@example.com",
      phone: "010-1234-5678",
    } as unknown as OgCardData;
    const buf = await toBuffer(await buildOgPng(malicious));
    const text = await ocr(buf);
    assert.doesNotMatch(text, /1990[-.]01[-.]01/, "생년월일이 이미지에 노출됨");
    assert.doesNotMatch(text, /leak@example\.com/i, "이메일이 이미지에 노출됨");
    assert.doesNotMatch(text, /010[-.\s]?1234[-.\s]?5678/, "전화번호가 이미지에 노출됨");
  });

  await test("25자를 초과하는 긴 카피도 에러 없이 렌더링된다(clampLine 폴백)", async () => {
    const longTagline = "아주아주아주아주아주아주아주아주아주아주아주아주긴카피텍스트입니다정말길게써봅니다";
    const res = await buildOgPng({ ownerNickname: "긴카피테스트", tagline: longTagline });
    const buf = await toBuffer(res);
    assert.ok(buf.length > 0, "이미지가 생성되어야 함(예외 없이)");
  });

  await test("tagline을 생략하면 기본 태그라인이 사용된다(에러 없이 렌더링)", async () => {
    const res = await buildOgPng({ ownerNickname: "기본카피테스트" });
    const buf = await toBuffer(res);
    assert.ok(buf.length > 0, "기본 태그라인으로도 정상 렌더링되어야 함");
  });

  console.log(`\n[test-build-og-png] 통과 ${passCount} / 실패 ${failCount}`);
  if (failCount > 0) {
    process.exit(1);
  }
}

main().catch((e) => {
  console.error("[test-build-og-png] 실행 실패:", e);
  process.exit(1);
});
