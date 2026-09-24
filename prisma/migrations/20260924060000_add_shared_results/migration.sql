-- [결과 공유 기능 — sintong-share-proposal.pdf] shared_results 테이블 신설.
-- SQLite(better-sqlite3) 대상. JSONB 대신 String(JSON 직렬화) 컬럼 사용.
CREATE TABLE "shared_results" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "share_id" TEXT NOT NULL,
    "user_id" INTEGER NOT NULL,
    "result_type" TEXT NOT NULL,
    "source_ref_id" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "payload" TEXT NOT NULL,
    "image_url" TEXT,
    "view_count" INTEGER NOT NULL DEFAULT 0,
    "status" TEXT NOT NULL DEFAULT 'active',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "deleted_at" DATETIME,
    CONSTRAINT "shared_results_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "shared_results_share_id_key" ON "shared_results"("share_id");
CREATE INDEX "shared_results_user_id_created_at_idx" ON "shared_results"("user_id", "created_at");
CREATE INDEX "shared_results_result_type_created_at_idx" ON "shared_results"("result_type", "created_at");
