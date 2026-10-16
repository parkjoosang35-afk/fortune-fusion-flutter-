"use client";

// [신통방통 AI 쿠폰 디자인 표시·숨김 기능 §4/§5/§6/§9] 관리자 "AI 쿠폰 디자인"
// 화면의 클라이언트 컴포넌트. 3개 패널로 구성:
//   1) AI 배경 생성 요청 + 생성된 배경 목록(선택)
//   2) 11개 표시/숨김 체크박스 + 이름/기본지정 + 저장
//   3) 실시간 미리보기(디바운스 PNG) + 저장된 템플릿 목록(복사/보관/기본지정/삭제)
//
// [§3 "표시 설정과 실제 쿠폰 기능 분리"] 이 화면은 오직 "이미지에 무엇을
// 그릴지"만 다룬다. 실제 쿠폰 발행/등록/검증 로직은 이 화면에서 전혀
// 호출하지 않는다(별도 "쿠폰 만들기" 화면에서 템플릿을 "선택"만 한다).
import { useCallback, useEffect, useRef, useState } from "react";
import {
  VISIBILITY_FIELD_LABELS,
  VISIBILITY_FIELD_ORDER,
  DEFAULT_VISIBILITY,
  type CouponVisibilityConfig,
} from "@/lib/bokju-coupon-visibility";

interface DesignAsset {
  id: number;
  prompt: string;
  imagePath: string;
  status: string;
  failReason: string | null;
  createdAt: string;
}

interface DesignTemplate {
  id: number;
  name: string;
  designAssetId: number | null;
  backgroundImagePath: string | null;
  visibility: CouponVisibilityConfig;
  isDefault: boolean;
  isArchived: boolean;
  campaignCount: number;
  createdAt: string;
  updatedAt: string;
}

const PROMPT_EXAMPLES = [
  "빨간색과 금색의 고급스러운 전통 쿠폰",
  "분홍색 꽃무늬 신규회원 쿠폰",
  "남색과 금색의 제휴업체 쿠폰",
  "명절 분위기의 이벤트 쿠폰",
  "깔끔하고 현대적인 선물 쿠폰",
];

async function fetchJson(url: string, init?: RequestInit) {
  const res = await fetch(url, init);
  const json = await res.json();
  if (!json.success) throw new Error(json.error || "요청 실패");
  return json.data;
}

export default function BokjuDesignTemplateManager({ canWrite }: { canWrite: boolean }) {
  const [assets, setAssets] = useState<DesignAsset[]>([]);
  const [templates, setTemplates] = useState<DesignTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // ── AI 배경 요청 상태 ──
  const [prompt, setPrompt] = useState("");
  const [generating, setGenerating] = useState(false);
  const [genError, setGenError] = useState<string | null>(null);

  // ── 편집 중인 템플릿 상태(새로 만들기/기존 수정 공용) ──
  const [editingId, setEditingId] = useState<number | null>(null); // null이면 "새로 저장"
  const [name, setName] = useState("");
  const [selectedAssetId, setSelectedAssetId] = useState<number | null>(null);
  const [visibility, setVisibility] = useState<CouponVisibilityConfig>({ ...DEFAULT_VISIBILITY });
  const [isDefault, setIsDefault] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saveOk, setSaveOk] = useState<string | null>(null);

  // ── 실시간 미리보기 ──
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const reload = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [assetData, tplData] = await Promise.all([
        fetchJson("/api/admin/bokju-coupons/design-assets"),
        fetchJson("/api/admin/bokju-coupons/design-templates?includeArchived=1"),
      ]);
      setAssets(assetData.assets);
      setTemplates(tplData.templates);
    } catch (e) {
      setError(e instanceof Error ? e.message : "목록 조회 실패");
    } finally {
      setLoading(false);
    }
  }, []);

  // [react-hooks/set-state-in-effect 회피 — BokjuCouponShareSection.tsx와 동일
  // 패턴] 외부에서 재사용 가능한 reload()를 직접 effect 본문에서 호출하는 대신,
  // effect 전용 inline async 함수 + cancelled 플래그로 최초 1회 로드를 감싼다.
  useEffect(() => {
    let cancelled = false;
    async function initialLoad() {
      setLoading(true);
      setError(null);
      try {
        const [assetData, tplData] = await Promise.all([
          fetchJson("/api/admin/bokju-coupons/design-assets"),
          fetchJson("/api/admin/bokju-coupons/design-templates?includeArchived=1"),
        ]);
        if (cancelled) return;
        setAssets(assetData.assets);
        setTemplates(tplData.templates);
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : "목록 조회 실패");
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    void initialLoad();
    return () => {
      cancelled = true;
    };
  }, []);

  // [§5 실시간 미리보기] visibility/selectedAssetId/name이 바뀔 때마다 500ms
  // 디바운스 후 미리보기 PNG를 다시 요청한다.
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      const qs = new URLSearchParams({
        visibility: JSON.stringify(visibility),
        title: name.trim() || "신통방통 복주머니 선물",
      });
      if (selectedAssetId) qs.set("designAssetId", String(selectedAssetId));
      setPreviewUrl(`/api/admin/bokju-coupons/design-templates/preview?${qs.toString()}`);
    }, 400);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [visibility, selectedAssetId, name]);

  if (loading) return <p className="text-sm text-slate-500">불러오는 중...</p>;

  function resetEditor() {
    setEditingId(null);
    setName("");
    setSelectedAssetId(null);
    setVisibility({ ...DEFAULT_VISIBILITY });
    setIsDefault(false);
    setSaveError(null);
    setSaveOk(null);
  }

  function loadTemplateIntoEditor(t: DesignTemplate) {
    setEditingId(t.id);
    setName(t.name);
    setSelectedAssetId(t.designAssetId);
    setVisibility({ ...t.visibility });
    setIsDefault(t.isDefault);
    setSaveError(null);
    setSaveOk(null);
  }

  async function requestAiBackground() {
    if (!prompt.trim()) {
      setGenError("배경 요청 문구를 입력해 주세요.");
      return;
    }
    setGenerating(true);
    setGenError(null);
    try {
      await fetchJson("/api/admin/bokju-coupons/design-assets", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt: prompt.trim() }),
      });
      setPrompt("");
      await reload();
    } catch (e) {
      // [정직한 실패 원칙] AI 미설정/호출 실패를 화면에 그대로 노출한다.
      setGenError(e instanceof Error ? e.message : "배경 생성 실패");
      await reload(); // 실패 이력도 목록에 반영(재시도 판단에 참고)
    } finally {
      setGenerating(false);
    }
  }

  async function saveTemplate() {
    if (!name.trim()) {
      setSaveError("템플릿 이름을 입력해 주세요.");
      return;
    }
    setSaving(true);
    setSaveError(null);
    setSaveOk(null);
    try {
      if (editingId) {
        await fetchJson(`/api/admin/bokju-coupons/design-templates/${editingId}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, designAssetId: selectedAssetId, visibility, isDefault }),
        });
        setSaveOk("저장되었습니다.");
      } else {
        const created = await fetchJson("/api/admin/bokju-coupons/design-templates", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, designAssetId: selectedAssetId, visibility, isDefault }),
        });
        setEditingId(created.id);
        setSaveOk("새 템플릿으로 저장되었습니다.");
      }
      await reload();
    } catch (e) {
      setSaveError(e instanceof Error ? e.message : "저장 실패");
    } finally {
      setSaving(false);
    }
  }

  async function duplicateTemplate(t: DesignTemplate) {
    try {
      await fetchJson(`/api/admin/bokju-coupons/design-templates/${t.id}/duplicate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "복사 실패");
    }
  }

  async function toggleArchive(t: DesignTemplate) {
    try {
      await fetchJson(`/api/admin/bokju-coupons/design-templates/${t.id}/archive`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ archived: !t.isArchived }),
      });
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "상태 변경 실패");
    }
  }

  async function setDefault(t: DesignTemplate) {
    try {
      await fetchJson(`/api/admin/bokju-coupons/design-templates/${t.id}/set-default`, { method: "POST" });
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "기본 지정 실패");
    }
  }

  async function removeTemplate(t: DesignTemplate) {
    if (!confirm(`"${t.name}" 템플릿을 삭제할까요? (사용 중인 캠페인이 있으면 삭제할 수 없습니다)`)) return;
    try {
      await fetchJson(`/api/admin/bokju-coupons/design-templates/${t.id}`, { method: "DELETE" });
      if (editingId === t.id) resetEditor();
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "삭제 실패");
    }
  }

  return (
    <div className="space-y-6">
      {error && (
        <div className="rounded-lg border border-rose-300 bg-rose-50 px-4 py-2 text-sm text-rose-800">{error}</div>
      )}

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* ── 1) AI 배경 생성 ── */}
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="mb-1 text-sm font-semibold text-slate-900">1. AI 배경 생성</h2>
          <p className="mb-3 text-xs text-slate-500">
            원하는 분위기를 문장으로 입력하세요. AI는 배경만 생성하며, 쿠폰명·번호·QR·수량은
            시스템이 별도로 배치합니다.
          </p>

          {canWrite && (
            <>
              <textarea
                value={prompt}
                onChange={(e) => setPrompt(e.target.value)}
                placeholder="예: 빨간색과 금색의 고급스러운 전통 쿠폰"
                rows={3}
                className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
              />
              <div className="mt-2 flex flex-wrap gap-1">
                {PROMPT_EXAMPLES.map((ex) => (
                  <button
                    key={ex}
                    type="button"
                    onClick={() => setPrompt(ex)}
                    className="rounded-full border border-slate-200 bg-slate-50 px-2 py-1 text-[11px] text-slate-500 hover:bg-slate-100"
                  >
                    {ex}
                  </button>
                ))}
              </div>
              <button
                type="button"
                onClick={requestAiBackground}
                disabled={generating}
                className="mt-3 w-full rounded bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
              >
                {generating ? "AI 배경 생성 중..." : "AI에게 배경 요청하기"}
              </button>
              {genError && (
                <p className="mt-2 rounded border border-amber-300 bg-amber-50 px-2 py-1.5 text-xs text-amber-800">
                  {genError}
                </p>
              )}
            </>
          )}

          <h3 className="mb-2 mt-5 text-xs font-semibold text-slate-700">생성된 배경 목록</h3>
          <div className="max-h-[480px] space-y-2 overflow-y-auto">
            <button
              type="button"
              onClick={() => setSelectedAssetId(null)}
              className={`flex w-full items-center gap-2 rounded-lg border p-2 text-left text-xs transition ${
                selectedAssetId === null ? "border-indigo-500 bg-indigo-50 ring-1 ring-indigo-500" : "border-slate-200 hover:bg-slate-50"
              }`}
            >
              <div className="flex h-12 w-9 shrink-0 items-center justify-center rounded border border-dashed border-slate-300 bg-slate-50 text-[9px] text-slate-400">
                흰배경
              </div>
              <span className="text-slate-600">배경 없음(흰 배경 기본값)</span>
            </button>
            {assets.map((a) => (
              <button
                key={a.id}
                type="button"
                disabled={a.status !== "READY"}
                onClick={() => setSelectedAssetId(a.id)}
                className={`flex w-full items-start gap-2 rounded-lg border p-2 text-left text-xs transition disabled:cursor-not-allowed disabled:opacity-60 ${
                  selectedAssetId === a.id ? "border-indigo-500 bg-indigo-50 ring-1 ring-indigo-500" : "border-slate-200 hover:bg-slate-50"
                }`}
              >
                {a.status === "READY" ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={a.imagePath} alt={a.prompt} className="h-12 w-9 shrink-0 rounded object-cover" />
                ) : (
                  <div className="flex h-12 w-9 shrink-0 items-center justify-center rounded border border-dashed border-rose-300 bg-rose-50 text-[9px] text-rose-500">
                    {a.status === "GENERATING" ? "생성중" : "실패"}
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-slate-800">{a.prompt}</p>
                  {a.status === "FAILED" && a.failReason && (
                    <p className="mt-0.5 truncate text-[10px] text-rose-600">{a.failReason}</p>
                  )}
                </div>
              </button>
            ))}
            {assets.length === 0 && (
              <p className="py-4 text-center text-xs text-slate-400">아직 생성된 배경이 없습니다.</p>
            )}
          </div>
        </div>

        {/* ── 2) 표시/숨김 11개 + 이름/기본/저장 ── */}
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="mb-1 text-sm font-semibold text-slate-900">
            2. 표시 항목 선택 {editingId ? `(수정 중: #${editingId})` : "(새 템플릿)"}
          </h2>
          <p className="mb-3 text-xs text-slate-500">
            체크 해제한 항목은 이미지에서 빠지고, 남은 항목이 자동으로 당겨 배치됩니다. 표시
            여부는 이미지에만 영향을 주며, 실제 등록/검증/지급 기능과는 무관합니다.
          </p>

          <label className="mb-1 block text-xs text-slate-500">템플릿 이름 *</label>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="예: 설날 이벤트용"
            disabled={!canWrite}
            className="mb-3 w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
          />

          <div className="space-y-1.5">
            {VISIBILITY_FIELD_ORDER.map((key) => (
              <label key={key} className="flex items-center gap-2 rounded px-1 py-1 text-sm text-slate-700 hover:bg-slate-50">
                <input
                  type="checkbox"
                  disabled={!canWrite}
                  checked={visibility[key]}
                  onChange={(e) => setVisibility((prev) => ({ ...prev, [key]: e.target.checked }))}
                  className="h-4 w-4 rounded border-slate-300"
                />
                {VISIBILITY_FIELD_LABELS[key]}
              </label>
            ))}
          </div>

          {canWrite && (
            <>
              <label className="mt-3 flex items-center gap-2 text-xs text-slate-600">
                <input
                  type="checkbox"
                  checked={isDefault}
                  onChange={(e) => setIsDefault(e.target.checked)}
                  className="h-4 w-4 rounded border-slate-300"
                />
                쿠폰 만들기 화면의 기본 템플릿으로 지정
              </label>

              <div className="mt-4 flex gap-2">
                <button
                  type="button"
                  onClick={saveTemplate}
                  disabled={saving}
                  className="flex-1 rounded bg-indigo-600 px-3 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
                >
                  {saving ? "저장 중..." : editingId ? "변경사항 저장" : "새 템플릿으로 저장"}
                </button>
                {editingId && (
                  <button
                    type="button"
                    onClick={resetEditor}
                    className="rounded border border-slate-300 px-3 py-2 text-sm text-slate-600 hover:bg-slate-100"
                  >
                    새로 만들기
                  </button>
                )}
              </div>
              {saveError && <p className="mt-2 text-xs text-rose-700">{saveError}</p>}
              {saveOk && <p className="mt-2 text-xs text-emerald-700">{saveOk}</p>}
            </>
          )}
        </div>

        {/* ── 3) 실시간 미리보기 + 저장된 템플릿 목록 ── */}
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <h2 className="mb-1 text-sm font-semibold text-slate-900">3. 실시간 미리보기</h2>
          <p className="mb-3 text-xs text-slate-500">샘플 데이터로 즉시 반영됩니다. 실제 발행 시에는 진짜 쿠폰 데이터로 렌더링됩니다.</p>
          <div className="flex justify-center rounded-lg bg-slate-100 p-3">
            {previewUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={previewUrl}
                alt="쿠폰 디자인 미리보기"
                className="h-auto w-full max-w-[220px] rounded-lg border border-slate-200 shadow-sm"
              />
            ) : (
              <div className="flex h-[320px] w-[180px] items-center justify-center text-xs text-slate-400">
                미리보기 로딩 중...
              </div>
            )}
          </div>

          <h3 className="mb-2 mt-5 text-xs font-semibold text-slate-700">저장된 템플릿 ({templates.length})</h3>
          <div className="max-h-[360px] space-y-2 overflow-y-auto">
            {templates.map((t) => (
              <div
                key={t.id}
                className={`rounded-lg border p-2 text-xs ${t.isArchived ? "border-slate-200 bg-slate-50 opacity-60" : "border-slate-200"}`}
              >
                <div className="flex items-center justify-between">
                  <button type="button" onClick={() => loadTemplateIntoEditor(t)} className="truncate text-left font-medium text-slate-800 hover:underline">
                    {t.name}
                  </button>
                  <div className="flex shrink-0 gap-1">
                    {t.isDefault && <span className="rounded bg-indigo-100 px-1.5 py-0.5 text-[10px] text-indigo-700">기본</span>}
                    {t.isArchived && <span className="rounded bg-slate-200 px-1.5 py-0.5 text-[10px] text-slate-600">중지됨</span>}
                  </div>
                </div>
                <p className="mt-0.5 text-[10px] text-slate-400">사용 중인 캠페인 {t.campaignCount}개</p>
                {canWrite && (
                  <div className="mt-1.5 flex flex-wrap gap-1">
                    <button type="button" onClick={() => duplicateTemplate(t)} className="rounded border border-slate-200 px-1.5 py-0.5 text-[10px] text-slate-600 hover:bg-slate-100">
                      복사
                    </button>
                    {!t.isDefault && (
                      <button type="button" onClick={() => setDefault(t)} className="rounded border border-slate-200 px-1.5 py-0.5 text-[10px] text-slate-600 hover:bg-slate-100">
                        기본지정
                      </button>
                    )}
                    <button type="button" onClick={() => toggleArchive(t)} className="rounded border border-slate-200 px-1.5 py-0.5 text-[10px] text-slate-600 hover:bg-slate-100">
                      {t.isArchived ? "사용재개" : "사용중지"}
                    </button>
                    <button type="button" onClick={() => removeTemplate(t)} className="rounded border border-rose-200 px-1.5 py-0.5 text-[10px] text-rose-600 hover:bg-rose-50">
                      삭제
                    </button>
                  </div>
                )}
              </div>
            ))}
            {templates.length === 0 && <p className="py-4 text-center text-xs text-slate-400">저장된 템플릿이 없습니다.</p>}
          </div>
        </div>
      </div>
    </div>
  );
}
