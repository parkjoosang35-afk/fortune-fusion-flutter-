/// [타로 섹션 전면 개편 §2 정보구조 ⑦ / §8 결과화면 콘텐츠 구조]
///
/// 결과화면의 "히어로 / 총평 / 7섹션 / 5액션" 구조를 데이터로 명시하는
/// 뷰모델. 기존 [TarotResultScreen]은 [TarotResultModel] + [TarotReadingExtras]
/// 파생값(한줄운세/조언/행운색/행운숫자/AI한마디)을 화면 위젯 트리 안에서
/// 직접 계산했는데, 이 계산을 이 파일로 옮겨 "결과 콘텐츠"를 하나의 값
/// 객체로 캡슐화한다. §11 P4에서 만들 공유용 결과카드(⑩)/심화해석 화면이
/// 동일한 [TarotResultView]를 재사용할 수 있게 하기 위한 선행 작업이다
/// (신규 계산 로직을 추가하지 않고, 기존 [TarotReadingExtras]를 그대로
/// 감싸는 방식 - 과설계 방지).
library;

import 'package:flutter/material.dart';
import 'tarot_category_model.dart';
import 'tarot_model.dart';
import 'tarot_reading_extras.dart';

/// §8 "결과보기" 7섹션 각각의 종류. 화면(리스트 렌더링)과 향후 공유카드
/// (요약 렌더링)가 동일한 타입 집합을 참조해 "7섹션"이라는 개념을 코드
/// 레벨에서도 명시적으로 고정한다.
enum TarotResultSectionType {
  cardName, // ① 카드 이름
  oneLiner, // ② 한 줄 운세
  aiReading, // (총평 - 서버 summary 전문)
  positions, // ③ 상세 리딩(포지션별)
  advice, // ④ 오늘의 조언
  luckyPair, // ⑤+⑥ 행운의 색 / 행운의 숫자
  aiClosing, // ⑦ AI 한마디
}

/// 섹션 1개의 메타데이터(아이콘/라벨). 실제 콘텐츠 값은 [TarotResultView]
/// 최상위 필드에 이미 계산되어 있으므로, 이 클래스는 렌더링 순서와 표시용
/// 아이콘/라벨만 담는 경량 값 객체다.
@immutable
class TarotResultSection {
  final TarotResultSectionType type;
  final String icon;
  final String label;
  const TarotResultSection({
    required this.type,
    required this.icon,
    required this.label,
  });
}

/// §8 결과화면 콘텐츠 구조 전체(히어로 카드 + 총평 + 7섹션)를 담는 뷰모델.
/// [TarotResultModel](서버 원본 응답)을 감싸며, [fromResult] 팩토리가
/// [TarotReadingExtras]의 결정론적 파생값 계산을 한 번에 수행한다.
@immutable
class TarotResultView {
  final TarotResultModel result;
  final TarotCard heroCard;
  final String oneLiner;
  final String advice;
  final String aiClosing;
  final String luckyColorName;
  final Color luckyColor;
  final int luckyNumber;
  final List<TarotResultSection> sections;

  /// [§11 P4] "내 운세 기록"/공유카드에 표시할 점수(62~97). 저장/공유
  /// 기능이 이 하나의 값만 참조하면 되도록 뷰모델 레벨에서 계산해둔다.
  final int score;

  /// [65종 타로 리딩엔진 §계획3 - 결과화면 7섹션 제목 동적화] 이 리딩이
  /// 65개 주제 중 하나에 속할 때(`TarotCategoryData.byId`로 찾아짐),
  /// "AI 리딩"/"오늘의 조언" 섹션 제목에 주제명을 붙여 65개 리딩이 각자
  /// 다른 화면처럼 느껴지게 한다. 매칭되지 않으면(레거시 general/love 등)
  /// 기존 고정 문구를 그대로 사용해 회귀를 방지한다.
  final String aiReadingLabel;
  final String adviceLabel;

  const TarotResultView({
    required this.result,
    required this.heroCard,
    required this.oneLiner,
    required this.advice,
    required this.aiClosing,
    required this.luckyColorName,
    required this.luckyColor,
    required this.luckyNumber,
    required this.sections,
    required this.score,
    required this.aiReadingLabel,
    required this.adviceLabel,
  });

  /// [§11 P4] "내 운세 기록" 저장 시 표시할 제목. 카드 이름 + 스프레드
  /// 종류를 조합해 히스토리 목록에서도 어떤 리딩이었는지 바로 알 수 있게 한다.
  String get saveTitle =>
      '${heroCard.nameKr} · ${_spreadLabel(result.spreadType)}';

  static String _spreadLabel(String spreadType) {
    switch (spreadType) {
      // [65종 타로 리딩엔진 §계획3] 5카드 라벨 추가(기존엔 default로
      // '원카드'라고 잘못 표시되는 버그가 있었다).
      case 'five_card':
        return '파이브카드';
      case 'three_card':
        return '쓰리카드';
      case 'yes_no':
        return 'YES/NO';
      case 'choice_ab':
        return 'A/B 비교';
      default:
        return '원카드';
    }
  }

  /// §8에서 고정된 7섹션 순서. 화면/공유카드 어디서든 이 상수를 그대로
  /// 참조해 순서가 어긋나지 않게 한다.
  static const List<TarotResultSection> defaultSections = [
    TarotResultSection(
      type: TarotResultSectionType.cardName,
      icon: '🃏',
      label: '카드',
    ),
    TarotResultSection(
      type: TarotResultSectionType.oneLiner,
      icon: '💫',
      label: '한 줄 운세',
    ),
    TarotResultSection(
      type: TarotResultSectionType.aiReading,
      icon: '🔮',
      label: 'AI 리딩',
    ),
    TarotResultSection(
      type: TarotResultSectionType.positions,
      icon: '🗺️',
      label: '상세 리딩',
    ),
    TarotResultSection(
      type: TarotResultSectionType.advice,
      icon: '🧭',
      label: '오늘의 조언',
    ),
    TarotResultSection(
      type: TarotResultSectionType.luckyPair,
      icon: '🍀',
      label: '행운의 색 · 숫자',
    ),
    TarotResultSection(
      type: TarotResultSectionType.aiClosing,
      icon: '🌙',
      label: 'AI 한마디',
    ),
  ];

  factory TarotResultView.fromResult(TarotResultModel result) {
    final heroCard = result.positions.first.card;
    final lucky = TarotReadingExtras.luckyColor(result.id);
    // [65종 타로 리딩엔진 §계획3] 서버가 응답에 실어준 topic(카테고리
    // 화면에서 명시 지정했거나, §계획2 자동매칭으로 결정된 값)이 65개
    // 주제 중 하나와 일치하면 그 한글 주제명을 섹션 제목에 반영한다.
    // 매칭 실패(general/love 등 레거시)면 topicName은 null -> 기존
    // 고정 문구('AI 리딩'/'오늘의 조언')를 그대로 사용한다.
    final topicName = TarotCategoryData.byId(result.topic)?.label;
    return TarotResultView(
      result: result,
      heroCard: heroCard,
      oneLiner: TarotReadingExtras.oneLiner(result.summary),
      advice: TarotReadingExtras.advice(result.id, result.topic),
      aiClosing: TarotReadingExtras.aiClosing(result.id),
      luckyColorName: lucky.name,
      luckyColor: lucky.color,
      luckyNumber: TarotReadingExtras.luckyNumber(result.id),
      sections: defaultSections,
      score: TarotReadingExtras.readingScore(result.id),
      aiReadingLabel: topicName != null ? '$topicName AI 리딩' : 'AI 리딩',
      adviceLabel: topicName != null ? '$topicName 조언' : '오늘의 조언',
    );
  }
}

/// §8 "5액션"(결과화면 하단 액션 바) - 다시 뽑기 / 저장하기 / 공유하기 /
/// 심화해석 / 히스토리. 각 액션의 처리 로직은 화면(State)에 두고, 이
/// enum은 액션 바를 데이터 기반으로 렌더링하기 위한 식별자 + 표시 정보만
/// 담는다.
enum TarotResultAction { history, redraw, save, share, deepDive }

extension TarotResultActionX on TarotResultAction {
  String get label {
    switch (this) {
      case TarotResultAction.history:
        return '히스토리';
      case TarotResultAction.redraw:
        return '다시 뽑기';
      case TarotResultAction.save:
        return '저장하기';
      case TarotResultAction.share:
        return '공유하기';
      case TarotResultAction.deepDive:
        return '심화해석';
    }
  }

  IconData get icon {
    switch (this) {
      case TarotResultAction.history:
        return Icons.history_rounded;
      case TarotResultAction.redraw:
        return Icons.refresh_rounded;
      case TarotResultAction.save:
        return Icons.bookmark_border_rounded;
      case TarotResultAction.share:
        return Icons.ios_share_rounded;
      case TarotResultAction.deepDive:
        return Icons.auto_awesome_rounded;
    }
  }
}
