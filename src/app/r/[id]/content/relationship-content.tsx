// 귀인지도 결과 전용 웹 렌더러(legacy 폴백) — `kind` 필드가 없는 구버전
// payload를 위한 단순 집계 카드(guin/oreunpal/horang). [비식별 원칙 유지]
// 이름은 노출하지 않고 관계유형별 집계만 보여준다.
//
// [2027-02 복원] `/r/[id]` 즉시 리다이렉트 전환(7d5ed92) 때 삭제되었던
// 파일을 그대로 복원한다. 현재 신규 공유(`kind:'relationship'`)는
// 이 파일이 아니라 `service-result-view.tsx`의 RelationshipView(V2 6종
// 집계 + 1:1 관계 상세 카드 지원)를 탄다 — 이 파일은 그 이전에 생성된
// 레거시 공유 링크만을 위한 하위호환 폴백이다.
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
