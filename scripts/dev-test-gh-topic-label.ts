// [2026-11 궁합 주제 반영 지시서] /gh/[token] 랜딩 페이지의 주제 라벨 반영
// (gh/[token]/page.tsx diff) 실 서버 검증. 로그인 사용자로 majorId 포함
// 초대를 생성한 뒤, 공개 랜딩 페이지 HTML에 주제 라벨(예: "연애 궁합")과
// OG 메타 태그가 반영되는지 확인한다. 읽기 전용 검증 + 테스트 계정만 사용.
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
  if (cond) console.log(`  ✅ ${msg}`);
  else { console.error(`  ❌ ${msg}`); failed = true; }
}

async function ensureTestUser(params: { nickname: string; email: string }) {
  const user = await prisma.user.upsert({
    where: { email: params.email },
    update: {},
    create: {
      email: params.email,
      nickname: params.nickname,
      gender: "female",
      passwordHash: "test-only-hash",
      status: "active",
    },
  });
  return user;
}

const SAMPLE_SAJU = guinjiSajuInputFromManseryeok(
  calculateSaju({ year: 1995, month: 3, day: 14, gender: "female", timeUnknown: true }),
);

async function main() {
  console.log("=== /gh/[token] 주제 라벨 반영 검증 (gh-topic-label diff) ===\n");

  const owner = await ensureTestUser({
    nickname: "GH라벨테스트유저",
    email: "gh_topic_label_test_owner@example.test",
  });
  const token = await signUserToken({ userId: owner.id, nickname: owner.nickname });

  console.log("[1] majorId='love', subName='썸 궁합' 포함 초대 생성");
  const createRes = await fetch(`${BASE_URL}/api/public/gunghap/invites`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ ownerName: owner.nickname, saju: SAMPLE_SAJU, majorId: "love", subName: "썸 궁합" }),
  });
  const createJson = await createRes.json();
  assert(createRes.status === 200 || createRes.status === 201, `생성 응답 상태 ${createRes.status}`);
  console.log("  응답:", JSON.stringify(createJson).slice(0, 300));
  const inviteToken = createJson?.data?.token ?? createJson?.token;
  assert(!!inviteToken, `초대 토큰 발급됨: ${inviteToken}`);

  if (!inviteToken) {
    console.error("토큰이 없어 이후 단계를 진행할 수 없습니다.");
    process.exit(1);
  }

  console.log("\n[2] GET /gh/{token} 랜딩 페이지 HTML 조회 (주제 라벨 확인)");
  const pageRes = await fetch(`${BASE_URL}/gh/${inviteToken}`);
  const html = await pageRes.text();
  assert(pageRes.status === 200, `페이지 응답 상태 ${pageRes.status}`);

  // OG 메타 태그 확인
  const ogTitleMatch = html.match(/<meta property="og:title" content="([^"]*)"/);
  const ogDescMatch = html.match(/<meta property="og:description" content="([^"]*)"/);
  console.log("  og:title =", ogTitleMatch?.[1]);
  console.log("  og:description =", ogDescMatch?.[1]);
  assert(!!ogTitleMatch && ogTitleMatch[1].includes("연애"), `og:title에 '연애' 포함: "${ogTitleMatch?.[1]}"`);
  assert(!!ogDescMatch && ogDescMatch[1].includes("연애"), `og:description에 '연애' 포함: "${ogDescMatch?.[1]}"`);

  console.log("\n[3] majorId 없는(레거시) 초대와 비교 — 기존 문구 유지되는지 확인");
  const createRes2 = await fetch(`${BASE_URL}/api/public/gunghap/invites`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}` },
    body: JSON.stringify({ ownerName: owner.nickname, saju: SAMPLE_SAJU }),
  });
  const createJson2 = await createRes2.json();
  const inviteToken2 = createJson2?.data?.token ?? createJson2?.token;
  assert(!!inviteToken2, `레거시 초대 토큰 발급됨: ${inviteToken2}`);
  const pageRes2 = await fetch(`${BASE_URL}/gh/${inviteToken2}`);
  const html2 = await pageRes2.text();
  const ogTitleMatch2 = html2.match(/<meta property="og:title" content="([^"]*)"/);
  console.log("  (레거시) og:title =", ogTitleMatch2?.[1]);
  assert(!!ogTitleMatch2 && ogTitleMatch2[1].includes("궁합지도 초대장") && !ogTitleMatch2[1].includes("연애"), `레거시 초대는 주제 없이 기존 문구 유지: "${ogTitleMatch2?.[1]}"`);

  console.log("\n[4] 본문(body) 내 분야 라벨 노출 여부 확인 (화면에 보이는 텍스트)");
  assert(html.includes("연애") , "본문 HTML에 '연애' 텍스트 포함 (화면 표시 추정)");

  console.log(failed ? "\n❌ 일부 검증 실패" : "\n✅ 전체 검증 통과");
  process.exit(failed ? 1 : 0);
}

main().catch((e) => { console.error("실행 중 오류:", e); process.exit(1); });
