-- [마케팅 쿠폰 디자인 및 발행 관리 기능 개선] 총 발행 수량 한도 필드 추가.
-- null = 무제한(기본값이 아닌 한정 수량이 기본이어야 하므로 애플리케이션
-- 레이어에서 입력을 강제하지만, 컬럼 자체는 하위호환을 위해 nullable로
-- 둔다 — 기존 캠페인은 전부 NULL(무제한)로 남아 기존 동작과 100% 동일하다.
ALTER TABLE "bokju_coupon_campaigns" ADD COLUMN "total_issue_limit" INTEGER;
