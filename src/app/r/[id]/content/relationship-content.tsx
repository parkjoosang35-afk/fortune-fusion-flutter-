// 귀인지도 결과 전용 웹 렌더러 — `guinji_result_card_screen.dart`가
// 보내는 payload(`kind:'relationship'`)를 관계유형별 인원수 카드로
// 그린다. [비식별 원칙 유지] 앱과 동일하게 이름은 노출하지 않고
// 관계유형별 집계(귀인/오른팔/호랑이 선생)만 보여준다.
import { SharePayload, asNumber, asString, asStringList } from "./types";

type Counts = { guin?: number; oreunpal?: number; horang?: number };

function asCounts(v: unknown): Counts | undefined {
  if (!v || typeof v !== "object") return undefined;
  const obj = v as Record<string, unknown>;
  return {
    guin: asNumber(obj.guin),
    oreunpal: asNumber(obj.oreunpal),
    horang: asNumber(obj.horang),
  };
}

export function RelationshipContent({ payload, description }: { payload: SharePayload; description?: string }) {
  const counts = asCounts(payload.counts);
  const summary = asString(payload.summary);
  const fallbackLines = asStringList(payload.highlights);

  const cards = counts
    ? [
        { label: "귀인", value: counts.guin, color: "#A6795E" },
        { label: "오른팔", value: counts.oreunpal, color: "#4A7AD8" },
        { label: "호랑이 선생", value: counts.horang, color: "#D86A4A" },
      ].filter((c) => c.value !== undefined)
    : [];

  return (
    <div className="space-y-4">
      {description && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{description}</p>}
      {!description && summary && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{summary}</p>}

      {cards.length > 0 && (
        <div className="grid grid-cols-3 gap-2.5">
          {cards.map((c) => (
            <div
              key={c.label}
              className="rounded-2xl border border-[#E8DDD0] bg-white/85 p-4 text-center shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]"
            >
              <p className="text-[22px] font-bold" style={{ color: c.color }}>
                {c.value}
                <span className="ml-0.5 text-[13px] font-semibold">명</span>
              </p>
              <p className="mt-1 text-[11px] font-semibold text-[#8A7468]">{c.label}</p>
            </div>
          ))}
        </div>
      )}

      {cards.length === 0 && fallbackLines && fallbackLines.length > 0 && (
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
