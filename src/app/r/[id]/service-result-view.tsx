// [앱·웹 공유 구조 전면 정리 — REQ-24] 서비스별 웹 결과 뷰.
// 기존 `/r/[id]`의 "제목+요약+줄나열" 공통 카드(shared-result-view)를
// 대체한다. URL 스킴은 그대로 유지(REQ-27)하며 내부 렌더만 교체한다.
//
// [데이터 소스] Flutter 결과 화면들이 POST /api/public/share로 보낸
// `kind` 구조화 payload를 그대로 소비한다(앱이 "admin_web 전용 렌더러"
// 용도로 미리 구조화해 두었다 — tarot/face/palm/saju/wish 각 화면 주석
// 참고). PII(성명·생년월일)는 앱이 애초에 넣지 않으므로 여기서 마스킹
// 대상 자체가 없다(Q4 기본안 준수).
//
// [방어적 파싱] face/palm의 features·topicResults·lines는 앱 모델 직렬화
// 결과라 필드명이 서비스마다 다를 수 있어, 알려진 키 후보들에서 문자열/
// 숫자를 찾는 헬퍼로 정규화한다. 모든 뷰는 payload가 비정상이어도
// summary+highlights 폴백으로 깨지지 않는다(legacy /r/ 링크 호환).
import Link from "next/link";
import type { ReactNode } from "react";

const SERIF = "'Noto Serif KR', serif";
const BRAND_BG = "#0C0408";
const GOLD = "#E7C878";

type AnyObj = Record<string, unknown>;

function asObj(v: unknown): AnyObj | null {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as AnyObj) : null;
}
function asList(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}
function pickStr(o: AnyObj | null, keys: string[]): string | null {
  if (!o) return null;
  for (const k of keys) {
    const v = o[k];
    if (typeof v === "string" && v.trim()) return v.trim();
    if (typeof v === "number") return String(v);
  }
  return null;
}
function pickNum(o: AnyObj | null, keys: string[]): number | null {
  if (!o) return null;
  for (const k of keys) {
    const v = o[k];
    if (typeof v === "number" && Number.isFinite(v)) return v;
    if (typeof v === "string" && v.trim() && Number.isFinite(Number(v))) return Number(v);
  }
  return null;
}
function pickBool(o: AnyObj | null, keys: string[]): boolean | null {
  if (!o) return null;
  for (const k of keys) if (typeof o[k] === "boolean") return o[k] as boolean;
  return null;
}

export function isStructuredPayload(payload: unknown, resultType: string): boolean {
  const o = asObj(payload);
  if (!o) return false;
  const kind = typeof o.kind === "string" ? o.kind : resultType;
  return ["tarot", "saju", "face", "palm", "wish"].includes(kind);
}

function Shell(props: { label: string; children: ReactNode; footer?: ReactNode }) {
  return (
    <section style={{ color: "#F5EFE6" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 18 }}>
        <span style={{ fontSize: 12, fontWeight: 700, letterSpacing: 1, color: GOLD, border: `1px solid ${GOLD}55`, borderRadius: 999, padding: "4px 12px" }}>
          {props.label}
        </span>
      </div>
      {props.children}
      {props.footer}
    </section>
  );
}

function Section(props: { title: string; children: ReactNode }) {
  return (
    <div style={{ marginTop: 18, borderRadius: 14, background: "#FFFFFF0A", border: "1px solid #FFFFFF14", padding: "16px 18px" }}>
      <h3 style={{ margin: 0, fontSize: 15, fontWeight: 700, color: GOLD, fontFamily: SERIF }}>{props.title}</h3>
      <div style={{ marginTop: 8, fontSize: 14.5, lineHeight: 1.75, color: "#EFE7DA", whiteSpace: "pre-wrap" }}>{props.children}</div>
    </div>
  );
}

function FallbackLines({ summary, highlights }: { summary?: string | null; highlights?: unknown }) {
  return (
    <>
      {summary ? <Section title="요약">{summary}</Section> : null}
      {asList(highlights).length > 0 ? (
        <Section title="주요 내용">
          {asList(highlights).map((h, i) => (
            <div key={i}>· {typeof h === "string" ? h : JSON.stringify(h)}</div>
          ))}
        </Section>
      ) : null}
    </>
  );
}

function ErrorEmpty({ text }: { text: string }) {
  return (
    <div style={{ marginTop: 18, borderRadius: 14, background: "#FFFFFF08", border: "1px dashed #FFFFFF20", padding: 20, fontSize: 14, color: "#C9BFAF", textAlign: "center" }}>
      {text}
    </div>
  );
}

// ---------- 타로 (5절: 카드명 정/역방향 · 스프레드 · 카드별 해석 · 총평) ----------
function TarotView({ p }: { p: AnyObj }) {
  const positions = asList(p.positions).map(asObj).filter((x): x is AnyObj => !!x);
  const advice = asObj(p.advice);
  const question = pickStr(p, ["question"]);
  const hero = pickStr(p, ["cardName"]);
  const summary = pickStr(p, ["summary"]);
  return (
    <Shell label="타로">
      {question ? <p style={{ margin: "0 0 14px", fontSize: 13.5, color: "#C9BFAF" }}>질문 · {question}</p> : null}
      {hero ? (
        <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 6 }}>
          <div style={{ width: 64, height: 96, borderRadius: 10, background: "linear-gradient(160deg,#2A1F3D,#141021)", border: `1.5px solid ${GOLD}88`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 30 }}>🔮</div>
          <div>
            <div style={{ fontSize: 18, fontWeight: 800, fontFamily: SERIF }}>{hero}</div>
            <div style={{ fontSize: 12.5, color: "#C9BFAF" }}>대표 카드</div>
          </div>
        </div>
      ) : null}
      {positions.map((pos, i) => {
        const label = pickStr(pos, ["label", "position", "name"]) ?? `포지션 ${i + 1}`;
        const card = pickStr(pos, ["cardName", "card", "name"]) ?? "카드";
        const reversed = pickBool(pos, ["isReversed", "reversed"]);
        const interp = pickStr(pos, ["interpretation", "text", "body", "meaning"]);
        return (
          <div key={i} style={{ marginTop: 14, display: "flex", gap: 12 }}>
            <div style={{ flexShrink: 0, width: 46, height: 68, borderRadius: 8, background: "linear-gradient(160deg,#2A1F3D,#141021)", border: `1px solid ${GOLD}66`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 20, transform: reversed ? "rotate(180deg)" : undefined }}>🃏</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13.5, fontWeight: 700, color: GOLD }}>{label} · {card} {reversed ? "(역방향)" : "(정방향)"}</div>
              <div style={{ fontSize: 14, lineHeight: 1.7, color: "#EFE7DA", marginTop: 4, whiteSpace: "pre-wrap" }}>{interp ?? "해석 정보가 없어요"}</div>
            </div>
          </div>
        );
      })}
      {advice ? (
        <Section title={pickStr(advice, ["label"]) ?? "오늘의 조언"}>{pickStr(advice, ["text", "body"]) ?? ""}</Section>
      ) : null}
      <Section title="총평">{summary ?? "요약이 준비되지 않았어요"}</Section>
      <Section title="행운 요소">
        {`행운의 색: ${pickStr(p, ["luckyColor"]) ?? "-"}\n행운의 숫자: ${pickStr(p, ["luckyNumber"]) ?? "-"}`}
      </Section>
    </Shell>
  );
}

// ---------- 정통사주 (5절: 구성 요약 · 엔진 해석 요약 · 생성 일시) ----------
function SajuView({ p, createdAt }: { p: AnyObj; createdAt: string | null }) {
  const blocks = asList(p.blocks).map(asObj).filter((x): x is AnyObj => !!x);
  const summary = pickStr(p, ["summary"]);
  return (
    <Shell
      label="정통사주"
      footer={createdAt ? <p style={{ marginTop: 22, fontSize: 12, color: "#8F857A" }}>생성 일시 · {createdAt}</p> : undefined}
    >
      {summary ? <Section title="한 줄 요약">{summary}</Section> : null}
      {blocks.map((b, i) => {
        const title = pickStr(b, ["title", "name", "label"]) ?? `해석 ${i + 1}`;
        const body = pickStr(b, ["body", "text", "content"]);
        return <Section key={i} title={title}>{body ?? "해석 정보가 없어요"}</Section>;
      })}
      {blocks.length === 0 && !summary ? <ErrorEmpty text="해석 내용이 준비되지 않았어요" /> : null}
    </Shell>
  );
}

// ---------- 관상 (5절: 유형·점수 · 부위별 해석 · 얼굴 구역 도식) ----------
function FaceView({ p }: { p: AnyObj }) {
  const features = asList(p.features).map(asObj).filter((x): x is AnyObj => !!x);
  const topics = asList(p.topicResults).map(asObj).filter((x): x is AnyObj => !!x);
  const summary = pickStr(p, ["summary"]);
  const typeStr = pickStr(p, ["faceType", "type", "typeName"]);
  const totalScore = pickNum(p, ["score", "totalScore", "faceScore"]);
  return (
    <Shell label="관상">
      {(typeStr || totalScore != null) && (
        <div style={{ display: "flex", gap: 10, marginBottom: 4 }}>
          {typeStr ? <span style={{ fontSize: 13, fontWeight: 700, background: "#FFFFFF12", borderRadius: 10, padding: "8px 14px" }}>유형 · {typeStr}</span> : null}
          {totalScore != null ? <span style={{ fontSize: 13, fontWeight: 700, background: "#FFFFFF12", borderRadius: 10, padding: "8px 14px" }}>점수 · {totalScore}</span> : null}
        </div>
      )}
      <div style={{ margin: "14px 0", display: "flex", justifyContent: "center" }}>
        {/* 얼굴 구역 강조 도식 — 이마/눈/코/입/턱 */}
        <svg width="150" height="190" viewBox="0 0 150 190" role="img" aria-label="얼굴 구역 도식">
          <ellipse cx="75" cy="95" rx="52" ry="70" fill="none" stroke={GOLD} strokeWidth="2" opacity="0.8" />
          <rect x="48" y="30" width="54" height="20" rx="8" fill={GOLD} opacity="0.25" />
          <text x="75" y="44" textAnchor="middle" fontSize="9" fill="#F5EFE6">이마</text>
          <rect x="34" y="62" width="34" height="14" rx="7" fill={GOLD} opacity="0.25" />
          <rect x="82" y="62" width="34" height="14" rx="7" fill={GOLD} opacity="0.25" />
          <text x="75" y="73" textAnchor="middle" fontSize="9" fill="#F5EFE6">눈</text>
          <rect x="64" y="88" width="22" height="16" rx="8" fill={GOLD} opacity="0.25" />
          <text x="75" y="100" textAnchor="middle" fontSize="9" fill="#F5EFE6">코</text>
          <rect x="56" y="114" width="38" height="14" rx="7" fill={GOLD} opacity="0.25" />
          <text x="75" y="125" textAnchor="middle" fontSize="9" fill="#F5EFE6">입</text>
          <rect x="55" y="140" width="40" height="16" rx="8" fill={GOLD} opacity="0.25" />
          <text x="75" y="152" textAnchor="middle" fontSize="9" fill="#F5EFE6">턱</text>
        </svg>
      </div>
      {features.map((f, i) => (
        <Section key={i} title={pickStr(f, ["region", "title", "name", "label", "part"]) ?? `특징 ${i + 1}`}>
          {pickStr(f, ["text", "description", "interpretation", "body", "content"]) ?? "해석 정보가 없어요"}
        </Section>
      ))}
      {topics.map((t, i) => {
        const score = pickNum(t, ["score", "point", "value"]);
        return (
          <Section key={i} title={`${pickStr(t, ["topic", "title", "name", "label"]) ?? `운세 ${i + 1}`}${score != null ? ` · ${score}점` : ""}`}>
            {pickStr(t, ["text", "description", "interpretation", "body"]) ?? "해석 정보가 없어요"}
          </Section>
        );
      })}
      {summary ? <Section title="총평">{summary}</Section> : null}
      {features.length === 0 && topics.length === 0 && !summary ? <ErrorEmpty text="관상 분석 내용이 준비되지 않았어요" /> : null}
    </Shell>
  );
}

// ---------- 손금 (5절: 주요 라인 분석 · 점수 · 손 라인 도식) ----------
function PalmView({ p }: { p: AnyObj }) {
  const lines = asList(p.lines).map(asObj).filter((x): x is AnyObj => !!x);
  const topics = asList(p.topicResults).map(asObj).filter((x): x is AnyObj => !!x);
  const summary = pickStr(p, ["summary"]);
  const lineNames = ["생명선", "두뇌선", "감정선", "운명선"];
  return (
    <Shell label="손금">
      <div style={{ margin: "10px 0 16px", display: "flex", justifyContent: "center" }}>
        {/* 손 라인 도식 — 4대 주요 라인 강조 */}
        <svg width="140" height="200" viewBox="0 0 140 200" role="img" aria-label="손금 라인 도식">
          <path d="M40 60 L40 20 M58 55 L58 12 M76 57 L76 14 M94 62 L94 26 M40 62 L108 62 L104 150 Q74 178 44 150 Z" fill="none" stroke={GOLD} strokeWidth="2" opacity="0.85" strokeLinejoin="round" />
          <path d="M46 84 Q68 96 96 86" fill="none" stroke="#FF8E8E" strokeWidth="2.2" />
          <text x="8" y="90" fontSize="8" fill="#F5EFE6">생명선</text>
          <path d="M46 100 Q70 104 98 98" fill="none" stroke={GOLD} strokeWidth="2.2" />
          <text x="8" y="106" fontSize="8" fill="#F5EFE6">두뇌선</text>
          <path d="M48 116 Q70 112 96 114" fill="none" stroke="#8EB4FF" strokeWidth="2.2" />
          <text x="8" y="122" fontSize="8" fill="#F5EFE6">감정선</text>
          <path d="M70 62 L66 132" fill="none" stroke="#B48EFF" strokeWidth="2.2" />
          <text x="98" y="70" fontSize="8" fill="#F5EFE6">운명선</text>
        </svg>
      </div>
      {lines.map((l, i) => {
        const score = pickNum(l, ["score", "point", "value"]);
        return (
          <Section key={i} title={`${pickStr(l, ["name", "title", "label", "line"]) ?? lineNames[i] ?? `라인 ${i + 1}`}${score != null ? ` · ${score}점` : ""}`}>
            {pickStr(l, ["text", "description", "interpretation", "body"]) ?? "해석 정보가 없어요"}
          </Section>
        );
      })}
      {topics.map((t, i) => {
        const score = pickNum(t, ["score", "point", "value"]);
        return (
          <Section key={i} title={`${pickStr(t, ["topic", "title", "name", "label"]) ?? `운세 ${i + 1}`}${score != null ? ` · ${score}점` : ""}`}>
            {pickStr(t, ["text", "description", "interpretation", "body"]) ?? "해석 정보가 없어요"}
          </Section>
        );
      })}
      {summary ? <Section title="총평">{summary}</Section> : null}
      {lines.length === 0 && topics.length === 0 && !summary ? <ErrorEmpty text="손금 분석 내용이 준비되지 않았어요" /> : null}
    </Shell>
  );
}

// ---------- 소원방 결과 (REQ-25 — 초대(/w/)와 화면·문구 구분) ----------
function WishResultView({ p }: { p: AnyObj }) {
  const summary = pickStr(p, ["summary"]);
  const levelName = pickStr(p, ["levelName"]);
  const daysLit = pickNum(p, ["daysLit"]);
  const level = pickNum(p, ["level"]);
  const color = pickStr(p, ["wishColor"]) ?? "hope";
  const colorHex: Record<string, string> = { hope: "#7FB5FF", love: "#FF8EB4", health: "#7BE0A8", wealth: "#FFD36E", dream: "#C39BFF" };
  const c = colorHex[color] ?? GOLD;
  return (
    <Shell label="소원방 결과">
      <p style={{ margin: "0 0 16px", fontSize: 15, fontFamily: SERIF, color: "#F5EFE6" }}>
        이 소원의 여정이 어떻게 끝났는지 보여드려요 <span style={{ color: "#C9BFAF", fontSize: 12 }}>(초대 화면이 아닙니다)</span>
      </p>
      <div style={{ display: "flex", alignItems: "center", gap: 16, borderRadius: 14, background: "#FFFFFF0A", border: `1px solid ${c}44`, padding: 18 }}>
        <div style={{ fontSize: 40 }}>🏮</div>
        <div>
          <div style={{ fontSize: 16, fontWeight: 800, fontFamily: SERIF, color: c }}>소원이 하늘에 닿았어요</div>
          <div style={{ fontSize: 12.5, color: "#C9BFAF", marginTop: 2 }}>
            {levelName ? `레벨 ${level ?? "-"} · ${levelName}` : null}
            {daysLit != null ? ` · ${daysLit}일 점등` : null}
          </div>
        </div>
      </div>
      {daysLit != null ? (
        <div style={{ marginTop: 14 }}>
          <div style={{ height: 8, borderRadius: 999, background: "#FFFFFF12", overflow: "hidden" }}>
            <div style={{ width: `${Math.min(100, (daysLit / 100) * 100)}%`, height: "100%", background: `linear-gradient(90deg, ${c}66, ${c})` }} />
          </div>
          <div style={{ fontSize: 11.5, color: "#8F857A", marginTop: 4 }}>달성 여정 — {daysLit}일의 정성</div>
        </div>
      ) : null}
      <FallbackLines summary={summary} highlights={p.highlights} />
    </Shell>
  );
}

export function ServiceResultView(props: { resultType: string; payload: unknown; createdAt: string | null }) {
  const o = asObj(props.payload);
  if (!o) {
    return (
      <Shell label={props.resultType}>
        <FallbackLines summary={null} highlights={[]} />
      </Shell>
    );
  }
  const kind = typeof o.kind === "string" ? o.kind : props.resultType;
  switch (kind) {
    case "tarot":
      return <TarotView p={o} />;
    case "saju":
    case "fortune":
      return <SajuView p={o} createdAt={props.createdAt} />;
    case "face":
      return <FaceView p={o} />;
    case "palm":
      return <PalmView p={o} />;
    case "wish":
      return <WishResultView p={o} />;
    default:
      return (
        <Shell label={props.resultType}>
          <FallbackLines summary={pickStr(o, ["summary"])} highlights={o.highlights} />
        </Shell>
      );
  }
}

// [REQ-21/23 — 웹 공유 버튼용 링크는 웹 결과 페이지 URL]
export function isWebShareSource(v: string | undefined): boolean {
  return v === "web";
}

export { BRAND_BG, GOLD };
export const _unusedLink = Link;
