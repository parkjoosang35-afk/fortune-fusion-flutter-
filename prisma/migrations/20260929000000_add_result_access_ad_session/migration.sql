-- [결과보기 통합 권한 시스템 v1.0, Phase4] §8.3 광고 완료 서버 재검증용 신규 테이블.
-- 기존 컬럼/테이블은 삭제하지 않고, 신규 테이블만 추가한다.

CREATE TABLE "result_access_ad_sessions" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "user_id" INTEGER NOT NULL,
    "session_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" DATETIME,
    CONSTRAINT "result_access_ad_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "result_access_ad_sessions_session_id_key" ON "result_access_ad_sessions"("session_id");
CREATE INDEX "result_access_ad_sessions_user_id_created_at_idx" ON "result_access_ad_sessions"("user_id", "created_at");
