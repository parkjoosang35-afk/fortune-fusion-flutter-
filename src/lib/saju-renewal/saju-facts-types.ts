// [정통사주 리뉴얼 v1.0] `/saju/v3/facts`(saju_engine, 기존 재사용) 실제 응답 구조를
// TypeScript로 옮긴 타입 선언.
//
// [출처] 이 타입은 추정이 아니라, saju_engine_v3.3_최종납품/saju_engine 디렉토리에서
// `calculate_saju(1990, 5, 15, 14, 30, gender='M', is_lunar=False,
// zihour_policy='traditional')`를 Python으로 직접 실행해 확보한 실제 응답 JSON을
// 그대로 타입화한 것이다(계산 엔진 코드 자체는 1장 원칙에 따라 수정하지 않음 — 이
// 파일은 admin_web 쪽에서 그 응답을 안전하게 다루기 위한 소비자 측 타입일 뿐이다).
//
// [방어적 설계] saju_engine은 외부(Python) 프로세스이므로, 필드 일부가 버전에 따라
// 누락되거나 null일 수 있다는 전제로 전부 optional(`?`)로 선언한다 — Firebase 데이터
// 타입 불일치 사고(위 가이드라인 "데이터 타입 일관성" 섹션)와 동일한 이유로, 이 파일을
// 소비하는 topic-evidence.ts/topic-engine.ts는 어디서도 non-null assertion(`!`)을
// 쓰지 않고 항상 옵셔널 체이닝 + 기본값으로 안전하게 접근한다.

export interface SajuV3PillarDetail {
  gan?: string;
  zhi?: string;
  kr?: string;
  element?: string;
}

export interface SajuV3Pillars {
  year?: SajuV3PillarDetail;
  month?: SajuV3PillarDetail;
  day?: SajuV3PillarDetail;
  hour?: SajuV3PillarDetail | null;
}

export interface SajuV3DayMaster {
  gan?: string;
  kr?: string;
  element?: string;
  yin_yang?: string;
  image?: string;
}

export interface SajuV3TenGods {
  year_gan?: string;
  month_gan?: string;
  hour_gan?: string;
  year_zhi?: string;
  month_zhi?: string;
  day_zhi?: string;
  hour_zhi?: string;
  // [인덱스 시그니처] bazi-elements.ts의 countTenGodGroup()/listTenGodSlots()가
  // Record<string, string|undefined> 형태로 범용 순회하기 위해 필요(구조적 타이핑 호환).
  [key: string]: string | undefined;
}

export interface SajuV3LuckPillar {
  start_age?: number;
  start_year?: number;
  gan_zhi?: string;
  gan_zhi_kr?: string;
}

export interface SajuV3CurrentLuck {
  start_age?: number;
  start_year?: number;
  gan_zhi?: string;
  gan_zhi_kr?: string;
}

export interface SajuV3ZhiQigan {
  year?: string[];
  month?: string[];
  day?: string[];
  hour?: string[];
}

export interface SajuV3TwelveStages {
  year?: string;
  month?: string;
  day?: string;
  hour?: string;
}

export interface SajuV3Relations {
  liuhe?: string[];
  sanhe?: string[];
  sanhe_half?: string[];
  chong?: string[];
  xing?: string[];
  xing_self?: string[];
  po?: string[];
  hai?: string[];
  yuanjin?: string[];
  gan_he?: string[];
}

export interface SajuV3Yongshin {
  yong?: string;
  yong_group?: string;
  hee?: string;
  hee_group?: string;
  gi?: string;
  gu?: string;
  reasons?: string[];
}

export interface SajuV3DayunPrecise {
  days_to_jieqi?: number;
  ref_jieqi?: string;
  direction?: string;
  method?: string;
  number?: number;
  start_age?: number;
  start_year?: number;
  source?: string;
}

/** `/saju/v3/facts` 응답 전체 — topic-evidence.ts가 조건 판정에 사용하는 부분만 타입화. */
export interface SajuV3Facts {
  input?: Record<string, unknown>;
  pillars?: SajuV3Pillars;
  day_master?: SajuV3DayMaster;
  day_master_strength?: string;
  day_master_strength_score?: number;
  five_elements_count?: Record<string, number>;
  five_elements_weighted?: Record<string, number>;
  ten_gods?: SajuV3TenGods;
  sinsal?: string[];
  gongmang?: string;
  luck_pillars?: SajuV3LuckPillar[];
  current_age?: number;
  current_luck?: SajuV3CurrentLuck;
  zhi_qigan?: SajuV3ZhiQigan;
  twelve_stages?: SajuV3TwelveStages;
  relations?: SajuV3Relations;
  yongshin?: SajuV3Yongshin;
  strength_details?: string[];
  dayun_precise?: SajuV3DayunPrecise;
  fact_schema_version?: string;
  [key: string]: unknown;
}
