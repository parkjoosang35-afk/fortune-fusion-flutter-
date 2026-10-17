// test/globals.d.ts
// ─────────────────────────────────────────────────────────────────────
// 테스트 하네스 전역 주입용 타입 선언.
// run-design-tests.ts 가 globalThis 에 describe/it/expect 를 주입하는데,
// tsc 는 그 존재를 모르기 때문에 테스트 파일이 "Cannot find name 'describe'"
// 로 188건씩 에러를 냅니다. 이 선언 하나로 전부 사라집니다.
//
// 설치: 이 파일을 프로젝트의 test/globals.d.ts 로 복사
//       (tsconfig 의 include 에 test/ 가 들어 있으면 자동 인식)
// ─────────────────────────────────────────────────────────────────────

interface CouponDesignExpectation {
  not: CouponDesignExpectation;
  toBe(expected: unknown): void;
  toEqual(expected: unknown): void;
  toContain(needle: unknown): void;
  toHaveLength(n: number): void;
  toBeDefined(): void;
  toBeUndefined(): void;
  toBeTruthy(): void;
  toBeFalsy(): void;
  toBeGreaterThan(n: number): void;
  toBeGreaterThanOrEqual(n: number): void;
  toBeLessThan(n: number): void;
  toBeLessThanOrEqual(n: number): void;
  toMatch(pattern: RegExp | string): void;
  toThrow(matcher?: RegExp | string): void;
}

type CouponDesignIt = {
  (name: string, fn: () => unknown | Promise<unknown>): void;
  skip(name: string): void;
  todo(name: string): void;
};

type CouponDesignDescribe = {
  (name: string, fn: () => unknown): void;
  skip(name: string, fn: () => unknown): void;
};

declare const describe: CouponDesignDescribe;
declare const it: CouponDesignIt;
declare const test: CouponDesignIt;
declare const beforeAll: (fn: () => unknown | Promise<unknown>) => void;
declare const afterAll: (fn: () => unknown | Promise<unknown>) => void;
declare const beforeEach: (fn: () => unknown | Promise<unknown>) => void;
declare const afterEach: (fn: () => unknown | Promise<unknown>) => void;
// vitest/jest 는 expect(값, 실패메시지) 2인자 형태를 허용한다.
// 테스트 파일이 expect(contrastRatio(...), p.id) 처럼 케이스 식별자를 넘기므로
// 두 번째 인자를 반드시 선언해야 TS2554 가 나지 않는다.
declare function expect(actual: unknown, message?: string): CouponDesignExpectation;
