-- [기획_01 콘텐츠운영 통합화면] ADD-only: content_ops_configs 신설
-- 기존 테이블은 전혀 건드리지 않는다. 9개 라이브 콘텐츠 + 신규 2개의
-- "노출 상태(visible/hidden/maintenance)"만 관리하는 신규 테이블.
CREATE TABLE "content_ops_configs" (
    "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    "content_key" TEXT NOT NULL,
    "exposure_status" TEXT NOT NULL DEFAULT 'visible',
    "maintenance_note" TEXT,
    "created_at" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" DATETIME NOT NULL,
    "updated_by" TEXT
);

CREATE UNIQUE INDEX "content_ops_configs_content_key_key" ON "content_ops_configs"("content_key");
CREATE INDEX "content_ops_configs_exposure_status_idx" ON "content_ops_configs"("exposure_status");
