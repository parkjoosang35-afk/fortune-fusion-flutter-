"use client";

// [복주머니 마케팅 쿠폰 최종본 §10 "기존 회원 푸시 알림"] 입력 라벨 9개를 그대로 구현.
// 발송할 쿠폰(캠페인) · 발송 방식(전체/개별) · 발송 대상(전체/신규/기존/지정) ·
// 푸시 제목 · 푸시 내용 · 연결 화면(안내만 표기, 실제 링크는 서버가 결정) ·
// 발송 시점(즉시/예약) · 테스트 발송 · 발송 결과(성공/실패 polling).
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

interface Campaign {
  id: number;
  title: string;
  status: string;
  issuedCount: number;
}

interface SearchedUser {
  id: number;
  nickname: string;
  email: string | null;
}

interface JobStatus {
  id: number;
  status: string;
  successCount: number;
  failCount: number;
  isTest: boolean;
}

export default function BokjuPushSendForm({
  campaigns,
  canWrite,
}: {
  campaigns: Campaign[];
  canWrite: boolean;
}) {
  const router = useRouter();
  const [campaignId, setCampaignId] = useState<number | "">("");
  const [sendMode, setSendMode] = useState<"BROADCAST" | "INDIVIDUAL">("BROADCAST");
  const [targetFilter, setTargetFilter] = useState<"ALL" | "NEW" | "EXISTING">("ALL");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [scheduleMode, setScheduleMode] = useState<"NOW" | "LATER">("NOW");
  const [scheduledAt, setScheduledAt] = useState("");

  // 개별 선물 대상 회원 검색/선택
  const [userQuery, setUserQuery] = useState("");
  const [searchResults, setSearchResults] = useState<SearchedUser[]>([]);
  const [selectedUsers, setSelectedUsers] = useState<SearchedUser[]>([]);

  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState<string | null>(null);
  const [job, setJob] = useState<JobStatus | null>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    if (!userQuery.trim()) {
      setSearchResults([]);
      return;
    }
    const t = setTimeout(async () => {
      const res = await fetch(`/api/admin/bokju-coupons/users-search?q=${encodeURIComponent(userQuery)}`);
      const json = await res.json();
      if (json.success) setSearchResults(json.data.users);
    }, 300);
    return () => clearTimeout(t);
  }, [userQuery]);

  useEffect(() => {
    if (job && (job.status === "PENDING" || job.status === "SENDING")) {
      pollRef.current = setInterval(async () => {
        const res = await fetch(`/api/admin/bokju-coupons/push-jobs/${job.id}`);
        const json = await res.json();
        if (json.success) {
          setJob(json.data);
          if (json.data.status !== "PENDING" && json.data.status !== "SENDING") {
            if (pollRef.current) clearInterval(pollRef.current);
            router.refresh();
          }
        }
      }, 2000);
      return () => {
        if (pollRef.current) clearInterval(pollRef.current);
      };
    }
  }, [job, router]);

  function addUser(u: SearchedUser) {
    if (!selectedUsers.some((s) => s.id === u.id)) setSelectedUsers((prev) => [...prev, u]);
    setUserQuery("");
    setSearchResults([]);
  }
  function removeUser(id: number) {
    setSelectedUsers((prev) => prev.filter((u) => u.id !== id));
  }

  async function submit(isTest: boolean) {
    setError(null);
    if (!campaignId) return setError("발송할 쿠폰(캠페인)을 선택하세요.");
    if (!title.trim()) return setError("푸시 제목을 입력하세요.");
    if (!body.trim()) return setError("푸시 내용을 입력하세요.");
    if (sendMode === "INDIVIDUAL" && selectedUsers.length === 0) {
      return setError("개별 선물 발송은 대상 회원을 1명 이상 선택해야 합니다.");
    }
    if (isTest && selectedUsers.length === 0) {
      return setError("테스트 발송은 확인할 회원을 1명 선택해야 합니다.");
    }

    setPending(isTest ? "test" : "send");
    try {
      const payload: Record<string, unknown> = {
        campaignId,
        sendMode,
        targetFilter: sendMode === "INDIVIDUAL" ? "SPECIFIC" : targetFilter,
        title,
        body,
        isTest,
      };
      if (sendMode === "INDIVIDUAL" || isTest) {
        payload.targetUserIds = selectedUsers.map((u) => u.id);
      }
      if (!isTest && scheduleMode === "LATER" && scheduledAt) {
        payload.scheduledAt = new Date(scheduledAt).toISOString();
      }

      const res = await fetch("/api/admin/bokju-coupons/push", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);

      if (isTest) {
        setError(null);
        alert(`테스트 발송 완료 (알림 생성: ${json.data.created ? "성공" : "대상 회원이 알림 수신을 꺼둠"})`);
      } else {
        setJob({ id: json.data.pushJobId, status: "PENDING", successCount: 0, failCount: 0, isTest: false });
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : "발송 요청 실패");
    } finally {
      setPending(null);
    }
  }

  if (!canWrite) {
    return (
      <div className="rounded-xl border border-slate-200 bg-slate-50 p-5 text-sm text-slate-500">
        이 메뉴에 대한 쓰기 권한이 없습니다. 조회만 가능합니다.
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-slate-200 bg-white p-5">
      {error && (
        <div className="mb-4 rounded-lg border border-rose-300 bg-rose-50 px-4 py-2 text-sm text-rose-700">
          {error}
        </div>
      )}

      {job && (
        <div className="mb-4 rounded-lg bg-slate-50 p-4 text-sm">
          발송 작업 상태: <strong>{job.status}</strong>
          {(job.status === "COMPLETED" || job.status === "PARTIAL" || job.status === "FAILED") && (
            <span className="ml-2">
              성공 <span className="font-semibold text-emerald-700">{job.successCount}</span>건 / 실패{" "}
              <span className="font-semibold text-rose-700">{job.failCount}</span>건
            </span>
          )}
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        {/* 1. 발송할 쿠폰 */}
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">발송할 쿠폰(캠페인)</label>
          <select
            value={campaignId}
            onChange={(e) => setCampaignId(e.target.value ? Number(e.target.value) : "")}
            className="w-full rounded border border-slate-300 px-3 py-2 text-sm"
          >
            <option value="">선택...</option>
            {campaigns.map((c) => (
              <option key={c.id} value={c.id}>
                {c.title} (발행 {c.issuedCount}장, {c.status})
              </option>
            ))}
          </select>
          {campaigns.length === 0 && (
            <p className="mt-1 text-xs text-amber-600">진행중/일시중지 상태의 캠페인이 없습니다. 먼저 캠페인을 만들고 쿠폰을 발행하세요.</p>
          )}
        </div>

        {/* 2. 발송 방식 */}
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">발송 방식</label>
          <div className="flex gap-4 pt-2 text-sm">
            <label className="flex items-center gap-1.5">
              <input
                type="radio"
                checked={sendMode === "BROADCAST"}
                onChange={() => setSendMode("BROADCAST")}
              />
              전체 이벤트 안내
            </label>
            <label className="flex items-center gap-1.5">
              <input
                type="radio"
                checked={sendMode === "INDIVIDUAL"}
                onChange={() => setSendMode("INDIVIDUAL")}
              />
              개별 회원 선물
            </label>
          </div>
        </div>

        {/* 3. 발송 대상 */}
        {sendMode === "BROADCAST" ? (
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">발송 대상</label>
            <select
              value={targetFilter}
              onChange={(e) => setTargetFilter(e.target.value as "ALL" | "NEW" | "EXISTING")}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm"
            >
              <option value="ALL">전체 회원</option>
              <option value="NEW">신규 회원(가입 7일 이내)</option>
              <option value="EXISTING">기존 회원(가입 7일 초과)</option>
            </select>
          </div>
        ) : (
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-600">
              발송 대상 — 선물할 회원 검색(닉네임/이메일)
            </label>
            <input
              type="text"
              value={userQuery}
              onChange={(e) => setUserQuery(e.target.value)}
              placeholder="닉네임 또는 이메일로 검색"
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm"
            />
            {searchResults.length > 0 && (
              <div className="mt-1 max-h-40 overflow-y-auto rounded border border-slate-200 bg-white shadow-sm">
                {searchResults.map((u) => (
                  <button
                    key={u.id}
                    type="button"
                    onClick={() => addUser(u)}
                    className="block w-full px-3 py-1.5 text-left text-sm hover:bg-slate-50"
                  >
                    {u.nickname} {u.email ? `(${u.email})` : ""}
                  </button>
                ))}
              </div>
            )}
            {selectedUsers.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1.5">
                {selectedUsers.map((u) => (
                  <span
                    key={u.id}
                    className="flex items-center gap-1 rounded-full bg-indigo-50 px-2.5 py-1 text-xs text-indigo-700"
                  >
                    {u.nickname}
                    <button type="button" onClick={() => removeUser(u.id)} className="text-indigo-400 hover:text-indigo-700">
                      ✕
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 4. 푸시 제목 */}
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">푸시 제목</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            maxLength={120}
            placeholder="예: 신통방통 복주머니 선물 쿠폰이 도착했어요!"
            className="w-full rounded border border-slate-300 px-3 py-2 text-sm"
          />
        </div>

        {/* 5. 푸시 내용 */}
        <div className="sm:col-span-2">
          <label className="mb-1 block text-xs font-medium text-slate-600">푸시 내용</label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            maxLength={500}
            rows={2}
            placeholder="쿠폰 이벤트 안내 문구를 입력하세요."
            className="w-full rounded border border-slate-300 px-3 py-2 text-sm"
          />
        </div>

        {/* 6. 연결 화면 (서버가 자동 결정 — 안내만 표시) */}
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">연결 화면</label>
          <p className="rounded border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-500">
            {sendMode === "INDIVIDUAL" ? "쿠폰 등록(해당 회원에게 배정된 쿠폰)" : "쿠폰함 또는 쿠폰 등록 안내"}
          </p>
        </div>

        {/* 7. 발송 시점 */}
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-600">발송 시점</label>
          <div className="flex items-center gap-4 pt-2 text-sm">
            <label className="flex items-center gap-1.5">
              <input type="radio" checked={scheduleMode === "NOW"} onChange={() => setScheduleMode("NOW")} />
              즉시
            </label>
            <label className="flex items-center gap-1.5">
              <input type="radio" checked={scheduleMode === "LATER"} onChange={() => setScheduleMode("LATER")} />
              예약
            </label>
            {scheduleMode === "LATER" && (
              <input
                type="datetime-local"
                value={scheduledAt}
                onChange={(e) => setScheduledAt(e.target.value)}
                className="rounded border border-slate-300 px-2 py-1 text-sm"
              />
            )}
          </div>
        </div>
      </div>

      {/* 8. 테스트 발송 / 9. 발송 실행 */}
      <div className="mt-5 flex gap-2 border-t border-slate-100 pt-4">
        <button
          type="button"
          onClick={() => submit(true)}
          disabled={pending !== null}
          className="rounded border border-slate-300 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-100 disabled:opacity-50"
        >
          {pending === "test" ? "발송 중..." : "테스트 발송(관리자 기기 확인)"}
        </button>
        <button
          type="button"
          onClick={() => submit(false)}
          disabled={pending !== null}
          className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
        >
          {pending === "send" ? "발송 요청 중..." : sendMode === "INDIVIDUAL" ? "선물 발송" : "이벤트 안내 발송"}
        </button>
      </div>
      <p className="mt-2 text-xs text-slate-400">
        * 개별 선물은 쿠폰을 먼저 해당 회원에게 배정하고 커밋한 뒤 알림을 보냅니다. 알림 발송이
        실패해도 이미 배정된 쿠폰은 취소되지 않으며, 회원은 쿠폰함에서 바로 확인할 수 있습니다.
      </p>
    </div>
  );
}
