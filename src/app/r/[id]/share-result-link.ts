// [REQ-21/23 — 웹 결과 공유 버튼용 공통 포트] navigator.share 지원 여부에
// 따라 OS 공유시트 → 클립보드 복사 → 수동 복사 순으로 폴백한다.
//
// [2027-02 복원] `/r/[id]` 즉시 리다이렉트 전환(7d5ed92) 때 삭제되었던
// 파일을 그대로 복원한다(web-share-button.tsx가 사용).
export type ShareOutcome = 'shared' | 'cancelled' | 'copied' | 'manual';
export type BrowserSharePort = {
  share?: (data: { title: string; text: string; url: string }) => Promise<void>;
  copy?: (text: string) => Promise<void>;
};
export async function shareResultLink(port: BrowserSharePort, data: { title: string; text: string; url: string }): Promise<ShareOutcome> {
  if (port.share) {
    try { await port.share(data); return 'shared'; }
    catch (error) {
      if ((error as {name?: string})?.name === 'AbortError') return 'cancelled';
    }
  }
  if (port.copy) {
    try { await port.copy(data.url); return 'copied'; } catch { /* 직접 복사 안내 */ }
  }
  return 'manual';
}
