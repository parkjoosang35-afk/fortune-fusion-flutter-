"use client";

// [마케팅 쿠폰 관리자 매뉴얼 — 화면 내 설명 기능]
// 관리자가 각 입력항목/버튼 옆의 "❓" 아이콘을 클릭하면 그 자리에서 기능 설명을
// 팝오버로 바로 확인할 수 있게 한다. 별도 PDF/DOCX 매뉴얼을 열어볼 필요 없이
// "헷갈리는 바로 그 화면"에서 즉시 답을 찾을 수 있도록 하는 것이 목적이다.
// 운영 코드(기존 폼/버튼의 동작)는 전혀 건드리지 않고, 설명 아이콘만 옆에 추가하는
// 방식이라 기능 자체에는 영향이 없다(순수 UI 추가).
import { useEffect, useRef, useState } from "react";
import { HelpCircle } from "lucide-react";

interface FieldHelpProps {
  /** 팝오버 안에 표시할 설명(여러 줄 가능). 줄바꿈은 \n으로 구분. */
  text: string;
  /** 팝오버 제목(선택). 없으면 설명만 표시. */
  title?: string;
  /** 아이콘 크기(px). 기본 14. */
  size?: number;
  /** 팝오버가 열리는 위치. 기본 right(아이콘 오른쪽 아래). 화면 끝에 가까운 요소는 left 권장. */
  align?: "left" | "right";
}

export default function FieldHelp({ text, title, size = 14, align = "right" }: FieldHelpProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    if (!open) return;
    function onDocClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    function onEsc(e: KeyboardEvent) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", onDocClick);
    document.addEventListener("keydown", onEsc);
    return () => {
      document.removeEventListener("mousedown", onDocClick);
      document.removeEventListener("keydown", onEsc);
    };
  }, [open]);

  return (
    <span ref={ref} className="relative inline-flex align-middle">
      <button
        type="button"
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setOpen((v) => !v);
        }}
        aria-label="도움말"
        aria-expanded={open}
        className="inline-flex items-center justify-center rounded-full text-slate-400 hover:text-indigo-600 focus:outline-none focus:ring-2 focus:ring-indigo-300"
        title="클릭하면 설명이 나와요"
      >
        <HelpCircle size={size} />
      </button>
      {open && (
        <div
          role="tooltip"
          className={`absolute top-full z-50 mt-1 w-72 rounded-lg border border-slate-200 bg-white p-3 text-xs leading-relaxed text-slate-700 shadow-lg ${
            align === "right" ? "left-0" : "right-0"
          }`}
        >
          {title && <p className="mb-1 font-semibold text-slate-900">{title}</p>}
          <p className="whitespace-pre-line">{text}</p>
        </div>
      )}
    </span>
  );
}
