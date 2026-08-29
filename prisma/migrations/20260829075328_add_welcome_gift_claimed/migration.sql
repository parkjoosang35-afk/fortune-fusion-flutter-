-- [Phase C - 웰컴 리워드 팝업 1회성 노출] users.welcome_gift_claimed
-- WelcomeRewardModal(회원가입 웰컴 리워드 팝업) CTA("복주머니 받기") 탭 여부를
-- 서버에 영속화한다. 기존 회원은 팝업 자체를 본 적이 없으므로 기본값 false로
-- 시작하되, 이미 가입 완료한 기존 사용자에게 뒤늦게 팝업이 뜨는 것은 의도한
-- 동작(신규 기능이므로 최초 1회 노출)이다.

ALTER TABLE "users" ADD COLUMN "welcome_gift_claimed" BOOLEAN NOT NULL DEFAULT false;
