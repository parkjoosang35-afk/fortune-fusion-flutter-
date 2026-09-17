-- 알림 실제 발송 연동: Notification.category / Notification.deepLink 필드 추가.
-- 응원/댓글/복주머니 이벤트 발생 시 notification-engine.ts가 이 두 필드를
-- 채워 실제 알림을 생성한다. 기존 NotificationPreference.category 화이트리스트
-- (marketing/fortune_update/matching/community)를 재사용한다.
ALTER TABLE "notifications" ADD COLUMN "category" TEXT;
ALTER TABLE "notifications" ADD COLUMN "deep_link" TEXT;
