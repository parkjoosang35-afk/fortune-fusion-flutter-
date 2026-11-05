-- [음력 윤달 핵심 결함 수정 지시] SajuFactsCache에 isLeapMonth 컬럼 추가.
-- birthKey 해시 구성에 isLeapMonth가 추가되므로, 평달/윤달만 다르고 나머지
-- 입력이 같은 두 음력 사용자가 같은 캐시를 잘못 공유하는 문제를 방지한다.
ALTER TABLE "saju_facts_cache" ADD COLUMN "is_leap_month" BOOLEAN NOT NULL DEFAULT false;
