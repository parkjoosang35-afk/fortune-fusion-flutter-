-- [재화 구조 정리 §복주머니 사용 구간표] 소원게시판 cheer/empathize/highlight/expose_boost
-- 신규 유료 액션 지원을 위한 컬럼 추가.
ALTER TABLE "comments" ADD COLUMN "cheer_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "comments" ADD COLUMN "empathize_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "wishes" ADD COLUMN "highlighted_until" DATETIME;
ALTER TABLE "wishes" ADD COLUMN "boosted_at" DATETIME;
