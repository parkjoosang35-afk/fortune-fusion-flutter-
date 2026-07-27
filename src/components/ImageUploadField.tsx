"use client";

// 이미지 URL 입력 + 로컬 파일 업로드를 함께 지원하는 공용 필드.
// - 기존 방식(이미지 URL 직접 입력)은 그대로 유지한다.
// - "파일 선택"으로 이미지를 고르면 /api/upload로 즉시 업로드하고,
//   반환된 URL을 동일한 name의 hidden input에 채워 넣어 기존 Server Action의
//   formData.get("imageUrl") 로직을 그대로 재사용할 수 있게 한다.
import { useRef, useState } from "react";

interface ImageUploadFieldProps {
  name: string;
  category: string;
  defaultValue?: string | null;
  className?: string;
  compact?: boolean; // 테이블 인라인 수정 행 등 좁은 공간용 스타일
  required?: boolean;
  placeholder?: string;
}

export default function ImageUploadField({
  name,
  category,
  defaultValue,
  className,
  compact = false,
  required = false,
  placeholder = "이미지 URL (선택)",
}: ImageUploadFieldProps) {
  const [url, setUrl] = useState(defaultValue ?? "");
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const inputBase =
    "rounded-lg border border-slate-700 bg-slate-800 text-white outline-none focus:border-indigo-500";
  const textInputClass = compact
    ? `w-40 px-2 py-1 text-sm ${inputBase}`
    : `px-3 py-2 text-sm md:col-span-2 ${inputBase}`;

  async function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    setError(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      fd.append("category", category);
      const res = await fetch("/api/upload", { method: "POST", body: fd });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? "업로드에 실패했습니다.");
        return;
      }
      setUrl(data.url);
    } catch {
      setError("업로드 중 오류가 발생했습니다.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = "";
    }
  }

  return (
    <div className={`flex flex-col gap-1 ${className ?? ""}`}>
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="text"
          name={name}
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder={placeholder}
          required={required}
          className={textInputClass}
        />
        <label
          className={`cursor-pointer rounded-lg border border-slate-700 bg-slate-800 px-3 py-1.5 text-xs text-slate-300 hover:bg-slate-700 ${
            uploading ? "pointer-events-none opacity-50" : ""
          }`}
        >
          {uploading ? "업로드 중..." : "파일 선택"}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/jpg,image/png,image/webp,image/gif"
            onChange={handleFileChange}
            className="hidden"
            disabled={uploading}
          />
        </label>
        {url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={url}
            alt="미리보기"
            className="h-9 w-9 rounded border border-slate-700 object-cover"
          />
        )}
      </div>
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  );
}
