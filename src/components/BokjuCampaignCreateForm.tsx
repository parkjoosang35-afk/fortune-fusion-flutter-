"use client";

// [복주머니 마케팅 쿠폰 최종본 §4] 쿠폰 만들기 — 13개 입력 라벨 중 서버 저장
// 대상 필드 + "2. 쿠폰 디자인"(디자인 템플릿 선택) + "12. 모바일 쿠폰 미리보기"를
// 폼으로 구성한다. 성공 시 캠페인 상세로 이동.
//
// [카카오톡 스타일 쿠폰 디자인 템플릿 4종] 입력 중인 쿠폰명/지급액/안내문구/
// 유효기간을 그대로 반영한 실시간 미리보기를 GET /api/admin/bokju-coupons/
// design-preview에서 받아와 보여준다. 입력값이 바뀔 때마다 매번 요청을 보내면
// 과도하므로 500ms debounce를 적용한다.
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

const DESIGN_TEMPLATES: { id: "CLASSIC" | "PREMIUM" | "KAKAO" | "MINIMAL"; label: string; hint: string }[] = [
  { id: "CLASSIC", label: "전통 복주머니", hint: "적갈색 · 금색 톤" },
  { id: "PREMIUM", label: "고급 선물", hint: "블랙 · 골드 톤" },
  { id: "KAKAO", label: "카카오톡 스타일", hint: "카카오 옐로우 · 말풍선" },
  { id: "MINIMAL", label: "미니멀", hint: "화이트 · 그레이 톤" },
];

// [AI 쿠폰 디자인 표시·숨김 기능 §9 "쿠폰 만들기 화면에서 선택"] 저장된 커스텀
// 템플릿 목록 항목 — GET /api/admin/bokju-coupons/design-templates 응답 형태와
// 일치시킨다(보관되지 않은 것만 내려오므로 별도 필터 불필요).
interface CustomTemplateOption {
  id: number;
  name: string;
  isDefault: boolean;
}

export default function BokjuCampaignCreateForm({ canWrite }: { canWrite: boolean }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [title, setTitle] = useState("");
  const [grantAmount, setGrantAmount] = useState(100);
  const [issueType, setIssueType] = useState<"INDIVIDUAL" | "SHARED">("INDIVIDUAL");
  const [targetAudience, setTargetAudience] = useState<"ALL" | "NEW" | "EXISTING">("ALL");
  const [useLimitPerMember, setUseLimitPerMember] = useState(1);
  const [sharedTotalLimit, setSharedTotalLimit] = useState(100);
  // [마케팅 쿠폰 발행 관리 개선 §3-1] 총 발행 수량 — 기본값은 요구사항대로
  // 무제한이 아닌 한정 수량(1,000)으로 시작한다. isUnlimited가 true면 제출 시
  // totalIssueLimit을 null로 보낸다.
  const [totalIssueLimit, setTotalIssueLimit] = useState(1000);
  const [isUnlimitedIssue, setIsUnlimitedIssue] = useState(false);
  const [validFrom, setValidFrom] = useState("");
  const [validTo, setValidTo] = useState("");
  const [guideText, setGuideText] = useState("");
  const [distributionMethod, setDistributionMethod] = useState<"DIRECT" | "PARTNER" | "GIFT">("PARTNER");
  const [designTemplate, setDesignTemplate] = useState<"CLASSIC" | "PREMIUM" | "KAKAO" | "MINIMAL">("CLASSIC");

  // [AI 쿠폰 디자인 표시·숨김 기능 §9] 저장된 커스텀 템플릿 선택(선택 사항).
  // null이면 기존 4종 내장 템플릿(designTemplate)을 그대로 쓴다 — 하위 호환.
  // customTemplateId가 선택되면 내장 4종 선택 UI는 비활성화 처리해 혼동을 막는다.
  const [customTemplates, setCustomTemplates] = useState<CustomTemplateOption[]>([]);
  const [customTemplateId, setCustomTemplateId] = useState<number | null>(null);

  // [12. 모바일 쿠폰 미리보기] 디자인/쿠폰명/지급액/안내문구/유효기간이 바뀔 때마다
  // 500ms debounce 후 미리보기 PNG를 다시 요청한다. 이미지 자체를 상태로 들고
  // 있지 않고 <img src={previewUrl}>로 직접 그리면 네트워크 요청/렌더가 자동
  // 동기화되므로 로딩 상태 관리가 단순해진다.
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!open) return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      if (customTemplateId != null) {
        // [AI 쿠폰 디자인 §9] 커스텀 템플릿이 선택된 경우, 그 템플릿의 저장된
        // visibility/배경으로 미리보기를 렌더링한다(디자인 관리 화면의 실시간
        // 미리보기와 동일한 엔드포인트). 템플릿 자체의 visibility는 서버가 이미
        // 알고 있으므로 템플릿 id만 넘기면 된다.
        const qs = new URLSearchParams({
          templateId: String(customTemplateId),
          title: title.trim() || "신통방통 복주머니 선물",
          grantAmount: String(grantAmount || 100),
          guideText: guideText.trim(),
          validFrom: validFrom || "",
          validTo: validTo || "",
        });
        setPreviewUrl(`/api/admin/bokju-coupons/design-templates/preview?${qs.toString()}`);
        return;
      }
      const qs = new URLSearchParams({
        template: designTemplate,
        title: title.trim() || "신통방통 복주머니 선물",
        grantAmount: String(grantAmount || 100),
        guideText: guideText.trim(),
        validFrom: validFrom || "",
        validTo: validTo || "",
      });
      setPreviewUrl(`/api/admin/bokju-coupons/design-preview?${qs.toString()}`);
    }, 500);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [open, designTemplate, customTemplateId, title, grantAmount, guideText, validFrom, validTo]);

  // [react-hooks/set-state-in-effect 회피 패턴 — BokjuCouponShareSection.tsx/
  // BokjuDesignTemplateManager.tsx와 동일하게 cancelled 플래그 + effect 내부
  // 인라인 fetch] 폼이 열릴 때 저장된 커스텀 템플릿 목록을 1회 조회한다.
  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    async function loadCustomTemplates() {
      try {
        const res = await fetch("/api/admin/bokju-coupons/design-templates");
        const json = await res.json();
        if (cancelled) return;
        if (json.success) {
          const list: CustomTemplateOption[] = (json.data.templates ?? []).map(
            (t: { id: number; name: string; isDefault: boolean }) => ({
              id: t.id,
              name: t.name,
              isDefault: t.isDefault,
            })
          );
          setCustomTemplates(list);
          // 기본 템플릿이 있으면 자동 선택(관리자가 "기본 템플릿"으로 지정한 의도 반영).
          const def = list.find((t) => t.isDefault);
          if (def) setCustomTemplateId(def.id);
        }
      } catch {
        // 목록 조회 실패는 치명적이지 않음 — 커스텀 템플릿 없이 내장 4종으로 계속 진행 가능.
        if (!cancelled) setCustomTemplates([]);
      }
    }
    void loadCustomTemplates();
    return () => {
      cancelled = true;
    };
  }, [open]);

  if (!canWrite) return null;

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return setError("쿠폰명을 입력해주세요.");
    if (!validFrom || !validTo) return setError("사용 시작일/만료일은 필수입니다.");
    setPending(true);
    setError(null);
    try {
      const res = await fetch("/api/admin/bokju-coupons/campaigns", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: title.trim(),
          grantAmount,
          issueType,
          targetAudience,
          useLimitPerMember,
          sharedTotalLimit: issueType === "SHARED" ? sharedTotalLimit : undefined,
          totalIssueLimit: isUnlimitedIssue ? null : totalIssueLimit,
          validFrom,
          validTo,
          guideText: guideText.trim() || undefined,
          distributionMethod,
          designTemplate,
          customTemplateId,
        }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      router.push(`/bokju-coupons/campaigns/${json.data.campaignId}`);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "캠페인 생성 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="mb-6">
      {!open ? (
        <button
          type="button"
          onClick={() => setOpen(true)}
          className="rounded-lg border border-indigo-300 bg-indigo-100 px-4 py-2 text-sm text-indigo-800 hover:bg-indigo-100"
        >
          + 새 쿠폰 캠페인 만들기
        </button>
      ) : (
        <form onSubmit={submit} className="grid grid-cols-1 gap-4 rounded-xl border border-slate-200 bg-white p-5 sm:grid-cols-2">
          <div className="sm:col-span-2">
            <label className="mb-1 block text-xs text-slate-500">1. 쿠폰명 *</label>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="예: 신통방통 복주머니 선물"
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">3. 지급 복주머니 *</label>
            <input
              type="number"
              min={1}
              value={grantAmount}
              onChange={(e) => setGrantAmount(Number(e.target.value))}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div className="sm:col-span-2">
            <label className="mb-2 block text-xs text-slate-500">2. 쿠폰 디자인</label>

            {customTemplates.length > 0 && (
              <div className="mb-3">
                <label className="mb-1 block text-[11px] text-slate-500">
                  AI 쿠폰 디자인에서 저장한 템플릿 (선택 사항 — 지정하면 아래 내장 4종 대신 사용됩니다)
                </label>
                <select
                  value={customTemplateId ?? ""}
                  onChange={(e) => setCustomTemplateId(e.target.value ? Number(e.target.value) : null)}
                  className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
                >
                  <option value="">사용 안 함 (아래 내장 4종 디자인 사용)</option>
                  {customTemplates.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.name}
                      {t.isDefault ? " (기본)" : ""}
                    </option>
                  ))}
                </select>
                <p className="mt-1 text-[11px] text-slate-400">
                  AI 쿠폰 디자인 탭에서 만든 표시 설정(QR·쿠폰번호·만료일 숨김 등)이 그대로 발행 이미지에 적용됩니다.
                </p>
              </div>
            )}

            <div className={customTemplateId != null ? "pointer-events-none opacity-40" : undefined}>
              <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
                {DESIGN_TEMPLATES.map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    disabled={customTemplateId != null}
                    onClick={() => setDesignTemplate(t.id)}
                    className={`rounded-lg border p-3 text-left text-xs transition ${
                      designTemplate === t.id
                        ? "border-indigo-500 bg-indigo-50 ring-1 ring-indigo-500"
                        : "border-slate-300 bg-white hover:bg-slate-50"
                    }`}
                  >
                    <div className="font-medium text-slate-900">{t.label}</div>
                    <div className="mt-0.5 text-[11px] text-slate-500">{t.hint}</div>
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">5. 쿠폰 유형</label>
            <select
              value={issueType}
              onChange={(e) => setIssueType(e.target.value as "INDIVIDUAL" | "SHARED")}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            >
              <option value="INDIVIDUAL">개별번호</option>
              <option value="SHARED">공용번호</option>
            </select>
          </div>

          {issueType === "SHARED" && (
            <div>
              <label className="mb-1 block text-xs text-slate-500">공용 총 사용 한도 *</label>
              <input
                type="number"
                min={1}
                value={sharedTotalLimit}
                onChange={(e) => setSharedTotalLimit(Number(e.target.value))}
                className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
              />
            </div>
          )}

          <div>
            <label className="mb-1 block text-xs text-slate-500">6. 사용 대상</label>
            <select
              value={targetAudience}
              onChange={(e) => setTargetAudience(e.target.value as "ALL" | "NEW" | "EXISTING")}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            >
              <option value="ALL">전체</option>
              <option value="NEW">신규 회원</option>
              <option value="EXISTING">기존 회원</option>
            </select>
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">총 발행 수량 *</label>
            <div className="flex items-center gap-2">
              <input
                type="number"
                min={1}
                value={totalIssueLimit}
                disabled={isUnlimitedIssue}
                onChange={(e) => setTotalIssueLimit(Number(e.target.value))}
                className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900 disabled:bg-slate-100 disabled:text-slate-400"
              />
              <label className="flex shrink-0 items-center gap-1 text-xs text-slate-600">
                <input
                  type="checkbox"
                  checked={isUnlimitedIssue}
                  onChange={(e) => setIsUnlimitedIssue(e.target.checked)}
                />
                무제한
              </label>
            </div>
            <p className="mt-1 text-[11px] text-slate-400">
              쿠폰을 총 몇 장까지 발행할 수 있는지 설정합니다(예: 100/500/1,000장). 기본값은 한정 수량이며,
              무제한 체크 시 총량 제한 없이 계속 발행할 수 있습니다.
            </p>
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">9. 1인당 발급 가능 수량</label>
            <input
              type="number"
              min={1}
              value={useLimitPerMember}
              onChange={(e) => setUseLimitPerMember(Number(e.target.value))}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
            <p className="mt-1 text-[11px] text-slate-400">
              한 회원이 이 쿠폰을 몇 번까지 등록(적립)할 수 있는지입니다. 총 발행 수량과 별도로 적용되며,
              무제한 발행이어도 이 제한은 그대로 적용됩니다.
            </p>
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">7. 사용 시작일 *</label>
            <input
              type="date"
              value={validFrom}
              onChange={(e) => setValidFrom(e.target.value)}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">8. 사용 만료일 *</label>
            <input
              type="date"
              value={validTo}
              onChange={(e) => setValidTo(e.target.value)}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs text-slate-500">11. 배포 방식</label>
            <select
              value={distributionMethod}
              onChange={(e) => setDistributionMethod(e.target.value as "DIRECT" | "PARTNER" | "GIFT")}
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            >
              <option value="PARTNER">제휴업체 배정</option>
              <option value="DIRECT">직접 배포</option>
              <option value="GIFT">회원 선물</option>
            </select>
          </div>

          <div className="sm:col-span-2">
            <label className="mb-1 block text-xs text-slate-500">10. 쿠폰 안내 문구</label>
            <input
              value={guideText}
              onChange={(e) => setGuideText(e.target.value)}
              placeholder="QR코드를 찍고 복주머니를 받으세요!"
              className="w-full rounded border border-slate-300 px-3 py-2 text-sm text-slate-900"
            />
          </div>

          <div className="sm:col-span-2">
            <label className="mb-2 block text-xs text-slate-500">12. 모바일 쿠폰 미리보기 (디자인 · 번호 · QR 확인)</label>
            <div className="flex justify-center rounded-lg bg-slate-100 p-4">
              {previewUrl ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={previewUrl}
                  alt="모바일 쿠폰 미리보기"
                  className="h-auto w-full max-w-[280px] rounded-lg border border-slate-200 shadow-sm"
                />
              ) : (
                <div className="flex h-[320px] w-[180px] items-center justify-center text-xs text-slate-400">
                  미리보기 로딩 중...
                </div>
              )}
            </div>
            <p className="mt-2 text-center text-[11px] text-slate-400">
              실제 쿠폰번호/QR은 발행 시 생성됩니다. 위 이미지는 레이아웃·색감 확인용 샘플입니다.
            </p>
          </div>

          <div className="flex gap-2 sm:col-span-2">
            <button
              type="submit"
              disabled={pending}
              className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
            >
              {pending ? "생성 중..." : "13. 쿠폰 캠페인 만들기(DRAFT)"}
            </button>
            <button
              type="button"
              onClick={() => setOpen(false)}
              className="rounded border border-slate-300 px-3 py-2 text-sm text-slate-500 hover:bg-slate-100"
            >
              취소
            </button>
          </div>
          {error && <p className="sm:col-span-2 text-xs text-rose-700">{error}</p>}
        </form>
      )}
    </div>
  );
}
