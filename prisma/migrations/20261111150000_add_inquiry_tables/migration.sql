-- [관리자 2.0 전면 재설계 - Task 9c, 2026-11-11] 1:1 고객문의 신규 테이블.
--
-- [범위 제한 — 중요, shrine_v3_talisman_tables 마이그레이션과 동일 원칙]
-- `prisma migrate dev`의 자동 diff는 이 변경과 무관한 과거 drift(users 테이블
-- google_id/kakao_id 컬럼 재추가 시도, shrine_issue_ledgers 삭제, wishes/
-- pass_category_usages RedefineTable 등)를 함께 포함시켜 위험한 스크립트를
-- 생성했다. 이번 마이그레이션은 그 drift와 무관하게 "inquiries"/
-- "inquiry_messages" 2개 신규 테이블 생성(ADD-only)만 수동으로 담는다.
-- 기존 테이블은 단 1개도 건드리지 않는다.

CREATE TABLE "inquiries" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "category" TEXT NOT NULL DEFAULT 'etc',
    "title" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'open',
    "assigned_admin_id" INTEGER,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "closed_at" DATETIME,
    "deleted_at" DATETIME,
    "created_by" TEXT,
    "updated_by" TEXT,
    CONSTRAINT "inquiries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "inquiries_assigned_admin_id_fkey" FOREIGN KEY ("assigned_admin_id") REFERENCES "admin_users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "inquiries_status_created_at_idx" ON "inquiries"("status", "created_at");
CREATE INDEX "inquiries_user_id_created_at_idx" ON "inquiries"("user_id", "created_at");

CREATE TABLE "inquiry_messages" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "inquiry_id" INTEGER NOT NULL,
    "sender_type" TEXT NOT NULL,
    "sender_admin_id" INTEGER,
    "body" TEXT NOT NULL,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "inquiry_messages_inquiry_id_fkey" FOREIGN KEY ("inquiry_id") REFERENCES "inquiries" ("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "inquiry_messages_sender_admin_id_fkey" FOREIGN KEY ("sender_admin_id") REFERENCES "admin_users" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX "inquiry_messages_inquiry_id_created_at_idx" ON "inquiry_messages"("inquiry_id", "created_at");
