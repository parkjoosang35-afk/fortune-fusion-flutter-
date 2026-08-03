"use client";

// 열림패스 첨부파일 신규 등록 폼.
// [사용자 요청] §6-2 첨부파일 관리 섹션 (업로드/용도선택/링크등록)
import { useActionState, useRef, useState } from "react";
import { createOpenPassAttachment, type AttachmentFormState } from "@/app/actions/open-pass-attachments";
import {
  ATTACHMENT_FILE_TYPES,
  ATTACHMENT_FILE_TYPE_LABELS,
  ATTACHMENT_PURPOSES,
  ATTACHMENT_PURPOSE_LABELS,
  type AttachmentFileType,
} from "@/lib/open-pass-constants";
import OpenPassAttachmentUploadField from "@/components/OpenPassAttachmentUploadField";

const initialState: AttachmentFormState = {};

export default function OpenPassAttachmentCreateForm({ canWrite }: { canWrite: boolean }) {
  const [state, formAction, pending] = useActionState(createOpenPassAttachment, initialState);
  const formRef = useRef<HTMLFormElement>(null);
  // [사용자 요청: CMS "새 배너(제휴 광고) 추가"와 동일한 2지선다 UX]
  // "이미지 + 링크 (기존 방식)" -> fileType='image', "광고소스(스크립트/iframe) 붙여넣기" -> fileType='rich_text_html'.
  // 고급 옵션(영상/문서/외부링크/광고대체 소재)은 아래 접이식 영역에서 필요할 때만 노출한다.
  const [adType, setAdType] = useState<"image" | "script">("image");
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const [fileType, setFileType] = useState<AttachmentFileType>("image");

  if (!canWrite) return null;

  // 고급 옵션이 열려있으면 그 select가 실제 fileType을 결정하고,
  // 아니면 위 2지선다(adType)가 결정한다.
  const effectiveFileType: AttachmentFileType = advancedOpen
    ? fileType
    : adType === "script"
      ? "rich_text_html"
      : "image";

  return (
    <form
      ref={formRef}
      action={async (formData) => {
        await formAction(formData);
        formRef.current?.reset();
        setAdType("image");
        setAdvancedOpen(false);
        setFileType("image");
      }}
      className="mb-6 grid grid-cols-1 gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-4"
    >
      <h2 className="col-span-full text-sm font-semibold text-white">새 첨부파일 등록</h2>

      {/* [사용자 요청] 배너(제휴 광고) 등록 화면과 동일한 형태의 2지선다 광고 유형 선택 */}
      {!advancedOpen && (
        <div className="col-span-full flex flex-wrap items-center gap-4 rounded-lg border border-slate-700 bg-slate-800/60 px-3 py-2 text-sm text-slate-300">
          <span className="text-xs text-slate-500">광고 유형</span>
          <label className="flex items-center gap-1.5">
            <input
              type="radio"
              name="adTypeUi"
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
              name="adTypeUi"
              value="script"
              checked={adType === "script"}
              onChange={() => setAdType("script")}
              className="accent-indigo-500"
            />
            광고소스(스크립트/iframe) 붙여넣기
          </label>
        </div>
      )}

      <input
        type="text"
        name="fileName"
        placeholder="파일명(제목) — 예: 열림패스 대표 배너 v1"
        required
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500 md:col-span-2"
      />

      {/* 실제 서버로 전달되는 fileType은 항상 hidden input(effectiveFileType)이 단일 소스다. */}
      <input type="hidden" name="fileType" value={effectiveFileType} />

      <select
        name="purpose"
        defaultValue="hero_banner"
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      >
        {ATTACHMENT_PURPOSES.map((p) => (
          <option key={p} value={p}>
            {ATTACHMENT_PURPOSE_LABELS[p]}
          </option>
        ))}
      </select>

      {advancedOpen ? (
        <>
          <select
            value={fileType}
            onChange={(e) => setFileType(e.target.value as AttachmentFileType)}
            className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
          >
            {ATTACHMENT_FILE_TYPES.map((t) => (
              <option key={t} value={t}>
                {ATTACHMENT_FILE_TYPE_LABELS[t]}
              </option>
            ))}
          </select>
          <OpenPassAttachmentUploadField fileType={fileType} />
        </>
      ) : adType === "image" ? (
        <OpenPassAttachmentUploadField fileType="image" />
      ) : (
        <div className="col-span-full">
          <textarea
            name="htmlContent"
            rows={4}
            placeholder={
              '제휴사/광고 네트워크가 제공한 원본 광고 태그를 그대로 붙여넣으세요.\n예) <iframe src="https://ads-partners.coupang.com/widgets.html?id=..." width="680" height="140" frameborder="0" scrolling="no"></iframe>'
            }
            className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 font-mono text-xs text-white outline-none focus:border-indigo-500"
          />
          <p className="mt-1 text-xs text-slate-500">
            쿠팡파트너스 위젯, AdMob, 기타 제휴사가 발급한 &lt;iframe&gt;/&lt;script&gt; 코드를 그대로 붙여넣으면
            앱에서 그대로 렌더링됩니다.
          </p>
          <input type="hidden" name="fileUrl" value="" />
          <input type="hidden" name="mimeType" value="" />
          <input type="hidden" name="fileSize" value="" />
        </div>
      )}

      <input
        type="number"
        name="displayOrder"
        placeholder="정렬 순서"
        defaultValue={0}
        className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white outline-none focus:border-indigo-500"
      />
      <label className="flex items-center gap-2 text-sm text-slate-300">
        <input type="checkbox" name="isActive" defaultChecked className="accent-indigo-500" /> 활성화
      </label>

      <div className="col-span-full">
        <button
          type="button"
          onClick={() => setAdvancedOpen((v) => !v)}
          className="text-xs text-slate-500 underline hover:text-slate-300"
        >
          {advancedOpen
            ? "간단 모드로 돌아가기"
            : "고급 옵션(영상/문서/외부링크/광고대체 소재 등 다른 유형)"}
        </button>
      </div>

      {state.error && (
        <p className="col-span-full rounded-lg bg-red-950/60 px-3 py-2 text-sm text-red-400">{state.error}</p>
      )}
      {state.success && (
        <p className="col-span-full rounded-lg bg-emerald-950/60 px-3 py-2 text-sm text-emerald-400">
          첨부파일이 등록되었습니다.
        </p>
      )}

      <div className="col-span-full">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white transition hover:bg-indigo-500 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {pending ? "등록 중..." : "첨부파일 등록"}
        </button>
      </div>
    </form>
  );
}
