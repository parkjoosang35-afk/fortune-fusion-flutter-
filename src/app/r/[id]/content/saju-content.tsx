// 정통사주 결과 전용 웹 렌더러 — `story_detail_screen.dart`가 보내는
// payload(`kind:'saju'`)를 5단 서사 구조(`blocks: [{title, body}]`)
// 그대로 카드 단위로 나열해 그린다(앱 내 스토리 화면의 단락 구성과
// 동일한 리듬을 웹에서도 재현).
import { SharePayload, asString, asStringList } from "./types";

const SERIF = "'Noto Serif KR', serif";

type Block = { title?: string; body?: string };

function asBlocks(v: unknown): Block[] | undefined {
  if (!Array.isArray(v)) return undefined;
  const out = v
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const obj = item as Record<string, unknown>;
      return {
        title: asString(obj.title),
        body: asString(obj.body),
      } as Block;
    })
    .filter((x): x is Block => x !== null && (!!x.title || !!x.body));
  return out.length > 0 ? out : undefined;
}

export function SajuContent({ payload, description }: { payload: SharePayload; description?: string }) {
  const blocks = asBlocks(payload.blocks);
  const summary = asString(payload.summary);
  const fallbackLines = asStringList(payload.highlights);

  return (
    <div className="space-y-4">
      {description && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{description}</p>}
      {!description && summary && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{summary}</p>}

      {blocks && blocks.length > 0 && (
        <div className="space-y-3">
          {blocks.map((b, i) => (
            <div
              key={i}
              className="rounded-2xl border border-[#E8DDD0] bg-white/85 p-4 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]"
            >
              <div className="mb-1.5 flex items-center gap-2">
                <span className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[#FBEFE8] text-[10px] font-bold text-[#A6795E]">
                  {i + 1}
                </span>
                {b.title && (
                  <p style={{ fontFamily: SERIF }} className="text-[13px] font-bold text-[#2A2438]">
                    {b.title}
                  </p>
                )}
              </div>
              {b.body && <p className="text-[13.5px] leading-relaxed text-[#2A2438]">{b.body}</p>}
            </div>
          ))}
        </div>
      )}

      {/* [하위 호환 폴백] blocks가 없는 구버전/QA 데이터는 highlights 나열로
          대체 표시한다 — 화면이 비어 보이지 않게. */}
      {!blocks && fallbackLines && fallbackLines.length > 0 && (
        <div className="space-y-2 rounded-3xl border border-[#E8DDD0] bg-white/85 p-4">
          {fallbackLines.map((line, i) => (
            <p key={i} className="text-[13.5px] leading-relaxed text-[#2A2438]">
              {line}
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
