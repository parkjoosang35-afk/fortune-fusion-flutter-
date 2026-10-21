"use client";
// [REQ-21/23 — 웹 공유 링크 생성 + 신통방통 웹 결과 공유 기능 복원, 2027-02]
// 웹 결과 페이지 안의 공유 버튼은 웹 결과 페이지 URL
// (`{origin}/web-result/{shareId}`)을 생성·공유한다 — 앱 공유 링크
// (`/r/{shareId}`, Android App Links autoVerify로 설치 기기에서 앱 직행)와
// 생성 경로가 분리된다(AC-21-1~3). 설치 강요 없이 콘텐츠 그대로 공유(REQ-23).
// navigator.share가 지원되는 모바일 브라우저/카카오톡 인앱 브라우저에서는
// OS 공유시트(카카오톡 포함)가 뜨고, 미지원 데스크톱에서는 클립보드 복사로
// 폴백한다.
import { useState } from "react";
import { shareResultLink, type ShareOutcome } from './share-result-link';

export function WebShareButton({ shareUrl, title, description }: { shareUrl: string; title: string; description: string }) {
  const [outcome, setOutcome] = useState<ShareOutcome | null>(null);
  const [busy, setBusy] = useState(false);
  async function share() {
    if (busy) return;
    setBusy(true);
    setOutcome(null);
    try {
      const result = await shareResultLink({
        share: typeof navigator !== 'undefined' && navigator.share ? data => navigator.share(data) : undefined,
        copy: typeof navigator !== 'undefined' && navigator.clipboard ? text => navigator.clipboard.writeText(text) : undefined,
      }, { title, text: `${title}\n${description}`, url: shareUrl });
      setOutcome(result);
    } finally { setBusy(false); }
  }
  return (
    <div>
    <button
      onClick={share}
      disabled={busy}
      aria-busy={busy}
      style={{
        width: "100%", marginTop: 24, padding: "14px 0", borderRadius: 12,
        background: "linear-gradient(135deg, #C99B7F, #A6795E)", color: "#fff",
        fontWeight: 800, fontSize: 15, border: "none", cursor: "pointer",
      }}
    >
      {busy ? '공유 준비 중' : outcome === 'copied' ? '링크를 복사했어요' : '이 결과를 웹 링크로 공유하기'}
    </button>
    {outcome === 'manual' && <div role="status" style={{ color: '#F5EFE6', marginTop: 12 }}>
      <p>공유·자동 복사가 지원되지 않아요. 아래 링크를 선택해서 복사해주세요.</p>
      <input aria-label="직접 복사할 결과 링크" readOnly value={shareUrl} onFocus={event => event.currentTarget.select()} style={{ width: '100%', boxSizing: 'border-box', padding: 12 }} />
    </div>}
    {outcome === 'copied' && <p role="status" style={{ color: '#F5EFE6' }}>원하는 앱에 링크를 붙여넣어 전달해주세요.</p>}
    </div>
  );
}
