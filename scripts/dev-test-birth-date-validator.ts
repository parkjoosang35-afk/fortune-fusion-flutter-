// [신통방통 정통사주 생년월일검증·일일재조회·어뷰징방지 최종지시서 §5/§11/§12]
// saju-birth-date-validator.ts 수동 검증 스크립트. 지시서/설계서가 제시한 예시
// 케이스를 그대로 돌려 기대 결과와 일치하는지 확인한다. 운영 코드에서 import되지
// 않으며, 기존 dev-test-*.ts 스크립트와 동일한 패턴(DB는 실제 dev.db 사용, prisma
// 클라이언트 재사용)을 따른다.
import { prisma } from "../src/lib/db";
import {
  validateBirthDate,
  BirthDateValidationError,
  type BirthDateValidationErrorCode,
} from "../src/lib/saju-birth-date-validator";

let pass = 0;
let fail = 0;

async function expectOk(
  label: string,
  input: Parameters<typeof validateBirthDate>[0]
) {
  try {
    const result = await validateBirthDate(input);
    console.log(`✅ ${label} → 정상 통과 (solar: ${result.solarYear}-${result.solarMonth}-${result.solarDay})`);
    pass++;
  } catch (e) {
    console.error(`❌ ${label} → 정상이어야 하는데 거부됨:`, e instanceof Error ? e.message : e);
    fail++;
  }
}

async function expectReject(
  label: string,
  input: Parameters<typeof validateBirthDate>[0],
  expectedCode: BirthDateValidationErrorCode
) {
  try {
    const result = await validateBirthDate(input);
    console.error(`❌ ${label} → 거부되어야 하는데 통과됨:`, result);
    fail++;
  } catch (e) {
    if (e instanceof BirthDateValidationError && e.code === expectedCode) {
      console.log(`✅ ${label} → 정상 거부(${e.code}): ${e.message}`);
      pass++;
    } else {
      console.error(`❌ ${label} → 다른 이유로 실패:`, e);
      fail++;
    }
  }
}

async function main() {
  console.log("=== 설계서(sintongbangtong-saju-policy) §4.2 / 최종지시서 §5 예시 케이스 ===\n");

  // §5 "예시: 2026년 10월 8일 기준" — 단, 테스트 실행 시점의 서버 "오늘"을 기준으로
  // 하므로, 정상 과거 날짜는 고정값, 미래/범위 케이스는 현재 연도 기준 상대값으로 구성.
  await expectOk("1980-05-10 (정상 과거 날짜)", { birthDate: "1980-05-10" });
  await expectOk("2000-01-01 (정상 과거 날짜)", { birthDate: "2000-01-01" });

  const nextYear = new Date().getUTCFullYear() + 1;
  await expectReject(`${nextYear}-01-01 (내년 → 미래 날짜)`, { birthDate: `${nextYear}-01-01` }, "FUTURE_DATE");
  await expectReject("2099-01-01 (미래 날짜)", { birthDate: "2099-01-01" }, "FUTURE_DATE");
  await expectReject("2300-10-06 (미래 날짜)", { birthDate: "2300-10-06" }, "FUTURE_DATE");

  await expectReject("2026-02-30 (존재하지 않는 날짜)", { birthDate: "2026-02-30" }, "DATE_NOT_EXIST");
  await expectReject("2025-13-01 (존재하지 않는 월)", { birthDate: "2025-13-01" }, "INVALID_FORMAT");
  await expectReject("2023-02-29 (평년 2/29, 존재하지 않음)", { birthDate: "2023-02-29" }, "DATE_NOT_EXIST");
  await expectOk("2024-02-29 (윤년, 정상 허용)", { birthDate: "2024-02-29" });

  await expectReject("1899-12-31 (범위 외, OUT_OF_RANGE)", { birthDate: "1899-12-31" }, "OUT_OF_RANGE");
  await expectOk("1900-01-01 (범위 경계값, 정상 허용)", { birthDate: "1900-01-01" });

  // 오늘 날짜(신생아 사주 등) — 허용되어야 함
  const today = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const todayStr = `${today.getUTCFullYear()}-${String(today.getUTCMonth() + 1).padStart(2, "0")}-${String(today.getUTCDate()).padStart(2, "0")}`;
  await expectOk(`${todayStr} (오늘 날짜, 신생아 사주 허용)`, { birthDate: todayStr });

  // 형식 오류
  await expectReject("1980-5-10 (자리수 부족, 형식 오류)", { birthDate: "1980-5-10" }, "INVALID_FORMAT");
  await expectReject("빈 문자열", { birthDate: "" }, "INVALID_FORMAT");
  await expectReject("19800510 (구분자 없음)", { birthDate: "19800510" }, "INVALID_FORMAT");

  // 음력 입력
  console.log("\n=== 음력 입력 케이스 ===");
  await expectOk("1990-08-15 (음력, 정상 날짜)", { birthDate: "1990-08-15", isLunar: true });
  // 2026년 음력 2월은 29일까지만 존재(윤달 아님) → 30일은 DATE_NOT_EXIST
  await expectReject("2026-02-30 (음력, 존재하지 않는 음력 날짜)", { birthDate: "2026-02-30", isLunar: true }, "DATE_NOT_EXIST");

  // 태어난 시 검증
  console.log("\n=== 태어난 시(hour) 검증 케이스 ===");
  await expectOk("1980-05-10 14시 (정상)", { birthDate: "1980-05-10", birthHour: 14 });
  await expectReject("1980-05-10 24시 (범위 밖)", { birthDate: "1980-05-10", birthHour: 24 }, "INVALID_TIME");
  await expectReject("1980-05-10 -1시 (범위 밖)", { birthDate: "1980-05-10", birthHour: -1 }, "INVALID_TIME");
  await expectOk("1980-05-10 시간모름 플래그(hour 무시)", {
    birthDate: "1980-05-10",
    birthHour: 99,
    birthTimeUnknown: true,
  });

  console.log(`\n=== 결과: ${pass}개 통과 / ${fail}개 실패 ===`);
  if (fail > 0) {
    console.error("❌ 일부 테스트 실패");
    process.exitCode = 1;
  } else {
    console.log("✅ saju-birth-date-validator.ts 전체 검증 통과");
  }

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error("스크립트 실행 중 오류:", e);
  process.exit(1);
});
