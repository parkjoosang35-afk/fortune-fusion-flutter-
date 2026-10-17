// run-design-tests.ts
// ─────────────────────────────────────────────────────────────────────
// 쿠폰 디자인 스튜디오 — 최소 테스트 하네스 (외부 의존 0)
//
// 왜 필요한가
//   · 대상 프로젝트(admin_web)에는 표준 테스트 러너(vitest/jest/mocha)가 없다.
//   · 기존 테스트 파일은 vitest 문법(describe/it/expect)으로 쓰여 있다.
//   · 그래서 이 파일이 그 3개를 "전역으로 주입"하고 테스트를 직접 실행한다.
//     → 테스트 본문은 한 글자도 고치지 않는다.
//
// 설치
//   이 파일을  scripts/run-design-tests.ts  로 복사
//   package.json scripts 에 한 줄 추가:
//       "test:coupon-design": "tsx scripts/run-design-tests.ts"
//
// 테스트 파일 쪽 수정 (딱 한 줄)
//   `import { describe, it, expect } from 'vitest';`  ← 이 줄을 삭제한다.
//   (describe/it/expect/beforeAll/afterAll 은 이미 전역으로 주입되어 있다)
//
// 실행
//   npm run test:coupon-design
//   npm run test:coupon-design -- -v        (통과 항목까지 전부 출력)
//
// 종료 코드
//   실패 0건 → 0 / 실패 1건 이상 → 1   (CI·배포 파이프라인에서 그대로 사용 가능)
// ─────────────────────────────────────────────────────────────────────
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

type TestCase = { name: string; fn: () => any };
type Hook = () => any;

let queue: TestCase[] = [];

let stack: string[] = [];
let beforeAlls: Hook[] = [];
let afterAlls: Hook[] = [];
let verbose = process.argv.includes('-v') || process.argv.includes('--verbose');

// ── 값 포맷 ──────────────────────────────────────────────────────────
function fmt(v: any): string {
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'function') return `[Function ${v.name || 'anonymous'}]`;
  if (v instanceof RegExp) return String(v);
  try {
    const s = JSON.stringify(v);
    return s === undefined ? String(v) : s.length > 160 ? s.slice(0, 160) + '…' : s;
  } catch {
    return String(v);
  }
}

function deepEqual(a: any, b: any): boolean {
  if (Object.is(a, b)) return true;
  if (typeof a !== typeof b || a === null || b === null) return false;
  if (typeof a !== 'object') return false;
  if (a instanceof Date || b instanceof Date) return a instanceof Date && b instanceof Date && a.getTime() === b.getTime();
  if (a instanceof RegExp || b instanceof RegExp) return String(a) === String(b);
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  return ka.every((k) => deepEqual(a[k], b[k]));
}

// ── expect ───────────────────────────────────────────────────────────
class Expectation {
  constructor(private actual: any, private negated = false) {}

  get not(): Expectation {
    return new Expectation(this.actual, !this.negated);
  }

  private assert(ok: boolean, msg: string): void {
    const good = this.negated ? !ok : ok;
    if (!good) throw new Error((this.negated ? '[not] ' : '') + msg);
  }

  toBe(expected: any): void {
    this.assert(Object.is(this.actual, expected), `expected ${fmt(this.actual)} to be ${fmt(expected)}`);
  }

  toEqual(expected: any): void {
    this.assert(deepEqual(this.actual, expected), `expected ${fmt(this.actual)} to equal ${fmt(expected)}`);
  }

  toContain(needle: any): void {
    const a = this.actual;
    const ok = typeof a === 'string' ? a.includes(needle) : Array.isArray(a) ? a.some((x) => deepEqual(x, needle)) : false;
    this.assert(ok, `expected ${fmt(a)} to contain ${fmt(needle)}`);
  }

  toHaveLength(n: number): void {
    this.assert(this.actual != null && this.actual.length === n, `expected length ${this.actual?.length} to be ${n}`);
  }

  toBeDefined(): void {
    this.assert(this.actual !== undefined, `expected value to be defined`);
  }

  toBeUndefined(): void {
    this.assert(this.actual === undefined, `expected ${fmt(this.actual)} to be undefined`);
  }

  toBeTruthy(): void {
    this.assert(!!this.actual, `expected ${fmt(this.actual)} to be truthy`);
  }

  toBeFalsy(): void {
    this.assert(!this.actual, `expected ${fmt(this.actual)} to be falsy`);
  }

  toBeGreaterThan(n: number): void {
    this.assert(this.actual > n, `expected ${fmt(this.actual)} to be > ${fmt(n)}`);
  }

  toBeGreaterThanOrEqual(n: number): void {
    this.assert(this.actual >= n, `expected ${fmt(this.actual)} to be >= ${fmt(n)}`);
  }

  toBeLessThan(n: number): void {
    this.assert(this.actual < n, `expected ${fmt(this.actual)} to be < ${fmt(n)}`);
  }

  toBeLessThanOrEqual(n: number): void {
    this.assert(this.actual <= n, `expected ${fmt(this.actual)} to be <= ${fmt(n)}`);
  }

  toMatch(pattern: RegExp | string): void {
    const s = String(this.actual);
    const ok = pattern instanceof RegExp ? pattern.test(s) : s.includes(pattern);
    this.assert(ok, `expected ${fmt(s)} to match ${String(pattern)}`);
  }

  toThrow(matcher?: RegExp | string): void {
    if (typeof this.actual !== 'function') throw new Error('toThrow(target) : target must be a function');
    let threw = false;
    let err: any;
    try {
      this.actual();
    } catch (e) {
      threw = true;
      err = e;
    }
    this.assert(threw, `expected function to throw, but it returned normally`);
    if (threw && matcher !== undefined) {
      const msg = String(err?.message ?? err);
      const ok = matcher instanceof RegExp ? matcher.test(msg) : msg.includes(matcher);
      if (!this.negated) {
        if (!ok) throw new Error(`expected thrown message ${fmt(msg)} to match ${String(matcher)}`);
      }
    }
  }
}

// ── 전역 주입 (테스트 파일이 import 없이 쓰도록) ──────────────────────
const registerDescribe = (name: string, fn: () => any): void => {
  stack.push(name);
  try {
    fn();
  } finally {
    stack.pop();
  }
};
(registerDescribe as any).skip = (name: string, fn: () => any): void => {
  stack.push(name);
  skipDepth += 1;
  try { fn(); } finally { skipDepth -= 1; stack.pop(); }
};
(globalThis as any).describe = registerDescribe;
let skipped: string[] = [];
let skipDepth = 0;
const registerIt = (name: string, fn: () => any): void => {
  const full = [...stack, name].join(' › ');
  if (skipDepth > 0) { skipped.push(full); return; }
  queue.push({ name: full, fn });
};
(registerIt as any).skip = (name: string): void => { skipped.push([...stack, name].join(' › ')); };
(registerIt as any).todo = (name: string): void => { skipped.push([...stack, name].join(' › ')); };
(globalThis as any).it = (globalThis as any).test = registerIt;
(globalThis as any).beforeAll = (fn: Hook): void => {
  beforeAlls.push(fn);
};
(globalThis as any).afterAll = (fn: Hook): void => {
  afterAlls.push(fn);
};
(globalThis as any).beforeEach = (): void => {};
(globalThis as any).afterEach = (): void => {};
(globalThis as any).expect = (actual: any): Expectation => new Expectation(actual);

// ── 실행 ─────────────────────────────────────────────────────────────
// [2단계] renderer.ts 가 이제 존재하므로 step2 테스트를 기본 목록에 포함한다.
// 1단계에서 제외했던 이유("렌더러가 없어 로드 자체가 실패한다")가 해소됐다.
// [3단계] revision.ts/dispatch.ts 가 이제 존재하므로 step3 테스트를 추가한다.
// step3 는 이 하네스에서 유일하게 실제 DB(dev.db)를 쓴다 — 테스트 전용
// 캠페인/쿠폰/리비전만 만들고 afterAll 에서 스스로 정리한다(기존 212행/
// 3행은 건드리지 않는다).
// [4단계 작업순서2] studio-api.ts(엔드포인트 5종의 핵심 로직)가 이제
// 존재하므로 step4 테스트를 추가한다. step3 와 동일하게 테스트 전용
// 캠페인만 만들고 afterAll 에서 스스로 정리한다.
const DEFAULT_FILES = [
  'test/design.step1-theme.test.ts',
  'test/design.step1-layout.test.ts',
  'test/design.step2-renderer.test.ts',
  'test/design.step3-revision.test.ts',
  'test/design.step4-studio-api.test.ts',
  'test/design.step4-legacy-convert.test.ts',
];

async function main(): Promise<void> {
  const args = process.argv.slice(2).filter((a) => !a.startsWith('-'));
  const files = args.length ? args : DEFAULT_FILES;

  let passed = 0;
  const failures: Array<{ name: string; message: string }> = [];

  for (const file of files) {
    queue = [];
    stack = [];
    skipped = [];
    beforeAlls = [];
    afterAlls = [];

    console.log(`\n▶ ${file}`);
    const abs = resolve(process.cwd(), file);
    try {
      await import(pathToFileURL(abs).href);
    } catch (e: any) {
      console.log(`  ✗ 파일 로드 실패: ${e?.message ?? e}`);
      failures.push({ name: `${file} (load)`, message: String(e?.stack ?? e) });
      continue;
    }

    for (const h of beforeAlls) await h();

    for (const t of queue) {
      try {
        await t.fn();
        passed += 1;
        if (verbose) console.log(`  ✓ ${t.name}`);
      } catch (e: any) {
        failures.push({ name: t.name, message: String(e?.message ?? e) });
        console.log(`  ✗ ${t.name}`);
      }
    }
    if (!verbose) console.log(`  ${queue.length}건 실행`);

    for (const h of afterAlls) await h();
    if (skipped.length) {
      console.log(`  ${skipped.length}건 건너뜀 (skip/todo)`);
      for (const sName of skipped) console.log(`   ⊘ ${sName}`);
    }
  }

  console.log('\n' + '─'.repeat(60));
  console.log(`  통과 ${passed}건 · 실패 ${failures.length}건`);
  if (failures.length) {
    console.log('\n  실패 상세:');
    for (const f of failures) console.log(`   ✗ ${f.name}\n      ${f.message}`);
    console.log('\n  → 실패가 1건이라도 있으면 exit code 1 로 종료합니다.');
    process.exit(1);
  }
  console.log('  전부 통과했습니다.');
}

main().catch((e) => {
  console.error('하네스 오류:', e);
  process.exit(1);
});
