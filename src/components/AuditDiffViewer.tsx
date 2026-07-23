"use client";

// 08_Web_Design.md §3.4 AuditTrailViewer — operation_logs의 before/after JSON을
// diff 형태로 시각화(감사로그 조회 화면 전용)
interface AuditDiffViewerProps {
  before: string | null;
  after: string | null;
}

function safeParse(json: string | null): Record<string, unknown> | null {
  if (!json) return null;
  try {
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export default function AuditDiffViewer({ before, after }: AuditDiffViewerProps) {
  const beforeObj = safeParse(before);
  const afterObj = safeParse(after);

  if (!beforeObj && !afterObj) {
    return <span className="text-xs text-slate-500">-</span>;
  }

  const keys = new Set<string>([
    ...(beforeObj ? Object.keys(beforeObj) : []),
    ...(afterObj ? Object.keys(afterObj) : []),
  ]);

  return (
    <div className="flex flex-col gap-0.5 text-xs">
      {[...keys].map((key) => {
        const beforeVal = beforeObj?.[key];
        const afterVal = afterObj?.[key];
        const changed = JSON.stringify(beforeVal) !== JSON.stringify(afterVal);
        return (
          <div key={key} className="flex gap-1">
            <span className="text-slate-500">{key}:</span>
            {beforeObj && (
              <span className={changed ? "text-red-400 line-through" : "text-slate-400"}>
                {JSON.stringify(beforeVal)}
              </span>
            )}
            {beforeObj && afterObj && changed && <span className="text-slate-600">→</span>}
            {afterObj && (
              <span className={changed ? "text-emerald-400" : "text-slate-400"}>
                {JSON.stringify(afterVal)}
              </span>
            )}
          </div>
        );
      })}
    </div>
  );
}
