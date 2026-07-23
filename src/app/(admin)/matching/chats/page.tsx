import { prisma } from "@/lib/db";
import { verifyAdminSession } from "@/lib/dal";
import { canAccessMenu } from "@/lib/rbac";
import { redirect } from "next/navigation";
import Link from "next/link";

// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 4차 소단위(도메인 M 4단계): 채팅 모니터링
// 04A M-6 chat_rooms, M-7 chat_messages 조회. "신고된 대화만 열람(사생활 보호
// 원칙, 평시 비열람)" — RBAC 05§5.2: cs는 "신고대응시만 채팅열람" 예외.
//
// [설계 충돌 검토 및 해결 — 원칙② 준수, schema.prisma ChatRoom/ChatMessage
//  모델 주석과 동일 근거] 05§3.6은 "신고된 대화만 열람"을 요구하나, 04A L-6
//  reports.target_type 화이트리스트(post/comment/wish/user)에는 chat_room/
//  chat_message가 포함되어 있지 않아 "채팅을 직접 신고"하는 04A 경로가 없다.
//  → 04A 원본 스키마 확장(target_type에 chat_room 추가) 대신, 이미 존재하는
//    target_type=user 신고를 매개로 간접 연결한다: 신고당한 회원이 참여한
//    matching_pairs → 그 pair의 related_pair_id로 연결된 chat_rooms만
//    "신고 관계자 대화방"으로 이 화면에 노출한다. 04A/05 두 문서 모두 수정
//    없이 그대로 준수하며, 실제 신고 내용과의 관련성 최종 판단은 관리자가
//    열람 후 수행한다(평시에는 신고 없는 대화방은 이 화면에 전혀 노출되지
//    않으므로 사생활 보호 원칙 준수).
// [RBAC cs 예외 처리] "신고대응시만 채팅열람"은 이 화면 자체가 이미
//   신고 관계자 대화방으로만 필터링되어 있으므로, cs가 이 화면에 접근하는
//   행위 자체가 곧 "신고 대응 목적의 열람"이 된다. 따라서 canAccessMenu의
//   기본 read 권한(matching: cs=R)을 그대로 사용하며, 별도의 화면별 예외
//   로직을 추가하지 않는다(matching 메뉴 read 권한 = 이 화면 접근 허용,
//   화면 자체의 필터링이 사생활 보호 정책을 담보).
// [Server Action 없음] 05§3.6 "조회 전용" 명시 — matching_likes_pairs(2차),
//   friends_follows(3차)와 동일 원칙.
export const dynamic = "force-dynamic";

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 19).replace("T", " ");
}

export default async function MatchingChatsPage() {
  const session = await verifyAdminSession();
  if (!canAccessMenu(session.roleCode, "matching")) {
    redirect("/dashboard");
  }

  // 1단계: target_type=user 신고에서 신고당한 회원 id 목록 추출
  const userReports = await prisma.report.findMany({
    where: { targetType: "user", deletedAt: null },
    select: { targetId: true, reason: true, status: true },
  });
  const reportedUserIds = new Set(userReports.map((r) => r.targetId));

  // 2단계: 신고당한 회원이 참여한 matching_pairs 조회
  const relatedPairs =
    reportedUserIds.size > 0
      ? await prisma.matchingPair.findMany({
          where: {
            OR: [{ userAId: { in: [...reportedUserIds] } }, { userBId: { in: [...reportedUserIds] } }],
          },
        })
      : [];
  const relatedPairIds = relatedPairs.map((p) => p.id);

  // 3단계: 그 매칭쌍에 연결된 chat_rooms만 조회(핵심 필터링 — 신고 없으면 빈 목록)
  const chatRooms =
    relatedPairIds.length > 0
      ? await prisma.chatRoom.findMany({
          where: { relatedPairId: { in: relatedPairIds }, deletedAt: null },
          orderBy: { createdAt: "desc" },
        })
      : [];

  const roomIds = chatRooms.map((r) => r.id);
  const messages =
    roomIds.length > 0
      ? await prisma.chatMessage.findMany({
          where: { roomId: { in: roomIds }, deletedAt: null },
          orderBy: { createdAt: "asc" },
        })
      : [];

  // 회원 닉네임 배치조회
  const userIds = [
    ...new Set([
      ...relatedPairs.flatMap((p) => [p.userAId, p.userBId]),
      ...messages.map((m) => m.senderId),
    ]),
  ];
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, nickname: true },
  });
  const userMap = new Map(users.map((u) => [u.id, u.nickname]));
  const nick = (id: number) => userMap.get(id) ?? `회원#${id}`;

  const pairMap = new Map(relatedPairs.map((p) => [p.id, p]));
  const messagesByRoom = new Map<number, typeof messages>();
  for (const m of messages) {
    const arr = messagesByRoom.get(m.roomId) ?? [];
    arr.push(m);
    messagesByRoom.set(m.roomId, arr);
  }

  // 신고 사유 표시용: 회원 id → 대표 신고 사유(가장 최근)
  const reasonMap = new Map<number, string>();
  for (const r of userReports) {
    reasonMap.set(r.targetId, r.reason);
  }

  const messageTypeBadge = (type: string) => {
    if (type === "image") {
      return (
        <span className="rounded-full bg-indigo-950/60 px-2 py-0.5 text-xs text-indigo-400">이미지</span>
      );
    }
    if (type === "system") {
      return (
        <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">시스템</span>
      );
    }
    return <span className="text-xs text-slate-500">텍스트</span>;
  };

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">매칭/궁합 관리 — 채팅 모니터링</h1>
        <p className="mt-1 text-sm text-slate-400">
          신고 처리 목적으로만 대화 내용을 열람합니다(사생활 보호 원칙, 평시 비열람). 회원
          신고(target_type=user)와 연계된 매칭 대화방만 아래에 노출됩니다.
        </p>
        <nav className="mt-4 flex gap-2 border-b border-slate-800 text-sm">
          <Link href="/matching/profiles" className="px-3 py-2 text-slate-400 hover:text-white">
            매칭 프로필
          </Link>
          <Link href="/matching/likes-pairs" className="px-3 py-2 text-slate-400 hover:text-white">
            매칭 성사 이력
          </Link>
          <Link href="/matching/friends-follows" className="px-3 py-2 text-slate-400 hover:text-white">
            친구/팔로우
          </Link>
          <span className="border-b-2 border-indigo-500 px-3 py-2 text-white">채팅 모니터링</span>
          <Link href="/matching/compatibility-weights" className="px-3 py-2 text-slate-400 hover:text-white">
            궁합 요소 가중치
          </Link>
          <Link href="/matching/compatibility-stats" className="px-3 py-2 text-slate-400 hover:text-white">
            궁합 통계
          </Link>
        </nav>
      </div>

      <div className="mb-4 rounded-xl border border-amber-900/50 bg-amber-950/20 p-4 text-sm text-amber-300">
        ⚠️ 이 화면은 사생활 보호 원칙에 따라 신고 접수된 회원과 관련된 대화방만 노출합니다.
        신고 없는 일반 대화방은 관리자에게 표시되지 않습니다.
      </div>

      <div className="mb-4 text-sm text-slate-400">
        신고 관계자 대화방 <span className="text-white">{chatRooms.length}</span>건 (전체 신고 회원{" "}
        <span className="text-white">{reportedUserIds.size}</span>명 기준)
      </div>

      {chatRooms.length === 0 && (
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-10 text-center text-slate-500">
          현재 신고와 연계된 대화방이 없습니다.
        </div>
      )}

      <div className="space-y-6">
        {chatRooms.map((room) => {
          const pair = room.relatedPairId ? pairMap.get(room.relatedPairId) : undefined;
          const roomMessages = messagesByRoom.get(room.id) ?? [];
          const participantAId = pair?.userAId;
          const participantBId = pair?.userBId;
          const reportedParticipant =
            participantAId && reportedUserIds.has(participantAId)
              ? participantAId
              : participantBId && reportedUserIds.has(participantBId)
                ? participantBId
                : undefined;

          return (
            <section key={room.id} className="overflow-hidden rounded-xl border border-slate-800 bg-slate-900">
              <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-800 bg-slate-950/40 px-4 py-3">
                <div className="flex items-center gap-3">
                  <span className="text-sm font-semibold text-white">
                    {participantAId ? nick(participantAId) : "?"} ↔ {participantBId ? nick(participantBId) : "?"}
                  </span>
                  <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-400">
                    {room.type === "matching" ? "매칭 채팅" : "친구 채팅"}
                  </span>
                  {pair?.status === "unmatched" && (
                    <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-500">
                      매칭 해제됨
                    </span>
                  )}
                </div>
                {reportedParticipant && (
                  <span className="rounded-full bg-rose-950/60 px-2 py-0.5 text-xs text-rose-400">
                    신고 대상: {nick(reportedParticipant)} — {reasonMap.get(reportedParticipant) ?? ""}
                  </span>
                )}
              </div>
              <div className="max-h-80 overflow-y-auto p-4">
                <table className="w-full text-left text-sm">
                  <thead className="border-b border-slate-800 text-xs uppercase text-slate-500">
                    <tr>
                      <th className="px-2 py-2">발신자</th>
                      <th className="px-2 py-2">내용</th>
                      <th className="px-2 py-2">유형</th>
                      <th className="px-2 py-2">발신시각</th>
                    </tr>
                  </thead>
                  <tbody>
                    {roomMessages.length === 0 && (
                      <tr>
                        <td colSpan={4} className="px-2 py-6 text-center text-slate-500">
                          메시지가 없습니다.
                        </td>
                      </tr>
                    )}
                    {roomMessages.map((m) => (
                      <tr key={m.id} className="border-b border-slate-800/60">
                        <td className="px-2 py-2 text-slate-200">{nick(m.senderId)}</td>
                        <td className="px-2 py-2 text-slate-300">{m.content}</td>
                        <td className="px-2 py-2">{messageTypeBadge(m.messageType)}</td>
                        <td className="px-2 py-2 text-slate-500">{fmtDate(m.createdAt)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          );
        })}
      </div>
      <p className="mt-4 text-xs text-slate-500">
        04A M-6/M-7 명시: chat_rooms.type은 matching/friend, chat_messages.message_type은
        text/image/system입니다. 신고(target_type=user) → matching_pairs → chat_rooms 경로로
        연계 필터링됩니다(04A reports 화이트리스트에 chat_room이 없으므로 간접 연결 방식 채택).
      </p>
    </div>
  );
}
