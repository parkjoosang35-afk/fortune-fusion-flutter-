-- [어뷰징 방지 개편] pass_category_usages 카운트 기준을 userPassId → userId+categoryKey+dateKey(KST 날짜)로 변경.
-- 기존 데이터(4건, 전부 테스트 데이터)는 dateKey가 없던 시절 값이라 오늘 날짜로는 유효하지 않으므로 초기화한다.
DELETE FROM "pass_category_usages";

-- 기존 unique 인덱스 제거
DROP INDEX "pass_category_usages_user_pass_id_category_key_key";

-- date_key 컬럼 추가 (NOT NULL, 기본값은 마이그레이션 시점에만 사용되고 이후 앱 코드가 항상 명시적으로 채움)
ALTER TABLE "pass_category_usages" ADD COLUMN "date_key" TEXT NOT NULL DEFAULT '';

-- 신규 unique 인덱스: userId + categoryKey + dateKey
CREATE UNIQUE INDEX "pass_category_usages_user_id_category_key_date_key_key" ON "pass_category_usages"("user_id", "category_key", "date_key");
