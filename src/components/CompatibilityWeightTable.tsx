import CompatibilityWeightRow from "./CompatibilityWeightRow";

interface Item {
  id: number;
  factorType: string;
  weight: number;
  isActive: boolean;
  updatedAt: Date;
}

interface CompatibilityWeightTableProps {
  items: Item[];
  canWrite: boolean;
}

// 05§3.6 F-3 "가중치 합 1.00 권장(애플리케이션 검증)" — 04A 원문이 "권장"
// (hard constraint 아님)이므로 서버 액션에서 저장 자체를 막지 않고, 저장 후
// 반환된 경고 메시지를 각 CompatibilityWeightRow가 직접 렌더링한다.
// 이 테이블 컴포넌트는 client 상태를 전혀 갖지 않으므로(경고 전파는
// CompatibilityWeightRow 내부에서 자체 처리) 서버 컴포넌트로 유지한다.
export default function CompatibilityWeightTable({ items, canWrite }: CompatibilityWeightTableProps) {
  return (
    <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
      <table className="w-full text-left text-sm">
        <thead className="border-b border-slate-200 text-xs uppercase text-slate-500">
          <tr>
            <th className="px-4 py-3">요소</th>
            <th className="px-4 py-3">가중치</th>
            <th className="px-4 py-3">상태</th>
            <th className="px-4 py-3">수정일</th>
            {canWrite && <th className="px-4 py-3">관리</th>}
          </tr>
        </thead>
        <tbody>
          {items.length === 0 && (
            <tr>
              <td colSpan={canWrite ? 5 : 4} className="px-4 py-10 text-center text-slate-500">
                등록된 궁합 요소 가중치가 없습니다.
              </td>
            </tr>
          )}
          {items.map((item) => (
            <CompatibilityWeightRow key={item.id} item={item} canWrite={canWrite} />
          ))}
        </tbody>
      </table>
    </div>
  );
}
