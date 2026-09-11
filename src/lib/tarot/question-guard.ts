// [자유질문 무관 텍스트 리딩 생성 버그 수정 - 질문 유효성/의도 검증]
//
// [배경] 자유질문 타로에서 "안녕하세요", "123456", "asdfgh", "사과",
// "나는 오늘 밥을 먹었다" 같이 타로로 해석할 의도가 전혀 없는 문장을
// 입력해도 정상적으로 카드가 뽑히고 리딩(summary)이 생성되는 문제가
// 있었다. 원인은 route.ts가 `question`이 "비어있지 않다"는 것만
// 확인하고 바로 카드 추첨 → LLM 호출로 넘어가는 구조였기 때문이다.
//
// [3단계 방어 원칙 - 대표님 지시서]
//   1) 입력 형식 검사(이 파일) — 빈 문자열/너무 짧음/숫자·특수문자만/
//      의미 없는 문자열/반복 문자를 규칙 기반으로 즉시 차단한다.
//   2) 질문 의도 검사(이 파일) — 형식은 통과했더라도 "물음표로 끝나는
//      의문형" 또는 "운세/타로 도메인 키워드가 하나라도 포함"되는
//      경우에만 최종 통과시킨다. 둘 다 없으면(예: "나는 오늘 밥을
//      먹었다"처럼 형식은 정상 문장이지만 질문도 아니고 운세 키워드도
//      없는 일반 서술문) 차단한다.
//   3) 리딩 AI 자체 방어(narrative-engine.ts 프롬프트에 방어 지시 추가) —
//      1)/2)를 모두 통과한 경우에만 LLM이 호출되므로 3)은 최후 방어선.
//
// [클라이언트-서버 이중 검증] 이 모듈은 서버(route.ts)에서 호출되는 것이
// 원칙이다 — Flutter 클라이언트 쪽에도 동일 판정을 미리 보여주는 것은
// UX상 바람직하지만(빠른 피드백), 클라이언트 검증만으로는 API를 직접
// 두들기는 우회가 가능하므로 최종 차단은 반드시 서버에서 이루어진다.
export interface QuestionValidationResult {
  valid: boolean;
  /** 차단 시 사용자에게 보여줄 안내 문구. valid=true면 undefined. */
  reason?: string;
}

const GUIDE_MESSAGE = "타로로 궁금한 내용을 질문해주세요.\n예: 그 사람과 다시 만날 수 있을까요?";

// 운세/타로 상담 도메인에서 자주 쓰이는 핵심 단어. topic-keywords.ts의
// 65개 주제 키워드 전체를 포함할 필요는 없다 — 여기서는 "이 문장이 상담
// 의도를 담고 있는가"만 판별하면 되므로, 각 카테고리를 대표하는 포괄적
// 단어 위주로 간결하게 구성한다(65개 세부 키워드는 topic-matcher가 그
// 다음 단계에서 별도로 처리).
const FORTUNE_DOMAIN_KEYWORDS = [
  // 연애/관계
  "연애", "사랑", "썸", "재회", "이별", "헤어", "고백", "결혼", "궁합",
  "인연", "짝사랑", "미련", "남자친구", "여자친구", "애인", "그사람",
  "그 사람", "짝", "연인", "장거리", "권태기", "바람",
  // 커리어/일
  "이직", "취업", "면접", "승진", "퇴사", "창업", "커리어", "직장",
  "회사", "일이", "업무", "동료", "상사", "프리랜서", "합격",
  // 금전
  "재물", "금전", "돈이", "투자", "계약", "지출", "자산", "수입",
  "재정", "복권", "대출",
  // 일상/운세 전반
  // [주의] "오늘"/"내일"/"이번주"/"올해" 같은 순수 시간 표현은 일반
  // 서술문("나는 오늘 밥을 먹었다")에도 흔히 등장해 오탐(false positive)을
  // 유발하므로 단독 키워드로 넣지 않는다 — 실제 "오늘의 운세"류 질문은
  // 대부분 의문형 어미(-까요/-일까 등)를 동반하므로 아래 isQuestionForm
  // 판정으로 이미 커버된다.
  "운세", "타로", "점괘", "사주", "앞날", "흐름이", "기운이", "행운",
  "조언을", "고민이",
  // 감정/내면
  "마음", "불안", "위로", "성장", "감정", "고민", "걱정", "자신감",
];

// 자모 반복/의미없는 감탄사류(ㅋㅋㅋ, ㅎㅎㅎ, ㅇㅇ, ㄷㄷ 등)를 걸러내기
// 위한 패턴 — 한글 자모(홀소리·닿소리)만으로 구성된 짧은 감탄사.
const KOREAN_JAMO_ONLY = /^[\u3131-\u318E\s]+$/;

// 숫자/특수문자로만 구성된 입력("123456", "!!!???", "1234-5678" 등).
const DIGITS_OR_SYMBOLS_ONLY = /^[\d\s!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?~`]+$/;

// 알파벳(영문)만으로 구성되고 사전 단어처럼 보이지 않는 저의미 입력
// ("asdfgh", "qwerty" 등)을 걸러내는 데 참고할 키보드 연타 패턴.
const KEYBOARD_MASH_PATTERNS = [
  /^[asdfghjkl]+$/i,
  /^[qwertyuiop]+$/i,
  /^[zxcvbnm]+$/i,
  /^qwerty/i,
  /^asdf/i,
];

/** 같은 문자(또는 2글자 패턴)가 과도하게 반복되는 입력을 감지한다. */
function isRepeatedChar(normalized: string): boolean {
  if (normalized.length < 2) return false;
  const uniqueChars = new Set(normalized.replace(/\s/g, "").split(""));
  // 공백을 제외한 전체 글자 종류가 2종 이하면서 3자 이상이면 반복으로 간주
  // (예: "ㅋㅋㅋㅋ" -> {ㅋ}, "하하하하" -> {하}, "ㅋㅎㅋㅎ" -> {ㅋ,ㅎ}).
  const noSpace = normalized.replace(/\s/g, "");
  if (noSpace.length >= 3 && uniqueChars.size <= 2) return true;
  return false;
}

/**
 * 사용자가 입력한 자유질문 문장이 타로 리딩을 생성할 만한 "유효한 질문"인지
 * 판단한다. 카드 추첨/LLM 호출 이전에 반드시 이 함수를 거쳐야 한다.
 */
export function validateTarotQuestion(rawQuestion: string): QuestionValidationResult {
  const question = rawQuestion.trim();

  // 1) 빈 문자열
  if (question.length === 0) {
    return { valid: false, reason: GUIDE_MESSAGE };
  }

  // 2) 너무 짧은 입력(2자 이하는 "사과", "안녕" 같은 의미 없는 단답이
  //    될 확률이 매우 높다. "재회?"처럼 3자여도 물음표가 있으면 아래
  //    의도 검사에서 별도로 구제된다).
  if (question.length < 2) {
    return { valid: false, reason: GUIDE_MESSAGE };
  }

  const normalized = question.replace(/\s+/g, "");

  // 3) 숫자/특수문자만으로 구성된 입력("123456", "!!!")
  if (DIGITS_OR_SYMBOLS_ONLY.test(question)) {
    return { valid: false, reason: GUIDE_MESSAGE };
  }

  // 4) 한글 자모(자음/모음)만으로 구성된 의미 없는 감탄사("ㅋㅋㅋㅋ", "ㅇㅇ")
  if (KOREAN_JAMO_ONLY.test(question)) {
    return { valid: false, reason: GUIDE_MESSAGE };
  }

  // 5) 영문 키보드 연타 패턴("asdfgh", "qwerty")
  for (const pattern of KEYBOARD_MASH_PATTERNS) {
    if (pattern.test(normalized)) {
      return { valid: false, reason: GUIDE_MESSAGE };
    }
  }

  // 6) 반복 문자("ㅋㅋㅋㅋㅋ", "하하하하하", "gggggg")
  if (isRepeatedChar(normalized)) {
    return { valid: false, reason: GUIDE_MESSAGE };
  }

  // ── 여기까지가 "형식 검사"(1단계). 아래는 "의도 검사"(2단계) ──
  //
  // 형식상으로는 정상적인 문장이라도("안녕하세요", "반갑습니다", "나는
  // 오늘 밥을 먹었다") 타로로 해석할 의도가 없는 일반 서술문은 여전히
  // 걸러야 한다. 판정 기준: 아래 둘 중 하나라도 만족해야 통과.
  //   (a) 의문형 문장 — 물음표로 끝나거나, "까요/일까/될까/줄까/할까/
  //       나요/있을까/좋을까" 등 한국어 의문형 종결/연결 어미가 포함.
  //   (b) 운세/타로 상담 도메인 키워드가 하나 이상 포함.
  const hasQuestionMark = question.includes("?") || question.includes("？");
  const KOREAN_QUESTION_ENDINGS = [
    "까요", "일까", "될까", "줄까", "할까", "나요", "가요",
    "습니까", "인가요", "인가", "궁금", "알려줘", "말해줘", "봐줘",
  ];
  const hasQuestionEnding = KOREAN_QUESTION_ENDINGS.some((e) => question.includes(e));
  const isQuestionForm = hasQuestionMark || hasQuestionEnding;

  const hasFortuneKeyword = FORTUNE_DOMAIN_KEYWORDS.some((kw) => question.includes(kw));

  if (!isQuestionForm && !hasFortuneKeyword) {
    return { valid: false, reason: GUIDE_MESSAGE };
  }

  return { valid: true };
}
