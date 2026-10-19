-- [보안 수정 2026-10-19 -- 전수검수 feat/saju-audit 762efc9 반영 ③] 노출 이력
-- "1건만 유지" 불변식을 유니크 인덱스로 강제한다. 기존에는 일반 인덱스만 있어
-- 동시 요청 시 중복 행 생성이 가능했다(경쟁조건). 먼저 중복을 정리한 뒤
-- 유니크 인덱스를 만든다(기존 운영 DB에 중복이 있어도 마이그레이션이 실패하지
-- 않도록 dedupe 선행).
DELETE FROM "topic_exposure_history"
WHERE "id" NOT IN (
    SELECT MIN("id") FROM "topic_exposure_history" GROUP BY "user_id", "topic_id", "birth_key"
);
CREATE UNIQUE INDEX IF NOT EXISTS "topic_exposure_history_user_topic_birth_key"
    ON "topic_exposure_history"("user_id", "topic_id", "birth_key");
