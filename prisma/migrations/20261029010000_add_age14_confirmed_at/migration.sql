-- [6-7-4-B-4 전면개정] 회원가입 시 "만 14세 이상입니다" 필수 체크박스 동의 시각 기록.
-- 기존 회원(이 체크박스 신설 이전 가입자)은 NULL로 유지한다(소급 백필 없음 —
-- terms_agreed_at/privacy_agreed_at과 동일한 원칙).

ALTER TABLE "users" ADD COLUMN "age14_confirmed_at" DATETIME;
