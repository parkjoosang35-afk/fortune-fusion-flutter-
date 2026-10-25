-- [신당(THE SHRINE) U12 어뷰징 방지 서버 연동] 2026-10-23 커밋 200a58e에서
-- schema.prisma만 변경되고 마이그레이션 파일이 누락되어 있던 것을
-- 2026-10-25 배포 전 점검 과정에서 발견, 수동으로 생성함.
--
-- [범위 제한 — 중요] 이 마이그레이션은 200a58e 커밋의 ADD-only 변경사항만
-- 담는다 (ShrineIssueLedger 신규 테이블 + UserProfile.realName 신규 컬럼).
-- `prisma migrate dev`의 자동 diff 생성을 사용하지 않은 이유: 자동 diff는
-- 이 변경과 무관한 과거 drift(마이그레이션 파일 없이 로컬 dev.db에만
-- db push 등으로 반영된 구조 — users.google_id/kakao_id,
-- result_access_transactions FK 정책, topic_exposure_history 인덱스명 등)를
-- 함께 포함시켜, SQLite 특성상 여러 테이블을 DROP+재생성(RedefineTable)하는
-- 위험한 스크립트를 생성했다. 그 drift는 이번 배포 승인 범위 밖이므로
-- 제외하고, 승인된 ADD-only 변경만 수동으로 작성한다.

-- CreateTable
CREATE TABLE "shrine_issue_ledgers" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "saju_fp" TEXT NOT NULL,
    "story_id" TEXT NOT NULL,
    "compose_key" TEXT NOT NULL,
    "serial" TEXT NOT NULL,
    "issued_date" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "shrine_issue_ledgers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "shrine_issue_ledgers_serial_key" ON "shrine_issue_ledgers"("serial");

-- CreateIndex
CREATE INDEX "shrine_issue_ledgers_user_id_issued_date_idx" ON "shrine_issue_ledgers"("user_id", "issued_date");

-- CreateIndex
CREATE UNIQUE INDEX "shrine_issue_ledgers_user_id_story_id_key" ON "shrine_issue_ledgers"("user_id", "story_id");

-- AlterTable (user_profiles에 real_name 컬럼 추가, ADD COLUMN만 — 기존 컬럼 무변경)
ALTER TABLE "user_profiles" ADD COLUMN "real_name" TEXT;
