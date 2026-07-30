"use client";

// 성취 후기 목록의 명예의 전당 선정(isFeatured) 토글 버튼 행.
import { useState, useTransition } from "react";
import { toggleWishReviewFeatured } from "@/app/actions/wish-review";

interface ReviewRow {
  id: number;
  authorNickname: string;
  content: string;
  createdAt: string;
  isFeatured: boolean;
}

export default function WishReviewFeatureRow({
  review,
  canWrite,
}: {
  review: ReviewRow;
  canWrite: boolean;
}) {
  const [isFeatured, setIsFeatured] = useState(review.isFeatured);
  const [isPending, startTransition] = useTransition();

  return (
    <tr className="border-b border-slate-800/60 hover:bg-slate-800/40">
      <td className="px-4 py-3 text-slate-200">{review.authorNickname}</td>
      <td className="max-w-md truncate px-4 py-3 text-slate-300">{review.content}</td>
      <td className="px-4 py-3 text-slate-500">
        {review.createdAt.slice(0, 19).replace("T", " ")}
      </td>
      <td className="px-4 py-3">
        {canWrite ? (
          <button
            type="button"
            disabled={isPending}
            onClick={() =>
              startTransition(async () => {
                const next = !isFeatured;
                setIsFeatured(next);
                await toggleWishReviewFeatured(review.id, next);
              })
            }
            className={`rounded-full px-3 py-1 text-xs font-medium transition ${
              isFeatured
                ? "bg-amber-950/60 text-amber-400 hover:bg-amber-900/60"
                : "bg-slate-800 text-slate-400 hover:bg-slate-700"
            }`}
          >
            {isFeatured ? "🏆 선정됨" : "선정하기"}
          </button>
        ) : (
          <span className="text-xs text-slate-500">{isFeatured ? "🏆 선정됨" : "-"}</span>
        )}
      </td>
    </tr>
  );
}
