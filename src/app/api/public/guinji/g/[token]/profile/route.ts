// 귀인지도 초대 링크 — 로그인 없는 "호스트 프로필 미리보기" API.
//
// [배경 — 2026-10 초대장 리디자인 v2] 사용자가 경쟁 서비스 레퍼런스
// (예: "가을 큰나무형" 캐릭터 카드 + "나는 OOO님에게 어떤 사람일까?" 설명)를
// 보고 "이게 꼭 들어가면 좋겠다"고 명시적으로 요구했다. 기존
// `GET /guinji/g/{token}`은 `requireUser()`로 로그인을 강제해(바이럴
// 게스트는 비로그인 상태이므로) 제출 *전에는* 호스트 이름조차 알 수 없는
// 구조였다(이 제약은 `guinji_invitation_letter.dart` 상단 주석에 이미
// 기록돼 있음). 이 라우트는 그 제약을 깨지 않으면서(개인정보 비식별 원칙
// 유지) "초대장을 받은 사람이 제출 전에 보여도 되는 최소한의 호스트
// 정보"만 새로 노출한다.
//
// [화이트리스트 원칙 — 절대] 이 라우트가 반환하는 값은 딱 두 가지뿐이다:
//   1. ownerName — 이미 `GET /guinji/g/{token}`(로그인 필요)과
//      `POST .../join` 응답에도 포함되는 닉네임이라 노출 수준이 더
//      높아지지 않는다.
//   2. characterType — `guinji-character-type.ts`(기존에 이미 구현돼
//      있었으나 어떤 라우트에서도 사용되지 않고 있던 순수 매핑 함수)가
//      `GuinjiMap.ownerSajuParsed`의 오행 카운트에서 파생한 "캐릭터
//      유형"(예: "큰 나무형") — 생년월일 원본, 사주 8글자, 성별 등은
//      이 라우트에서 절대 반환하지 않는다.
// `relation-summary/route.ts`와 동일한 비식별 경계를 따른다.
import { NextResponse } from "next/server";
import { prisma } from "@/lib/db";
import type { GuinjiSajuInput } from "@/lib/guinji-relation-judger";
import { deriveCharacterType } from "@/lib/guinji-character-type";

export const dynamic = "force-dynamic";

const CORS_HEADERS = { "Access-Control-Allow-Origin": "*" };

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ token: string }> }
) {
  const { token } = await params;

  try {
    const map = await prisma.guinjiMap.findUnique({
      where: { token },
      select: {
        deletedAt: true,
        status: true,
        ownerSajuParsed: true,
        owner: { select: { nickname: true } },
      },
    });

    if (!map || map.deletedAt != null || map.status !== "active") {
      return NextResponse.json(
        { success: false, error: "지도를 찾을 수 없어요.", code: "NOT_FOUND" },
        { status: 404, headers: CORS_HEADERS }
      );
    }

    let characterType: {
      element: string;
      hanja: string;
      title: string;
      tagline: string;
      description: string;
      color: string;
    } | null = null;

    if (map.ownerSajuParsed) {
      try {
        const ownerSaju = JSON.parse(map.ownerSajuParsed) as GuinjiSajuInput;
        characterType = deriveCharacterType(ownerSaju.fiveElementsCount);
      } catch (e) {
        // [정직성 원칙] 파싱 실패 시 캐릭터 카드는 조용히 숨긴다(에러로
        // 전체 요청을 막지 않음) — ownerName만으로도 화면은 정상 동작한다.
        console.error("[GET /api/public/guinji/g/[token]/profile] ownerSajuParsed 파싱 실패:", e);
      }
    }

    return NextResponse.json(
      {
        success: true,
        data: {
          ownerName: map.owner.nickname,
          characterType,
        },
      },
      { headers: CORS_HEADERS }
    );
  } catch (e) {
    console.error("[GET /api/public/guinji/g/[token]/profile] 실패:", e);
    return NextResponse.json(
      { success: false, error: "호스트 정보 조회 중 오류가 발생했습니다." },
      { status: 500, headers: CORS_HEADERS }
    );
  }
}

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: { ...CORS_HEADERS, "Access-Control-Allow-Methods": "GET, OPTIONS" },
  });
}
