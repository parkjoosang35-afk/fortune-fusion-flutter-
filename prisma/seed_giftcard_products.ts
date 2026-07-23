// 상점 관리 — 상품권 상품(giftcard_products) 목업 데이터 시딩 스크립트
// 04A J-1 giftcard_products
import "dotenv/config";
import { PrismaClient } from "../src/generated/prisma/client";
import { PrismaBetterSqlite3 } from "@prisma/adapter-better-sqlite3";

const adapter = new PrismaBetterSqlite3({
  url: process.env.DATABASE_URL ?? "file:./prisma/dev.db",
});
const prisma = new PrismaClient({ adapter });

const PRODUCTS = [
  {
    name: "스타벅스 아메리카노 교환권",
    brand: "스타벅스",
    requiredPoint: 4500,
    stockCount: 200,
    validDays: 365,
    imageUrl: "https://placehold.co/300x300/00704a/ffffff?text=Starbucks",
  },
  {
    name: "스타벅스 카페라떼 교환권",
    brand: "스타벅스",
    requiredPoint: 5000,
    stockCount: 150,
    validDays: 365,
    imageUrl: "https://placehold.co/300x300/00704a/ffffff?text=Starbucks",
  },
  {
    name: "GS25 모바일 상품권 5천원",
    brand: "GS25",
    requiredPoint: 5000,
    stockCount: 300,
    validDays: 180,
    imageUrl: "https://placehold.co/300x300/1428a0/ffffff?text=GS25",
  },
  {
    name: "CGV 영화 관람권",
    brand: "CGV",
    requiredPoint: 12000,
    stockCount: 80,
    validDays: 180,
    imageUrl: "https://placehold.co/300x300/e50914/ffffff?text=CGV",
  },
  {
    name: "배스킨라빈스 파인트 교환권",
    brand: "배스킨라빈스",
    requiredPoint: 8000,
    stockCount: 100,
    validDays: 365,
    imageUrl: "https://placehold.co/300x300/e6007e/ffffff?text=BR",
  },
  {
    name: "올리브영 모바일 상품권 1만원",
    brand: "올리브영",
    requiredPoint: 10000,
    stockCount: 120,
    validDays: 365,
    imageUrl: "https://placehold.co/300x300/6f42c1/ffffff?text=OliveYoung",
  },
  {
    name: "배달의민족 상품권 5천원",
    brand: "배달의민족",
    requiredPoint: 5000,
    stockCount: 0, // 품절 샘플(재고 소진 화면 확인용)
    validDays: 365,
    imageUrl: "https://placehold.co/300x300/2ac1bc/ffffff?text=Baemin",
  },
  {
    name: "이디야커피 아메리카노 교환권",
    brand: "이디야커피",
    requiredPoint: 3000,
    stockCount: 250,
    validDays: 365,
    imageUrl: "https://placehold.co/300x300/8b4513/ffffff?text=EdiyaCoffee",
  },
  {
    name: "네이버페이 포인트 5천원권",
    brand: "네이버페이",
    requiredPoint: 5000,
    stockCount: 500,
    validDays: 365,
    imageUrl: "https://placehold.co/300x300/03c75a/ffffff?text=NaverPay",
  },
  {
    name: "판매중지 상품권 샘플",
    brand: "테스트브랜드",
    requiredPoint: 1000,
    stockCount: 10,
    validDays: 90,
    imageUrl: "https://placehold.co/300x300/64748b/ffffff?text=Inactive",
  },
];

async function main() {
  console.log("=== 상점관리(상품권 상품) 목업 데이터 시딩 시작 ===");
  let created = 0;
  for (let i = 0; i < PRODUCTS.length; i++) {
    const p = PRODUCTS[i];
    const existing = await prisma.giftcardProduct.findFirst({ where: { name: p.name } });
    if (existing) continue;

    // 마지막 샘플("판매중지 상품권 샘플")은 is_active=false 상태로 생성해 비활성 화면 확인용으로 사용
    const isActive = p.name !== "판매중지 상품권 샘플";

    await prisma.giftcardProduct.create({
      data: {
        ...p,
        isActive,
        createdBy: "system_seed",
        updatedBy: "system_seed",
      },
    });
    created++;
  }
  console.log(`[seed_giftcard_products] -> 상품권 상품 ${created}건 생성`);
  console.log("=== 시딩 완료 ===");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
