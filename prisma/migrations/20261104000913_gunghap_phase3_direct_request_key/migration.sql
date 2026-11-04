-- [궁합지도 통합 최종 개발 지시서 Phase 3 — 직접 생성(DIRECT) 멱등키]
-- gunghap_pair_result에 request_key 컬럼(nullable)을 추가하고,
-- (owner_user_id, request_key) 복합 UNIQUE 인덱스를 생성한다.
--
-- [목적] "API 재시도로 인한 중복 생성"과 "사용자가 의도적으로 같은 상대와
-- 다시 궁합을 보는 것"을 데이터 내용이 아니라 "요청 세션"으로 구분한다.
-- Flutter 클라이언트는 사용자가 "확인하기"를 누르는 매 순간 새 UUID를
-- 생성해 request_key로 전송한다 — 같은 클릭의 네트워크 재시도는 동일
-- request_key를 재전송하므로 기존 결과를 그대로 반환(중복 생성 0건),
-- 사용자가 나중에 다시 버튼을 누르면 새 UUID이므로 새 결과가 생성된다
-- (의도적 재조회는 허용).
--
-- [기존 데이터 영향 없음 — 단순 컬럼 추가] 테이블 재생성(rename-copy-drop)
-- 불필요 — SQLite ADD COLUMN은 nullable 컬럼이면 테이블 재구성 없이
-- 즉시 적용된다(Phase 2의 invite_id nullable 전환과 달리, 이번엔 NOT NULL
-- 제약을 푸는 작업이 아니므로 더 가벼운 마이그레이션이다).
--
-- [기존 INVITE 16건과 절대 충돌하지 않음] owner_user_id/request_key 둘 다
-- INVITE 결과에서는 NULL로 유지된다. SQLite 복합 UNIQUE 인덱스는 구성
-- 컬럼 중 하나라도 NULL이면 해당 행을 다른 모든 행과 "별개"로 취급하므로
-- (Phase 2에서 invite_id 단일 컬럼 UNIQUE에 대해 스크래치 DB로 실증 검증한
-- 것과 동일한 SQLite 표준 동작), 기존 16건의 (NULL, NULL) 조합이 서로
-- 몇 건이 있든 전혀 제약 위반이 되지 않는다.
ALTER TABLE "gunghap_pair_result" ADD COLUMN "request_key" TEXT;

CREATE UNIQUE INDEX "gunghap_pair_result_owner_user_id_request_key_key" ON "gunghap_pair_result"("owner_user_id", "request_key");
