"use client";

// [열림패스/행복머니/복주머니 통합정책] §6 운영 테스트랩 / §7-3 화면 구성 / §12 시나리오 1~8.
// 유저 선택 → 3대 자산 테스트 카드 → 통합 시뮬레이션 → 최근 결과 로그, 전 구간을
// useTransition + 일반 Server Action 직접 호출 패턴으로 구현한다(FormData 불필요).
import { useState, useTransition, useCallback } from "react";
import {
  adminGetUserAssetSnapshot,
  adminSearchUsers,
  adminGrantOpenPass,
  adminForceExpireOpenPass,
  adminRevokeOpenPass,
  adminSimulateOpenPassSource,
  adminManualGrantHappyMoney,
  adminManualDeductHappyMoney,
  adminSimulatePurchaseHappyMoneyProduct,
  adminSimulatePurchaseOpenPassViaHappyMoney,
  adminSimulatePurchaseSubscriptionOrGift,
  adminSimulateInsufficientBalance,
  adminManualGrantLuckPouch,
  adminManualDeductLuckPouch,
  adminSimulateLuckPouchRule,
  adminRunIntegratedScenario,
  adminSimulateAdRewardSuccess,
  adminSimulateAdRewardFail,
  adminSimulateAdRewardNoFill,
  adminSimulateAdRewardCancel,
  adminSimulateAdRewardTimeout,
  adminSetOpenPassRemainingMinutes,
  adminGrantOpenPassAccumulationTest,
  adminPreviewProductAdConfig,
  type SimResult,
} from "@/app/actions/admin-simulation";

interface PolicyOption {
  id: number;
  name: string;
  durationMin: number;
  happyMoneyPrice: number | null;
}
interface ProductOption {
  id: number;
  name: string;
  cashPrice: number;
  happyMoneyAmount: number;
  bonusAmount: number;
}
interface RuleOption {
  id: number;
  name: string;
  ruleType: string;
  actionType: string;
  amount: number;
  cashPrice: number | null;
}

interface LogEntry {
  id: number;
  ok: boolean;
  message: string;
  at: string;
}

interface Snapshot {
  user: { id: number; nickname: string; status: string };
  happyMoneyBalance: number;
  luckPouchBalance: number;
  isOpenPassActive: boolean;
  activeOpenPass: { id: number; policyName: string; expiresAt: string; scope: string } | null;
  openPasses: Array<{ id: number; policyName: string; status: string; sourceType: string; activatedAt: string; expiresAt: string }>;
  recentPointHistory: Array<{ id: number; amount: number; type: string; sourceType: string; memo: string | null; createdAt: string }>;
  recentLuckHistory: Array<{ id: number; amount: number; type: string; sourceType: string; memo: string | null; createdAt: string }>;
}

interface AdSourceOption {
  id: number;
  sourceName: string;
  sourceType: string;
  isActive: boolean;
}

export default function TestLabPanel({
  policies,
  products,
  rules,
  adSources = [],
}: {
  policies: PolicyOption[];
  products: ProductOption[];
  rules: RuleOption[];
  adSources?: AdSourceOption[];
}) {
  const [userId, setUserId] = useState<number>(1);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<Array<{ id: number; nickname: string; email: string | null }>>([]);
  const [snapshot, setSnapshot] = useState<Snapshot | null>(null);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [isPending, startTransition] = useTransition();
  const logIdRef = useState(() => ({ current: 0 }))[0];

  const pushLog = useCallback((r: SimResult) => {
    logIdRef.current += 1;
    setLogs((prev) => [
      { id: logIdRef.current, ok: r.success, message: r.message, at: new Date().toLocaleTimeString("ko-KR") },
      ...prev,
    ].slice(0, 30));
  }, [logIdRef]);

  const refreshSnapshot = useCallback((targetUserId: number) => {
    startTransition(async () => {
      const r = await adminGetUserAssetSnapshot(targetUserId);
      if (r.success) setSnapshot(r.data as unknown as Snapshot);
      else pushLog(r);
    });
  }, [pushLog]);

  const run = useCallback((fn: () => Promise<SimResult>, refresh = true) => {
    startTransition(async () => {
      const r = await fn();
      pushLog(r);
      if (refresh) refreshSnapshot(userId);
    });
  }, [pushLog, refreshSnapshot, userId]);

  const firstPolicyId = policies[0]?.id;
  const [selectedPolicyId, setSelectedPolicyId] = useState<number | undefined>(firstPolicyId);
  const firstProductId = products[0]?.id;
  const [selectedProductId, setSelectedProductId] = useState<number | undefined>(firstProductId);
  const earnRules = rules.filter((r) => r.ruleType === "earn");
  const spendRules = rules.filter((r) => r.ruleType === "spend");
  const purchaseRules = rules.filter((r) => r.ruleType === "purchase");
  const [selectedEarnRuleId, setSelectedEarnRuleId] = useState<number | undefined>(earnRules[0]?.id);
  const [selectedSpendRuleId, setSelectedSpendRuleId] = useState<number | undefined>(spendRules[0]?.id);
  const [selectedPurchaseRuleId, setSelectedPurchaseRuleId] = useState<number | undefined>(purchaseRules[0]?.id);
  const [selectedAdSourceId, setSelectedAdSourceId] = useState<number | undefined>(adSources[0]?.id);

  // [프리패스 테스트 인프라 §8-A] "5분 남음 만들기" / "활성 중 추가지급(누적확인)" 입력값
  const [remainingMinutes, setRemainingMinutes] = useState(5);
  const [accumMinutes, setAccumMinutes] = useState(30);

  const [hmAmount, setHmAmount] = useState(1000);
  const [hmMemo, setHmMemo] = useState("테스트랩 지급");
  const [lpAmount, setLpAmount] = useState(10);
  const [lpMemo, setLpMemo] = useState("테스트랩 지급");
  const [insufficientAmount, setInsufficientAmount] = useState(999999999);
  const [subGiftAmount, setSubGiftAmount] = useState(9900);

  return (
    <div className="space-y-6">
      {/* 1) 유저 선택 */}
      <section className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">1. 테스트 대상 유저 선택</h2>
        <div className="flex flex-wrap items-center gap-2">
          <input
            type="number"
            value={userId}
            onChange={(e) => setUserId(Number(e.target.value))}
            className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
            min={1}
          />
          <button
            onClick={() => refreshSnapshot(userId)}
            disabled={isPending}
            className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            유저 ID로 조회
          </button>
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="닉네임/이메일 검색"
            className="w-48 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
          />
          <button
            onClick={() =>
              startTransition(async () => {
                const r = await adminSearchUsers(searchQuery);
                if (r.success) setSearchResults((r.data?.users as typeof searchResults) ?? []);
              })
            }
            disabled={isPending}
            className="rounded-lg border border-slate-700 px-4 py-2 text-sm text-slate-300 hover:bg-slate-800 disabled:opacity-50"
          >
            검색
          </button>
          {searchResults.length > 0 && (
            <select
              onChange={(e) => {
                const id = Number(e.target.value);
                setUserId(id);
                refreshSnapshot(id);
              }}
              className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
            >
              <option value="">검색 결과 선택...</option>
              {searchResults.map((u) => (
                <option key={u.id} value={u.id}>
                  #{u.id} {u.nickname} ({u.email ?? "-"})
                </option>
              ))}
            </select>
          )}
        </div>

        {snapshot && (
          <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-lg border border-slate-800 bg-slate-950 p-3">
              <p className="text-xs text-slate-500">유저</p>
              <p className="text-sm text-white">
                #{snapshot.user.id} {snapshot.user.nickname}
              </p>
            </div>
            <div className="rounded-lg border border-slate-800 bg-slate-950 p-3">
              <p className="text-xs text-slate-500">열림패스</p>
              <p className={`text-sm font-medium ${snapshot.isOpenPassActive ? "text-emerald-400" : "text-slate-400"}`}>
                {snapshot.isOpenPassActive ? `활성 (${snapshot.activeOpenPass?.policyName})` : "비활성"}
              </p>
            </div>
            <div className="rounded-lg border border-slate-800 bg-slate-950 p-3">
              <p className="text-xs text-slate-500">복주머니(§3 수동조정 경로)</p>
              <p className="text-sm font-medium text-amber-400">{snapshot.happyMoneyBalance.toLocaleString()}개</p>
            </div>
            <div className="rounded-lg border border-slate-800 bg-slate-950 p-3">
              <p className="text-xs text-slate-500">복주머니(§4 규칙기반 경로)</p>
              <p className="text-sm font-medium text-sky-400">{snapshot.luckPouchBalance.toLocaleString()}개</p>
            </div>
          </div>
        )}
      </section>

      {/* 2) 프리패스 테스트 */}
      <section className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">2. 프리패스 테스트</h2>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <span className="text-xs text-slate-500">정책:</span>
          <select
            value={selectedPolicyId}
            onChange={(e) => setSelectedPolicyId(Number(e.target.value))}
            className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
          >
            {policies.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-wrap gap-2">
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminGrantOpenPass({ userId, policyId: selectedPolicyId!, durationOverrideMin: 30 }))} className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50">30분 지급</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminGrantOpenPass({ userId, policyId: selectedPolicyId!, durationOverrideMin: 60 }))} className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50">1시간 지급</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminGrantOpenPass({ userId, policyId: selectedPolicyId!, durationOverrideMin: 1440 }))} className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50">24시간 지급</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminGrantOpenPass({ userId, policyId: selectedPolicyId!, scopeOverride: "fortune_today" }))} className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50">fortune_today만 지급</button>
          <button disabled={isPending || !snapshot?.activeOpenPass} onClick={() => run(() => adminForceExpireOpenPass(snapshot!.activeOpenPass!.id))} className="rounded-lg border border-red-900 px-3 py-1.5 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50">강제 만료</button>
          <button disabled={isPending || !snapshot?.activeOpenPass} onClick={() => run(() => adminRevokeOpenPass(snapshot!.activeOpenPass!.id))} className="rounded-lg border border-red-900 px-3 py-1.5 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50">회수(revoke)</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminSimulateOpenPassSource({ userId, policyId: selectedPolicyId!, source: "ad_reward" }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">광고보상 지급 시뮬</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminSimulateOpenPassSource({ userId, policyId: selectedPolicyId!, source: "purchase" }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">구매 지급 시뮬</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminSimulateOpenPassSource({ userId, policyId: selectedPolicyId!, source: "event" }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">이벤트 지급 시뮬</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminSimulateOpenPassSource({ userId, policyId: selectedPolicyId!, source: "test_mode" }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">테스트 지급 시뮬</button>
        </div>

        {/* [§8-A] 5분 남음 만들기 / 활성 중 추가지급(누적확인) */}
        <div className="mt-3 flex flex-wrap items-center gap-2 border-t border-slate-800 pt-3">
          <span className="text-xs text-slate-500">임박만료 테스트:</span>
          <input
            type="number"
            value={remainingMinutes}
            onChange={(e) => setRemainingMinutes(Number(e.target.value))}
            min={1}
            className="w-20 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1.5 text-xs text-white outline-none focus:border-indigo-500"
          />
          <button
            disabled={isPending || !selectedPolicyId}
            onClick={() => run(() => adminSetOpenPassRemainingMinutes({ userId, policyId: selectedPolicyId!, remainingMinutes }))}
            className="rounded-lg border border-amber-900 px-3 py-1.5 text-xs text-amber-400 hover:bg-amber-950/40 disabled:opacity-50"
          >
            {remainingMinutes}분 남음 만들기
          </button>

          <span className="ml-4 text-xs text-slate-500">누적지급 테스트(활성 중 추가):</span>
          <input
            type="number"
            value={accumMinutes}
            onChange={(e) => setAccumMinutes(Number(e.target.value))}
            min={1}
            className="w-20 rounded-lg border border-slate-700 bg-slate-800 px-2 py-1.5 text-xs text-white outline-none focus:border-indigo-500"
          />
          <button
            disabled={isPending || !selectedPolicyId}
            onClick={() => run(() => adminGrantOpenPassAccumulationTest({ userId, policyId: selectedPolicyId!, durationOverrideMin: accumMinutes }))}
            className="rounded-lg border border-sky-900 px-3 py-1.5 text-xs text-sky-400 hover:bg-sky-950/40 disabled:opacity-50"
          >
            {accumMinutes}분 추가 지급(누적 확인)
          </button>
        </div>
      </section>

      {/* 3) 복주머니 테스트 - 수동조정 · 레거시 구매 카탈로그 경로 (구 "행복머니 테스트") */}
      <section className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">3. 복주머니 테스트 (수동조정 · 레거시 구매 카탈로그)</h2>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <input type="number" value={hmAmount} onChange={(e) => setHmAmount(Number(e.target.value))} className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500" placeholder="금액" />
          <input type="text" value={hmMemo} onChange={(e) => setHmMemo(e.target.value)} className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500" placeholder="메모" />
          <button disabled={isPending} onClick={() => run(() => adminManualGrantHappyMoney({ userId, amount: hmAmount, memo: hmMemo }))} className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50">수동 지급</button>
          <button disabled={isPending} onClick={() => run(() => adminManualDeductHappyMoney({ userId, amount: hmAmount, memo: hmMemo }))} className="rounded-lg border border-red-900 px-3 py-1.5 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50">수동 차감</button>
        </div>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <span className="text-xs text-slate-500">충전상품:</span>
          <select value={selectedProductId} onChange={(e) => setSelectedProductId(Number(e.target.value))} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500">
            {products.map((p) => (
              <option key={p.id} value={p.id}>{p.name}</option>
            ))}
          </select>
          <button disabled={isPending || !selectedProductId} onClick={() => run(() => adminSimulatePurchaseHappyMoneyProduct({ userId, productId: selectedProductId! }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">충전 구매 시뮬</button>
        </div>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <span className="text-xs text-slate-500">열림패스(복주머니 구매):</span>
          <select value={selectedPolicyId} onChange={(e) => setSelectedPolicyId(Number(e.target.value))} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500">
            {policies.map((p) => (
              <option key={p.id} value={p.id}>{p.name}{p.happyMoneyPrice != null ? ` (${p.happyMoneyPrice.toLocaleString()})` : " (구매불가)"}</option>
            ))}
          </select>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminSimulatePurchaseOpenPassViaHappyMoney({ userId, policyId: selectedPolicyId! }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">열림패스 구매 시뮬</button>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <input type="number" value={subGiftAmount} onChange={(e) => setSubGiftAmount(Number(e.target.value))} className="w-28 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500" placeholder="금액" />
          <button disabled={isPending} onClick={() => run(() => adminSimulatePurchaseSubscriptionOrGift({ userId, kind: "subscription", amount: subGiftAmount }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">구독 구매 시뮬</button>
          <button disabled={isPending} onClick={() => run(() => adminSimulatePurchaseSubscriptionOrGift({ userId, kind: "gift", amount: subGiftAmount }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">상품권 구매 시뮬</button>
          <input type="number" value={insufficientAmount} onChange={(e) => setInsufficientAmount(Number(e.target.value))} className="w-32 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500" placeholder="초과 금액" />
          <button disabled={isPending} onClick={() => run(() => adminSimulateInsufficientBalance({ userId, amount: insufficientAmount }), false)} className="rounded-lg border border-amber-900 px-3 py-1.5 text-xs text-amber-400 hover:bg-amber-950/40 disabled:opacity-50">잔액부족 실패 시뮬</button>
        </div>
      </section>

      {/* 4) 복주머니 테스트 - 적립/사용/구매 규칙(LuckPouchRule) 기반 시뮬레이션 */}
      <section className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">4. 복주머니 테스트 (적립/사용/구매 규칙표)</h2>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <input type="number" value={lpAmount} onChange={(e) => setLpAmount(Number(e.target.value))} className="w-24 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500" placeholder="수량" />
          <input type="text" value={lpMemo} onChange={(e) => setLpMemo(e.target.value)} className="w-40 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500" placeholder="메모" />
          <button disabled={isPending} onClick={() => run(() => adminManualGrantLuckPouch({ userId, amount: lpAmount, memo: lpMemo }))} className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50">수동 지급</button>
          <button disabled={isPending} onClick={() => run(() => adminManualDeductLuckPouch({ userId, amount: lpAmount, memo: lpMemo }))} className="rounded-lg border border-red-900 px-3 py-1.5 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50">수동 차감</button>
        </div>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <span className="text-xs text-slate-500">적립 액션:</span>
          <select value={selectedEarnRuleId} onChange={(e) => setSelectedEarnRuleId(Number(e.target.value))} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500">
            {earnRules.map((r) => (<option key={r.id} value={r.id}>{r.name} (+{r.amount})</option>))}
          </select>
          <button disabled={isPending || !selectedEarnRuleId} onClick={() => run(() => adminSimulateLuckPouchRule({ userId, ruleId: selectedEarnRuleId! }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">적립 실행</button>
        </div>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <span className="text-xs text-slate-500">소비 액션(응원/공감/강조/노출강화/부적):</span>
          <select value={selectedSpendRuleId} onChange={(e) => setSelectedSpendRuleId(Number(e.target.value))} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500">
            {spendRules.map((r) => (<option key={r.id} value={r.id}>{r.name} (-{r.amount})</option>))}
          </select>
          <button disabled={isPending || !selectedSpendRuleId} onClick={() => run(() => adminSimulateLuckPouchRule({ userId, ruleId: selectedSpendRuleId! }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">사용 실행</button>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs text-slate-500">구매:</span>
          <select value={selectedPurchaseRuleId} onChange={(e) => setSelectedPurchaseRuleId(Number(e.target.value))} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500">
            {purchaseRules.map((r) => (<option key={r.id} value={r.id}>{r.name}</option>))}
          </select>
          <button disabled={isPending || !selectedPurchaseRuleId} onClick={() => run(() => adminSimulateLuckPouchRule({ userId, ruleId: selectedPurchaseRuleId! }))} className="rounded-lg bg-indigo-950/60 px-3 py-1.5 text-xs text-indigo-300 hover:bg-indigo-900/60 disabled:opacity-50">구매 실행 시뮬</button>
        </div>
      </section>

      {/* 5) 통합 시뮬레이션 */}
      <section className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">5. 통합 시뮬레이션</h2>
        <div className="flex flex-wrap gap-2">
          <button
            disabled={isPending || !selectedProductId || !selectedPolicyId}
            onClick={() => run(() => adminRunIntegratedScenario({ scenarioKey: "purchase_happy_money_then_open_pass", userId, productId: selectedProductId, policyId: selectedPolicyId }))}
            className="rounded-lg border border-emerald-900 px-3 py-1.5 text-xs text-emerald-400 hover:bg-emerald-950/40 disabled:opacity-50"
          >
            충전→열림패스구매→해제확인
          </button>
          <button
            disabled={isPending || !selectedEarnRuleId || !selectedSpendRuleId}
            onClick={() => run(() => adminRunIntegratedScenario({ scenarioKey: "earn_luck_pouch_then_spend", userId, earnRuleId: selectedEarnRuleId, spendRuleId: selectedSpendRuleId }))}
            className="rounded-lg border border-emerald-900 px-3 py-1.5 text-xs text-emerald-400 hover:bg-emerald-950/40 disabled:opacity-50"
          >
            적립→응원사용→잔액확인
          </button>
          <button
            disabled={isPending || !selectedSpendRuleId}
            onClick={() => run(() => adminRunIntegratedScenario({ scenarioKey: "luck_pouch_highlight", userId, spendRuleId: selectedSpendRuleId }))}
            className="rounded-lg border border-emerald-900 px-3 py-1.5 text-xs text-emerald-400 hover:bg-emerald-950/40 disabled:opacity-50"
          >
            글강조적용확인
          </button>
          <button
            disabled={isPending}
            onClick={() => run(() => adminRunIntegratedScenario({ scenarioKey: "expire_open_pass_then_relock", userId }))}
            className="rounded-lg border border-emerald-900 px-3 py-1.5 text-xs text-emerald-400 hover:bg-emerald-950/40 disabled:opacity-50"
          >
            만료→재잠금확인
          </button>
          <button
            disabled={isPending}
            onClick={() => run(() => adminRunIntegratedScenario({ scenarioKey: "policy_reload_check", userId }), false)}
            className="rounded-lg border border-emerald-900 px-3 py-1.5 text-xs text-emerald-400 hover:bg-emerald-950/40 disabled:opacity-50"
          >
            정책변경→앱반영안내
          </button>
        </div>
      </section>

      {/* 7) 프리패스 광고 보상 시뮬레이션 */}
      <section className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">7. 프리패스 광고 보상 시뮬레이션 (성공/실패/no-fill/취소/타임아웃/설정미리보기)</h2>
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <span className="text-xs text-slate-500">정책:</span>
          <select value={selectedPolicyId} onChange={(e) => setSelectedPolicyId(Number(e.target.value))} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500">
            {policies.map((p) => (<option key={p.id} value={p.id}>{p.name}</option>))}
          </select>
          <span className="text-xs text-slate-500">광고소스:</span>
          <select value={selectedAdSourceId} onChange={(e) => setSelectedAdSourceId(Number(e.target.value))} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500">
            {adSources.map((a) => (<option key={a.id} value={a.id}>{a.sourceName}{a.isActive ? "" : " (비활성)"}</option>))}
          </select>
        </div>
        <div className="flex flex-wrap gap-2">
          <button disabled={isPending || !selectedPolicyId || !selectedAdSourceId} onClick={() => run(() => adminSimulateAdRewardSuccess({ userId, policyId: selectedPolicyId!, adSourceId: selectedAdSourceId! }))} className="rounded-lg bg-emerald-950/60 px-3 py-1.5 text-xs text-emerald-400 hover:bg-emerald-900/60 disabled:opacity-50">광고 성공→보상지급</button>
          <button disabled={isPending || !selectedAdSourceId} onClick={() => run(() => adminSimulateAdRewardFail({ userId, adSourceId: selectedAdSourceId!, policyId: selectedPolicyId }))} className="rounded-lg border border-red-900 px-3 py-1.5 text-xs text-red-400 hover:bg-red-950/40 disabled:opacity-50">광고 실패→fallback</button>
          <button disabled={isPending || !selectedAdSourceId} onClick={() => run(() => adminSimulateAdRewardNoFill({ userId, adSourceId: selectedAdSourceId!, policyId: selectedPolicyId }))} className="rounded-lg border border-amber-900 px-3 py-1.5 text-xs text-amber-400 hover:bg-amber-950/40 disabled:opacity-50">no-fill→fallback</button>
          <button disabled={isPending || !selectedAdSourceId} onClick={() => run(() => adminSimulateAdRewardCancel({ userId, adSourceId: selectedAdSourceId!, policyId: selectedPolicyId }))} className="rounded-lg border border-orange-900 px-3 py-1.5 text-xs text-orange-400 hover:bg-orange-950/40 disabled:opacity-50">중도취소→fallback</button>
          <button disabled={isPending || !selectedAdSourceId} onClick={() => run(() => adminSimulateAdRewardTimeout({ userId, adSourceId: selectedAdSourceId!, policyId: selectedPolicyId }))} className="rounded-lg border border-rose-900 px-3 py-1.5 text-xs text-rose-400 hover:bg-rose-950/40 disabled:opacity-50">타임아웃→fallback</button>
          <button disabled={isPending || !selectedPolicyId} onClick={() => run(() => adminPreviewProductAdConfig({ policyId: selectedPolicyId! }), false)} className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-800 disabled:opacity-50">상품 광고설정 미리보기</button>
        </div>
      </section>

      {/* 6) 최근 시뮬레이션 결과 */}
      <section className="rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h2 className="mb-3 text-sm font-semibold text-white">6. 최근 시뮬레이션 결과</h2>
        {logs.length === 0 ? (
          <p className="text-sm text-slate-500">아직 실행한 테스트가 없습니다.</p>
        ) : (
          <ul className="space-y-2">
            {logs.map((log) => (
              <li
                key={log.id}
                className={`whitespace-pre-wrap rounded-lg border px-3 py-2 text-xs ${
                  log.ok ? "border-emerald-900/60 bg-emerald-950/30 text-emerald-300" : "border-red-900/60 bg-red-950/30 text-red-300"
                }`}
              >
                <span className="mr-2 text-slate-500">[{log.at}]</span>
                {log.message}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
