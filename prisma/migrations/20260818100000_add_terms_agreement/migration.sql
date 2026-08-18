-- [6-7-4-B-4] 회원가입 시 필수 약관(이용약관/개인정보처리방침) 동의 시각 기록.
-- 기존 회원은 가입 당시 약관동의 UI 자체가 없었으므로 NULL로 유지한다
-- (소급 백필 없음 — 실제로 동의한 적 없는 사실을 왜곡하지 않기 위함).

ALTER TABLE "users" ADD COLUMN "terms_agreed_at" DATETIME;
ALTER TABLE "users" ADD COLUMN "privacy_agreed_at" DATETIME;
