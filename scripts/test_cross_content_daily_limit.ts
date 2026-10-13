import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { NextRequest } from 'next/server';
import { prisma } from '../src/lib/db';
import { signUserToken } from '../src/lib/user-auth';
import { grantOpenPass, checkDailyAbsoluteLimit, todayRangeKst } from '../src/lib/open-pass-service';
import { beginResultAccess, recoverExpiredCompatibilityTransactions, failAndRefundResultAccess } from '../src/lib/result-access-service';
import { POST as tarot } from '../src/app/api/public/fortune/tarot/route';
import { POST as compatibility } from '../src/app/api/public/compatibility/request/route';
async function main() {
  assert.equal(process.env.REGRESSION_LOCAL_DB, '1');
  assert.ok(process.env.DATABASE_URL?.includes('/home/user/workspace/'));
  const suffix = randomUUID().slice(0,8);
  const user = await prisma.user.create({ data: { email: `cross_${suffix}@example.com`, nickname: `cross_${suffix}`, passwordHash: 'test' } });
  const policy = await prisma.passPolicy.create({ data: { name: `교차검증 ${suffix}`, passType: 'event', durationMin: 1, grantCount: 10, validityDays: 1, isActive: false } });
  const { userPass } = await grantOpenPass({ userId: user.id, policyId: policy.id, sourceType: 'test_mode' });
  await prisma.wallet.create({ data: { userId: user.id, currencyType: 'POINT', balance: 0 } });
  const old = await prisma.aiPromptTemplate.findMany({ where: { fortuneTypeOrDomain: { in: ['tarot','compatibility'] }, isActive: true } });
  const templateIds: number[] = [];
  const originalFetch = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = async () => { calls++; await new Promise(r=>setTimeout(r,80)); return new Response(JSON.stringify({content:[{type:'text',text:'교차 검증 모의 해석입니다.'}]}),{status:200}); };
  const token = await signUserToken({ userId: user.id, nickname: user.nickname });
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };
  const begin = (id: string, type: string) => beginResultAccess({userId:user.id,transactionId:id,contentType:type,paymentMethod:'FREEPASS'});
  const remaining = async () => (await prisma.userPass.findUniqueOrThrow({where:{id:userPass.id}})).remainingCount;
  const send = async (type: string, id: string) => {
    const body = type === 'tarot' ? {question:'앞으로 전체 운세는 어떻게 될까요?',topic:'cross_unmatched',spreadType:'three_card'} : {type:'friend',nameA:'나',nameB:'상대',birthDateA:'1990-01-01',birthDateB:'1991-02-02'};
    const response = await (type === 'tarot' ? tarot : compatibility)(new NextRequest('http://localhost/test',{method:'POST',headers,body:JSON.stringify({...body,transactionId:id,paymentMethod:'FREEPASS'})}));
    return {status:response.status,body:await response.json()};
  };
  try {
    await prisma.aiPromptTemplate.updateMany({where:{id:{in:old.map(t=>t.id)}},data:{isActive:false}});
    for (const type of ['tarot','compatibility']) templateIds.push((await prisma.aiPromptTemplate.create({data:{fortuneTypeOrDomain:type,version:9999,templateBody:'시험용',isActive:true}})).id);
    // 각 방향에서 마지막 슬롯을 경쟁하도록 실제 두 라우트를 반복한다.
    for (const order of [['tarot','compatibility'],['compatibility','tarot']]) {
      await prisma.fortuneRequest.createMany({data:Array.from({length:4},()=>({userId:user.id,fortuneType:'test',inputPayload:'{}',sourceType:'test',status:'success',pointSpent:0}))});
      const ids = order.map(type=>`${type}_${randomUUID()}`);
      for (let i=0;i<2;i++) await begin(ids[i],order[i]);
      const before = await remaining();
      const outcomes = await Promise.all(order.map((type,i)=>send(type,ids[i])));
      assert.deepEqual(outcomes.map(r=>r.status).sort(),[200,403]);
      assert.equal(await remaining(),before!+1);
      assert.equal((await checkDailyAbsoluteLimit(user.id)).usageCount,5);
      const winner = outcomes.findIndex(r=>r.status===200);
      const beforeRetry = calls;
      assert.equal((await send(order[winner],ids[winner])).status,200);
      assert.equal(calls,beforeRetry);
      console.log(`PASS: ${order.join('↔')} 마지막 슬롯은 1건 성공·1건 403환불, 상한 후 재열람 무생성`);
      await prisma.resultAccessTransaction.deleteMany({where:{userId:user.id}});
      await prisma.fortuneResult.deleteMany({where:{request:{userId:user.id}}});
      await prisma.fortuneRequest.deleteMany({where:{userId:user.id}});
      await prisma.compatibilityResult.deleteMany({where:{request:{requesterUserId:user.id}}});
      await prisma.aiRequestLog.deleteMany({where:{domain:'compatibility',requestRefId:{in:(await prisma.compatibilityRequest.findMany({where:{requesterUserId:user.id},select:{id:true}})).map(r=>r.id)}}});
      await prisma.compatibilityRequest.deleteMany({where:{requesterUserId:user.id}});
    }
    const midnight = new Date('2026-10-13T15:00:00.000Z');
    const beforeMidnight = new Date(midnight.getTime()-1);
    assert.equal(todayRangeKst(beforeMidnight).end.toISOString(),midnight.toISOString());
    assert.equal(todayRangeKst(midnight).start.toISOString(),midnight.toISOString());
    await prisma.fortuneRequest.createMany({data:[beforeMidnight,midnight].map(createdAt=>({userId:user.id,fortuneType:'test',inputPayload:'{}',sourceType:'test',status:'success',pointSpent:0,createdAt}))});
    const id = `boundary_${suffix}`;
    await begin(id,'tarot');
    await prisma.resultAccessTransaction.update({where:{transactionId:id},data:{contentId:'tarot:generating',updatedAt:beforeMidnight}});
    assert.equal((await checkDailyAbsoluteLimit(user.id,prisma,undefined,beforeMidnight)).usageCount,2);
    assert.equal((await checkDailyAbsoluteLimit(user.id,prisma,undefined,midnight)).usageCount,2);
    assert.equal((await checkDailyAbsoluteLimit(user.id,prisma,id,midnight)).usageCount,1);
    await failAndRefundResultAccess(id);
    assert.equal((await checkDailyAbsoluteLimit(user.id,prisma,undefined,midnight)).usageCount,1);
    console.log('PASS: KST 23:59:59.999→00:00:00 성공 날짜 분리, 진행 예약은 자정 넘어 유지, 자신의 예약 중복 제외·환불 예약 해제');
    const staleId = `stale_tarot_${suffix}`;
    await begin(staleId,'tarot');
    const beforeRecovery = await remaining();
    await prisma.resultAccessTransaction.update({where:{transactionId:staleId},data:{contentId:'tarot:generating',updatedAt:new Date(Date.now()-6*60*1000)}});
    await recoverExpiredCompatibilityTransactions(user.id);
    assert.equal(await remaining(),beforeRecovery!+1);
    assert.equal((await prisma.resultAccessTransaction.findUniqueOrThrow({where:{transactionId:staleId}})).status,'refunded');
    console.log('PASS: 오래된 타로 pending도 동일 서버 복구로 1회 환불');
    console.log('교차 콘텐츠·자정 경계 로컬 시험 통과. 모의 LLM/주입 시각이며 운영 실호출·실제 자정 대기 시험 아님.');
  } finally {
    globalThis.fetch=originalFetch;
    await prisma.resultAccessTransaction.deleteMany({where:{userId:user.id}});
    await prisma.fortuneResult.deleteMany({where:{request:{userId:user.id}}});
    await prisma.fortuneRequest.deleteMany({where:{userId:user.id}});
    await prisma.compatibilityResult.deleteMany({where:{request:{requesterUserId:user.id}}});
    await prisma.aiRequestLog.deleteMany({where:{domain:'compatibility',requestRefId:{in:(await prisma.compatibilityRequest.findMany({where:{requesterUserId:user.id},select:{id:true}})).map(r=>r.id)}}});
    await prisma.compatibilityRequest.deleteMany({where:{requesterUserId:user.id}});
    await prisma.userPass.deleteMany({where:{userId:user.id}});
    await prisma.aiPromptTemplate.deleteMany({where:{id:{in:templateIds}}});
    await prisma.aiPromptTemplate.updateMany({where:{id:{in:old.map(t=>t.id)}},data:{isActive:true}});
    await prisma.passPolicy.delete({where:{id:policy.id}});
  }
}
main().then(()=>process.exit(0)).catch(e=>{console.error('TEST FAILED:',e);process.exit(1)});
