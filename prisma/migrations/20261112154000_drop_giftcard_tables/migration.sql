-- [2026-11 정책변경] 상품권(giftcard) 교환 기능 완전삭제(사용자 확정 "완전삭제")
-- 관리자 화면/공개 API/Flutter 앱 코드 삭제에 이어, 아래 7개 테이블도 DROP한다.
-- Payment 테이블의 과거 order_type='giftcard' 결제기록(3건)은 폴리모픽 참조(FK 아님)이며
-- 04A 결제원장 보존원칙에 따라 그대로 유지된다(영향 없음).
PRAGMA foreign_keys=OFF;
DROP TABLE IF EXISTS "giftcard_refunds";
DROP TABLE IF EXISTS "giftcard_expiry_logs";
DROP TABLE IF EXISTS "giftcard_reissues";
DROP TABLE IF EXISTS "giftcard_cancels";
DROP TABLE IF EXISTS "giftcard_usages";
DROP TABLE IF EXISTS "giftcard_issues";
DROP TABLE IF EXISTS "giftcard_products";
PRAGMA foreign_keys=ON;
