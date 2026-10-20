// [2026-10-14 재배포 검증] d68ee13(본문 우선 재편) + nginx client_max_body_size 15m
// 실측 검증용 — 소형(6.4KB) 테스트로는 413 미발생을 증명할 수 없으므로
// 수 MB(약 4MB) 원본 PNG로 실제 업로드가 통과하는지 확인한다.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { SignJWT } from 'jose';
import { prisma } from '../src/lib/db';

const BASE = 'https://sintong.kr';

async function signUserToken(payload: { userId: number; nickname: string }) {
  const secretKey = process.env.SESSION_SECRET;
  assert.ok(secretKey, 'SESSION_SECRET 환경변수가 설정되지 않았습니다.');
  const encodedKey = new TextEncoder().encode(secretKey);
  return new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(encodedKey);
}

async function main() {
  const suffix = randomUUID().slice(0, 8);
  const user = await prisma.user.create({
    data: {
      email: `prod_e2e_check_${suffix}@sintong-internal.invalid`,
      nickname: `운영점검${suffix}`,
      passwordHash: 'not-a-real-password-hash',
      signupChannel: 'internal_check',
    },
  });
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });
  let shareId: string | null = null;
  try {
    // [핵심] 실제 폰 원본 캡처와 비슷한 해상도(1170x2400, 노이즈 포함)로
    // 약 4MB급 PNG를 만들어 base64 JSON 전송 시 12MB 캡 + nginx 15m 설정이
    // 실제로 통과하는지 확인한다. (순수 단색은 PNG 압축이 너무 잘 돼서
    // 수 MB를 만들 수 없으므로 랜덤 노이즈 버퍼로 비압축성 데이터를 구성)
    // [크기 조정] nginx 구 기본값(1m)보다는 훨씬 크고, 앱 자체의
    // ORIGINAL_PNG_MAX_BYTES(8MB) 캡은 넘지 않는 범위(약 3MB)로 타겟팅.
    // 순수 랜덤 노이즈는 PNG 비압축으로 과도하게 커지므로, 저주파 그라디언트
    // + 약한 노이즈를 섞어 "실제 사진/캡처와 비슷한 압축률"을 모사한다.
    const width = 1170;
    const height = 1600;
    const raw = Buffer.alloc(width * height * 4);
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 4;
        const base = ((x * 37 + y * 53) % 256);
        const jitter = Math.floor(Math.random() * 40);
        raw[idx] = (base + jitter) % 256;
        raw[idx + 1] = ((base * 2) + jitter) % 256;
        raw[idx + 2] = ((base * 3) + jitter) % 256;
        raw[idx + 3] = 255;
      }
    }
    const png = await sharp(raw, { raw: { width, height, channels: 4 } })
      .png({ compressionLevel: 3 })
      .toBuffer();
    const pngSizeMb = (png.length / 1024 / 1024).toFixed(2);
    console.log(`생성된 테스트 PNG 크기: ${pngSizeMb} MB (${png.length} bytes)`);
    assert.ok(
      png.length > 1.5 * 1024 * 1024 && png.length < 7 * 1024 * 1024,
      `테스트 PNG 크기가 목표 범위(1.5~7MB) 밖임(${pngSizeMb}MB) — 재조정 필요`,
    );

    const base64 = png.toString('base64');
    const bodyObj = {
      resultType: 'tarot',
      title: '운영 배포 후 점검(대용량)',
      description: '413/413 nginx 15m 실측용',
      payload: { kind: 'tarot', summary: 'prod e2e large png check' },
      originalPngBase64: base64,
      originalShareConsent: true,
    };
    const bodyStr = JSON.stringify(bodyObj);
    console.log(`요청 바디 전체 크기: ${(bodyStr.length / 1024 / 1024).toFixed(2)} MB`);

    const created = await fetch(`${BASE}/api/public/share`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: bodyStr,
    });
    const createdBodyText = await created.text();
    assert.equal(
      created.status,
      201,
      `공유 생성 실패: HTTP ${created.status} ${createdBodyText.slice(0, 500)}`,
    );
    const createdJson = JSON.parse(createdBodyText);
    shareId = createdJson.data.shareId as string;
    console.log(`✅ 대용량(${pngSizeMb}MB) 원본 PNG 업로드 성공 — 413 미발생 확인. shareId=${shareId}`);

    const page = await fetch(`${BASE}/r/${shareId}`);
    assert.equal(page.status, 200);
    const html = await page.text();
    assert.ok(html.includes(`/api/public/share/${shareId}?original=1`));
    assert.ok(html.includes('원본 결과 저장'));
    assert.ok(html.includes('noindex, nofollow'));
    console.log('✅ /r/[id] SSR 렌더 확인 (원본이미지 경로 + 저장버튼 + noindex)');

    const image = await fetch(`${BASE}/api/public/share/${shareId}?original=1`);
    assert.equal(image.status, 200);
    const imageBytes = Buffer.from(await image.arrayBuffer());
    assert.ok(imageBytes.equals(png));
    console.log('✅ 원본 이미지 바이트 단위 일치 확인');

    const del = await fetch(`${BASE}/api/public/share/${shareId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    assert.equal(del.status, 200);

    const imageAfter = await fetch(`${BASE}/api/public/share/${shareId}?original=1`);
    assert.equal(imageAfter.status, 404);
    const pageAfter = await fetch(`${BASE}/r/${shareId}`);
    const afterHtml = await pageAfter.text();
    assert.ok(!afterHtml.includes('원본 결과 저장'));
    assert.ok(afterHtml.includes('결과를 찾을 수 없어요'));
    console.log('✅ 삭제 후 404 전환 확인');

    console.log('\n🎉 전체 통과: nginx client_max_body_size 15m 실측 OK, d68ee13 공유 파이프라인 OK');
  } finally {
    if (shareId) await prisma.sharedResult.deleteMany({ where: { shareId } }).catch(() => {});
    await prisma.sharedResult.deleteMany({ where: { userId: user.id } }).catch(() => {});
    await prisma.user.delete({ where: { id: user.id } }).catch(() => {});
  }
}
main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
