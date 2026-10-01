// reviews 하위 라우트(PATCH/GET list/congrats/report) 공용 DTO 변환.
// wish-rooms/[id]/review/route.ts(V1)의 toReviewDto와 동일 규칙을 공유하되, 여기서는
// congratsByMe/mine을 호출부가 넘겨주는 viewerUserId로 매번 계산한다(목록 조회 대응).
import { toWishRoomReviewPublicId } from "../_shared";

const STATUS_TO_FE: Record<string, string> = {
  visible: "OK",
  review: "REVIEW",
  hidden_by_report: "HIDDEN",
  deleted_by_admin: "DELETED",
};

export interface ReviewRow {
  id: number;
  roomId: number;
  userId: number;
  text: string;
  photoUrl: string | null;
  congratsCount: number;
  status: string;
  user?: { nickname: string } | null;
  room?: { text: string; wishColor: string } | null;
  congrats?: { userId: number }[];
}

export function toReviewDto(v: ReviewRow, viewerUserId: number | null) {
  return {
    id: toWishRoomReviewPublicId(v.id),
    roomId: String(v.roomId),
    author: v.user?.nickname ?? "",
    wishText: v.room?.text ?? "",
    text: v.text,
    wishColor: v.room?.wishColor ?? "hope",
    photo: v.photoUrl,
    congrats: v.congratsCount,
    congratsByMe: viewerUserId != null ? (v.congrats ?? []).some((c) => c.userId === viewerUserId) : false,
    mine: viewerUserId != null && v.userId === viewerUserId,
    status: STATUS_TO_FE[v.status] ?? "OK",
  };
}
