import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { NextRequest } from 'next/server';
import { prisma } from '../src/lib/db';
import { signUserToken } from '../src/lib/user-auth';
import { grantOpenPass, checkDailyAbsoluteLimit } from '../src/lib/open-pass-service';
import { beginResultAccess, recoverExpiredCompatibilityTransactions } from '../src/lib/result-access-service';
import { POST } from '../src/app/api/public/compatibility/request/route';
import { GET as history } from '../src/app/api/public/compatibility/history/route';
import { GET as result } from '../src/app/api/public/compatibility/result/[id]/route';
import { GET as daily } from '../src/app/api/public/fortune/daily/route';
import { POST as clientFail } from '../src/app/api/public/result-access/fail/route';
import { POST as clientComplete } from '../src/app/api/public/result-access/complete/route';
import { GET as quote } from '../src/app/api/public/result-access/quote/route';

async function main() {
  assert.equal(process.env.REGRESSION_LOCAL_DB, '1');
  assert.ok(process.env.DATABASE_URL?.includes('/home/user/workspace/'), '샌드박스 DB만 허용');
  const suffix = randomUUID().slice(0, 8);
  const user = await prisma.user.create({ data: { email: `compat_reg_${suffix}@example.com`, nickname: `compat_${suffix}`, passwordHash: 'test' } });
  const other = await prisma.user.create({ data: { email: `compat_other_${suffix}@example.com`, nickname: `other_${suffix}`, passwordHash: 'test' } });
  const policy = await prisma.passPolicy.create({ data: { name: `궁합검증 ${suffix}`, passType: 'event', durationMin: 1, grantCount: 12, validityDays: 1, isActive: false } });
  const { userPass } = await grantOpenPass({ userId: user.id, policyId: policy.id, sourceType: 'test_mode' });
  await prisma.wallet.create({ data: { userId: user.id, currencyType: 'POINT', balance: 0 } });
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });
  const otherToken = await signUserToken({ userId: other.id, nickname: other.nickname });
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
  const templates = await prisma.aiPromptTemplate.findMany({ where: { fortuneTypeOrDomain: 'compatibility', isActive: true } });
  const originalFetch = globalThis.fetch;
  let calls = 0; // LLM(completeText) 호출 횟수만 센다(기존 의미 그대로 유지).
  let fail = false;
  let expireDuringGeneration: string | null = null;
  let templateId: number | undefined;
  // [궁합 사주 팩터 개선] route.ts가 이제 saju_engine(/compatibility)도 호출한다.
  // 이 mock은 URL로 분기해, 기존 `calls`(LLM 3토픽 호출수 검증)의 의미를
  // 그대로 보존하고, saju_engine 쪽은 항상 정상 응답(final_score)을 주어
  // 기존 테스트가 "폴백 없는 saju-v1 정상 경로"를 타게 한다(폴백 자체의
  // 동작은 아래 신규 U1~U5/I1~I4 테스트에서 별도로 검증한다).
  globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
    if (url.endsWith('/compatibility')) {
      // saju_engine 호출(saju-compat-score.ts가 `${baseUrl}/compatibility`로 호출).
      return new Response(JSON.stringify({ final_score: 72, band: '70-79' }), { status: 200 });
    }
    calls++;
    if (expireDuringGeneration) {
      const id = expireDuringGeneration;
      expireDuringGeneration = null;
      await prisma.resultAccessTransaction.update({ where: { transactionId: id }, data: { updatedAt: new Date(Date.now() - 6 * 60 * 1000) } });
    }
    await new Promise(resolve => setTimeout(resolve, 80));
    return new Response(JSON.stringify(fail ? { error: { message: '모의 실패' } } : { content: [{ type: 'text', text: '검증용 궁합 해석: 서로의 생각을 확인하고 차이를 존중하세요.' }] }), { status: fail ? 503 : 200 });
  };
  const remaining = async () => (await prisma.userPass.findUniqueOrThrow({ where: { id: userPass.id } })).remainingCount;
  const begin = async (id: string) => beginResultAccess({ userId: user.id, transactionId: id, contentType: 'compatibility', paymentMethod: 'FREEPASS' });
  const send = async (id: string, patch: Record<string, unknown> = {}) => {
    const response = await POST(new NextRequest('http://localhost/api/public/compatibility/request', { method: 'POST', headers, body: JSON.stringify({ type: 'love', nameA: '나', nameB: '상대', birthDateA: '1990-01-01', birthDateB: '1991-02-02', paymentMethod: 'FREEPASS', transactionId: id, ...patch }) }));
    return { status: response.status, body: await response.json() };
  };
  try {
    await prisma.aiPromptTemplate.updateMany({ where: { id: { in: templates.map(t => t.id) } }, data: { isActive: false } });
    const missingId = `compat_missing_${suffix}`;
    await begin(missingId);
    const missing = await send(missingId);
    assert.equal(missing.status, 503);
    assert.equal(await remaining(), 12);
    assert.equal((await prisma.resultAccessTransaction.findUniqueOrThrow({ where: { transactionId: missingId } })).status, 'refunded');
    console.log('PASS: 설정 누락은 503, 게이트 선차감 복구, 가짜 성공 없음');
    templateId = (await prisma.aiPromptTemplate.create({ data: { fortuneTypeOrDomain: 'compatibility', version: 9999, templateBody: '검증용', isActive: true } })).id;
    const invalidId = `compat_invalid_${suffix}`;
    await begin(invalidId);
    assert.equal((await send(invalidId, { birthDateA: '1990-02-30' })).status, 400);
    assert.equal(await remaining(), 12);
    console.log('PASS: 잘못된 날짜는 400, 선차감 복구');
    const recentId = `compat_recent_${suffix}`;
    await begin(recentId);
    const mutationRequest = () => new NextRequest('http://localhost/result-access', { method: 'POST', headers, body: JSON.stringify({ transactionId: recentId }) });
    assert.equal((await clientFail(mutationRequest())).status, 409);
    assert.equal((await clientComplete(mutationRequest())).status, 409);
    await recoverExpiredCompatibilityTransactions(other.id);
    assert.equal(await remaining(), 11);
    await recoverExpiredCompatibilityTransactions(user.id);
    assert.equal(await remaining(), 11);
    await prisma.resultAccessTransaction.update({ where: { transactionId: recentId }, data: { contentId: 'compatibility:generating', updatedAt: new Date(Date.now() - 6 * 60 * 1000) } });
    const beforeRecoveryCalls = calls;
    await Promise.all([recoverExpiredCompatibilityTransactions(user.id), recoverExpiredCompatibilityTransactions(user.id)]);
    assert.equal(await remaining(), 12);
    assert.equal(calls, beforeRecoveryCalls);
    assert.equal((await send(recentId)).status, 409);
    assert.equal((await prisma.resultAccessTransaction.findUniqueOrThrow({ where: { transactionId: recentId } })).status, 'refunded');
    const preSendId = `compat_presend_${suffix}`;
    await begin(preSendId);
    await prisma.resultAccessTransaction.update({ where: { transactionId: preSendId }, data: { updatedAt: new Date(Date.now() - 6 * 60 * 1000) } });
    const q = await quote(new NextRequest('http://localhost/api/public/result-access/quote?contentType=compatibility', { headers }));
    assert.equal(q.status, 200);
    assert.equal(await remaining(), 12);
    console.log('PASS: 진행 거래 임의 완료·환불 차단, 최근 pending 유지, 오래된 생성/호출전 pending 동시 복구 정확히 1회, 타인 복구 불가');
    const lateId = `compat_late_${suffix}`;
    await begin(lateId);
    expireDuringGeneration = lateId;
    assert.equal((await send(lateId)).status, 500);
    assert.equal(await remaining(), 12);
    assert.equal(await prisma.compatibilityRequest.count({ where: { requesterUserId: user.id } }), 0);
    console.log('PASS: 임대시간 경과 후 늦은 응답은 결과·성공 저장 롤백하고 1회 복구');
    const successId = `compat_success_${suffix}`;
    await begin(successId);
    const success = await send(successId);
    assert.equal(success.status, 200);
    assert.equal(await remaining(), 11);
    const txn = await prisma.resultAccessTransaction.findUniqueOrThrow({ where: { transactionId: successId } });
    assert.equal(txn.status, 'success');
    assert.equal(txn.contentId, success.body.data.id);
    const h = await history(new NextRequest('http://localhost/api/public/compatibility/history', { headers }));
    assert.equal((await h.json()).data[0].summary, success.body.data.summary);
    const beforeRetry = calls;
    assert.equal((await send(successId, { birthDateA: '' })).body.data.id, success.body.data.id);
    assert.equal(calls, beforeRetry);
    assert.equal(await remaining(), 11);
    assert.equal((await send(successId, { paymentMethod: 'POUCH' })).status, 400);
    console.log('PASS: 정상 1회 소비, 응답↔DB↔이력 연결, 성공 재열람 무차감·무생성');
    const foreign = await result(new NextRequest('http://localhost/result', { headers: { Authorization: `Bearer ${otherToken}` } }), { params: Promise.resolve({ id: success.body.data.id }) });
    assert.equal(foreign.status, 404);
    const anon = await result(new NextRequest('http://localhost/result'), { params: Promise.resolve({ id: success.body.data.id }) });
    assert.equal(anon.status, 401);
    console.log('PASS: 궁합 단건 조회 본인만 허용, 타인 404·비로그인 401');
    fail = true;
    const failId = `compat_fail_${suffix}`;
    await begin(failId);
    assert.equal((await send(failId)).status, 500);
    assert.equal(await remaining(), 11);
    assert.equal(await prisma.compatibilityRequest.count({ where: { requesterUserId: user.id } }), 1);
    fail = false;
    const concurrentId = `compat_concurrent_${suffix}`;
    await begin(concurrentId);
    const beforeConcurrent = calls;
    const simultaneous = await Promise.all([send(concurrentId), send(concurrentId)]);
    assert.deepEqual(simultaneous.map(r => r.status).sort(), [200, 409]);
    assert.equal(calls - beforeConcurrent, 3);
    assert.equal(await remaining(), 10);
    assert.equal((await checkDailyAbsoluteLimit(user.id)).usageCount, 2);
    console.log('PASS: 모의 LLM 실패 전액 복구, 동시 요청 결과 1건/LLM 3토픽 1세트, 일일 상한에 궁합 포함');
    for (let i = 0; i < 2; i++) assert.equal((await send(`compat_limit_fill_${suffix}_${i}`)).status, 200);
    assert.equal((await checkDailyAbsoluteLimit(user.id)).usageCount, 4);
    const raceIds = Array.from({ length: 5 }, (_, i) => `compat_last_slot_${suffix}_${i}`);
    for (const id of raceIds) await begin(id);
    const balanceBeforeRace = await remaining();
    const callsBeforeRace = calls;
    const race = await Promise.all(raceIds.map(id => send(id)));
    assert.equal(race.filter(r => r.status === 200).length, 1);
    assert.equal(race.filter(r => r.status === 403 && r.body.reason === 'DAILY_ABSOLUTE_LIMIT_REACHED').length, 4);
    assert.equal(calls - callsBeforeRace, 3);
    assert.equal(await remaining(), balanceBeforeRace! + 4);
    assert.equal(await prisma.compatibilityRequest.count({ where: { requesterUserId: user.id } }), 5);
    assert.equal((await checkDailyAbsoluteLimit(user.id)).allowed, false);
    console.log('PASS: 다른 거래 5개가 마지막 일일 슬롯 경합 → 1건 생성·LLM 3회, 4건 403·선차감 복구');
    const beforeLimitBalance = await remaining();
    const limitedId = `compat_limited_${suffix}`;
    await begin(limitedId);
    assert.equal((await send(limitedId)).status, 403);
    assert.equal(await remaining(), beforeLimitBalance);
    const beforeLimitRetry = calls;
    assert.equal((await send(successId)).status, 200);
    assert.equal(calls, beforeLimitRetry);
    console.log('PASS: 당일 상한 도달 시 새 생성 403·선차감 복구, 성공 거래 재열람은 허용');
    const beforeDailyCalls = calls;
    const emptyDaily = await daily(new NextRequest('http://localhost/api/public/fortune/daily', { headers }));
    assert.equal(emptyDaily.status, 410);
    assert.equal(await prisma.fortuneRequest.count({ where: { userId: user.id } }), 0);
    const old = await prisma.fortuneRequest.create({ data: { userId: user.id, fortuneType: 'daily', inputPayload: '{}', sourceType: 'ai_generated', pointSpent: 0, status: 'success', createdAt: new Date('2026-01-01T00:00:00Z') } });
    await prisma.fortuneResult.create({ data: { requestId: old.id, resultText: '보존할 예전 일간 운세', resultMeta: JSON.stringify({ luckyNumber: 2 }), aiModel: 'test', promptTemplateId: templateId, promptVersion: 9999, status: 'active' } });
    const archived = await daily(new NextRequest(`http://localhost/api/public/fortune/daily?requestId=df_${old.id}`, { headers }));
    assert.equal(archived.status, 200);
    const archiveBody = await archived.json();
    assert.equal(archiveBody.data.summaryText, '보존할 예전 일간 운세');
    assert.equal(archiveBody.data.firstViewBonus, 0);
    assert.equal(archiveBody.data.readOnly, true);
    const otherArchive = await daily(new NextRequest(`http://localhost/api/public/fortune/daily?requestId=df_${old.id}`, { headers: { Authorization: `Bearer ${otherToken}` } }));
    assert.equal(otherArchive.status, 404);
    assert.equal(calls, beforeDailyCalls);
    assert.equal(await prisma.pointHistory.count({ where: { userId: user.id } }), 0);
    assert.equal((await prisma.wallet.findFirstOrThrow({ where: { userId: user.id } })).balance, 0);
    console.log('PASS: 오늘의 운세 신규 생성 410, 과거 결과 본인 조회만 200, LLM·보너스·지갑 변경 없음');
    console.log('궁합/일간 운세 로컬 DB·실제 라우트 회귀 통과. LLM은 모의이며 운영 E3 검증 아님.');
  } finally {
    globalThis.fetch = originalFetch;
    await prisma.aiPromptTemplate.updateMany({ where: { id: { in: templates.map(t => t.id) } }, data: { isActive: true } });
    await prisma.resultAccessTransaction.deleteMany({ where: { userId: user.id } });
    await prisma.compatibilityResult.deleteMany({ where: { request: { requesterUserId: user.id } } });
    await prisma.aiRequestLog.deleteMany({ where: { domain: 'compatibility', requestRefId: { in: (await prisma.compatibilityRequest.findMany({ where: { requesterUserId: user.id }, select: { id: true } })).map(r => r.id) } } });
    await prisma.compatibilityRequest.deleteMany({ where: { requesterUserId: user.id } });
    await prisma.fortuneResult.deleteMany({ where: { request: { userId: user.id } } });
    await prisma.fortuneRequest.deleteMany({ where: { userId: user.id } });
    await prisma.userPass.deleteMany({ where: { userId: user.id } });
    if (templateId) await prisma.aiPromptTemplate.delete({ where: { id: templateId } });
    await prisma.passPolicy.delete({ where: { id: policy.id } });
  }
}
main().then(() => process.exit(0)).catch(error => { console.error('TEST FAILED:', error); process.exit(1); });
