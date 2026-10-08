// [TK-5 "facts 스키마 표준화(사주·대운·세운·십성·용신·신살)" — §5.1·6]
//
// [배경] TK-5의 목표는 saju_engine 응답 스키마를 "새로 설계"하는 것이 아니다 —
// 엔진(`/saju/v3/facts`)은 이미 고정된 응답을 주고, admin_web은 그 응답의
// 소비자일 뿐이다(saju-facts-types.ts 상단 주석 "계산 엔진 코드는 수정하지
// 않는다" 원칙). 이 스크립트는 그 소비자 쪽 타입(SajuV3Facts)이 엔진의 실제
// 응답 전체를 빠짐없이, 정확하게 반영하고 있는지를 실측으로 검증 + 회귀 고정한다.
//
// [TK-5 진행 중 발견/수정 사항]
//   1) policy 필드가 실제 응답에 항상 존재하지만 타입에 없었음 → SajuV3Policy
//      타입 추가로 보강(이 스크립트가 그 존재와 하위 필드를 검증).
//   2) topic-evidence.ts 내부 note 문자열에서 "세운"이라는 용어가 실제로는
//      current_luck(10년 단위 "대운")을 가리키는 데 잘못 쓰이고 있었음 — 진짜
//      세운(연 단위 운세)은 엔진 facts 응답에 전혀 없다(category69.py의
//      _year_rows()에만 존재, /saju/v3/facts에는 없음). 이 스크립트가 그 "세운
//      필드 부재"를 명시적으로 확인해, §10.2 리스크("세운(연도별)은 facts
//      미포함 시 게이트가 검증 불가")가 실제로 이 상태임을 회귀 테스트로 고정한다.
//   3) L1 코어 블록(pillars/day_master/ten_gods/yongshin/luck_pillars/
//      current_luck/relations/sinsal/twelve_stages/zhi_qigan) 전체가 실제
//      응답에 존재하는지 1건의 실측 호출로 스냅샷 검증한다.
import { getSajuFacts } from "../src/lib/saju-renewal/saju-engine-client";
import type { SajuV3Facts } from "../src/lib/saju-renewal/saju-facts-types";

let failCount = 0;

function check(label: string, condition: boolean) {
  console.log(`${condition ? "✅" : "❌"} ${label}`);
  if (!condition) failCount++;
}

function main() {
  return getSajuFacts({
    year: 1990,
    month: 5,
    day: 15,
    hour: 14,
    minute: 30,
    gender: "male",
    isLunar: false,
  }).then(({ facts }) => {
    console.log("=== TK-5 facts 스키마 L1 코어 블록 실존 확인 ===");
    check("pillars(사주 4주) 존재", !!facts.pillars);
    check("pillars.year/month/day/hour 전부 존재", !!(facts.pillars?.year && facts.pillars?.month && facts.pillars?.day && facts.pillars?.hour));
    check("day_master(일간) 존재", !!facts.day_master);
    check("day_master_strength(신강약) 존재", typeof facts.day_master_strength === "string");
    check("five_elements_weighted(오행 가중) 존재", !!facts.five_elements_weighted);
    check("ten_gods(십성) 존재", !!facts.ten_gods);
    check("yongshin(용신) 존재", !!facts.yongshin);
    check("luck_pillars(대운 배열) 존재 및 비어있지 않음", Array.isArray(facts.luck_pillars) && facts.luck_pillars.length > 0);
    check("current_luck(현재 대운) 존재", !!facts.current_luck);
    check("relations(합충형파해) 존재", !!facts.relations);
    check("sinsal(신살 목록) 존재", Array.isArray(facts.sinsal));
    check("twelve_stages(십이운성) 존재", !!facts.twelve_stages);
    check("zhi_qigan(지장간) 존재", !!facts.zhi_qigan);
    check("dayun_precise(대운수 정밀 계산 근거) 존재", !!facts.dayun_precise);

    console.log("\n=== TK-5 신규 보강: policy 필드 ===");
    check("policy 필드 존재(이전엔 타입 미등록)", !!facts.policy);
    check("policy.true_solar(진태양시 적용 여부) boolean", typeof facts.policy?.true_solar === "boolean");
    check("policy.current_year(세운/대운 계산 기준연도) number", typeof facts.policy?.current_year === "number");

    console.log("\n=== TK-5 §10.2 리스크 확인: 세운(연도별) facts 미포함 ===");
    // [중요] "세운"(연 단위 운세, 예: 2026년 운세)은 luck_pillars/current_luck
    // (대운, 10년 단위)과 다른 개념이다. saju_engine /saju/v3/facts는 세운을
    // 전혀 제공하지 않는다 — 있다면 이 테스트가 깨져서 topic-evidence.ts의
    // "세운" 용어 오용을 다시 점검하라는 신호가 되어야 한다.
    const factsAsRecord = facts as unknown as Record<string, unknown>;
    check(
      "facts 응답에 진짜 세운(연도별) 필드가 없음(현재 엔진 한계 — PDF §10.2 리스크와 일치)",
      factsAsRecord.sewoon === undefined &&
        factsAsRecord.annual_luck === undefined &&
        factsAsRecord.year_luck === undefined
    );

    console.log("\n=== TK-5 대운 배열 구조 검증 ===");
    const firstRealPillar = (facts.luck_pillars ?? []).find((lp) => lp.gan_zhi);
    check("luck_pillars 원소가 start_age/start_year/gan_zhi/gan_zhi_kr 4필드를 모두 가짐", !!(
      firstRealPillar &&
      typeof firstRealPillar.start_age === "number" &&
      typeof firstRealPillar.start_year === "number" &&
      typeof firstRealPillar.gan_zhi === "string" &&
      typeof firstRealPillar.gan_zhi_kr === "string"
    ));

    const typed: SajuV3Facts = facts; // 컴파일 타임에 SajuV3Facts로 안전하게 대입되는지 확인(타입 회귀 방지)
    check("SajuV3Facts 타입으로 안전하게 대입됨(컴파일 타임 보장)", !!typed);

    console.log(failCount === 0 ? "\n✅ TK-5 facts 스키마 표준화 검증 전체 통과" : `\n❌ TK-5 검증 ${failCount}건 실패`);
    if (failCount > 0) process.exitCode = 1;
  });
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
