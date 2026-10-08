// npm `lunar-javascript`(원저자 6tail, Flutter `lunar` pub.dev 패키지와
// 동일 알고리즘·동일 버전 1.7.7)에는 자체 타입 선언이 없다. 이 파일은
// `saju-manseryeok-engine.ts`에서 실제로 사용하는 표면만 최소로 선언한다
// (전체 API를 다 옮기지 않음 — 필요한 것만 정확히 타입화하는 것이 목적).
declare module "lunar-javascript" {
  export class EightChar {
    getYearGan(): string;
    getYearZhi(): string;
    getMonthGan(): string;
    getMonthZhi(): string;
    getDayGan(): string;
    getDayZhi(): string;
    getTimeGan(): string;
    getTimeZhi(): string;
    getYun(gender: number): Yun;
  }

  export class Yun {
    // [중대 수정 — 2026-09] `getDaYun()`은 npm 원본에서 `n?: number`를
    // 받아 라운드 개수를 지정할 수 있다(생략 시 10). Dart 원본
    // `Yun.getDaYunBy(int n)`과 동일 함수(이름만 다름). index<1(소운기,
    // 빈 간지)을 걸러내려면 넉넉히 가져와야 하므로 인자를 노출한다.
    getDaYun(n?: number): DaYun[];
  }

  export class DaYun {
    // index 0은 "소운기"(출생~첫 대운 시작 전 과도기)로 getGanZhi()가
    // 빈 문자열을 반환한다 — 실제 대운(index>=1)만 걸러내는 데 필요.
    getIndex(): number;
    getStartAge(): number;
    getStartYear(): number;
    getGanZhi(): string;
  }

  export class Lunar {
    static fromYmdHms(
      year: number,
      month: number,
      day: number,
      hour: number,
      minute: number,
      second: number
    ): Lunar;
    // [신통방통 정통사주 생년월일검증 최종지시서 §4 — 음력 입력 검증] 시각 없이
    // 날짜만으로 생성할 때 사용. 존재하지 않는 음력 날짜(윤달 아님 등)를 넣으면
    // 라이브러리가 예외를 던진다(saju-birth-date-validator.ts가 이를 포착해
    // DATE_NOT_EXIST로 변환).
    static fromYmd(year: number, month: number, day: number): Lunar;
    getSolar(): Solar;
    getEightChar(): EightChar;
    toString(): string;
  }

  export class Solar {
    static fromYmdHms(
      year: number,
      month: number,
      day: number,
      hour: number,
      minute: number,
      second: number
    ): Solar;
    getLunar(): Lunar;
    // [saju-birth-date-validator.ts — 음력→양력 변환 결과 연/월/일 추출]
    getYear(): number;
    getMonth(): number;
    getDay(): number;
    toString(): string;
  }
}
