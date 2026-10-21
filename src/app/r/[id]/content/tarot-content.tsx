// 타로 결과 전용 웹 렌더러 — `tarot_result_screen.dart`가 보내는 payload
// (`kind:'tarot'`)를 타로 서비스 특유의 레이아웃(질문 → 메인 카드 →
// 포지션별 스프레드 → 조언 → 행운의 색/숫자)으로 그린다.
//
// [2027-02 복원] `/r/[id]` 즉시 리다이렉트 전환(7d5ed92) 때 삭제되었던
// 파일을 그대로 복원한다(legacy 'kind' 미포함 payload 하위호환 폴백 경로).
import { SharePayload, asString, asStringList, asNumber } from "./types";

const SERIF = "'Noto Serif KR', serif";

type Position = { label?: string; cardName?: string; isReversed?: boolean; interpretation?: string };

function asPositions(v: unknown): Position[] | undefined {
  if (!Array.isArray(v)) return undefined;
  const out = v
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const obj = item as Record<string, unknown>;
      return {
        label: asString(obj.label),
        cardName: asString(obj.cardName),
        isReversed: typeof obj.isReversed === "boolean" ? obj.isReversed : undefined,
        interpretation: asString(obj.interpretation),
      } as Position;
    })
    .filter((x): x is Position => x !== null);
  return out.length > 0 ? out : undefined;
}

export function TarotContent({ payload, description }: { payload: SharePayload; description?: string }) {
  const question = asString(payload.question);
  const cardName = asString(payload.cardName);
  const positions = asPositions(payload.positions);
  const advice = payload.advice as { label?: string; text?: string } | undefined;
  const adviceLabel = advice && typeof advice === "object" ? asString(advice.label) : undefined;
  const adviceText = advice && typeof advice === "object" ? asString(advice.text) : undefined;
  const luckyColor = asString(payload.luckyColor);
  const luckyNumber = asNumber(payload.luckyNumber);
  const summary = asString(payload.summary);
  const fallbackLines = asStringList(payload.highlights);

  return (
    <div className="space-y-4">
      {question && (
        <div className="rounded-2xl border border-[#2A2438]/15 bg-[#2A2438]/5 px-4 py-3">
          <p className="text-[11px] font-semibold text-[#8A7468]">질문</p>
          <p className="mt-1 text-[13.5px] leading-relaxed text-[#2A2438]">{question}</p>
        </div>
      )}

      {cardName && (
        <div className="rounded-3xl border border-[#E8DDD0] bg-gradient-to-br from-[#2A2438] to-[#4A3F5C] px-5 py-6 text-center shadow-[0_8px_30px_-10px_rgba(42,36,56,0.4)]">
          <p className="text-[11px] font-semibold tracking-wide text-[#E8B4A5]">오늘의 카드</p>
          <p style={{ fontFamily: SERIF }} className="mt-2 text-[22px] font-bold text-white">
            {cardName}
          </p>
        </div>
      )}

      {description && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{description}</p>}
      {!description && summary && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{summary}</p>}

      {positions && positions.length > 0 && (
        <div className="space-y-2.5">
          {positions.map((p, i) => (
            <div
              key={i}
              className="rounded-2xl border border-[#E8DDD0] bg-white/85 p-4 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]"
            >
              <div className="mb-1.5 flex items-center justify-between">
                <span className="text-[11px] font-bold text-[#A6795E]">{p.label ?? `포지션 ${i + 1}`}</span>
                {p.cardName && (
                  <span className="text-[12px] font-semibold text-[#2A2438]">
                    {p.cardName}
                    {p.isReversed ? " (역방향)" : ""}
                  </span>
                )}
              </div>
              {p.interpretation && (
                <p className="text-[13px] leading-relaxed text-[#2A2438]">{p.interpretation}</p>
              )}
            </div>
          ))}
        </div>
      )}

      {(adviceText || luckyColor || luckyNumber !== undefined) && (
        <div className="rounded-2xl border border-[#F5D9C9] bg-[#FBEFE8] p-4">
          {adviceText && (
            <p className="mb-2 text-[13px] leading-relaxed text-[#2A2438]">
              <span className="font-bold text-[#A6795E]">{adviceLabel ?? "오늘의 조언"}: </span>
              {adviceText}
            </p>
          )}
          <div className="flex gap-4 text-[12px] text-[#8A7468]">
            {luckyColor && <span>행운의 색: {luckyColor}</span>}
            {luckyNumber !== undefined && <span>행운의 숫자: {luckyNumber}</span>}
          </div>
        </div>
      )}

      {/* [하위 호환 폴백] 구조화 필드(positions 등)가 없는 구버전/QA 데이터는
          highlights 문자열 나열로 대체 표시한다 — 화면이 비어 보이지 않게. */}
      {!positions && fallbackLines && fallbackLines.length > 0 && (
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
