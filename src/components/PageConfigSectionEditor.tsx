"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  BLOCK_TYPES,
  BLOCK_TYPE_LABELS,
  STYLE_PRESETS,
  BACKGROUND_PRESETS,
  ALIGNMENT_PRESETS,
  DENSITY_PRESETS,
  PLATFORM_TARGETS,
  LINKED_ASSET_TYPES,
  RULE_TYPES,
  RULE_TYPE_LABELS,
  RULE_TYPE_ALLOWED_OPERATORS,
  ATTACHMENT_USAGE_TYPES,
  TEXT_LIMITS,
  type BlockType,
  type RuleType,
  type RuleOperator,
} from "@/lib/page-config-constants";

interface AttachmentData {
  id: number;
  attachmentUrl: string;
  usageType: string;
  isPrimary: boolean;
  displayOrder: number;
}
interface DisplayRuleData {
  id: number;
  ruleType: string;
  ruleOperator: string;
  ruleValue: string;
  isActive: boolean;
}
interface SectionData {
  id: number;
  sectionKey: string;
  blockType: string;
  title: string | null;
  subtitle: string | null;
  description: string | null;
  buttonText: string | null;
  buttonLink: string | null;
  badgeText: string | null;
  emptyStateText: string | null;
  stylePreset: string;
  backgroundPreset: string;
  alignmentPreset: string;
  densityPreset: string;
  isRequired: boolean;
  isPinned: boolean;
  scheduleEnabled: boolean;
  startAt: string | null;
  endAt: string | null;
  platformTargets: string[] | null;
  linkedAssetType: string | null;
  linkedFeatureScope: string | null;
  linkedCampaignId: string | null;
  linkedProductId: string | null;
  attachments: AttachmentData[];
  displayRules: DisplayRuleData[];
}

export default function PageConfigSectionEditor({
  section,
  canWrite,
}: {
  section: SectionData;
  canWrite: boolean;
}) {
  return (
    <div className="space-y-6">
      <ContentEditCard section={section} canWrite={canWrite} />
      <StyleAndLinkageCard section={section} canWrite={canWrite} />
      <ScheduleCard section={section} canWrite={canWrite} />
      <DisplayRulesCard section={section} canWrite={canWrite} />
      <AttachmentsCard section={section} canWrite={canWrite} />
    </div>
  );
}

function Card({ title, hint, children }: { title: string; hint?: string; children: React.ReactNode }) {
  return (
    <section className="rounded-xl border border-slate-200 bg-white p-5">
      <h2 className="text-base font-semibold text-slate-900">{title}</h2>
      {hint && <p className="mt-1 text-xs text-slate-500">{hint}</p>}
      <div className="mt-4">{children}</div>
    </section>
  );
}

function CharCounter({ value, limit }: { value: string; limit: number }) {
  const over = value.length > limit;
  return (
    <span className={`text-xs ${over ? "text-rose-700" : "text-slate-500"}`}>
      {value.length}/{limit}
    </span>
  );
}

// ── §4 텍스트 편집 ─────────────────────────────────────────────────────
function ContentEditCard({ section, canWrite }: { section: SectionData; canWrite: boolean }) {
  const router = useRouter();
  const [title, setTitle] = useState(section.title ?? "");
  const [subtitle, setSubtitle] = useState(section.subtitle ?? "");
  const [description, setDescription] = useState(section.description ?? "");
  const [buttonText, setButtonText] = useState(section.buttonText ?? "");
  const [buttonLink, setButtonLink] = useState(section.buttonLink ?? "");
  const [badgeText, setBadgeText] = useState(section.badgeText ?? "");
  const [emptyStateText, setEmptyStateText] = useState(section.emptyStateText ?? "");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  async function save() {
    setPending(true);
    setError(null);
    setSaved(false);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/content`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title, subtitle, description, buttonText, buttonLink, badgeText, emptyStateText }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setSaved(true);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "저장 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <Card title="텍스트 편집" hint="폰트/사이즈/줄간격은 디자인 시스템에 고정되어 있어 여기서 바꿀 수 없습니다. 내용(글자)만 편집합니다.">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="제목" limit={TEXT_LIMITS.title} value={title} onChange={setTitle} disabled={!canWrite} />
        <Field label="부제목" limit={TEXT_LIMITS.subtitle} value={subtitle} onChange={setSubtitle} disabled={!canWrite} />
        <Field
          label="설명"
          limit={TEXT_LIMITS.description}
          value={description}
          onChange={setDescription}
          disabled={!canWrite}
          textarea
        />
        <Field label="버튼 텍스트" limit={TEXT_LIMITS.buttonText} value={buttonText} onChange={setButtonText} disabled={!canWrite} />
        <div>
          <label className="mb-1 block text-xs text-slate-500">버튼 링크(CTA/딥링크/외부링크)</label>
          <input
            value={buttonLink}
            onChange={(e) => setButtonLink(e.target.value)}
            disabled={!canWrite}
            placeholder="/fortune/daily 또는 https://..."
            className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 disabled:opacity-50"
          />
        </div>
        <Field label="배지 텍스트" limit={TEXT_LIMITS.badgeText} value={badgeText} onChange={setBadgeText} disabled={!canWrite} />
        <Field
          label="빈 상태 안내문구"
          limit={TEXT_LIMITS.emptyStateText}
          value={emptyStateText}
          onChange={setEmptyStateText}
          disabled={!canWrite}
        />
      </div>
      {canWrite && (
        <div className="mt-4 flex items-center gap-3">
          <button
            type="button"
            onClick={save}
            disabled={pending}
            className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            {pending ? "저장 중..." : "텍스트 저장"}
          </button>
          {saved && <span className="text-xs text-emerald-700">저장되었습니다.</span>}
          {error && <span className="text-xs text-rose-700">{error}</span>}
        </div>
      )}
    </Card>
  );
}

function Field({
  label,
  limit,
  value,
  onChange,
  disabled,
  textarea,
}: {
  label: string;
  limit: number;
  value: string;
  onChange: (v: string) => void;
  disabled?: boolean;
  textarea?: boolean;
}) {
  return (
    <div>
      <div className="mb-1 flex items-center justify-between">
        <label className="text-xs text-slate-500">{label}</label>
        <CharCounter value={value} limit={limit} />
      </div>
      {textarea ? (
        <textarea
          value={value}
          onChange={(e) => onChange(e.target.value)}
          disabled={disabled}
          rows={2}
          className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 disabled:opacity-50"
        />
      ) : (
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          disabled={disabled}
          className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 disabled:opacity-50"
        />
      )}
    </div>
  );
}

// ── §7/§8/§11 블록타입/스타일 프리셋/자산연결 ─────────────────────────
function StyleAndLinkageCard({ section, canWrite }: { section: SectionData; canWrite: boolean }) {
  const router = useRouter();
  const [blockType, setBlockType] = useState<BlockType>(section.blockType as BlockType);
  const [stylePreset, setStylePreset] = useState(section.stylePreset);
  const [backgroundPreset, setBackgroundPreset] = useState(section.backgroundPreset);
  const [alignmentPreset, setAlignmentPreset] = useState(section.alignmentPreset);
  const [densityPreset, setDensityPreset] = useState(section.densityPreset);
  const [platformTargets, setPlatformTargets] = useState<string[]>(section.platformTargets ?? []);
  const [linkedAssetType, setLinkedAssetType] = useState(section.linkedAssetType ?? "");
  const [linkedFeatureScope, setLinkedFeatureScope] = useState(section.linkedFeatureScope ?? "");
  const [linkedCampaignId, setLinkedCampaignId] = useState(section.linkedCampaignId ?? "");
  const [linkedProductId, setLinkedProductId] = useState(section.linkedProductId ?? "");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  function togglePlatform(p: string) {
    setPlatformTargets((prev) => (prev.includes(p) ? prev.filter((x) => x !== p) : [...prev, p]));
  }

  async function save() {
    setPending(true);
    setError(null);
    setSaved(false);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          blockType,
          stylePreset,
          backgroundPreset,
          alignmentPreset,
          densityPreset,
          platformTargets: platformTargets.length > 0 ? platformTargets : null,
          linkedAssetType: linkedAssetType || null,
          linkedFeatureScope: linkedFeatureScope || null,
          linkedCampaignId: linkedCampaignId || null,
          linkedProductId: linkedProductId || null,
        }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setSaved(true);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "저장 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <Card
      title="블록 타입 / 스타일 프리셋 / 정책 자산 연동"
      hint="자유 CSS/좌표 입력은 지원하지 않으며, 미리 정의된 프리셋 중에서만 선택합니다."
    >
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <SelectField label="블록 타입" value={blockType} onChange={(v) => setBlockType(v as BlockType)} disabled={!canWrite}>
          {BLOCK_TYPES.map((bt) => (
            <option key={bt} value={bt}>
              {BLOCK_TYPE_LABELS[bt]}
            </option>
          ))}
        </SelectField>
        <SelectField label="스타일 프리셋" value={stylePreset} onChange={setStylePreset} disabled={!canWrite}>
          {STYLE_PRESETS.map((v) => (
            <option key={v} value={v}>
              {v}
            </option>
          ))}
        </SelectField>
        <SelectField label="배경 프리셋" value={backgroundPreset} onChange={setBackgroundPreset} disabled={!canWrite}>
          {BACKGROUND_PRESETS.map((v) => (
            <option key={v} value={v}>
              {v}
            </option>
          ))}
        </SelectField>
        <SelectField label="정렬 프리셋" value={alignmentPreset} onChange={setAlignmentPreset} disabled={!canWrite}>
          {ALIGNMENT_PRESETS.map((v) => (
            <option key={v} value={v}>
              {v}
            </option>
          ))}
        </SelectField>
        <SelectField label="밀도 프리셋" value={densityPreset} onChange={setDensityPreset} disabled={!canWrite}>
          {DENSITY_PRESETS.map((v) => (
            <option key={v} value={v}>
              {v}
            </option>
          ))}
        </SelectField>
        <SelectField label="연동 자산 타입(선택)" value={linkedAssetType} onChange={setLinkedAssetType} disabled={!canWrite}>
          <option value="">없음</option>
          {LINKED_ASSET_TYPES.map((v) => (
            <option key={v} value={v}>
              {v}
            </option>
          ))}
        </SelectField>
        <div>
          <label className="mb-1 block text-xs text-slate-500">연동 기능 스코프</label>
          <input
            value={linkedFeatureScope}
            onChange={(e) => setLinkedFeatureScope(e.target.value)}
            disabled={!canWrite}
            className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 disabled:opacity-50"
          />
        </div>
        <div>
          <label className="mb-1 block text-xs text-slate-500">캠페인/상품 ID(선택)</label>
          <div className="flex gap-1">
            <input
              value={linkedCampaignId}
              onChange={(e) => setLinkedCampaignId(e.target.value)}
              disabled={!canWrite}
              placeholder="campaignId"
              className="w-1/2 rounded border border-slate-300 bg-white px-2 py-2 text-sm text-slate-900 disabled:opacity-50"
            />
            <input
              value={linkedProductId}
              onChange={(e) => setLinkedProductId(e.target.value)}
              disabled={!canWrite}
              placeholder="productId"
              className="w-1/2 rounded border border-slate-300 bg-white px-2 py-2 text-sm text-slate-900 disabled:opacity-50"
            />
          </div>
        </div>
      </div>

      <div className="mt-4">
        <label className="mb-1 block text-xs text-slate-500">노출 플랫폼(선택하지 않으면 전체 노출)</label>
        <div className="flex gap-3">
          {PLATFORM_TARGETS.map((p) => (
            <label key={p} className="flex items-center gap-1 text-sm text-slate-600">
              <input
                type="checkbox"
                checked={platformTargets.includes(p)}
                onChange={() => togglePlatform(p)}
                disabled={!canWrite}
              />
              {p}
            </label>
          ))}
        </div>
      </div>

      {canWrite && (
        <div className="mt-4 flex items-center gap-3">
          <button
            type="button"
            onClick={save}
            disabled={pending}
            className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            {pending ? "저장 중..." : "스타일/연동 저장"}
          </button>
          {saved && <span className="text-xs text-emerald-700">저장되었습니다.</span>}
          {error && <span className="text-xs text-rose-700">{error}</span>}
        </div>
      )}
    </Card>
  );
}

function SelectField({
  label,
  value,
  onChange,
  disabled,
  children,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  disabled?: boolean;
  children: React.ReactNode;
}) {
  return (
    <div>
      <label className="mb-1 block text-xs text-slate-500">{label}</label>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={disabled}
        className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 disabled:opacity-50"
      >
        {children}
      </select>
    </div>
  );
}

// ── §13 예약 노출 ─────────────────────────────────────────────────────
function ScheduleCard({ section, canWrite }: { section: SectionData; canWrite: boolean }) {
  const router = useRouter();
  const [scheduleEnabled, setScheduleEnabled] = useState(section.scheduleEnabled);
  const [startAt, setStartAt] = useState(section.startAt ? section.startAt.slice(0, 16) : "");
  const [endAt, setEndAt] = useState(section.endAt ? section.endAt.slice(0, 16) : "");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  async function save() {
    setPending(true);
    setError(null);
    setSaved(false);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/schedule`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          scheduleEnabled,
          startAt: startAt ? new Date(startAt).toISOString() : null,
          endAt: endAt ? new Date(endAt).toISOString() : null,
        }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setSaved(true);
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "저장 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <Card title="예약 노출" hint="시각은 기기(브라우저) 로컬 타임존 기준으로 입력합니다. 서버는 UTC로 저장합니다.">
      <label className="mb-3 flex items-center gap-2 text-sm text-slate-600">
        <input type="checkbox" checked={scheduleEnabled} onChange={(e) => setScheduleEnabled(e.target.checked)} disabled={!canWrite} />
        예약 노출 사용
      </label>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div>
          <label className="mb-1 block text-xs text-slate-500">시작 시각</label>
          <input
            type="datetime-local"
            value={startAt}
            onChange={(e) => setStartAt(e.target.value)}
            disabled={!canWrite || !scheduleEnabled}
            className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 disabled:opacity-50"
          />
        </div>
        <div>
          <label className="mb-1 block text-xs text-slate-500">종료 시각</label>
          <input
            type="datetime-local"
            value={endAt}
            onChange={(e) => setEndAt(e.target.value)}
            disabled={!canWrite || !scheduleEnabled}
            className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 disabled:opacity-50"
          />
        </div>
      </div>
      {canWrite && (
        <div className="mt-4 flex items-center gap-3">
          <button
            type="button"
            onClick={save}
            disabled={pending}
            className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            {pending ? "저장 중..." : "예약 저장"}
          </button>
          {saved && <span className="text-xs text-emerald-700">저장되었습니다.</span>}
          {error && <span className="text-xs text-rose-700">{error}</span>}
        </div>
      )}
    </Card>
  );
}

// ── §9 노출 조건 ──────────────────────────────────────────────────────
function DisplayRulesCard({ section, canWrite }: { section: SectionData; canWrite: boolean }) {
  const router = useRouter();
  const [rules, setRules] = useState(section.displayRules);
  const [ruleType, setRuleType] = useState<RuleType>("login_status");
  const [ruleOperator, setRuleOperator] = useState<RuleOperator>(RULE_TYPE_ALLOWED_OPERATORS.login_status[0]);
  const [ruleValue, setRuleValue] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function onRuleTypeChange(rt: RuleType) {
    setRuleType(rt);
    setRuleOperator(RULE_TYPE_ALLOWED_OPERATORS[rt][0]);
  }

  async function addRule() {
    if (!ruleValue.trim()) {
      setError("조건 값을 입력하세요.");
      return;
    }
    setPending(true);
    setError(null);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/conditions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ruleType, ruleOperator, ruleValue: ruleValue.trim() }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setRules((prev) => [...prev, json.data]);
      setRuleValue("");
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "조건 추가 실패");
    } finally {
      setPending(false);
    }
  }

  async function removeRule(ruleId: number) {
    setPending(true);
    setError(null);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/conditions/${ruleId}`, {
        method: "DELETE",
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setRules((prev) => prev.filter((r) => r.id !== ruleId));
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "조건 삭제 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <Card
      title="노출 조건 (Display Rules)"
      hint="개발자 표현식이 아니라 (조건 타입, 연산자, 값) 3요소 조합으로만 조건을 만듭니다. 조건이 없으면 항상 노출됩니다."
    >
      {rules.length === 0 ? (
        <p className="text-sm text-slate-500">등록된 노출 조건이 없습니다.</p>
      ) : (
        <ul className="mb-4 space-y-2">
          {rules.map((r) => (
            <li key={r.id} className="flex items-center justify-between rounded border border-slate-200 px-3 py-2 text-sm">
              <span className="text-slate-600">
                <span className="text-indigo-800">{RULE_TYPE_LABELS[r.ruleType as RuleType] ?? r.ruleType}</span>{" "}
                {r.ruleOperator} <span className="text-slate-500">&quot;{r.ruleValue}&quot;</span>
              </span>
              {canWrite && (
                <button
                  type="button"
                  onClick={() => removeRule(r.id)}
                  disabled={pending}
                  className="rounded border border-rose-300 px-2 py-1 text-xs text-rose-700 hover:bg-rose-100 disabled:opacity-40"
                >
                  삭제
                </button>
              )}
            </li>
          ))}
        </ul>
      )}

      {canWrite && (
        <div className="flex flex-col gap-2 sm:flex-row sm:items-end">
          <SelectField label="조건 타입" value={ruleType} onChange={(v) => onRuleTypeChange(v as RuleType)}>
            {RULE_TYPES.map((rt) => (
              <option key={rt} value={rt}>
                {RULE_TYPE_LABELS[rt]}
              </option>
            ))}
          </SelectField>
          <SelectField label="연산자" value={ruleOperator} onChange={(v) => setRuleOperator(v as RuleOperator)}>
            {RULE_TYPE_ALLOWED_OPERATORS[ruleType].map((op) => (
              <option key={op} value={op}>
                {op}
              </option>
            ))}
          </SelectField>
          <div className="flex-1">
            <label className="mb-1 block text-xs text-slate-500">조건 값</label>
            <input
              value={ruleValue}
              onChange={(e) => setRuleValue(e.target.value)}
              placeholder="예: true / 1000 / ios,android"
              className="w-full rounded border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900"
            />
          </div>
          <button
            type="button"
            onClick={addRule}
            disabled={pending}
            className="rounded bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-50"
          >
            추가
          </button>
        </div>
      )}
      {error && <p className="mt-2 text-xs text-rose-700">{error}</p>}
    </Card>
  );
}

// ── §10 첨부파일 ──────────────────────────────────────────────────────
function AttachmentsCard({ section, canWrite }: { section: SectionData; canWrite: boolean }) {
  const router = useRouter();
  const [attachments, setAttachments] = useState(section.attachments);
  const [usageType, setUsageType] = useState<(typeof ATTACHMENT_USAGE_TYPES)[number]>(ATTACHMENT_USAGE_TYPES[0]);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setPending(true);
    setError(null);
    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("category", "page-configs");
      const uploadRes = await fetch("/api/upload", { method: "POST", body: formData });
      const uploadJson = await uploadRes.json();
      if (uploadJson.error) throw new Error(uploadJson.error);

      const bindRes = await fetch(`/api/admin/page-configs/home/sections/${section.id}/attachments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ attachmentUrl: uploadJson.url, usageType, isPrimary: attachments.length === 0 }),
      });
      const bindJson = await bindRes.json();
      if (!bindJson.success) throw new Error(bindJson.error);
      setAttachments((prev) => [...prev, bindJson.data]);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "업로드 실패");
    } finally {
      setPending(false);
      e.target.value = "";
    }
  }

  async function setPrimary(attachmentId: number) {
    setPending(true);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/attachments/${attachmentId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ isPrimary: true }),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setAttachments((prev) =>
        prev.map((a) => ({ ...a, isPrimary: a.usageType === json.data.usageType ? a.id === attachmentId : a.isPrimary })),
      );
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "대표 지정 실패");
    } finally {
      setPending(false);
    }
  }

  async function unbind(attachmentId: number) {
    setPending(true);
    try {
      const res = await fetch(`/api/admin/page-configs/home/sections/${section.id}/attachments/${attachmentId}`, {
        method: "DELETE",
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error);
      setAttachments((prev) => prev.filter((a) => a.id !== attachmentId));
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "해제 실패");
    } finally {
      setPending(false);
    }
  }

  return (
    <Card title="첨부파일 (배너/아이콘/배경/폴백 이미지)" hint="이미지는 앱 코드에 하드코딩하지 않고 이 바인딩 구조를 통해 연결됩니다.">
      {attachments.length === 0 ? (
        <p className="mb-3 text-sm text-slate-500">등록된 첨부파일이 없습니다.</p>
      ) : (
        <ul className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
          {attachments.map((a) => (
            // eslint-disable-next-line @next/next/no-img-element
            <li key={a.id} className="overflow-hidden rounded-lg border border-slate-200">
              <img src={a.attachmentUrl} alt={a.usageType} className="h-24 w-full object-cover" />
              <div className="p-2 text-xs">
                <div className="flex items-center justify-between text-slate-500">
                  <span>{a.usageType}</span>
                  {a.isPrimary && <span className="rounded bg-indigo-100 px-1 text-indigo-800">대표</span>}
                </div>
                {canWrite && (
                  <div className="mt-1 flex gap-1">
                    {!a.isPrimary && (
                      <button type="button" onClick={() => setPrimary(a.id)} disabled={pending} className="text-indigo-700 hover:underline">
                        대표지정
                      </button>
                    )}
                    <button type="button" onClick={() => unbind(a.id)} disabled={pending} className="text-rose-700 hover:underline">
                      해제
                    </button>
                  </div>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}

      {canWrite && (
        <div className="flex items-end gap-3">
          <SelectField label="용도" value={usageType} onChange={(v) => setUsageType(v as (typeof ATTACHMENT_USAGE_TYPES)[number])}>
            {ATTACHMENT_USAGE_TYPES.map((u) => (
              <option key={u} value={u}>
                {u}
              </option>
            ))}
          </SelectField>
          <div>
            <label className="mb-1 block text-xs text-slate-500">이미지 업로드</label>
            <input type="file" accept="image/*" onChange={handleUpload} disabled={pending} className="text-sm text-slate-600" />
          </div>
        </div>
      )}
      {error && <p className="mt-2 text-xs text-rose-700">{error}</p>}
    </Card>
  );
}
