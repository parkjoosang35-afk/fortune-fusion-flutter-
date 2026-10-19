// 관상/손금 결과 전용 웹 렌더러 — `face_result_screen.dart`/
// `palm_result_screen.dart`가 보내는 payload(`kind:'face'|'palm'`)를
// "부위별 특징 + 주제별 운세" 2단 구획으로 그린다. 두 서비스는 구조가
// 동일(features/lines + topicResults)하므로 한 컴포넌트를 공유하되
// partKind로 라벨만 구분한다.
import { SharePayload, asString, asStringList, asStringRecord } from "./types";

const TOPIC_ORDER = ["재물", "애정", "직업", "건강"];

function orderedEntries(record: Record<string, string>): [string, string][] {
  const ordered: [string, string][] = [];
  for (const key of TOPIC_ORDER) {
    if (record[key] !== undefined) ordered.push([key, record[key]]);
  }
  for (const [k, v] of Object.entries(record)) {
    if (!TOPIC_ORDER.includes(k)) ordered.push([k, v]);
  }
  return ordered;
}

export function FacePalmContent({
  payload,
  partKind,
  description,
}: {
  payload: SharePayload;
  partKind: "face" | "palm";
  description?: string;
}) {
  const partRecord = asStringRecord(partKind === "face" ? payload.features : payload.lines);
  const topicRecord = asStringRecord(payload.topicResults);
  const summary = asString(payload.summary);
  const fallbackLines = asStringList(payload.highlights);
  const partLabel = partKind === "face" ? "부위별 특징" : "손금 라인별 특징";

  return (
    <div className="space-y-4">
      {description && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{description}</p>}
      {!description && summary && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{summary}</p>}

      {partRecord && (
        <div>
          <p className="mb-2 text-[11px] font-bold text-[#A6795E]">{partLabel}</p>
          <div className="space-y-2">
            {Object.entries(partRecord).map(([key, value]) => (
              <div
                key={key}
                className="rounded-2xl border border-[#E8DDD0] bg-white/85 p-4 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]"
              >
                <p className="mb-1 text-[12px] font-bold text-[#2A2438]">{key}</p>
                <p className="text-[13px] leading-relaxed text-[#6E5A54]">{value}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {topicRecord && (
        <div>
          <p className="mb-2 text-[11px] font-bold text-[#A6795E]">주제별 운세</p>
          <div className="grid grid-cols-2 gap-2.5">
            {orderedEntries(topicRecord).map(([key, value]) => (
              <div key={key} className="rounded-2xl border border-[#F5D9C9] bg-[#FBEFE8] p-3">
                <p className="mb-1 text-[11px] font-bold text-[#A6795E]">{key}</p>
                <p className="text-[12px] leading-relaxed text-[#2A2438]">{value}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {!partRecord && !topicRecord && fallbackLines && fallbackLines.length > 0 && (
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
