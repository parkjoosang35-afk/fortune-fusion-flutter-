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
