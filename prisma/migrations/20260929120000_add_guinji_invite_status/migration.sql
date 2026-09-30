-- [귀인지도 초대링크 재발급 v1.1] guinji_map에 초대 링크 상태 필드 3종 추가.
-- SQLite는 enum을 지원하지 않아 String으로 관리("active" | "revoked", 스키마 전체 컨벤션과 동일).
-- 기존 status(지도 자체 소프트삭제)와는 별개 개념이므로 컬럼명을 invite_status로 분리한다.
-- 참고: SQLite는 ALTER TABLE ADD COLUMN에서 non-constant DEFAULT(CURRENT_TIMESTAMP 등)를
-- 허용하지 않으므로, token_issued_at은 nullable로 추가한 뒤 아래 UPDATE로 백필한다.

ALTER TABLE "guinji_map" ADD COLUMN "invite_status" TEXT NOT NULL DEFAULT 'active';
ALTER TABLE "guinji_map" ADD COLUMN "token_issued_at" DATETIME;
ALTER TABLE "guinji_map" ADD COLUMN "revoked_at" DATETIME;

-- 백필: 기존 row는 token이 최초 생성 시점(created_at)에 발급된 것으로 간주.
UPDATE "guinji_map" SET "token_issued_at" = "created_at" WHERE "token_issued_at" IS NULL;
