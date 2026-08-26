-- [어뷰징 방지 개편, 2026-08 AI 상담 실연동] consultation_sessions에
-- date_key(KST 날짜)/turn_count/ad_reward_log_id 3개 컬럼을 추가하고,
-- (user_id, date_key) 유니크 제약으로 "유저당 하루 1세션"을 강제한다.
-- 기존 데이터는 started_at(UTC)을 KST(+9h)로 보정한 날짜로 백필한다.

ALTER TABLE "consultation_sessions" ADD COLUMN "date_key" TEXT NOT NULL DEFAULT '';
ALTER TABLE "consultation_sessions" ADD COLUMN "turn_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "consultation_sessions" ADD COLUMN "ad_reward_log_id" INTEGER;

-- 기존 12개 세션의 date_key를 started_at 기준 KST 날짜로 백필
UPDATE "consultation_sessions"
SET "date_key" = date(datetime("started_at", '+9 hours'));

CREATE UNIQUE INDEX "consultation_sessions_user_id_date_key_key" ON "consultation_sessions"("user_id", "date_key");
