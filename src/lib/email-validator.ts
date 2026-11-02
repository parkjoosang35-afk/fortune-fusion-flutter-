// 이메일 형식 검증 유틸 — [신통방통 이메일 회원가입 오류 수정 지시서]
//
// [배경] 클라이언트(Flutter `core/utils/email_validator.dart`)에서 1차로
// 형식을 막더라도, 클라이언트 검증은 우회될 수 있으므로(API 직접 호출 등)
// 서버가 최종 방어선 역할을 해야 한다. "가짜 성공 처리 금지" 원칙과 동일한
// 맥락 — 반드시 서버 측에서도 동일 기준으로 재검증한다.
//
// [검증 기준] Flutter 쪽과 동일한 패턴(로컬파트@도메인.TLD, TLD는 영문
// 2자 이상)을 사용한다. 두 구현의 정규식은 반드시 동일한 기준을
// 유지할 것 — 한쪽만 바뀌면 "클라이언트는 막는데 서버는 통과" 같은
// 불일치가 생긴다.
const EMAIL_PATTERN =
  /^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$/;

export function isValidEmail(email: string): boolean {
  return EMAIL_PATTERN.test(email.trim());
}

export const INVALID_EMAIL_MESSAGE = "올바른 이메일 주소를 입력해 주세요.";
