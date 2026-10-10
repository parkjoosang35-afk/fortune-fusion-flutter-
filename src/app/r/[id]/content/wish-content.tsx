// 소원방 "결과 공유" 전용 웹 렌더러 — `complete_screen.dart`의 `_shareResult`
// 가 보내는 payload(`kind:'wish'`)를 소원 성취 기념 카드로 그린다.
//
// [초대 공유와의 구분 — 지시서 3항] 이 컴포넌트는 "결과 공유"
// (ShareResultType.wish, `/r/{shareId}`)만 다룬다. 소원방 "초대 공유"
// (`main_room_screen.dart` `_ShareSheet`, `/w/{token}`)는 완전히 다른
// 목적(참여 유도)의 별도 페이지(`app/w/[token]/page.tsx`)이며 이 파일과
// 무관하다 — 절대 통합하지 않는다.
import { SharePayload, asNumber, asString, asStringList } from "./types";

const SERIF = "'Noto Serif KR', serif";

export function WishContent({ payload, description }: { payload: SharePayload; description?: string }) {
  const ownerName = asString(payload.ownerName);
  const levelName = asString(payload.levelName);
  const level = asNumber(payload.level);
  const daysLit = asNumber(payload.daysLit);
  const wishColor = asString(payload.wishColor);
  const summary = asString(payload.summary);
  const fallbackLines = asStringList(payload.highlights);

  const hasAchievement = levelName !== undefined || daysLit !== undefined || wishColor !== undefined;

  return (
    <div className="space-y-4">
      {description && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{description}</p>}
      {!description && summary && <p className="text-[14px] leading-relaxed text-[#6E5A54]">{summary}</p>}

      {hasAchievement && (
        <div
          className="rounded-3xl border border-[#E8DDD0] px-5 py-7 text-center shadow-[0_8px_30px_-10px_rgba(166,121,94,0.35)]"
          style={{
            backgroundImage: `linear-gradient(135deg, ${wishColor ?? "#A6795E"}22, #FBEFE8)`,
          }}
        >
          <p className="text-[11px] font-semibold tracking-wide text-[#A6795E]">
            {ownerName ? `${ownerName}님의 소원방` : "소원방"}
          </p>
          {levelName && (
            <p style={{ fontFamily: SERIF }} className="mt-2 text-[22px] font-bold text-[#2A2438]">
              {levelName}
              {level !== undefined ? ` · Lv.${level}` : ""}
            </p>
          )}
          <div className="mt-4 flex items-center justify-center gap-6">
            {daysLit !== undefined && (
              <div>
                <p className="text-[20px] font-bold text-[#2A2438]">{daysLit}</p>
                <p className="text-[11px] text-[#8A7468]">점등 일수</p>
              </div>
            )}
            {wishColor && (
              <div className="flex flex-col items-center">
                <span
                  className="h-5 w-5 rounded-full border border-[#E8DDD0]"
                  style={{ backgroundColor: wishColor }}
                />
                <p className="mt-1 text-[11px] text-[#8A7468]">소원 빛깔</p>
              </div>
            )}
          </div>
        </div>
      )}

      {!hasAchievement && fallbackLines && fallbackLines.length > 0 && (
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
