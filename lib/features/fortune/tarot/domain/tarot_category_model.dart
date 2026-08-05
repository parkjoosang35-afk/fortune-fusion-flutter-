/// [타로 섹션 전면 개편 §4 타로 서브 카테고리 설계]
///
/// 6개 그룹(연애/관계, 일/커리어, 금전/현실, 일상/운세, 감정/내면, 특별테마)
/// 총 65개 서브 카테고리의 데이터 모델과 정적 데이터.
///
/// [topicKey]는 기존 `tarot_text_engine.dart`의 20개 [TarotTopic.id] 중
/// 하나로 매핑된다(§1-3 실행 원칙 2 - 텍스트 엔진은 즉시 확장하지 않고
/// 매핑으로 대응). 신규 카테고리 65개가 20개 topic으로 수렴하는 것은
/// 의도된 설계로, 카테고리별 비주얼(아이콘/컬러/모션/문구) 차별화로
/// 체감 다양성을 만들고, 텍스트 풀 자체의 확장은 2차 로드맵(§11 P7)에서
/// 진행한다.
library;

import 'package:flutter/material.dart';
import '../presentation/theme/tarot_colors.dart';

/// 6개 서브 카테고리 그룹.
enum TarotCategoryGroup { love, career, wealth, daily, emotion, special }

extension TarotCategoryGroupX on TarotCategoryGroup {
  String get label {
    switch (this) {
      case TarotCategoryGroup.love:
        return '연애 · 관계';
      case TarotCategoryGroup.career:
        return '일 · 커리어';
      case TarotCategoryGroup.wealth:
        return '금전 · 현실';
      case TarotCategoryGroup.daily:
        return '일상 · 운세';
      case TarotCategoryGroup.emotion:
        return '감정 · 내면';
      case TarotCategoryGroup.special:
        return '특별 테마';
    }
  }

  String get moodCopy {
    switch (this) {
      case TarotCategoryGroup.love:
        return '흔들리고 이어지는 마음의 결을 들여다봐요';
      case TarotCategoryGroup.career:
        return '지금 걷고 있는 길의 방향을 비춰봐요';
      case TarotCategoryGroup.wealth:
        return '흘러들고 흘러나가는 것들의 흐름을 읽어요';
      case TarotCategoryGroup.daily:
        return '오늘과 다가올 하루하루의 결을 미리 봐요';
      case TarotCategoryGroup.emotion:
        return '지금 내 안에 흐르는 감정을 가만히 들여다봐요';
      case TarotCategoryGroup.special:
        return '조금 더 특별한 순간을 위한 테마들';
    }
  }

  Color get accentColor {
    switch (this) {
      case TarotCategoryGroup.love:
        return TarotColors.groupLoveGlow;
      case TarotCategoryGroup.career:
        return TarotColors.groupCareer;
      case TarotCategoryGroup.wealth:
        return TarotColors.groupWealth;
      case TarotCategoryGroup.daily:
        return TarotColors.groupDaily;
      case TarotCategoryGroup.emotion:
        return TarotColors.groupEmotion;
      case TarotCategoryGroup.special:
        return TarotColors.groupSpecial;
    }
  }
}

/// 카테고리 진입 모션 종류(§6 애니메이션 시스템과 연계).
enum TarotEntryMotion {
  rippleSpread, // 물결 리플
  fogDissolve, // 안개 디졸브
  circleRewind, // 원형 되감기
  vibrateSignal, // 진동하듯 미세 흔들림
  lightConverge, // 빛이 한 점으로 모임
  glowExpand, // 핑크 글로우 확산
  lightMerge, // 두 빛이 하나로 합쳐짐
  starPath, // 별빛 경로가 그려짐
  curtainSlide, // 커튼이 걷히듯 슬라이드
  constellationLine, // 별이 이어지는 궤적선
  petalFall, // 꽃잎이 떨어지는 파티클
  redThread, // 붉은 실 궤적
  featherDrift, // 깃털이 흩날리는 드리프트
  clockGlow, // 시계 문양 빛무리
  doorOpenBeam, // 문이 열리는 광선 확장
  focusZoom, // 조준선이 좁아지는 포커스
  crossBeam, // 직선광선 교차
  parallelFlow, // 두 선이 나란히 흐름
  graphRise, // 그래프형 광선 상승
  stepLight, // 계단형 빛 계층
  rocketRise, // 로켓처럼 빛 상승
  compassSpin, // 나침반 회전
  buildingFocus, // 건물 실루엣 부각
  calendarFlip, // 달력 페이지 넘김 광선
  puzzleFit, // 조각이 맞춰지는 빛
  sproutGlow, // 새싹 형태 빛 번짐
  coinFall, // 동전 낙하 파티클
  signatureLine, // 서명선 그려짐
  hourglassFall, // 모래시계 빛 낙하
  crackWarning, // 균열형 경고 광선
  lockOpen, // 자물쇠가 열리는 빛
  boxOpen, // 상자가 열리는 빛무리
  grainDrift, // 낟알이 흩날리는 드리프트
  sunBurst, // 태양빛 원형 확산
  weekPageGlow, // 주간 캘린더 빛 페이지
  moonExpand, // 달 모양 광원 확대
  constellationBurst, // 별자리 전체 확산
  whisperSpread, // 속삭임처럼 번지는 빛
  shieldBeam, // 방패형 광선
  cloverSpark, // 클로버 빛 파편
  forkBeam, // 갈림길 광선 분기
  dawnGradient, // 새벽빛 그라데이션
  seasonBeam, // 계절 사분할 광선
  candleFlicker, // 촛불처럼 흔들리는 광원
  fogLift, // 안개가 서서히 걷힘
  waveSpread, // 부드러운 파동 확산
  leafDrift, // 잎이 흩날리는 드리프트
  sproutRise, // 새싹 빛 번짐(재사용)
  mirrorGlow, // 거울처럼 비치는 광원
  gemSparkle, // 원석이 빛나는 반짝임
  treeRise, // 나무가 자라는 광선 상승
  rippleRing, // 물방울 파동 링
  clockReverse, // 시계 광선 역회전
  cardFlipZoom, // 카드 실루엣 확대+플립
  symbolSpin, // 문양 회전 광선
  dawnBrighten, // 새벽빛 서서히 밝아짐
  fullMoonExpand, // 보름달 광원 확대
  starConverge, // 별빛이 한 점에 모임
  doorBeam, // 문이 서서히 열리는 광선
  mazeLine, // 미로 라인이 그려짐
  vineDrift, // 덩굴이 번지는 드리프트
  constellationConnect, // 별자리 라인 연결
  candleSpread, // 촛불 빛 확산
}

class TarotCategoryMeta {
  final String id;
  final TarotCategoryGroup group;
  final String label;
  final String moodCopy;
  final String emoji;
  final Color accentColor;
  final TarotEntryMotion entryMotion;
  final String topicKey; // TarotTopic.id (tarot_text_engine.dart) 매핑
  final bool isPremium;
  final bool isNew;
  final int popularityScore;

  const TarotCategoryMeta({
    required this.id,
    required this.group,
    required this.label,
    required this.moodCopy,
    required this.emoji,
    required this.accentColor,
    required this.entryMotion,
    required this.topicKey,
    this.isPremium = false,
    this.isNew = false,
    this.popularityScore = 50,
  });

  Color get glowColor => accentColor.withValues(alpha: 0.55);
}

/// 65개 서브 카테고리 정적 데이터(§4 표와 1:1 대응).
class TarotCategoryData {
  TarotCategoryData._();

  static const List<TarotCategoryMeta> all = [
    // ── 그룹 A: 연애/관계 (14개) ──
    TarotCategoryMeta(
      id: 'love_flow_of_crush',
      group: TarotCategoryGroup.love,
      label: '썸의 흐름',
      moodCopy: '흔들리는 마음의 방향을 읽어요',
      emoji: '🌊',
      accentColor: TarotColors.groupLoveGlow,
      entryMotion: TarotEntryMotion.rippleSpread,
      topicKey: 'love',
      popularityScore: 96,
    ),
    TarotCategoryMeta(
      id: 'love_inner_truth',
      group: TarotCategoryGroup.love,
      label: '상대의 속마음',
      moodCopy: '말하지 않은 진심에 다가가요',
      emoji: '🌙',
      accentColor: Color(0xFFC68FE0),
      entryMotion: TarotEntryMotion.fogDissolve,
      topicKey: 'crush',
      popularityScore: 92,
    ),
    TarotCategoryMeta(
      id: 'love_reunion_chance',
      group: TarotCategoryGroup.love,
      label: '재회 가능성',
      moodCopy: '다시 이어질 수 있을까요',
      emoji: '🔁',
      accentColor: TarotColors.groupLove,
      entryMotion: TarotEntryMotion.circleRewind,
      topicKey: 'reunion',
      popularityScore: 88,
    ),
    TarotCategoryMeta(
      id: 'love_will_they_contact',
      group: TarotCategoryGroup.love,
      label: '연락이 올까',
      moodCopy: '기다림 끝의 신호를 봐요',
      emoji: '📱',
      accentColor: TarotColors.groupLoveGlow,
      entryMotion: TarotEntryMotion.vibrateSignal,
      topicKey: 'crush',
      popularityScore: 90,
    ),
    TarotCategoryMeta(
      id: 'love_confession_timing',
      group: TarotCategoryGroup.love,
      label: '고백 타이밍',
      moodCopy: '마음을 전할 순간을 찾아요',
      emoji: '💌',
      accentColor: Color(0xFFE88FC0),
      entryMotion: TarotEntryMotion.lightConverge,
      topicKey: 'love',
      popularityScore: 84,
    ),
    TarotCategoryMeta(
      id: 'love_fortune',
      group: TarotCategoryGroup.love,
      label: '연애운',
      moodCopy: '다가올 사랑의 결을 봐요',
      emoji: '💞',
      accentColor: TarotColors.groupLoveGlow,
      entryMotion: TarotEntryMotion.glowExpand,
      topicKey: 'love',
      popularityScore: 99,
    ),
    TarotCategoryMeta(
      id: 'love_marriage_chance',
      group: TarotCategoryGroup.love,
      label: '결혼 가능성',
      moodCopy: '함께할 미래를 그려봐요',
      emoji: '💍',
      accentColor: Color(0xFFC68FE0),
      entryMotion: TarotEntryMotion.lightMerge,
      topicKey: 'marriage',
      popularityScore: 80,
    ),
    TarotCategoryMeta(
      id: 'love_relationship_future',
      group: TarotCategoryGroup.love,
      label: '관계의 미래',
      moodCopy: '이 인연이 향하는 곳',
      emoji: '🔮',
      accentColor: TarotColors.groupLove,
      entryMotion: TarotEntryMotion.starPath,
      topicKey: 'relationship',
      popularityScore: 78,
    ),
    TarotCategoryMeta(
      id: 'love_secret_relationship',
      group: TarotCategoryGroup.love,
      label: '비밀연애',
      moodCopy: '숨겨둔 마음의 흐름',
      emoji: '🤫',
      accentColor: Color(0xFF8C5B9E),
      entryMotion: TarotEntryMotion.curtainSlide,
      topicKey: 'crush',
      popularityScore: 60,
    ),
    TarotCategoryMeta(
      id: 'love_long_distance',
      group: TarotCategoryGroup.love,
      label: '장거리 연애',
      moodCopy: '거리를 넘는 마음의 온도',
      emoji: '✈️',
      accentColor: Color(0xFFC68FE0),
      entryMotion: TarotEntryMotion.constellationLine,
      topicKey: 'relationship',
      popularityScore: 55,
    ),
    TarotCategoryMeta(
      id: 'love_lingering_after_breakup',
      group: TarotCategoryGroup.love,
      label: '이별 후 미련',
      moodCopy: '남은 마음을 들여다봐요',
      emoji: '🥀',
      accentColor: Color(0xFF9E6FA0),
      entryMotion: TarotEntryMotion.petalFall,
      topicKey: 'reunion',
      popularityScore: 70,
    ),
    TarotCategoryMeta(
      id: 'love_destined_connection',
      group: TarotCategoryGroup.love,
      label: '운명의 인연',
      moodCopy: '실이 이어진 사람을 찾아요',
      emoji: '🧵',
      accentColor: TarotColors.groupLoveGlow,
      entryMotion: TarotEntryMotion.redThread,
      topicKey: 'love',
      popularityScore: 74,
    ),
    TarotCategoryMeta(
      id: 'love_next_chapter_of_crush',
      group: TarotCategoryGroup.love,
      label: '짝사랑의 다음 장',
      moodCopy: '혼자만의 마음, 다음은 어디로',
      emoji: '🕊️',
      accentColor: Color(0xFFE88FC0),
      entryMotion: TarotEntryMotion.featherDrift,
      topicKey: 'crush',
      isNew: true,
      popularityScore: 65,
    ),
    TarotCategoryMeta(
      id: 'love_timing_of_fate',
      group: TarotCategoryGroup.love,
      label: '인연의 타이밍',
      moodCopy: '지금이 만날 때가 맞을까요',
      emoji: '💫',
      accentColor: Color(0xFFC68FE0),
      entryMotion: TarotEntryMotion.clockGlow,
      topicKey: 'relationship',
      isNew: true,
      popularityScore: 62,
    ),

    // ── 그룹 B: 일/커리어 (12개) ──
    TarotCategoryMeta(
      id: 'career_job_change',
      group: TarotCategoryGroup.career,
      label: '이직운',
      moodCopy: '새로운 문 앞에서',
      emoji: '🔄',
      accentColor: TarotColors.groupCareer,
      entryMotion: TarotEntryMotion.doorOpenBeam,
      topicKey: 'career_change',
      popularityScore: 82,
    ),
    TarotCategoryMeta(
      id: 'career_interview_result',
      group: TarotCategoryGroup.career,
      label: '면접 결과',
      moodCopy: '준비한 것이 통할까요',
      emoji: '🎯',
      accentColor: Color(0xFF6B8FD4),
      entryMotion: TarotEntryMotion.focusZoom,
      topicKey: 'exam',
      popularityScore: 75,
    ),
    TarotCategoryMeta(
      id: 'career_boss_relationship',
      group: TarotCategoryGroup.career,
      label: '상사와의 관계',
      moodCopy: '위태로운 균형을 읽어요',
      emoji: '🧑‍💼',
      accentColor: Color(0xFF4A6BB0),
      entryMotion: TarotEntryMotion.crossBeam,
      topicKey: 'relationship',
      popularityScore: 58,
    ),
    TarotCategoryMeta(
      id: 'career_coworker_flow',
      group: TarotCategoryGroup.career,
      label: '동료와의 흐름',
      moodCopy: '함께 걷는 길의 결',
      emoji: '🤝',
      accentColor: TarotColors.groupCareer,
      entryMotion: TarotEntryMotion.parallelFlow,
      topicKey: 'relationship',
      popularityScore: 52,
    ),
    TarotCategoryMeta(
      id: 'career_project_result',
      group: TarotCategoryGroup.career,
      label: '프로젝트 결과',
      moodCopy: '지금 이 일의 끝은',
      emoji: '📊',
      accentColor: Color(0xFF6B8FD4),
      entryMotion: TarotEntryMotion.graphRise,
      topicKey: 'business',
      popularityScore: 60,
    ),
    TarotCategoryMeta(
      id: 'career_promotion_chance',
      group: TarotCategoryGroup.career,
      label: '승진 가능성',
      moodCopy: '한 계단 더 오를 수 있을까',
      emoji: '🪜',
      accentColor: Color(0xFF7B9AD8),
      entryMotion: TarotEntryMotion.stepLight,
      topicKey: 'career_change',
      popularityScore: 66,
    ),
    TarotCategoryMeta(
      id: 'career_startup_fortune',
      group: TarotCategoryGroup.career,
      label: '창업운',
      moodCopy: '새로 세우는 것의 미래',
      emoji: '🚀',
      accentColor: TarotColors.groupCareer,
      entryMotion: TarotEntryMotion.rocketRise,
      topicKey: 'business',
      popularityScore: 63,
    ),
    TarotCategoryMeta(
      id: 'career_freelance_fortune',
      group: TarotCategoryGroup.career,
      label: '프리랜서 운',
      moodCopy: '혼자 걷는 길의 방향',
      emoji: '🧭',
      accentColor: Color(0xFF6B8FD4),
      entryMotion: TarotEntryMotion.compassSpin,
      topicKey: 'business',
      popularityScore: 48,
    ),
    TarotCategoryMeta(
      id: 'career_current_job_future',
      group: TarotCategoryGroup.career,
      label: '현재 직장의 미래',
      moodCopy: '지금 있는 곳은 안전할까',
      emoji: '🏢',
      accentColor: Color(0xFF4A6BB0),
      entryMotion: TarotEntryMotion.buildingFocus,
      topicKey: 'job',
      popularityScore: 57,
    ),
    TarotCategoryMeta(
      id: 'career_yearly_flow',
      group: TarotCategoryGroup.career,
      label: '올해 커리어 흐름',
      moodCopy: '한 해의 일의 결을 봐요',
      emoji: '📅',
      accentColor: TarotColors.groupCareer,
      entryMotion: TarotEntryMotion.calendarFlip,
      topicKey: 'career_change',
      popularityScore: 54,
    ),
    TarotCategoryMeta(
      id: 'career_aptitude_direction',
      group: TarotCategoryGroup.career,
      label: '적성과 방향',
      moodCopy: '내게 맞는 길을 찾아요',
      emoji: '🧩',
      accentColor: Color(0xFF7B9AD8),
      entryMotion: TarotEntryMotion.puzzleFit,
      topicKey: 'job',
      isNew: true,
      popularityScore: 50,
    ),
    TarotCategoryMeta(
      id: 'career_new_sprout',
      group: TarotCategoryGroup.career,
      label: '커리어 새싹',
      moodCopy: '이제 막 시작하는 일의 운',
      emoji: '🌱',
      accentColor: Color(0xFF6B8FD4),
      entryMotion: TarotEntryMotion.sproutGlow,
      topicKey: 'study',
      isNew: true,
      popularityScore: 45,
    ),

    // ── 그룹 C: 금전/현실 (9개) ──
    TarotCategoryMeta(
      id: 'wealth_fortune',
      group: TarotCategoryGroup.wealth,
      label: '재물운',
      moodCopy: '흘러들어오는 것의 흐름',
      emoji: '💰',
      accentColor: TarotColors.groupWealth,
      entryMotion: TarotEntryMotion.constellationLine,
      topicKey: 'wealth',
      popularityScore: 94,
    ),
    TarotCategoryMeta(
      id: 'wealth_spending_flow',
      group: TarotCategoryGroup.wealth,
      label: '소비 흐름',
      moodCopy: '지금 새어나가는 것들',
      emoji: '🛍️',
      accentColor: Color(0xFFC89550),
      entryMotion: TarotEntryMotion.coinFall,
      topicKey: 'wealth',
      popularityScore: 58,
    ),
    TarotCategoryMeta(
      id: 'wealth_investment_flow',
      group: TarotCategoryGroup.wealth,
      label: '투자 흐름',
      moodCopy: '지금의 결정, 흐름이 맞을까',
      emoji: '📈',
      accentColor: TarotColors.groupWealth,
      entryMotion: TarotEntryMotion.graphRise,
      topicKey: 'wealth',
      popularityScore: 71,
    ),
    TarotCategoryMeta(
      id: 'wealth_contract_success',
      group: TarotCategoryGroup.wealth,
      label: '계약 성사 가능성',
      moodCopy: '도장 찍기 전 살펴봐요',
      emoji: '📝',
      accentColor: Color(0xFFC89550),
      entryMotion: TarotEntryMotion.signatureLine,
      topicKey: 'contract',
      popularityScore: 50,
    ),
    TarotCategoryMeta(
      id: 'wealth_incoming_timing',
      group: TarotCategoryGroup.wealth,
      label: '돈이 들어오는 시기',
      moodCopy: '기다림의 끝은 언제',
      emoji: '⏳',
      accentColor: TarotColors.groupWealth,
      entryMotion: TarotEntryMotion.hourglassFall,
      topicKey: 'wealth',
      popularityScore: 68,
    ),
    TarotCategoryMeta(
      id: 'wealth_spending_warning',
      group: TarotCategoryGroup.wealth,
      label: '지출 경고',
      moodCopy: '새는 곳을 미리 봐요',
      emoji: '⚠️',
      accentColor: Color(0xFFB98040),
      entryMotion: TarotEntryMotion.crackWarning,
      topicKey: 'wealth',
      popularityScore: 46,
    ),
    TarotCategoryMeta(
      id: 'wealth_solution_hint',
      group: TarotCategoryGroup.wealth,
      label: '금전 문제 해결 힌트',
      moodCopy: '막힌 곳을 푸는 실마리',
      emoji: '🔑',
      accentColor: TarotColors.groupWealth,
      entryMotion: TarotEntryMotion.lockOpen,
      topicKey: 'wealth',
      popularityScore: 49,
    ),
    TarotCategoryMeta(
      id: 'wealth_asset_direction',
      group: TarotCategoryGroup.wealth,
      label: '자산의 방향',
      moodCopy: '가진 것을 어디로 옮길까',
      emoji: '📦',
      accentColor: Color(0xFFC89550),
      entryMotion: TarotEntryMotion.boxOpen,
      topicKey: 'wealth',
      isNew: true,
      popularityScore: 42,
    ),
    TarotCategoryMeta(
      id: 'wealth_harvest_timing',
      group: TarotCategoryGroup.wealth,
      label: '수확의 시기',
      moodCopy: '결실이 맺히는 때',
      emoji: '🌾',
      accentColor: TarotColors.groupWealth,
      entryMotion: TarotEntryMotion.grainDrift,
      topicKey: 'wealth',
      isNew: true,
      popularityScore: 40,
    ),

    // ── 그룹 D: 일상/운세 (10개) ──
    TarotCategoryMeta(
      id: 'daily_today_tarot',
      group: TarotCategoryGroup.daily,
      label: '오늘의 타로',
      moodCopy: '오늘, 카드가 건네는 한마디',
      emoji: '☀️',
      accentColor: TarotColors.groupDaily,
      entryMotion: TarotEntryMotion.sunBurst,
      topicKey: 'today',
      popularityScore: 100,
    ),
    TarotCategoryMeta(
      id: 'daily_this_week',
      group: TarotCategoryGroup.daily,
      label: '이번 주 흐름',
      moodCopy: '일주일의 결을 미리 봐요',
      emoji: '📆',
      accentColor: Color(0xFFA5B4D8),
      entryMotion: TarotEntryMotion.weekPageGlow,
      topicKey: 'today',
      popularityScore: 78,
    ),
    TarotCategoryMeta(
      id: 'daily_this_month',
      group: TarotCategoryGroup.daily,
      label: '이번 달 흐름',
      moodCopy: '달이 차오르는 한 달의 흐름',
      emoji: '🌕',
      accentColor: TarotColors.groupDaily,
      entryMotion: TarotEntryMotion.moonExpand,
      topicKey: 'today',
      popularityScore: 70,
    ),
    TarotCategoryMeta(
      id: 'daily_this_year',
      group: TarotCategoryGroup.daily,
      label: '올해의 흐름',
      moodCopy: '한 해를 관통하는 메시지',
      emoji: '🎆',
      accentColor: Color(0xFF9AACD0),
      entryMotion: TarotEntryMotion.constellationBurst,
      topicKey: 'today',
      popularityScore: 65,
    ),
    TarotCategoryMeta(
      id: 'daily_message_needed_now',
      group: TarotCategoryGroup.daily,
      label: '지금 필요한 메시지',
      moodCopy: '지금 당신에게 필요한 말',
      emoji: '💬',
      accentColor: TarotColors.groupDaily,
      entryMotion: TarotEntryMotion.whisperSpread,
      topicKey: 'general',
      popularityScore: 72,
    ),
    TarotCategoryMeta(
      id: 'daily_things_to_watch',
      group: TarotCategoryGroup.daily,
      label: '조심할 일',
      moodCopy: '미리 알면 피할 수 있어요',
      emoji: '🛡️',
      accentColor: Color(0xFF8FA0C8),
      entryMotion: TarotEntryMotion.shieldBeam,
      topicKey: 'general',
      popularityScore: 55,
    ),
    TarotCategoryMeta(
      id: 'daily_luck_point',
      group: TarotCategoryGroup.daily,
      label: '행운 포인트',
      moodCopy: '오늘의 행운이 숨은 곳',
      emoji: '🍀',
      accentColor: TarotColors.groupDaily,
      entryMotion: TarotEntryMotion.cloverSpark,
      topicKey: 'general',
      popularityScore: 68,
    ),
    TarotCategoryMeta(
      id: 'daily_direction_of_choice',
      group: TarotCategoryGroup.daily,
      label: '선택의 방향',
      moodCopy: '두 갈래 길 중 어디로',
      emoji: '🧭',
      accentColor: Color(0xFFA5B4D8),
      entryMotion: TarotEntryMotion.forkBeam,
      topicKey: 'choice',
      popularityScore: 62,
    ),
    TarotCategoryMeta(
      id: 'daily_tomorrow_feeling',
      group: TarotCategoryGroup.daily,
      label: '내일의 예감',
      moodCopy: '하루 앞서 마음을 준비해요',
      emoji: '🌤️',
      accentColor: TarotColors.groupDaily,
      entryMotion: TarotEntryMotion.dawnGradient,
      topicKey: 'today',
      isNew: true,
      popularityScore: 44,
    ),
    TarotCategoryMeta(
      id: 'daily_quarterly_flow',
      group: TarotCategoryGroup.daily,
      label: '분기의 흐름',
      moodCopy: '석 달의 결을 미리 짚어요',
      emoji: '🗓️',
      accentColor: Color(0xFF9AACD0),
      entryMotion: TarotEntryMotion.seasonBeam,
      topicKey: 'today',
      isNew: true,
      popularityScore: 38,
    ),

    // ── 그룹 E: 감정/내면 (10개) ──
    TarotCategoryMeta(
      id: 'emotion_current_heart',
      group: TarotCategoryGroup.emotion,
      label: '지금 내 마음',
      moodCopy: '지금 내 안에 흐르는 것',
      emoji: '🕯️',
      accentColor: TarotColors.groupEmotion,
      entryMotion: TarotEntryMotion.candleFlicker,
      topicKey: 'general',
      popularityScore: 77,
    ),
    TarotCategoryMeta(
      id: 'emotion_anxiety_root',
      group: TarotCategoryGroup.emotion,
      label: '불안의 원인',
      moodCopy: '흐릿한 마음의 뿌리를 봐요',
      emoji: '🌫️',
      accentColor: Color(0xFFB89AD0),
      entryMotion: TarotEntryMotion.fogLift,
      topicKey: 'general',
      popularityScore: 64,
    ),
    TarotCategoryMeta(
      id: 'emotion_need_comfort',
      group: TarotCategoryGroup.emotion,
      label: '위로가 필요한 순간',
      moodCopy: '잠시, 마음을 내려놓아요',
      emoji: '🤲',
      accentColor: TarotColors.groupEmotion,
      entryMotion: TarotEntryMotion.waveSpread,
      topicKey: 'general',
      popularityScore: 73,
    ),
    TarotCategoryMeta(
      id: 'emotion_to_let_go',
      group: TarotCategoryGroup.emotion,
      label: '놓아야 할 감정',
      moodCopy: '이제는 흘려보낼 것들',
      emoji: '🍃',
      accentColor: Color(0xFFA88FC0),
      entryMotion: TarotEntryMotion.leafDrift,
      topicKey: 'general',
      popularityScore: 56,
    ),
    TarotCategoryMeta(
      id: 'emotion_can_i_restart',
      group: TarotCategoryGroup.emotion,
      label: '다시 시작할 수 있을까',
      moodCopy: '다시 피어날 자리를 찾아요',
      emoji: '🌱',
      accentColor: TarotColors.groupEmotion,
      entryMotion: TarotEntryMotion.sproutRise,
      topicKey: 'general',
      popularityScore: 60,
    ),
    TarotCategoryMeta(
      id: 'emotion_advice_for_myself',
      group: TarotCategoryGroup.emotion,
      label: '나를 위한 조언',
      moodCopy: '스스로에게 건네는 말',
      emoji: '🪞',
      accentColor: Color(0xFFB89AD0),
      entryMotion: TarotEntryMotion.mirrorGlow,
      topicKey: 'general',
      popularityScore: 66,
    ),
    TarotCategoryMeta(
      id: 'emotion_hidden_talent',
      group: TarotCategoryGroup.emotion,
      label: '숨은 재능',
      moodCopy: '아직 발견되지 않은 것',
      emoji: '💎',
      accentColor: TarotColors.groupEmotion,
      entryMotion: TarotEntryMotion.gemSparkle,
      topicKey: 'general',
      popularityScore: 52,
    ),
    TarotCategoryMeta(
      id: 'emotion_inner_growth',
      group: TarotCategoryGroup.emotion,
      label: '내면 성장 메시지',
      moodCopy: '지금의 나를 키우는 말',
      emoji: '🌿',
      accentColor: Color(0xFFA88FC0),
      entryMotion: TarotEntryMotion.treeRise,
      topicKey: 'general',
      popularityScore: 48,
    ),
    TarotCategoryMeta(
      id: 'emotion_wave',
      group: TarotCategoryGroup.emotion,
      label: '감정의 파동',
      moodCopy: '지금 마음이 흔들리는 결',
      emoji: '🫧',
      accentColor: TarotColors.groupEmotion,
      entryMotion: TarotEntryMotion.rippleRing,
      topicKey: 'general',
      isNew: true,
      popularityScore: 40,
    ),
    TarotCategoryMeta(
      id: 'emotion_time_lag',
      group: TarotCategoryGroup.emotion,
      label: '마음의 시차',
      moodCopy: '지금 마음이 머무는 시간',
      emoji: '🕰️',
      accentColor: Color(0xFFB89AD0),
      entryMotion: TarotEntryMotion.clockReverse,
      topicKey: 'general',
      isNew: true,
      popularityScore: 36,
    ),

    // ── 그룹 F: 특별 테마 (10개) ──
    TarotCategoryMeta(
      id: 'special_soul_card',
      group: TarotCategoryGroup.special,
      label: '소울 카드',
      moodCopy: '당신의 영혼과 닿은 카드',
      emoji: '🃏',
      accentColor: TarotColors.groupSpecial,
      entryMotion: TarotEntryMotion.cardFlipZoom,
      topicKey: 'general',
      isPremium: true,
      popularityScore: 69,
    ),
    TarotCategoryMeta(
      id: 'special_destiny_card',
      group: TarotCategoryGroup.special,
      label: '운명의 카드',
      moodCopy: '오늘 당신을 찾아온 카드',
      emoji: '⚜️',
      accentColor: TarotColors.groupSpecialNavy,
      entryMotion: TarotEntryMotion.symbolSpin,
      topicKey: 'general',
      isPremium: true,
      popularityScore: 71,
    ),
    TarotCategoryMeta(
      id: 'special_dawn_tarot',
      group: TarotCategoryGroup.special,
      label: '새벽 타로',
      moodCopy: '가장 조용한 시간의 메시지',
      emoji: '🌌',
      accentColor: Color(0xFF2A2A50),
      entryMotion: TarotEntryMotion.dawnBrighten,
      topicKey: 'today',
      isPremium: true,
      popularityScore: 47,
    ),
    TarotCategoryMeta(
      id: 'special_full_moon_tarot',
      group: TarotCategoryGroup.special,
      label: '보름달 타로',
      moodCopy: '달이 가장 밝은 밤의 리딩',
      emoji: '🌕',
      accentColor: Color(0xFF4A3A70),
      entryMotion: TarotEntryMotion.fullMoonExpand,
      topicKey: 'today',
      isPremium: true,
      popularityScore: 53,
    ),
    TarotCategoryMeta(
      id: 'special_wish_tarot',
      group: TarotCategoryGroup.special,
      label: '소원 타로',
      moodCopy: '마음속 소원을 비춰봐요',
      emoji: '⭐',
      accentColor: TarotColors.groupSpecial,
      entryMotion: TarotEntryMotion.starConverge,
      topicKey: 'general',
      isPremium: true,
      popularityScore: 61,
    ),
    TarotCategoryMeta(
      id: 'special_lucky_door_tarot',
      group: TarotCategoryGroup.special,
      label: '행운의 문 타로',
      moodCopy: '열리는 문 너머의 기운',
      emoji: '🚪',
      accentColor: TarotColors.groupSpecialNavy,
      entryMotion: TarotEntryMotion.doorBeam,
      topicKey: 'general',
      isPremium: true,
      popularityScore: 45,
    ),
    TarotCategoryMeta(
      id: 'special_maze_of_fate_tarot',
      group: TarotCategoryGroup.special,
      label: '인연의 미로 타로',
      moodCopy: '얽힌 인연의 길을 찾아요',
      emoji: '🧵',
      accentColor: TarotColors.groupSpecial,
      entryMotion: TarotEntryMotion.mazeLine,
      topicKey: 'love',
      isPremium: true,
      popularityScore: 43,
    ),
    TarotCategoryMeta(
      id: 'special_secret_garden_tarot',
      group: TarotCategoryGroup.special,
      label: '비밀 정원 타로',
      moodCopy: '숨겨진 정원에서 듣는 말',
      emoji: '🏵️',
      accentColor: Color(0xFF4A3A70),
      entryMotion: TarotEntryMotion.vineDrift,
      topicKey: 'general',
      isPremium: true,
      popularityScore: 39,
    ),
    TarotCategoryMeta(
      id: 'special_guardian_star_tarot',
      group: TarotCategoryGroup.special,
      label: '별자리 수호 타로',
      moodCopy: '당신을 지키는 별의 메시지',
      emoji: '🦢',
      accentColor: Color(0xFF2A2A50),
      entryMotion: TarotEntryMotion.constellationConnect,
      topicKey: 'general',
      isPremium: true,
      isNew: true,
      popularityScore: 41,
    ),
    TarotCategoryMeta(
      id: 'special_midnight_vow_tarot',
      group: TarotCategoryGroup.special,
      label: '자정의 서약 타로',
      moodCopy: '하루의 끝, 스스로에게 묻는 말',
      emoji: '🕯️',
      accentColor: TarotColors.groupSpecialNavy,
      entryMotion: TarotEntryMotion.candleSpread,
      topicKey: 'general',
      isPremium: true,
      isNew: true,
      popularityScore: 37,
    ),
  ];

  static List<TarotCategoryMeta> byGroup(TarotCategoryGroup group) =>
      all.where((c) => c.group == group).toList();

  static List<TarotCategoryMeta> popular({int take = 6}) {
    final sorted = List<TarotCategoryMeta>.from(all)
      ..sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
    return sorted.take(take).toList();
  }

  static List<TarotCategoryMeta> newest({int take = 8}) =>
      all.where((c) => c.isNew).take(take).toList();

  static List<TarotCategoryMeta> premium({int take = 10}) =>
      all.where((c) => c.isPremium).take(take).toList();

  static TarotCategoryMeta? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  static int get totalCount => all.length;
}
