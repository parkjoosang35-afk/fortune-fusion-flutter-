// [2026-11-11 긴급 보안조치 ②] community/matching API 12개 비활성화 공용 헬퍼.
//
// 배경: 전수조사 결과(rbac.ts 주석 참조) Flutter 앱/admin_web 어디에서도
// 호출하지 않는 죽은 API였으며, community/boards·posts·comments 등 일부
// GET 엔드포인트는 인증 없이 외부에서 그대로 호출 가능한 상태였다(보안 공백).
// 해당 관리자 화면(boards/posts/comments/reports/likes/files,
// matching/profiles·likes-pairs·friends-follows·chats)도 이미 삭제되어
// 운영으로 조치할 수 없는 상태이므로, 라우트 자체를 비활성화한다.
//
// [비파괴 원칙] Prisma 스키마/테이블(CommunityPost, CommunityBoard, Comment,
// Like, MatchingProfile, MatchingLike, MatchingPair, ChatRoom, ChatMessage,
// Report 등)은 전혀 건드리지 않는다 — wishroom(소원방) 등 다른 라이브 기능이
// 동일 테이블을 polymorphic하게 공유 중이기 때문. 이 파일은 route.ts(HTTP
// 진입점)만 비활성화 응답으로 바꾸는 역할만 한다.
//
// [원복 방법] git에서 각 route.ts의 이전 커밋을 복원하면 즉시 원래 기능으로
// 되돌릴 수 있다.
import { NextResponse } from "next/server";

export const DISABLED_CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

/** 비활성화된 API 공통 응답 — 410 Gone (한때 존재했으나 더 이상 제공하지 않음을 명시). */
export function disabledResponse() {
  return NextResponse.json(
    { success: false, error: "이 API는 더 이상 제공되지 않습니다." },
    { status: 410, headers: DISABLED_CORS_HEADERS }
  );
}

export function disabledOptionsResponse(methods: string) {
  return new NextResponse(null, {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": methods,
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    },
  });
}
