// [신통방통 타로 65종 주제 연동 - §계획2 자유질문 자동매칭]
//
// 사용자가 "자유질문" 화면에서 topic을 지정하지 않고(레거시 2칩
// general/love 중 하나만 선택) 자유 문장으로 질문을 입력했을 때,
// 그 문장에 담긴 키워드를 분석해 65개 주제 중 가장 근접한 주제로
// 자동 라우팅하기 위한 키워드 사전이다.
//
// 데이터 출처: `docs/tarot_65_topics_design_table.md`의 "질문목적"과
// Flutter `tarot_suggested_questions.dart`의 사용자 발화체 예시 문구를
// 참고해, 각 주제를 다른 주제와 구별할 수 있는 핵심 단어/구절을
// 선정했다(공백 제거 후 부분일치 검사이므로 조사가 붙어도 매칭됨:
// 예) "재회" -> "재회를", "재회가" 모두 매칭).
//
// ⚠️ `daily_direction_of_choice`(선택의 방향)는 이 사전에서 의도적으로
// 제외한다. 이 주제는 choice_ab 스프레드 전용이며 optionA/optionB
// 입력이 반드시 필요하므로, 자유질문 자동매칭으로 이 주제가 선택되면
// 필수 파라미터 누락으로 오류가 발생한다(카테고리 화면을 통해서만
// 진입 가능해야 한다).
export const TOPIC_KEYWORDS: Record<string, string[]> = {
  // ── A. 연애·관계 (14, daily_direction_of_choice 제외) ──
  love_flow_of_crush: ["썸", "그린라이트", "밀당", "썸타는"],
  love_inner_truth: ["속마음", "진짜마음", "숨기고있는마음", "숨긴감정"],
  love_reunion_chance: ["재회", "헤어진", "다시만날", "다시만나"],
  love_will_they_contact: ["연락이올까", "먼저연락", "연락올까", "연락이"],
  love_confession_timing: ["고백"],
  love_fortune: ["연애운", "새로운인연이", "연애전반"],
  love_marriage_chance: ["결혼"],
  love_relationship_future: ["관계의미래", "관계앞으로", "관계가안정", "이관계어떻게"],
  love_secret_relationship: ["비밀연애", "비밀리에연애"],
  love_long_distance: ["장거리", "장거리연애"],
  love_lingering_after_breakup: ["미련", "이별후"],
  love_destined_connection: ["운명의인연", "운명적인", "특별한인연"],
  love_next_chapter_of_crush: ["짝사랑"],
  love_timing_of_fate: ["인연의타이밍", "좋은인연이", "인연을만날"],

  // ── B. 일·커리어 (12) ──
  career_job_change: ["이직"],
  career_interview_result: ["면접"],
  career_boss_relationship: ["상사"],
  career_coworker_flow: ["동료"],
  career_project_result: ["프로젝트"],
  career_promotion_chance: ["승진"],
  career_startup_fortune: ["창업"],
  career_freelance_fortune: ["프리랜서"],
  career_current_job_future: ["지금다니는직장", "현재직장", "이회사에계속", "다니는직장"],
  career_yearly_flow: ["올해커리어", "올해제커리어", "커리어흐름"],
  career_aptitude_direction: ["적성", "나에게맞는일", "저에게맞는일"],
  career_new_sprout: ["막시작한일", "이제시작한", "커리어새싹", "이경력을계속"],

  // ── C. 금전·현실 (9) ──
  wealth_fortune: ["재물운", "금전운"],
  wealth_spending_flow: ["소비패턴", "제소비", "소비를어떻게"],
  wealth_investment_flow: ["투자"],
  wealth_contract_success: ["계약"],
  wealth_incoming_timing: ["돈이들어", "자금흐름", "돈들어올", "여유가생길"],
  wealth_spending_warning: ["지출", "돈이새어"],
  wealth_solution_hint: ["돈문제", "금전문제", "돈문제풀릴"],
  wealth_asset_direction: ["가진자산", "자산관리", "자산을"],
  wealth_harvest_timing: ["수확의시기", "결실을맺을", "노력한결실"],

  // ── D. 일상·운세 (10, daily_direction_of_choice 제외) ──
  daily_today_tarot: ["오늘하루는", "오늘조심", "오늘저에게"],
  daily_this_week: ["이번주"],
  daily_this_month: ["이번달"],
  daily_this_year: ["올한해", "올해저에게", "올해전체적으로"],
  daily_message_needed_now: ["지금필요한메시지", "지금저에게필요한", "지금이상황에서"],
  daily_things_to_watch: ["조심해야할일", "경계해야할", "앞으로조심"],
  daily_luck_point: ["행운포인트", "행운이숨", "행운을어떻게"],
  daily_tomorrow_feeling: ["내일은", "내일하루", "내일예감", "내일조심"],
  daily_quarterly_flow: ["석달", "분기에", "앞으로석달"],

  // ── E. 감정·내면 (10) ──
  emotion_current_heart: ["지금내마음", "제마음이지금", "지금제마음"],
  emotion_anxiety_root: ["불안"],
  emotion_need_comfort: ["위로가필요", "위로를"],
  emotion_to_let_go: ["놓아야할감정", "흘려보내야", "붙잡고있는감정"],
  emotion_can_i_restart: ["다시시작할수", "다시일어설"],
  emotion_advice_for_myself: ["나를위한조언", "스스로에게어떤말", "저에게필요한조언"],
  emotion_hidden_talent: ["숨은재능", "발견못한강점"],
  emotion_inner_growth: ["성장을위해", "내면성장", "어떻게성장하고"],
  emotion_wave: ["감정의파동", "마음이흔들", "왜이렇게마음이"],
  emotion_time_lag: ["마음의시차", "마음이머물", "그때에머물"],

  // ── F. 특별테마 (10) ──
  special_soul_card: ["소울카드", "영혼과맞닿은"],
  special_destiny_card: ["운명의카드", "오늘나를찾아온카드"],
  special_dawn_tarot: ["새벽", "잠들지못"],
  special_full_moon_tarot: ["보름달"],
  special_wish_tarot: ["소원"],
  special_lucky_door_tarot: ["행운의문", "열리는문", "기회의문"],
  special_maze_of_fate_tarot: ["인연의미로", "얽힌인연", "이미로를"],
  special_secret_garden_tarot: ["비밀정원", "마음속정원"],
  special_guardian_star_tarot: ["저를지켜주는별", "별자리", "지켜온것"],
  special_midnight_vow_tarot: ["자정", "다짐", "서약"],
};
