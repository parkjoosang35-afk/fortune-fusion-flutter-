import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { NextRequest } from 'next/server';
import { prisma } from '../src/lib/db';
import { signUserToken } from '../src/lib/user-auth';
import { POST } from '../src/app/api/public/share/route';
import { GET, DELETE } from '../src/app/api/public/share/[shareId]/route';
import sharp from 'sharp';
import { rm, readFile } from 'node:fs/promises';
// react-server 조건에서는 DOM 렌더러 대신 반환된 서버 컴포넌트 트리를 검사한다.
// Next 서버/클라이언트 컴포넌트 렌더 검증은 실제 Next 런타임에서 별도로 수행한다.
async function main() {
  assert.equal(process.env.REGRESSION_LOCAL_DB,'1');
  assert.ok(process.env.DATABASE_URL?.includes('/home/user/workspace/'));
   const suffix=randomUUID();
   process.env.SHARE_SNAPSHOT_DIR = `/tmp/opencode/share-snapshot-test-${suffix}`;
   process.env.PUBLIC_BASE_URL = 'http://localhost';
  const user=await prisma.user.create({data:{email:`share_${suffix}@example.com`,nickname:`공유${suffix.slice(0,8)}`,passwordHash:'test'}});
  const token=await signUserToken({userId:user.id,nickname:user.nickname});
  if (process.env.SHARE_HTTP_BASE) {
    const base=process.env.SHARE_HTTP_BASE;
    assert.equal(base,'http://localhost:3111');
    try {
       const png=process.env.SHARE_TAROT_FIXTURE === '1' ? await readFile('/tmp/opencode/tarot-result-fixture.png') : await sharp({create:{width:390,height:3000,channels:4,background:'#161618'}}).png().toBuffer();
      const created=await fetch(`${base}/api/public/share`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({resultType:'tarot',title:'로컬 원본 시험',description:'로컬 검증',payload:{kind:'tarot',summary:'재구성제외'},originalPngBase64:png.toString('base64'),originalShareConsent:true})});
      assert.equal(created.status,201);
      const id=(await created.json()).data.shareId;
      const page=await fetch(`${base}/r/${id}`);
      assert.equal(page.status,200);
      const html=await page.text();
      assert.ok(html.includes(`/api/public/share/${id}?original=1`));
      assert.ok(html.includes('원본 결과 저장'));
      assert.ok(!html.includes('앱에서 보면 더 자세한'));
      assert.ok(html.includes(`/api/public/og/share/${id}.png`));
      assert.ok(html.includes('noindex, nofollow'));
      const image=await fetch(`${base}/api/public/share/${id}?original=1`);
      assert.equal(image.status,200);
      assert.deepEqual(Buffer.from(await image.arrayBuffer()),png);
      console.log('PASS HTTP: Next SSR 원본 img·저장·OG 분리·noindex·PNG 일치');
             if (process.env.SHARE_TAROT_FIXTURE === '1') {
         console.log(`FIXTURE_SHARE_ID=${id}`);
         return;
       }
       assert.equal((await fetch(`${base}/api/public/share/${id}`,{method:'DELETE',headers:{Authorization:`Bearer ${token}`}})).status,200);
      assert.equal((await fetch(`${base}/api/public/share/${id}?original=1`)).status,404);
      const after=await (await fetch(`${base}/r/${id}`)).text();
      assert.ok(!after.includes('원본 결과 저장'));
      assert.ok(after.includes('결과를 찾을 수 없어요'));
      console.log('PASS HTTP: 삭제 후 이미지404·SSR 원본 제거');
     } finally {if (process.env.SHARE_TAROT_FIXTURE !== '1') await prisma.sharedResult.deleteMany({where:{userId:user.id}});}
    return;
  }
  const bodyText='전체 본문 '.repeat(2000)+'최종문장표식';
  try {
    for (const resultType of ['saju','tarot','face','palm','wish']) {
      const payload={kind:resultType,summary:'전체 요약',blocks:[{title:'전체',body:bodyText}]};
      const response=await POST(new NextRequest('http://localhost/api/public/share',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({resultType,title:'전체 결과',description:'미리보기 '.repeat(100),payload})}));
      assert.equal(response.status,201);
      const created=await response.json();
      const shared=await GET(new NextRequest('http://localhost/share'),{params:Promise.resolve({shareId:created.data.shareId})});
      assert.equal(shared.status,200);
      const data=(await shared.json()).data;
      assert.equal(data.payload.blocks[0].body,bodyText);
      assert.equal(data.description.length,120);
      console.log(`PASS: ${resultType} 긴 본문 끝까지 보존, 비로그인 공유 조회, OG 설명만 120자`);
    }
    const oversized=await POST(new NextRequest('http://localhost/share',{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({resultType:'saju',title:'초과',description:'설명',payload:{summary:'x'.repeat(200001)}})}));
    assert.equal(oversized.status,400);
     console.log('PASS: 유한 크기 상한 초과는 거절, 조용한 본문 절단 없음');
     const png = await sharp({create:{width:390,height:3000,channels:4,background:'#161618'}}).png().toBuffer();
     const snapshotBody = {resultType:'saju',title:'원본 검증',description:'설명',payload:{kind:'saju',summary:'원본 저장'},originalPngBase64:png.toString('base64'),originalShareConsent:true};
     const create = (body: unknown, authenticated = true) => POST(new NextRequest('http://localhost/api/public/share', {method:'POST',headers:{'Content-Type':'application/json',...(authenticated ? {Authorization:`Bearer ${token}`} : {})},body:JSON.stringify(body)}));
     assert.equal((await create(snapshotBody,false)).status,401);
     assert.equal((await create({...snapshotBody,originalShareConsent:false})).status,400);
     assert.equal((await create({...snapshotBody,originalPngBase64:'not-a-png'})).status,400);
     assert.equal((await create({...snapshotBody,originalPngBase64:png.subarray(0,40).toString('base64')})).status,400);
     assert.equal((await create({...snapshotBody,originalPngBase64:'a'.repeat(12*1024*1024)})).status,413);
     console.log('PASS: 무인증·미동의·비PNG·손상PNG·요청 크기 초과 차단');
     const response = await create(snapshotBody);
     assert.equal(response.status,201);
     const id = (await response.json()).data.shareId;
     const params = {params:Promise.resolve({shareId:id})};
     const fetchImage = () => GET(new NextRequest(`http://localhost/api/public/share/${id}?original=1`),params);
     const image = await fetchImage();
     assert.equal(image.status,200);
     assert.equal(image.headers.get('content-type'),'image/png');
     assert.equal(image.headers.get('cache-control'),'private, no-store');
     assert.deepEqual(Buffer.from(await image.arrayBuffer()),png);
     const dto = (await (await GET(new NextRequest(`http://localhost/api/public/share/${id}`),params)).json()).data;
     assert.equal(dto.originalImageUrl,`http://localhost/api/public/share/${id}?original=1`);
     console.log('PASS: 익명 원본PNG 바이트 완전 일치·원본 URL 응답·캐시 미저장');
     const other = await signUserToken({userId:user.id+999999,nickname:'타인'});
     assert.equal((await DELETE(new NextRequest('http://localhost/share',{method:'DELETE',headers:{Authorization:`Bearer ${other}`}}),params)).status,403);
     assert.equal((await fetchImage()).status,200);
     assert.equal((await DELETE(new NextRequest('http://localhost/share',{method:'DELETE',headers:{Authorization:`Bearer ${token}`}}),params)).status,200);
     assert.equal((await fetchImage()).status,404);
     console.log('PASS: 타인 삭제 거절·본인 삭제 후 원본 접근 차단');
  } finally {
    // 조회수 best-effort 쓰기가 끝나도록 기다린 뒤 시험 링크만 정리.
    await new Promise(r=>setTimeout(r,100));
     await prisma.sharedResult.deleteMany({where:{userId:user.id}});
     await rm(process.env.SHARE_SNAPSHOT_DIR!,{recursive:true,force:true});
  }
}
main().then(()=>process.exit(0)).catch(e=>{console.error(e);process.exit(1)});
