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
    getDaYun(): DaYun[];
  }

  export class DaYun {
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
    toString(): string;
  }
}
