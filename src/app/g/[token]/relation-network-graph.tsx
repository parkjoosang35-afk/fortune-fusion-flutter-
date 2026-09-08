// 관계 지도 네트워크 그래프 — 사용자 요구("4번째 레퍼런스처럼 나와야 바이럴이
// 된다")의 핵심 신규 시각화. 중앙 "나" 노드 + 관계유형(12라벨)별 위성
// 노드 + 연결선으로 구성된 별자리 스타일 SVG.
//
// [2026-09 전면 재작성 — 12라벨 체계] key 타입을 기존 5종 리터럴 유니언
// 에서 `GuinjiRelationType`(12종)으로 교체한다.
//
// [비식별 원칙] 이 컴포넌트는 멤버 이름/생년월일 등 어떤 개인정보도 받지
// 않는다 — props는 오직 "관계유형별 인원수(집계)"뿐이다. 로그인 없는
// 방문자에게 지인 개개인의 신상을 노출하지 않기 위한 의도적 설계다
// (기존 `_shared.ts`의 화이트리스트 원칙과 동일 경계).
//
// [결정론적 렌더링] Math.random()을 쓰지 않는다 — 서버 컴포넌트로 매
// 요청마다 같은 counts가 들어오면 항상 같은 SVG가 나오도록 인덱스 기반
// 각도 계산만 사용한다(하이드레이션 불일치 방지 + 캐시 친화적).
//
// [2026-09, 애니메이션 추가 — 사용자 명시 지시 "화려하게 움직이게"] 좌표
// 계산 로직(polarToXY, sectorSpan 등)은 완전히 결정론적 상태를 유지하고,
// 오직 순수 CSS `@keyframes` 애니메이션만 덧씌운다 — 매 요청 동일 counts에
// 대해 SVG 구조/좌표는 항상 동일하고, 애니메이션은 클라이언트에서 재생되는
// 시각 효과일 뿐이므로 서버 컴포넌트 하이드레이션 불일치가 발생하지 않는다.
// 효과 구성:
//   1) 중앙 "나" 노드 — 은은한 glow pulse (숨쉬듯 커지고 작아짐)
//   2) 위성 노드 — 각자 다른 delay로 pulse (별이 반짝이는 느낌)
//   3) 연결선 — stroke-dasharray 애니메이션으로 빛이 흐르는 느낌
//   4) 배경 궤도 원 2개 — 아주 느리게 회전(오브젝트가 살아있는 느낌)
import type { GuinjiRelationType } from "@/lib/guinji-relation-judger";

export interface RelationCount {
  key: GuinjiRelationType;
  label: string;
  hanja: string;
  color: string;
  count: number;
}

const SIZE = 320;
const CENTER = SIZE / 2;
const CENTER_RADIUS = 26;
const SATELLITE_RADIUS_BASE = 78;
const SATELLITE_RADIUS_STEP = 22;
const NODE_RADIUS = 14;

function polarToXY(cx: number, cy: number, radius: number, angleDeg: number) {
  const rad = (angleDeg * Math.PI) / 180;
  return { x: cx + radius * Math.cos(rad), y: cy + radius * Math.sin(rad) };
}

export function RelationNetworkGraph({
  counts,
  ownerName,
}: {
  counts: RelationCount[];
  ownerName: string;
}) {
  const activeTypes = counts.filter((c) => c.count > 0);
  const total = counts.reduce((sum, c) => sum + c.count, 0);
  const sectorSpan = 360 / Math.max(activeTypes.length, 1);

  const nodes: Array<{ x: number; y: number; color: string; label: string; hanja: string }> = [];
  activeTypes.forEach((type, sectorIndex) => {
    const sectorCenterAngle = -90 + sectorIndex * sectorSpan;
    const n = Math.min(type.count, 6); // 시각적 과밀 방지 — 6개 초과분은 숫자로만 표기
    for (let i = 0; i < n; i++) {
      // 같은 유형 안에서는 부채꼴로 살짝 벌리고, 바깥으로 갈수록 반지름을 늘려 별자리처럼 배치.
      const spread = n > 1 ? (i / (n - 1) - 0.5) * Math.min(sectorSpan * 0.7, 40) : 0;
      const angle = sectorCenterAngle + spread;
      const radius = SATELLITE_RADIUS_BASE + (i % 3) * SATELLITE_RADIUS_STEP;
      const { x, y } = polarToXY(CENTER, CENTER, radius, angle);
      nodes.push({ x, y, color: type.color, label: type.label, hanja: type.hanja });
    }
  });

  return (
    <div className="rounded-3xl border border-[#E8DDD0] bg-white/85 p-5 shadow-[0_4px_20px_-8px_rgba(166,121,94,0.15)]">
      <div className="mb-3 flex items-baseline justify-between">
        <h2 style={{ fontFamily: "'Noto Serif KR', serif" }} className="text-base font-bold text-[#2A2438]">관계 지도</h2>
        <span className="text-sm font-medium text-[#6E5A54]">{total}명</span>
      </div>

      {total === 0 ? (
        <p className="py-8 text-center text-sm text-[#A08C82]">
          아직 지도에 오른 사람이 없어요.
          <br />
          가장 먼저 이름을 올려 보세요.
        </p>
      ) : (
        <svg
          viewBox={`0 0 ${SIZE} ${SIZE}`}
          className="mx-auto block w-full max-w-[280px]"
          role="img"
          aria-label={`${ownerName}님의 관계 지도, 총 ${total}명`}
        >
          <style>{`
            @keyframes gm-orbit-slow { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
            @keyframes gm-orbit-slow-reverse { from { transform: rotate(0deg); } to { transform: rotate(-360deg); } }
            @keyframes gm-center-pulse {
              0%, 100% { transform: scale(1); filter: drop-shadow(0 0 0px rgba(42,36,56,0.4)); }
              50% { transform: scale(1.06); filter: drop-shadow(0 0 6px rgba(166,121,94,0.55)); }
            }
            @keyframes gm-node-twinkle {
              0%, 100% { opacity: 0.85; transform: scale(1); }
              50% { opacity: 1; transform: scale(1.18); }
            }
            @keyframes gm-line-flow {
              to { stroke-dashoffset: -24; }
            }
            .gm-orbit-a { transform-origin: ${CENTER}px ${CENTER}px; animation: gm-orbit-slow 40s linear infinite; }
            .gm-orbit-b { transform-origin: ${CENTER}px ${CENTER}px; animation: gm-orbit-slow-reverse 55s linear infinite; }
            .gm-center-node { transform-origin: ${CENTER}px ${CENTER}px; animation: gm-center-pulse 2.6s ease-in-out infinite; }
            .gm-satellite { transform-box: fill-box; transform-origin: center; animation: gm-node-twinkle 2.2s ease-in-out infinite; }
            .gm-line { stroke-dasharray: 4 6; animation: gm-line-flow 1.6s linear infinite; }
            @media (prefers-reduced-motion: reduce) {
              .gm-orbit-a, .gm-orbit-b, .gm-center-node, .gm-satellite, .gm-line { animation: none; }
            }
          `}</style>

          {/* 은하수 느낌의 옅은 배경 원들 — 아주 느리게 서로 반대로 회전 */}
          <circle
            className="gm-orbit-a"
            cx={CENTER}
            cy={CENTER}
            r={SATELLITE_RADIUS_BASE}
            fill="none"
            stroke="#E8DDD0"
            strokeDasharray="2 4"
            strokeWidth={1}
          />
          <circle
            className="gm-orbit-b"
            cx={CENTER}
            cy={CENTER}
            r={SATELLITE_RADIUS_BASE + SATELLITE_RADIUS_STEP * 2}
            fill="none"
            stroke="#F0E7DA"
            strokeDasharray="2 4"
            strokeWidth={1}
          />

          {/* 중앙 노드에서 각 위성 노드로 이어지는 연결선 — 빛이 흐르듯 애니메이션 */}
          {nodes.map((node, i) => (
            <line
              key={`line-${i}`}
              className="gm-line"
              x1={CENTER}
              y1={CENTER}
              x2={node.x}
              y2={node.y}
              stroke={node.color}
              strokeOpacity={0.4}
              strokeWidth={1.5}
            />
          ))}

          {/* 위성 노드 — 별이 반짝이듯 각자 다른 타이밍으로 pulse */}
          {nodes.map((node, i) => (
            <g
              key={`node-${i}`}
              className="gm-satellite"
              style={{ animationDelay: `${(i % 6) * 0.35}s` }}
            >
              <circle cx={node.x} cy={node.y} r={NODE_RADIUS} fill={node.color} fillOpacity={0.85} />
              <text
                x={node.x}
                y={node.y + 4}
                textAnchor="middle"
                fontSize={11}
                fontWeight={700}
                fill="#FFFFFF"
              >
                {node.hanja}
              </text>
            </g>
          ))}

          {/* 중앙 "나" 노드 — 은은하게 숨쉬듯 glow pulse */}
          <g className="gm-center-node">
            <circle cx={CENTER} cy={CENTER} r={CENTER_RADIUS} fill="#2A2438" />
            <text x={CENTER} y={CENTER + 5} textAnchor="middle" fontSize={15} fontWeight={700} fill="#FBF7EF">
              나
            </text>
          </g>
        </svg>
      )}

      {/* 오행/관계유형 12분류 요약 카드 */}
      <div className="mt-4 grid grid-cols-4 gap-1.5">
        {counts.map((c) => (
          <div
            key={c.key}
            className="flex flex-col items-center rounded-xl border border-[#E8DDD0] bg-white px-1 py-2"
          >
            <span
              className="mb-1 flex h-6 w-6 items-center justify-center rounded-full text-[11px] font-bold text-white"
              style={{ backgroundColor: c.color }}
            >
              {c.hanja}
            </span>
            <span className="text-[11px] text-[#6E5A54]">{c.label}</span>
            <span className="text-sm font-bold text-[#2A2438]">{c.count}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
