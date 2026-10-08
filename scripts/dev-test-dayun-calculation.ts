// [TK-4 "대운 계산 규칙 확정 + 회귀 테스트(성별/입춘/음년)" — §6, PDF §9 T1/T2/T3]
//
// [배경] TK-4의 목표는 "계산 로직을 새로 만드는 것"이 아니다 — saju_engine
// (`/saju/v3/facts`)이 이미 대운 계산을 수행하고 있고, 1장 원칙("계산 엔진은
// 수정하지 않는다")에 따라 이 코드는 엔진을 건드리지 않는다. 이 스크립트의
// 목적은 §6.1~6.3이 명시한 규칙(순행/역행, 대운수, 입춘 경계)을 엔진이 실제로
// 올바르게 구현하고 있는지 "회귀 테스트로 고정"하는 것이다 — 향후 엔진이나
// saju-engine-client.ts가 변경되어도 이 테스트가 즉시 깨지도록 한다.
//
// [검증 항목 — PDF §6.1 원문 검증 예시 + §9 T1/T2/T3]
//   T1/T2: "1972-02-13" 남/여 — 성별만 바꾸면 대운 방향이 전면 반전되는지.
//     PDF 원문 기대값: 남=순행·첫대운癸卯(1979-1988)·대운수8세·2026현재대운丁未(2019-2028)
//                       여=역행·첫대운辛丑(1974-1983)·대운수3세·2026현재대운丙申(2024-2033)
//   T3: 입춘 경계 — 입춘 이전 출생은 연주가 "전년도 간지"로 재판정되는지.
//     1990년 입춘=2/4 기준, 2/2(입춘前)와 2/5(입춘後) 연주를 비교.
//   추가: 음력(is_lunar=true) 입력이 거부되지 않고 정상적으로 만세력 변환되는지.
//
// [실행] 이 스크립트는 getSajuFacts()(SajuFactsCache 경유)를 실제로 호출하므로
// saju_engine(uvicorn, 127.0.0.1:8000)이 실행 중이어야 하고, DB(Prisma)에도
// 접근한다(userId=null로 호출해 특정 사용자에 귀속시키지 않음).
import { getSajuFacts } from "../src/lib/saju-renewal/saju-engine-client";

let failCount = 0;

function assertEqual(label: string, actual: unknown, expected: unknown) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  console.log(`${ok ? "✅" : "❌"} ${label}: 실제=${JSON.stringify(actual)} 기대=${JSON.stringify(expected)}`);
  if (!ok) failCount++;
}

async function main() {
  // ── T1/T2: 1972-02-13 남/여 — 성별만으로 대운 방향 전면 반전(§6.1 원문 검증 예시) ──
  const male = await getSajuFacts({ year: 1972, month: 2, day: 13, hour: 12, minute: 0, gender: "male", isLunar: false });
  const female = await getSajuFacts({ year: 1972, month: 2, day: 13, hour: 12, minute: 0, gender: "female", isLunar: false });

  console.log("\n=== T1: 1972-02-13 남성 ===");
  assertEqual("방향", male.facts.dayun_precise?.direction, "순행");
  assertEqual("첫 대운(월주 다음)", male.facts.luck_pillars?.[1]?.gan_zhi_kr, "계묘");
  assertEqual("첫 대운 시작나이(대운수)", male.facts.luck_pillars?.[1]?.start_age, 8);
  assertEqual("첫 대운 시작연도", male.facts.luck_pillars?.[1]?.start_year, 1979);
  assertEqual("2026년 현재 대운", male.facts.current_luck?.gan_zhi_kr, "정미");
  assertEqual("현재 대운 시작연도", male.facts.current_luck?.start_year, 2019);

  console.log("\n=== T2: 1972-02-13 여성(성별만 반전) ===");
  assertEqual("방향", female.facts.dayun_precise?.direction, "역행");
  assertEqual("첫 대운", female.facts.luck_pillars?.[1]?.gan_zhi_kr, "신축");
  assertEqual("첫 대운 시작나이(대운수)", female.facts.luck_pillars?.[1]?.start_age, 3);
  assertEqual("첫 대운 시작연도", female.facts.luck_pillars?.[1]?.start_year, 1974);
  assertEqual("2026년 현재 대운", female.facts.current_luck?.gan_zhi_kr, "병신");
  assertEqual("현재 대운 시작연도", female.facts.current_luck?.start_year, 2024);

  // 남/여 월주가 동일한지도 확인(순행/역행 판정 외에 다른 변수가 끼어들지 않았는지 검증).
  assertEqual("남/여 월주 동일(가/나 비교 유효성)", male.facts.pillars?.month?.kr, female.facts.pillars?.month?.kr);

  // ── T3: 입춘 경계 — 입춘 이전 출생은 연주=전년도 간지(§6.3) ──
  // 1990년 입춘 = 2/4. 2/2(입춘 전)는 1989년 간지(己巳)와 같아야 하고, 2/5(입춘 후)는 1990년 간지(庚午)로 바뀌어야 한다.
  console.log("\n=== T3: 입춘 경계(1990년 입춘=2/4) ===");
  const beforeLichun = await getSajuFacts({ year: 1990, month: 2, day: 2, hour: 12, minute: 0, gender: "male", isLunar: false });
  const afterLichun = await getSajuFacts({ year: 1990, month: 2, day: 5, hour: 12, minute: 0, gender: "male", isLunar: false });
  const refPrevYear = await getSajuFacts({ year: 1989, month: 12, day: 31, hour: 12, minute: 0, gender: "male", isLunar: false });

  assertEqual("입춘 이전(2/2) 연주 = 전년도(1989) 간지", beforeLichun.facts.pillars?.year?.kr, refPrevYear.facts.pillars?.year?.kr);
  assertEqual("입춘 이전(2/2) 연주", beforeLichun.facts.pillars?.year?.kr, "기사");
  assertEqual("입춘 이후(2/5) 연주 = 당해(1990) 간지", afterLichun.facts.pillars?.year?.kr, "경오");

  // ── 추가: 음력 입력(is_lunar=true) — §6.4 "양/음력 필수, 기본값 없음"이 정상 변환되는지 ──
  console.log("\n=== 추가: 음력 입력 변환 ===");
  const lunarCase = await getSajuFacts({ year: 2000, month: 1, day: 1, hour: 12, minute: 0, gender: "female", isLunar: true });
  // 2000-01-01을 음력으로 해석하면 1999년 음력 섣달(또는 동짓달 근방)이 되어, 연주가 1999년 간지(己卯)가 되어야 한다.
  assertEqual("음력 2000-01-01 → 연주(1999년 간지)", lunarCase.facts.pillars?.year?.kr, "기묘");
  assertEqual("음력 변환 흔적(input.birth_lunar 존재)", typeof lunarCase.facts.input?.birth_lunar === "string" && (lunarCase.facts.input.birth_lunar as string).length > 0, true);

  console.log(failCount === 0 ? "\n✅ TK-4 대운 계산 회귀 테스트 전체 통과" : `\n❌ TK-4 회귀 테스트 ${failCount}건 실패`);
  if (failCount > 0) process.exitCode = 1;
}

main()
  .catch((e) => {
    console.error("테스트 실행 중 오류:", e);
    process.exitCode = 1;
  })
  .finally(async () => {
    const { prisma } = await import("../src/lib/db");
    await prisma.$disconnect();
  });
