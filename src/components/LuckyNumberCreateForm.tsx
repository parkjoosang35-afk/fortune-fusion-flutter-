"use client";

// "오늘의 행운숫자" 관리자 콘텐츠 등록 폼.
// [사용자 요청] "오늘의 행운숫자 섹션은 꼭 광고을 아니 하던것 진핼해" — BannerCreateForm.tsx의
// 구조(라디오로 콘텐츠 유형 선택 → 유형별 조건부 입력 필드)를 참고하되, positionCode(노출 위치)는
// 단일 슬롯 콘텐츠이므로 제거하고, adType(image/script) 2종 대신 contentType(image/video/script)
// 3종으로 확장한다. 업로드는 ImageUploadField를 재사용하지 않고 MediaUploadField를 사용한다.
import { useActionState, useRef, useState } from "react";
import { createLuckyNumberContent, type LuckyNumberFormState } from "@/app/actions/luckyNumberContent";
import MediaUploadField from "@/components/MediaUploadField";

const initialState: LuckyNumberFormState = {};

export default function LuckyNumberCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createLuckyNumberContent, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  const [uploadFieldKey, setUploadFieldKey] = useState(0);
  const [contentType, setContentType] = useState<"image" | "video" | "script">("image");

  if (!canWrite) return null;

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
        setUploadFieldKey((k) => k + 1);
        setContentType("image");
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-200 bg-white p-4 md:grid-cols-4"
    >
      <h3 className="col-span-full text-sm font-semibold text-slate-900">
        새 행운숫자 콘텐츠 추가
      </h3>

      {/* 콘텐츠 유형 선택: 이미지 / 영상 / 소스(스크립트) — 광고(banners)와는 무관한 별도 콘텐츠 */}
      <div className="col-span-full flex gap-4 rounded-lg border border-slate-300 bg-white/60 px-3 py-2 text-sm text-slate-600">
        <span className="text-xs text-slate-500">콘텐츠 유형</span>
        <label className="flex items-center gap-1.5">
          <input
            type="radio"
            name="contentType"
            value="image"
            checked={contentType === "image"}
            onChange={() => setContentType("image")}
            className="accent-purple-500"
          />
          이미지
        </label>
        <label className="flex items-center gap-1.5">
          <input
            type="radio"
            name="contentType"
            value="video"
            checked={contentType === "video"}
            onChange={() => setContentType("video")}
            className="accent-purple-500"
          />
          영상
        </label>
        <label className="flex items-center gap-1.5">
          <input
            type="radio"
            name="contentType"
            value="script"
            checked={contentType === "script"}
            onChange={() => setContentType("script")}
            className="accent-purple-500"
          />
          소스(스크립트/HTML)
        </label>
      </div>

      <input
        type="text"
        name="title"
        placeholder="콘텐츠 제목 (예: 2024년 12월 행운 숫자)"
        required
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500 md:col-span-2"
      />
      <input
        type="number"
        name="sortOrder"
        placeholder="노출 순서"
        min={0}
        defaultValue={0}
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
      />
      <input
        type="text"
        name="caption"
        placeholder="캡션(선택, 이미지/영상 하단 설명)"
        className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
      />

      {contentType === "image" && (
        <MediaUploadField
          key={uploadFieldKey}
          name="imageUrl"
          category="lucky-number"
          kind="image"
          className="md:col-span-4"
          placeholder="이미지 URL"
        />
      )}
      {contentType === "video" && (
        <MediaUploadField
          key={uploadFieldKey}
          name="videoUrl"
          category="lucky-number"
          kind="video"
          className="md:col-span-4"
          placeholder="영상 URL"
        />
      )}
      {contentType === "script" && (
        <div className="col-span-full">
          <textarea
            name="script"
            rows={4}
            placeholder="행운숫자 카드에 그대로 렌더링할 HTML/스크립트 코드를 입력하세요."
            className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 font-mono text-xs text-slate-900 outline-none focus:border-purple-500"
          />
          <p className="mt-1 text-xs text-slate-500">
            HTML 코드를 그대로 붙여넣으면 앱 내 웹뷰로 렌더링됩니다.
          </p>
        </div>
      )}

      <label className="flex flex-col gap-1 text-xs text-slate-500">
        시작일시(선택)
        <input
          type="datetime-local"
          name="startAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-500">
        종료일시(선택)
        <input
          type="datetime-local"
          name="endAt"
          className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 outline-none focus:border-purple-500"
        />
      </label>
      <label className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-600">
        <input type="checkbox" name="isActive" defaultChecked className="accent-purple-500" />
        활성화(노출)
      </label>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-100 px-3 py-2 text-sm text-red-700">
          {state.error}
        </p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-100 px-3 py-2 text-sm text-emerald-700">
          행운숫자 콘텐츠가 추가되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-purple-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-purple-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "추가 중..." : "행운숫자 콘텐츠 추가"}
        </button>
      </div>
    </form>
  );
}
