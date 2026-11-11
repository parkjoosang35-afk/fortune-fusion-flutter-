-- [관리자 2.0 전면 재설계 - Task 11, 2026-11-11] AI시스템관리 3단계 자동진단
-- 신규 테이블.
--
-- [범위 제한 — 중요, shrine_v3_talisman_tables/add_inquiry_tables 마이그레이션과
-- 동일 원칙] `prisma migrate dev`의 자동 diff는 이 변경과 무관한 과거 drift를
-- 함께 포함시켜 위험한 스크립트를 생성한다. 이번 마이그레이션은 그 drift와
-- 무관하게 "system_diagnoses" 1개 신규 테이블 생성(ADD-only)만 수동으로 담는다.
-- 기존 테이블은 단 1개도 건드리지 않는다.

CREATE TABLE "system_diagnoses" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "category" TEXT NOT NULL,
    "detected_issue" TEXT NOT NULL,
    "severity" TEXT NOT NULL DEFAULT 'info',
    "diagnosis_text" TEXT,
    "suggested_action" TEXT,
    "status" TEXT NOT NULL DEFAULT 'detected',
    "approved_admin_id" INTEGER,
    "approved_at" DATETIME,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "system_diagnoses_approved_admin_id_fkey" FOREIGN KEY ("approved_admin_id") REFERENCES "admin_users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "system_diagnoses_status_created_at_idx" ON "system_diagnoses"("status", "created_at");
