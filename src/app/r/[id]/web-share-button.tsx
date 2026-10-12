"use client";
// [REQ-21/23 — 웹 공유 링크 생성] 웹 결과 페이지 안의 공유 버튼은 웹 결과
// 페이지 URL(`{origin}/r/{shareId}?src=web`)을 생성·공유한다 — 앱 공유 링크
// (`/r/{shareId}`, Android App Links autoVerify로 설치 기기에서 앱 직행)와
// 생성 경로가 분리된다(AC-21-1~3). 설치 강요 없이 콘텐츠 그대로 공유(REQ-23).
import { useState } from "react";

export function WebShareButton({ shareUrl, title, description }: { shareUrl: string; title: string; description: string }) {
  const [copied, setCopied] = useState(false);
  async function share() {
    const data = { title, text: `${title}\n${description}`, url: shareUrl };
    try {
      if (typeof navigator !== "undefined" && navigator.share) {
        await navigator.share(data);
        return;
      }
      await navigator.clipboard.writeText(shareUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      /* 사용자가 공유를 취소한 경우 — 조용히 무시 */
    }
  }
  return (
    <button
      onClick={share}
      style={{
        width: "100%", marginTop: 24, padding: "14px 0", borderRadius: 12,
        background: "linear-gradient(135deg, #C99B7F, #A6795E)", color: "#fff",
        fontWeight: 800, fontSize: 15, border: "none", cursor: "pointer",
      }}
    >
      {copied ? "링크를 복사했어요" : "🔗 이 결과를 웹 링크로 공유하기"}
    </button>
  );
}
