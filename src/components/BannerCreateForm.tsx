"use client";

import { useActionState, useRef, useState } from "react";
import { createBanner, type BannerFormState } from "@/app/actions/banners";
import ImageUploadField from "@/components/ImageUploadField";

const initialState: BannerFormState = {};

const POSITION_OPTIONS = [
  { value: "home_top", label: "홈 상단(home_top)" },
  { value: "home_middle", label: "홈 중단(home_middle)" },
  { value: "home_bottom", label: "홈 하단(home_bottom)" },
];

interface BannerCreateFormProps {
  canWrite: boolean;
  // [프리패스 단순화] 프리패스 설정 화면에서 이 폼을 재사용할 때 지정된 값으로
  // 고정하고(open_pass) 위치 선택 자체를 숨긴다. 생략시(CMS 홈배너 화면)는
  // 기존과 동일하게 직접 선택하는 select를 보여준다.
  fixedPositionCode?: string;
  title?: string;
}

export default function BannerCreateForm({ canWrite, fixedPositionCode, title }: BannerCreateFormProps) {
  const [state, formAction, pending] = useActionState(createBanner, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const [uploadFieldKey, setUploadFieldKey] = useState(0);
  const [adType, setAdType] = useState<"image" | "script">("image");

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
        setUploadFieldKey((k) => k + 1);
        setAdType("image");
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-white">
        {title ?? "새 배너(제휴 광고) 추가"}
      </h3>

      {/* 광고 유형 선택: 이미지형(기존) vs 광고소스형(제휴사 원본 스크립트/iframe) */}
      <div className="col-span-full flex gap-4 rounded-lg border border-slate-700 bg-slate-800/60 px-3 py-2 text-sm text-slate-300">
        <span className="text-xs text-slate-500">광고 유형</span>
        <label className="flex items-center gap-1.5">
          <input
            type="radio"
            name="adType"
            value="image"
            checked={adType === "image"}
            onChange={() => setAdType("image")}
            className="accent-indigo-500"
          />
          이미지 + 링크 (기존 방식)
        </label>
        <label className="flex items-center gap-1.5">
          <input
            type="radio"
            name="adType"
            value="script"
            checked={adType === "script"}
            onChange={() => setAdType("script")}
            className="accent-indigo-500"
          />
          광고소스(스크립트/iframe) 붙여넣기
        </label>
      </div>

      <input
        type="text"
        name="title"
        placeholder="배너 제목 (예: 쿠팡파트너스 - OO 상품)"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />
      {fixedPositionCode ? (
        <input type="hidden" name="positionCode" value={fixedPositionCode} />
      ) : (
        <select
          name="positionCode"
          defaultValue="home_top"
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        >
          {POSITION_OPTIONS.map((p) => (
            <option key={p.value} value={p.value}>
              {p.label}
            </option>
          ))}
        </select>
      )}
      <input
        type="number"
        name="sortOrder"
        placeholder="노출 순서"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />

      {adType === "image" ? (
        <>
          <ImageUploadField
            key={uploadFieldKey}
            name="imageUrl"
            category="banners"
            className="md:col-span-2"
            placeholder="이미지 URL (배너 썸네일)"
          />
          <input
            type="text"
            name="linkUrl"
            placeholder="제휴 링크 URL (쿠팡파트너스 등, 선택)"
            className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
          />
        </>
      ) : (
        <div className="col-span-full">
          <textarea
            name="adScript"
            rows={4}
            placeholder={
              '제휴사가 제공한 원본 광고 태그를 그대로 붙여넣으세요.\n예) <iframe src="https://ads-partners.coupang.com/widgets.html?id=..." width="680" height="140" frameborder="0" scrolling="no"></iframe>'
            }
            className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 font-mono text-xs text-white outline-none focus:border-indigo-500"
          />
          <p className="mt-1 text-xs text-slate-500">
            쿠팡파트너스 위젯, Google AdSense, 기타 제휴사가 발급한 &lt;iframe&gt;/&lt;script&gt; 코드를
            그대로 붙여넣으면 앱/웹에서 그대로 렌더링됩니다. (link_url은 사용하지 않음)
          </p>
        </div>
      )}
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        시작일시(선택)
        <input
          type="datetime-local"
          name="startAt"
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        종료일시(선택)
        <input
          type="datetime-local"
          name="endAt"
          className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
        />
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-300">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" />
        활성화(노출)
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          배너가 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "배너 추가"}
        </button>
      </div>
    </form>
  );
}
