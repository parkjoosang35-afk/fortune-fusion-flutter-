// 귀인지도 "동심원 궤도" 지도 — 웹 전용 신설 컴포넌트.
//
// [2026-11, 귀인지도·소원방 초대장 최종 정상화 지시서 — 사용자 명시 지시]
// "이름+생년월일 입력 시 결과을 신통방통 웹에서 결과을 보여줘야해 첨부한
// 이미지 참조 들어온 사람은 지도에 자기가 있는게 보일거구 지도에 참여한걸
// 보게 될거구 들어오면 그사람과의 관계 결과 갱신해주면돼 여기서부터는 니가
// 흐름에 맞춰서 기획하면돼고"
//
// 사용자가 첨부한 이미지는 Flutter 앱의 실제 귀인지도 화면
// (`lib/features/guinji/widgets/guinji_orbit_map.dart`)이다 — 동심원 점선
// 궤도(안쪽 貴 → 바깥쪽 衝) 위에 원형 아바타 노드들이 배치되고, 중앙에
// 지도 주인 노드가 있는 구조. 이 파일은 그 비주얼 언어를 웹(SVG)으로
// 그대로 재현하되, 앱 코드/엔진은 전혀 건드리지 않고(지시 "앱거는
// 건드리지말고") 완전히 새로운 웹 전용 컴포넌트로 만든다.
//
// [기존 RelationNetworkGraph와의 관계] 기존 위성형 그래프
// (`relation-network-graph.tsx`)는 수정하지 않고 그대로 둔다(다른 곳에서
// 참조할 가능성 대비). 이 페이지(`guinji-invite-interactive.tsx`)에서만
// 이 신규 컴포넌트로 교체해 사용한다.
//
// [비식별 원칙 — 부분 완화, 사용자 명시 지시로 "나"만 예외] 기존 원칙은
// "어떤 개인정보도 넘기지 않는다"였으나, 사용자가 이번에 "들어온 사람은
// 지도에 자기가 있는게 보일거구"라고 명시적으로 요구했다. 따라서:
//   - 다른 멤버(= 이 요청의 본인이 아닌 사람)는 기존과 동일하게 이름 없는
//     점(dot)으로만 표시한다 — 그 사람들의 신상은 여전히 노출하지 않는다.
//   - "지금 이 폼을 제출해 결과를 받은 바로 그 사람"만, 자신이 로컬에
//     입력한 이름(`self.name`, 서버에 저장되긴 하지만 본인이 이미 알고
//     있는 자기 자신의 정보)을 자기 화면에 한해 하이라이트로 보여준다.
//     이는 "비식별 원칙"이 보호하려는 대상(제3자의 개인정보 노출)을
//     침해하지 않는다 — 본인이 자기 자신을 보는 것이기 때문이다.
"use client";

import type { RelationCount } from "./relation-network-graph";

const SIZE = 320;
const CENTER = SIZE / 2;
const CENTER_RADIUS = 28;

// [앱과 동일한 궤도 반지름 비율] Flutter `guinji_orbit_map.dart`의
// `guinjiOrbitRadii = [55, 78, 100, 122, 144, 164]`(6종, 貴→衝 순서)와
// 동일한 간격 패턴을 이 SVG 캔버스(320) 크기에 맞게 그대로 적용한다.
const ORBIT_RADII = [50, 72, 94, 116, 138, 158];
const DOT_RADIUS = 11;
const SELF_RADIUS = 17;
const MAX_DOTS_PER_RING = 7;

export interface SelfNode {
  name: string;
  relationType: string;
}

function polarToXY(radius: number, angleRad: number) {
  return { x: CENTER + radius * Math.cos(angleRad), y: CENTER + radius * Math.sin(angleRad) };
}

export function GuinjiOrbitMap({
  counts,
  ownerName,
  self,
}: {
  counts: RelationCount[]; // GUINJI_V2_RELATION_TYPE_ORDER 순서 그대로 전달되어야 함(index = orbit)
  ownerName: string;
  self?: SelfNode | null;
}) {
  const total = counts.reduce((sum, c) => sum + c.count, 0);
  const selfOrbitIndex = self ? counts.findIndex((c) => c.key === self.relationType) : -1;

  type DotNode = { x: number; y: number; color: string; hanja: string; isSelf: boolean; name?: string };
  const dots: DotNode[] = [];
  const overflowLabels: Array<{ x: number; y: number; text: string; color: string }> = [];

  counts.forEach((type, orbitIndex) => {
    const r = ORBIT_RADII[orbitIndex];
    // [핵심] self가 이 궤도에 속하면, 집계(count)에서 본인 1명을 빼고 나머지만
    // 익명 점으로 그린다 — 서버가 돌려준 mapSummary.counts는 본인을 포함한
    // 합계이므로, 본인 노드와 익명 점이 겹쳐 "한 명이 두 번" 보이지 않게 한다.
    const isSelfOrbit = orbitIndex === selfOrbitIndex;
    const anonymousCount = isSelfOrbit ? Math.max(0, type.count - 1) : type.count;
    if (anonymousCount === 0 && !isSelfOrbit) return;

    // 본인 노드는 항상 궤도의 정top(−90°)에 고정 배치해 "내 자리"가 매번
    // 같은 곳에 있도록 한다(같은 데이터면 항상 같은 그림 — 결정론적 렌더링
    // 원칙 계승).
    const selfAngle = -Math.PI / 2;
    if (isSelfOrbit && self) {
      const { x, y } = polarToXY(r, selfAngle);
      dots.push({ x, y, color: type.color, hanja: type.hanja, isSelf: true, name: self.name });
    }

    const visibleAnon = Math.min(anonymousCount, MAX_DOTS_PER_RING);
    const overflow = anonymousCount - visibleAnon;
    // 본인이 top을 차지했으니, 익명 점들은 top을 피해 나머지 궤도 둘레에
    // 고르게 분산 배치한다(겹침 방지).
    const startOffset = isSelfOrbit ? (Math.PI * 2) / Math.max(visibleAnon + 1, 1) : 0;
    const angleStep = (Math.PI * 2) / Math.max(visibleAnon, 1);
    for (let i = 0; i < visibleAnon; i++) {
      const angle = selfAngle + startOffset + angleStep * i;
      const { x, y } = polarToXY(r, angle);
      dots.push({ x, y, color: type.color, hanja: type.hanja, isSelf: false });
    }
    if (overflow > 0) {
      const { x, y } = polarToXY(r, selfAngle + startOffset + angleStep * visibleAnon);
      overflowLabels.push({ x, y, text: `+${overflow}`, color: type.color });
    }
  });

  return (
    <div className="rounded-3xl border border-[#2A2A2E] bg-[#161618] p-5 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
      <div className="mb-3 flex items-baseline justify-between">
        <h2 style={{ fontFamily: "'Noto Serif KR', serif" }} className="text-base font-bold text-[#F2F0EC]">
          {ownerName}님의 귀인 지도
        </h2>
        <span className="text-sm font-medium text-[#8A8880]">{total}명</span>
      </div>

      {self && (
        <p className="mb-3 rounded-xl bg-[#7BA05B]/10 px-3 py-2 text-center text-xs font-medium text-[#5A7A43]">
          ✦ 지도에 참여했어요 — 아래 지도에서 {self.name}님의 자리를 확인해 보세요.
        </p>
      )}

      {total === 0 ? (
        <p className="py-8 text-center text-sm text-[#575650]">
          아직 지도에 오른 사람이 없어요.
          <br />
          가장 먼저 이름을 올려 보세요.
        </p>
      ) : (
        <svg
          viewBox={`0 0 ${SIZE} ${SIZE}`}
          className="mx-auto block w-full max-w-[300px]"
          role="img"
          aria-label={`${ownerName}님의 귀인 지도, 총 ${total}명${self ? `, ${self.name}님 참여함` : ""}`}
        >
          <style>{`
            @keyframes gom-center-pulse {
              0%, 100% { transform: scale(1); filter: drop-shadow(0 0 0px rgba(42,36,56,0.4)); }
              50% { transform: scale(1.05); filter: drop-shadow(0 0 6px rgba(233,196,106,0.5)); }
            }
            @keyframes gom-self-glow {
              0%, 100% { filter: drop-shadow(0 0 2px rgba(255,255,255,0.3)); }
              50% { filter: drop-shadow(0 0 10px rgba(255,255,255,0.85)); }
            }
            @keyframes gom-twinkle {
              0%, 100% { opacity: 0.8; }
              50% { opacity: 1; }
            }
            .gom-center { transform-origin: ${CENTER}px ${CENTER}px; animation: gom-center-pulse 2.8s ease-in-out infinite; }
            .gom-self { transform-box: fill-box; transform-origin: center; animation: gom-self-glow 1.8s ease-in-out infinite; }
            .gom-dot { transform-box: fill-box; transform-origin: center; animation: gom-twinkle 2.4s ease-in-out infinite; }
            @media (prefers-reduced-motion: reduce) {
              .gom-center, .gom-self, .gom-dot { animation: none; }
            }
          `}</style>

          {/* 동심원 점선 궤도 6개 — 안쪽(貴) → 바깥쪽(衝), 앱 guinji_orbit_map.dart와 동일한 시각 언어 */}
          {ORBIT_RADII.map((r, i) => (
            <circle
              key={`orbit-${i}`}
              cx={CENTER}
              cy={CENTER}
              r={r}
              fill="none"
              stroke={counts[i]?.color ?? "#2A2A2E"}
              strokeOpacity={0.35}
              strokeDasharray="3 4"
              strokeWidth={1}
            />
          ))}

          {/* 익명 집계 점 — 다른 참여자(비식별, 이름 없음) */}
          {dots
            .filter((d) => !d.isSelf)
            .map((d, i) => (
              <g key={`dot-${i}`} className="gom-dot" style={{ animationDelay: `${(i % 6) * 0.3}s` }}>
                <circle cx={d.x} cy={d.y} r={DOT_RADIUS} fill={d.color} fillOpacity={0.3} stroke={d.color} strokeWidth={1.5} />
                <text x={d.x} y={d.y + 3.5} textAnchor="middle" fontSize={10} fontWeight={700} fill={d.color}>
                  {d.hanja}
                </text>
              </g>
            ))}

          {/* 오버플로우 "+N" 표기 */}
          {overflowLabels.map((o, i) => (
            <text
              key={`of-${i}`}
              x={o.x}
              y={o.y + 3.5}
              textAnchor="middle"
              fontSize={9}
              fontWeight={700}
              fill={o.color}
              opacity={0.8}
            >
              {o.text}
            </text>
          ))}

          {/* [핵심 신설] 본인 노드 — 방금 참여한 게스트 자신만 이름과 함께
              하이라이트(흰색 이중 테두리 + glow)로 표시한다. */}
          {dots
            .filter((d) => d.isSelf)
            .map((d, i) => (
              <g key={`self-${i}`}>
                <g className="gom-self">
                  <circle cx={d.x} cy={d.y} r={SELF_RADIUS + 3} fill="none" stroke="#FFFFFF" strokeWidth={1.5} strokeOpacity={0.7} />
                  <circle cx={d.x} cy={d.y} r={SELF_RADIUS} fill={d.color} />
                  <text x={d.x} y={d.y + 4.5} textAnchor="middle" fontSize={13} fontWeight={800} fill="#0B0B0D">
                    {d.hanja}
                  </text>
                </g>
                <text
                  x={d.x}
                  y={d.y + SELF_RADIUS + 14}
                  textAnchor="middle"
                  fontSize={10.5}
                  fontWeight={800}
                  fill="#F2F0EC"
                >
                  {d.name}
                </text>
                <text
                  x={d.x}
                  y={d.y - SELF_RADIUS - 8}
                  textAnchor="middle"
                  fontSize={9}
                  fontWeight={700}
                  fill="#E9C46A"
                >
                  ✦ 당신
                </text>
              </g>
            ))}

          {/* 중앙 노드 — 지도 주인 */}
          <g className="gom-center">
            <circle cx={CENTER} cy={CENTER} r={CENTER_RADIUS} fill="#F2F0EC" />
            <text x={CENTER} y={CENTER - 2} textAnchor="middle" fontSize={13} fontWeight={700} fill="#0B0B0D">
              나
            </text>
            <text x={CENTER} y={CENTER + 12} textAnchor="middle" fontSize={8} fontWeight={500} fill="#575650">
              {ownerName.length > 6 ? `${ownerName.slice(0, 6)}…` : ownerName}
            </text>
          </g>
        </svg>
      )}

      {/* 범례 — 6종 관계유형 색상/한자/인원수 */}
      <div className="mt-4 grid grid-cols-3 gap-1.5">
        {counts.map((c) => {
          const isSelfType = self?.relationType === c.key;
          return (
            <div
              key={c.key}
              className="flex flex-col items-center rounded-xl border px-1 py-2"
              style={{
                borderColor: isSelfType ? c.color : "#2A2A2E",
                backgroundColor: isSelfType ? `${c.color}1A` : "#1C1C1F",
              }}
            >
              <span
                className="mb-1 flex h-6 w-6 items-center justify-center rounded-full text-[11px] font-bold text-white"
                style={{ backgroundColor: c.color }}
              >
                {c.hanja}
              </span>
              <span className="text-[11px] text-[#8A8880]">{c.label}</span>
              <span className="text-sm font-bold text-[#F2F0EC]">{c.count}</span>
              {isSelfType && <span className="mt-0.5 text-[9px] font-bold text-[#E9C46A]">· 나</span>}
            </div>
          );
        })}
      </div>
    </div>
  );
}
