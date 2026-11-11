-- [관리자 2.0 전면 재설계 - Task 12a] 도완녀상담 신청-배정-진행-완료 상태머신
-- ADD-only 수동 마이그레이션 (20261111150000_add_inquiry_tables,
-- 20261111160000_add_system_diagnosis_table과 동일한 패턴).
-- 기존 테이블/컬럼에 대한 변경은 전혀 없음 — 신규 테이블 2개만 추가한다.

CREATE TABLE "dowanyeo_counselors" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "name" TEXT NOT NULL,
    "specialty" TEXT,
    "intro_body" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT
);
CREATE INDEX "dowanyeo_counselors_status_idx" ON "dowanyeo_counselors"("status");

CREATE TABLE "dowanyeo_consultation_requests" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "counselor_id" INTEGER,
    "topic" TEXT NOT NULL,
    "request_memo" TEXT,
    "preferred_at" DATETIME,
    "status" TEXT NOT NULL DEFAULT 'requested',
    "point_history_id" INTEGER,
    "assigned_admin_id" INTEGER,
    "assigned_at" DATETIME,
    "started_at" DATETIME,
    "completed_at" DATETIME,
    "cancelled_at" DATETIME,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    CONSTRAINT "dowanyeo_consultation_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "dowanyeo_consultation_requests_counselor_id_fkey" FOREIGN KEY ("counselor_id") REFERENCES "dowanyeo_counselors" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "dowanyeo_consultation_requests_point_history_id_fkey" FOREIGN KEY ("point_history_id") REFERENCES "point_histories" ("id") ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT "dowanyeo_consultation_requests_assigned_admin_id_fkey" FOREIGN KEY ("assigned_admin_id") REFERENCES "admin_users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "dowanyeo_consultation_requests_point_history_id_key" ON "dowanyeo_consultation_requests"("point_history_id");
CREATE INDEX "dowanyeo_consultation_requests_status_created_at_idx" ON "dowanyeo_consultation_requests"("status", "created_at");
CREATE INDEX "dowanyeo_consultation_requests_user_id_created_at_idx" ON "dowanyeo_consultation_requests"("user_id", "created_at");
