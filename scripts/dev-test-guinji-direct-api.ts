// 귀인지도 DIRECT API(members/direct) 수동 통합 테스트.
// 사전조건: `npx next dev -p 3000`이 떠 있어야 한다.
// 실행: npx tsx scripts/dev-test-guinji-direct-api.ts
import { prisma } from "../src/lib/db";
import { calculateSaju, guinjiSajuInputFromManseryeok } from "../src/lib/saju-manseryeok-engine";
import { SignJWT } from "jose";

const secretKey = process.env.SESSION_SECRET;
if (!secretKey) throw new Error("SESSION_SECRET 환경변수가 필요합니다(.env 확인).");
const encodedKey = new TextEncoder().encode(secretKey);

async function signUserToken(payload: { userId: number; nickname: string }): Promise<string> {
  return new SignJWT(payload)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("30d")
    .sign(encodedKey);
}

const BASE_URL = "http://localhost:3000";

let failed = false;
function assert(cond: boolean, msg: string) {
  if (cond) {
    console.log(`  ✅ ${msg}`);
  } else {
    console.error(`  ❌ ${msg}`);
    failed = true;
  }
}

async function ensureTestUser(params: { nickname: string; email: string }) {
  const user = await prisma.user.upsert({
    where: { email: params.email },
    update: {},
    create: {
      email: params.email,
      nickname: params.nickname,
      passwordHash: "test-only-hash",
      status: "active",
    },
  });
  return user;
}

async function main() {
  console.log("── 귀인지도 DIRECT API 테스트 시작 ──");

  const owner = await ensureTestUser({ nickname: "귀인지도DIRECT테스트오너", email: "guinji-direct-test-owner@example.com" });
  const otherOwner = await ensureTestUser({ nickname: "귀인지도DIRECT테스트타인", email: "guinji-direct-test-other@example.com" });

  // 기존 테스트 잔여 데이터 정리
  await prisma.guinjiRelationship.deleteMany({ where: { ownerId: { in: [owner.id, otherOwner.id] } } });
  await prisma.guinjiMapMember.deleteMany({ where: { map: { ownerId: { in: [owner.id, otherOwner.id] } } } });
  await prisma.guinjiMap.deleteMany({ where: { ownerId: { in: [owner.id, otherOwner.id] } } });

  const ownerSaju = guinjiSajuInputFromManseryeok(
    calculateSaju({ year: 1990, month: 5, day: 14, hour: 10, minute: 0, gender: "female", isLunar: false, timeUnknown: false, isLeapMonth: false })
  );

  const map = await prisma.guinjiMap.create({
    data: {
      ownerId: owner.id,
      name: `${owner.nickname}의 지도`,
      token: `test-direct-${Date.now()}`,
      ownerSajuParsed: JSON.stringify(ownerSaju),
    },
  });
  const otherMap = await prisma.guinjiMap.create({
    data: {
      ownerId: otherOwner.id,
      name: `${otherOwner.nickname}의 지도`,
      token: `test-direct-other-${Date.now()}`,
      ownerSajuParsed: JSON.stringify(ownerSaju),
    },
  });

  const ownerToken = await signUserToken({ userId: owner.id, nickname: owner.nickname });
  const otherToken = await signUserToken({ userId: otherOwner.id, nickname: otherOwner.nickname });

  const publicMapId = `gm_${map.id}`;

  console.log("\n[1] 인증 없이 호출 → 401");
  {
    const res = await fetch(`${BASE_URL}/api/public/guinji/maps/${publicMapId}/members/direct`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "테스트지인", gender: "male", solarLunar: "solar", birthDate: "1995-03-10" }),
    });
    assert(res.status === 401, `401 응답 (실제: ${res.status})`);
  }

  console.log("\n[2] 소유자가 지인 직접 추가 → 201 + 관계 판정");
  let memberId: string | undefined;
  {
    const res = await fetch(`${BASE_URL}/api/public/guinji/maps/${publicMapId}/members/direct`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        name: "테스트지인",
        gender: "male",
        solarLunar: "solar",
        birthDate: "1995-03-10",
        birthTime: "14:30",
      }),
    });
    const body = await res.json();
    assert(res.status === 201, `201 응답 (실제: ${res.status}, body: ${JSON.stringify(body)})`);
    assert(body.success === true, "success:true");
    assert(typeof body.data?.memberId === "string", `memberId 존재 (${body.data?.memberId})`);
    assert(typeof body.data?.relationship?.relationType === "string", `relationType 존재 (${body.data?.relationship?.relationType})`);
    assert(typeof body.data?.relationship?.chemistryScore === "number", `chemistryScore 존재 (${body.data?.relationship?.chemistryScore})`);
    assert(body.data?.created === true, "created:true");
    memberId = body.data?.memberId;
  }

  console.log("\n[3] 동일 (이름+생년월일) 재요청 → 200 + created:false (idempotent)");
  {
    const res = await fetch(`${BASE_URL}/api/public/guinji/maps/${publicMapId}/members/direct`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({
        name: "테스트지인",
        gender: "male",
        solarLunar: "solar",
        birthDate: "1995-03-10",
        birthTime: "14:30",
      }),
    });
    const body = await res.json();
    assert(res.status === 200, `200 응답 (실제: ${res.status})`);
    assert(body.data?.created === false, "created:false(중복 방지)");
    assert(body.data?.memberId === memberId, "동일 memberId 재반환");
  }

  console.log("\n[4] 타인의 지도에 호출 → 404(MAP_NOT_FOUND, 소유자 검증)");
  {
    const res = await fetch(`${BASE_URL}/api/public/guinji/maps/${publicMapId}/members/direct`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${otherToken}` },
      body: JSON.stringify({ name: "다른사람시도", gender: "female", solarLunar: "solar", birthDate: "1998-07-07" }),
    });
    const body = await res.json();
    assert(res.status === 404, `404 응답 (실제: ${res.status})`);
    assert(body.success === false, "success:false");
  }

  console.log("\n[5] 성별 누락 → 400");
  {
    const res = await fetch(`${BASE_URL}/api/public/guinji/maps/${publicMapId}/members/direct`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ name: "성별누락", solarLunar: "solar", birthDate: "1995-03-10" }),
    });
    assert(res.status === 400, `400 응답 (실제: ${res.status})`);
  }

  console.log("\n[6] 잘못된 날짜(윤달 아닌데 13월 등) → 400");
  {
    const res = await fetch(`${BASE_URL}/api/public/guinji/maps/${publicMapId}/members/direct`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${ownerToken}` },
      body: JSON.stringify({ name: "잘못된날짜", gender: "male", solarLunar: "solar", birthDate: "1995-02-30" }),
    });
    assert(res.status === 400, `400 응답 (실제: ${res.status})`);
  }

  console.log("\n[7] 생성된 멤버가 joinedUserId:null인지(DB 직접 확인)");
  {
    const dbId = Number((memberId ?? "m_0").replace("m_", ""));
    const member = await prisma.guinjiMapMember.findUnique({ where: { id: dbId } });
    assert(member?.joinedUserId === null, `joinedUserId null (실제: ${member?.joinedUserId})`);
  }

  console.log("\n[8] GET /guinji/maps/me — 새 멤버가 목록에 반영되는지");
  {
    const res = await fetch(`${BASE_URL}/api/public/guinji/maps/me`, {
      headers: { Authorization: `Bearer ${ownerToken}` },
    });
    const body = await res.json();
    const found = (body.data?.members ?? []).find((m: { memberId?: string }) => m.memberId === memberId);
    assert(!!found, `members 목록에 포함됨 (${JSON.stringify(found)})`);
    const rel = (body.data?.relationships ?? []).find((r: { memberId?: string }) => r.memberId === memberId);
    assert(!!rel, `relationships 목록에 포함됨 (${JSON.stringify(rel)})`);
  }

  // 정리
  await prisma.guinjiRelationship.deleteMany({ where: { ownerId: { in: [owner.id, otherOwner.id] } } });
  await prisma.guinjiMapMember.deleteMany({ where: { map: { ownerId: { in: [owner.id, otherOwner.id] } } } });
  await prisma.guinjiMap.deleteMany({ where: { ownerId: { in: [owner.id, otherOwner.id] } } });

  console.log(failed ? "\n❌ 일부 테스트 실패" : "\n✅ 모든 테스트 통과");
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
