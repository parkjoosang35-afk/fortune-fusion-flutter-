// 04A M-6 chat_rooms / M-7 chat_messages 시드 데이터
// 05_Admin_System_Design.md §3.6 "매칭/궁합 관리" — 4차 소단위(채팅 모니터링,
// "신고된 대화만 열람" 사생활 보호 원칙). 방안 A(reports target_type=user →
// matching_pairs → chat_rooms 간접 연결)를 검증할 수 있도록, 신고 관계자가
// 포함된 매칭쌍의 채팅방 1개(열람 대상)와 신고와 무관한 일반 채팅방 여러 개
// (비열람 대상, 필터링 정상 동작 검증용)를 함께 시딩한다.
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

async function main() {
  const users = await prisma.user.findMany({ orderBy: { id: "asc" } });
  const pairs = await prisma.matchingPair.findMany({ orderBy: { id: "asc" } });
  if (users.length < 10 || pairs.length < 3) {
    console.error("선행 시드(회원 10명, matching_pairs 3건)가 필요합니다. 먼저 실행하세요.");
    process.exit(1);
  }
  const u = (i: number) => users[i].id;

  // pair3(6↔9, unmatched)는 신고당한 회원(users[5]=user6)이 포함된 매칭쌍
  // → "신고 관계자 대화방"으로 노출되어야 하는 열람 대상.
  const reportedPair = pairs.find((p) => p.userAId === u(5) || p.userBId === u(5));
  if (!reportedPair) {
    console.error("신고당한 회원(user6)이 포함된 matching_pair를 찾을 수 없습니다.");
    process.exit(1);
  }

  // ── chat_rooms: 3개(신고 관계자 대화방 1개 + 일반 대화방 2개) ──
  const roomReported = await prisma.chatRoom.create({
    data: {
      type: "matching",
      relatedPairId: reportedPair.id,
      status: "active",
      createdBy: "system",
      updatedBy: "system",
    },
  });

  const roomNormalMatching = await prisma.chatRoom.create({
    data: {
      type: "matching",
      relatedPairId: pairs[0].id, // pair1(1↔2, active) — 신고 무관, 비열람 대상
      status: "active",
      createdBy: "system",
      updatedBy: "system",
    },
  });

  const roomNormalFriend = await prisma.chatRoom.create({
    data: {
      type: "friend",
      relatedPairId: null, // friend 타입은 매칭쌍과 무관
      status: "active",
      createdBy: "system",
      updatedBy: "system",
    },
  });

  console.log(
    `ChatRooms created: 3건 (신고관계자방 id=${roomReported.id}, 일반매칭방 id=${roomNormalMatching.id}, 친구방 id=${roomNormalFriend.id})`
  );

  // ── chat_messages: 신고 관계자 대화방에 5건(text/image/system 혼합), 일반 방들에도 각 2~3건 ──
  const messages = [
    // 신고 관계자 대화방(user6 ↔ user9) — 실제 신고 사유와 관련될 수 있는 대화 내용
    { roomId: roomReported.id, senderId: u(5), content: "안녕하세요! 만나서 반가워요.", messageType: "text" },
    { roomId: roomReported.id, senderId: u(8), content: "네 반갑습니다 :)", messageType: "text" },
    { roomId: roomReported.id, senderId: u(5), content: "[사진]", messageType: "image" },
    { roomId: roomReported.id, senderId: u(8), content: "이런 내용은 부적절해요.", messageType: "text" },
    { roomId: roomReported.id, senderId: u(5), content: "매칭이 해제되었습니다.", messageType: "system" },
    // 일반 매칭 대화방(user1 ↔ user2) — 신고 무관, 비열람 대상
    { roomId: roomNormalMatching.id, senderId: u(0), content: "오늘 저녁 뭐 드실래요?", messageType: "text" },
    { roomId: roomNormalMatching.id, senderId: u(1), content: "파스타 어때요?", messageType: "text" },
    // 친구 채팅방(user3 발신) — 신고 무관, 비열람 대상
    { roomId: roomNormalFriend.id, senderId: u(2), content: "이번 주말에 시간 되세요?", messageType: "text" },
  ];
  for (const m of messages) {
    await prisma.chatMessage.create({
      data: { ...m, createdBy: "system", updatedBy: "system" },
    });
  }
  console.log(`ChatMessages created: ${messages.length}건`);

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
