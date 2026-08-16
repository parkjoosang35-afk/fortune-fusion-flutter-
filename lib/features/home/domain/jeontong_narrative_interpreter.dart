// ============================================================
// [정통사주 결과 화면 개편] 소비자용 "진솔한 이야기체" 해석 생성기.
//
// [배경] 사용자가 점신(占神) 결과 화면 스크린샷을 근거로 "결과 화면이
// 너무 어지럽고 사주를 알아볼 수 없다"고 지적했다. 원인은 두 가지였다:
//   (A) 전문 원국판(천간/지지/오행/십신 등)이 소비자용 해석보다 먼저
//       나와 화면 진입 즉시 낯선 한자·전문 용어부터 마주하게 됨.
//   (B) 정작 해석 문장 자체도 2~3문장짜리로 너무 짧아 "풀어서 알아볼"
//       수 있는 수준이 아니었음(jeontong_eighty_report_builder.dart의
//       결정론적 카테고리 메타데이터 기반 문장).
// 사용자 최종 지시(요약): "진행하고, 너무 짧지 않게 길게, 소비자의
// 핵심을 파고들고, 사주가 나오는 대로 풀이하되 좋은 결과가 나오게
// 조심스럽게, 인생 이야기도 담아서, 만세력 엔진 결과를 진실되게 마음을
// 담아 풀이" — 이 파일이 그 지시를 코드로 옮긴 결과물이다.
//
// [절대 원칙 — 재계산 금지] 이 파일은 사주를 새로 계산하지 않는다.
// 오직 이미 PHASE1~4 실계산 파이프라인
// (JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4 →
// SajuInterpreter.fullInterpretation)이 만들어낸 [SajuFullInterpretation]
// (일간/오행/십신/재물/직업/애정/건강/신살/현재대운 9종 구조화 데이터)을
// "재료"로 삼아, 여러 문단짜리 자연어 이야기로 조합·서술하는 순수 함수
// 레이어일 뿐이다. dart:core만 사용하는 가벼운 문자열 조합이므로
// jeontong_eighty_result_frame_bench_test.dart의 프레임 예산(warm≤3/
// cold≤6)에 영향을 주지 않는다.
//
// [톤 원칙]
// - 부정적·절망적 표현 금지. 신강/신약, 재다신약, 무관무인 같은 다소
//   생소하거나 얼핏 부정적으로 들릴 수 있는 판정도 "그래서 이렇게 하면
//   더 좋다"는 건설적 조언으로 반드시 마무리한다.
// - 건강(major == g) 카테고리는 절대 의학적 진단처럼 표현하지 않는다.
//   "~계통 질환 위험" 대신 "~부분을 평소에 잘 챙기면 좋다" 식의
//   생활 관리 조언 톤을 사용한다.
// - 전문 한자·용어(天乙貴人 등)는 괄호 안에 원어를 살짝 곁들이되,
//   문장의 주된 흐름은 항상 순우리말 이야기체로 유지한다.
library;

import 'jeontong_eighty_matrix.dart'
    show JeontongCategoryEntry, JeontongMajorCode;
import 'saju_interpreter.dart';

/// 여러 문단짜리 이야기체 해석을 생성하는 순수 함수 모음.
class JeontongNarrativeInterpreter {
  JeontongNarrativeInterpreter._();

  /// [interp]와 카테고리 [entry], 사용자 [name](없으면 null)을 받아
  /// 4~6개 문단으로 구성된 이야기체 해석을 반환한다.
  ///
  /// 각 문단은 이미 줄바꿈 없는 하나의 문자열(여러 문장)이며, 위젯
  /// 레이어(JeontongNarrativeCard)가 문단 사이에 시각적 여백을 넣는다.
  static List<String> paragraphs(
    SajuFullInterpretation interp,
    JeontongCategoryEntry entry, {
    String? name,
  }) {
    final honorific = _honorific(name);
    return [
      _openingParagraph(interp, honorific),
      _traitsParagraph(interp, honorific),
      _categoryParagraph(interp, entry.major, honorific),
      _luckParagraph(interp, honorific),
      _closingParagraph(interp, entry.major, honorific),
    ].where((p) => p.trim().isNotEmpty).toList(growable: false);
  }

  /// 이름이 있으면 "○○님", 없으면 "이 사주의 주인공"으로 호칭한다.
  /// 문장 맨 앞에 올 때와 문장 중간에 올 때 모두 자연스럽도록 단일
  /// 명사구로 통일한다.
  static String _honorific(String? name) {
    if (name == null || name.trim().isEmpty) return '이 사주의 주인공';
    return '$name님';
  }

  // ------------------------------------------------------------
  // 문단 1 — 오프닝: 일간(日干)을 이야기로 풀어 소개
  // ------------------------------------------------------------
  static String _openingParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final dm = interp.dayMasterAnalysis;
    final image = interp.saju.dayMaster.image;
    final gan = interp.saju.dayMaster.kr;
    final strength = interp.saju.dayMasterStrength;
    final strengthWord = strength.contains('强')
        ? '기운이 단단하고 힘이 넘치는'
        : strength.contains('中')
        ? '균형이 잘 잡힌'
        : '섬세하고 유연한';

    final weaknessNote = dm.weaknesses.isNotEmpty
        ? ' 다만 ${_joinKo(dm.weaknesses)} 같은 부분은 스스로 잘 알아채고 다스릴 줄 알면, 오히려 그것이 $honorific만의 균형 감각이 되어줄 거예요.'
        : '';

    return '$honorific의 사주를 열어보면, 그 뿌리에는 $gan($image)의 기운이 자리하고 있어요. '
        '${dm.nature} '
        '만세력으로 짚어본 이 사주는 $strengthWord 흐름을 타고났고, ${dm.personality} '
        '이런 타고난 성정은 하루아침에 만들어진 것이 아니라, 태어난 그 순간의 하늘과 땅의 기운이 $honorific 안에 그대로 새겨진 것이에요.$weaknessNote';
  }

  // ------------------------------------------------------------
  // 문단 2 — 성향: 오행 과다/부족 + 십신 우세 성향을 인생 이야기로
  // ------------------------------------------------------------
  static String _traitsParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final fe = interp.fiveElementsAnalysis;
    final tg = interp.tenGodsAnalysis;

    final buf = StringBuffer();

    if (fe.excess.isNotEmpty || fe.lack.isNotEmpty) {
      final lines = <String>[
        for (final el in fe.excess) _elementExcessPositive(el),
        for (final el in fe.lack) _elementLackPositive(el),
      ];
      buf.write(
        '오행의 흐름을 살펴보면 ${_joinKo(lines)} '
        '이런 기운의 쏠림은 좋고 나쁨을 가르는 잣대가 아니라, $honorific이 세상을 살아가는 고유한 리듬이라고 보면 돼요. ',
      );
    } else {
      buf.write(
        '오행 다섯 가지 기운이 사주 안에 비교적 고르게 자리 잡고 있어서, $honorific은 어느 한쪽으로 치우치지 않고 상황에 맞게 유연하게 대처하는 힘을 갖고 있어요. ',
      );
    }

    final dominantDetail = tg.details.isNotEmpty ? tg.details.first : null;
    if (dominantDetail != null) {
      buf.write(
        '사주 안에서 특히 도드라지는 기운은 십신 중 ${tg.dominantEasy}(${tg.dominantName})이에요. '
        '이는 ${dominantDetail.meaning} — 그래서 평소 ${dominantDetail.positive} 모습으로 자주 드러나곤 하죠. '
        '이 기운이 $honorific의 인생 곳곳에서, 사람을 대하는 태도부터 중요한 결정을 내리는 순간까지 은은하게 영향을 미치고 있을 거예요.',
      );
    }

    return buf.toString().trim();
  }

  /// 오행별 이름(예: '목'/'화'/'토'/'금'/'수')만 받아, 원본 rules JSON의
  /// "excess" 필드(질환·부정 감정 나열)를 그대로 노출하지 않고, 같은
  /// 오행이 과다할 때 나타나는 "장점이 두드러지는 방향"으로 톤을
  /// 순화해 직접 작성한 문장을 돌려준다(사용자 지시: 좋은 결과가 나오게
  /// 조심스럽게 풀이). 원본 rules JSON의 값에 의존하지 않으므로 룰 파일이
  /// 바뀌어도 항상 긍정적인 톤을 유지한다.
  static String _elementExcessPositive(String element) {
    switch (element) {
      case '목':
        return '목(木)의 기운이 풍부해서 성장하고 뻗어나가려는 힘이 강한 편이에요. 그 힘을 밖으로 잘 풀어낼 때 훨씬 편안해져요';
      case '화':
        return '화(火)의 기운이 넘쳐서 열정과 표현력이 남다른 편이에요. 다만 가끔은 속도를 늦추고 숨을 고르는 시간도 함께 가지면 좋아요';
      case '토':
        return '토(土)의 기운이 든든해서 무엇이든 품고 중심을 잡는 힘이 큰 편이에요. 가끔은 스스로를 위한 여유도 챙겨주면 더 좋아요';
      case '금':
        return '금(金)의 기운이 강해서 결단력과 원칙이 뚜렷한 편이에요. 그 예리함을 부드러운 말투로 감싸면 관계가 한결 편안해져요';
      case '수':
        return '수(水)의 기운이 깊어서 지혜롭고 사색적인 면이 두드러지는 편이에요. 생각이 많아질 때는 가까운 사람과 나누는 대화가 큰 힘이 돼요';
      default:
        return '';
    }
  }

  static String _elementLackPositive(String element) {
    switch (element) {
      case '목':
        return '목(木)의 기운은 조금 여백이 있는 편이라, 계획을 세울 때 주변 사람의 의견을 들으면 더 든든한 결정을 내릴 수 있어요';
      case '화':
        return '화(火)의 기운은 여백이 있는 편이라, 스스로를 표현하는 연습을 조금씩 해보면 관계가 한결 풍성해질 수 있어요';
      case '토':
        return '토(土)의 기운은 여백이 있는 편이라, 규칙적인 생활 리듬을 만들어가면 마음이 훨씬 안정될 수 있어요';
      case '금':
        return '금(金)의 기운은 여백이 있는 편이라, 중요한 결정을 내릴 때 조금 더 시간을 갖고 정리하면 후회가 줄어들 수 있어요';
      case '수':
        return '수(水)의 기운은 여백이 있는 편이라, 충분한 휴식과 수분 섭취처럼 몸을 아끼는 작은 습관이 큰 도움이 될 수 있어요';
      default:
        return '';
    }
  }

  // ------------------------------------------------------------
  // 문단 3 — 카테고리 관점(평생/대운/세운/오늘/궁합/특수주제/건강/개운)에
  // 맞춰 재물/직업/애정/건강 중 관련 있는 것을 자연스럽게 녹인 핵심 문단.
  // ------------------------------------------------------------
  static String _categoryParagraph(
    SajuFullInterpretation interp,
    JeontongMajorCode major,
    String honorific,
  ) {
    switch (major) {
      case JeontongMajorCode.a:
        return _lifetimeParagraph(interp, honorific);
      case JeontongMajorCode.b:
        return _daewoonParagraph(interp, honorific);
      case JeontongMajorCode.c:
        return _thisYearParagraph(interp, honorific);
      case JeontongMajorCode.d:
        return _todayParagraph(interp, honorific);
      case JeontongMajorCode.e:
        return _loveParagraph(interp, honorific);
      case JeontongMajorCode.f:
        return _topicParagraph(interp, honorific);
      case JeontongMajorCode.g:
        return _healthParagraph(interp, honorific);
      case JeontongMajorCode.h:
        return _luckyCharmParagraph(interp, honorific);
    }
  }

  static String _lifetimeParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final wealth = interp.wealthFortune;
    final career = interp.careerFortune;
    final love = interp.loveFortune;
    return '평생의 흐름이라는 큰 틀에서 보면, $honorific의 재물운은 ${_soften(_wealthNarrative(wealth, honorific))} '
        '일과 진로 쪽으로는 ${career.structure} 성향이 뚜렷해서, ${_soften(career.message)} '
        '사람과 인연을 맺는 방식에서는 ${_soften(_loveNarrative(love))} '
        '이 세 가지 흐름이 서로 맞물리며 $honorific만의 고유한 인생 그림을 그려가고 있는 거예요.';
  }

  static String _daewoonParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final luck = interp.currentLuckAnalysis;
    if (luck.message == null) {
      return '지금 이 시기에 해당하는 대운 정보는 조금 더 정밀한 계산이 필요해서, 우선은 타고난 사주의 결을 중심으로 풀이해 드렸어요.';
    }
    return '지금 $honorific이 지나고 있는 큰 흐름, 즉 대운은 ${luck.title}${luck.ageRange != null ? '(${luck.ageRange})' : ''}이에요. '
        '이 10년은 ${_soften(luck.message!)} '
        '대운은 계절이 바뀌듯 자연스럽게 찾아오는 흐름이라, 지금 이 시기의 기운을 미리 알고 준비하는 것만으로도 훨씬 여유롭게 지나갈 수 있어요.';
  }

  static String _thisYearParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final luck = interp.currentLuckAnalysis;
    final wealth = interp.wealthFortune;
    final base = luck.message != null
        ? '올해는 ${luck.title}의 큰 흐름 안에 놓여 있는 해예요. ${_soften(luck.message!)} '
        : '올해는 타고난 사주 본연의 기운이 비교적 뚜렷하게 드러나는 시기예요. ';
    return '$base'
        '특히 재물 쪽 흐름을 함께 짚어보면, ${_soften(_wealthNarrative(wealth, honorific))} '
        '한 해를 통째로 보면 잔잔한 흐름 속에서도 분명 변화의 순간들이 있을 텐데, 그 순간마다 $honorific이 원래 갖고 있던 기질대로 차분히 대응하면 좋은 결과로 이어질 가능성이 높아요.';
  }

  static String _todayParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final dm = interp.dayMasterAnalysis;
    return '가까운 오늘과 이달의 흐름은 타고난 일간의 기질이 특히 도드라지는 시점이에요. '
        '${_soften(dm.personality)} '
        '이런 날에는 큰 결정을 서두르기보다, $honorific 본연의 리듬에 맞춰 하루하루를 채워가는 편이 오히려 더 좋은 흐름을 만들어줘요. 작은 선택 하나가 며칠 뒤 뜻밖의 좋은 결과로 이어질 수 있으니, 지금 이 순간의 감각을 믿어봐도 좋아요.';
  }

  static String _loveParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final love = interp.loveFortune;
    final tg = interp.tenGodsAnalysis;
    return '인연이라는 주제로 $honorific의 사주를 들여다보면, ${_soften(_loveNarrative(love))} '
        '사주 안에서 우세한 기운인 ${tg.dominantEasy}의 성향이 관계 안에서도 그대로 드러나곤 하는데, 이는 상대방과의 궁합을 볼 때도 중요한 열쇠가 돼요. '
        '결국 좋은 인연은 억지로 맞추는 것이 아니라, $honorific 고유의 기운을 편안하게 받아줄 수 있는 상대를 만났을 때 가장 자연스럽게 이어진답니다.';
  }

  static String _topicParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final wealth = interp.wealthFortune;
    final career = interp.careerFortune;
    return '구체적인 주제로 들어가 보면, 재물 쪽으로는 ${_soften(_wealthNarrative(wealth, honorific))} '
        '진로나 직업 쪽으로는 ${career.structure} 기운이 강하게 흘러서, ${_soften(career.message)} '
        '${career.recommended.isNotEmpty ? '특히 ${_joinKo(career.recommended)} 같은 분야가 $honorific의 타고난 결과 잘 맞아떨어질 가능성이 높아요.' : ''}';
  }

  static String _healthParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final health = interp.healthFortune;
    final fe = interp.fiveElementsAnalysis;
    final organs = health.coreOrgans.isNotEmpty
        ? _joinKo(health.coreOrgans)
        : '몸 전반';
    // [오행 문단(_traitsParagraph)과 동일한 원칙] health.warnings는
    // "~계통 주의" 같은 기계적인 원본 조합 문구라 이야기체 흐름과
    // 어울리지 않는다. 대신 fe.excess/fe.lack(오행 이름만)을 받아
    // 완전히 새로 쓴 생활 관리 톤의 자연어 문장으로 교체한다.
    final careLines = <String>[
      for (final el in fe.excess) _elementHealthCareNote(el, isExcess: true),
      for (final el in fe.lack) _elementHealthCareNote(el, isExcess: false),
    ]..removeWhere((s) => s.isEmpty);
    final careNote = careLines.isNotEmpty ? '${_joinKo(careLines)}. ' : '';
    final foodNote = health.recommendedFood.isNotEmpty
        ? '${_joinKo(health.recommendedFood)} 같은 음식을 가까이하면 몸의 균형을 잡는 데 도움이 될 거예요. '
        : '';
    return '체질과 건강이라는 주제에서는, $honorific의 사주가 타고난 기운상 $organs 쪽 흐름과 특히 인연이 깊어요. '
        '$careNote'
        '이건 의학적인 진단이 아니라, 오래전부터 전해온 명리 체질론에 근거한 생활 속 참고일 뿐이니 너무 무겁게 받아들이지 않아도 돼요. '
        '$foodNote'
        '몸을 아끼는 마음으로 평소 컨디션을 살피는 습관만 들여도, 타고난 체질의 균형이 한결 편안해질 거예요.';
  }

  /// 오행별로 "과다(isExcess=true)" 또는 "여백(isExcess=false)"일 때의
  /// 건강 관리 조언을 완전히 새로 쓴 문장으로 돌려준다. rules JSON의
  /// excess/lack 필드(질환·부정 감정 나열)는 절대 참조하지 않는다.
  static String _elementHealthCareNote(
    String element, {
    required bool isExcess,
  }) {
    if (isExcess) {
      switch (element) {
        case '목':
          return '목(木)의 기운이 두드러진 편이라 간과 눈 쪽에 피로가 쌓이기 쉬우니, 틈틈이 눈을 쉬어주고 가볍게 몸을 풀어주면 한결 편안해져요';
        case '화':
          return '화(火)의 기운이 활발한 편이라 심장과 혈액 순환에 신경을 쓰면 좋은데, 카페인을 조금 줄이고 충분한 수면을 챙기는 것만으로도 큰 도움이 돼요';
        case '토':
          return '토(土)의 기운이 두터운 편이라 소화기 쪽 컨디션을 살피면 좋고, 규칙적인 식사 시간을 지키는 습관이 몸의 균형을 잡아줘요';
        case '금':
          return '금(金)의 기운이 강한 편이라 호흡기와 피부 건강을 틈틈이 챙기면 좋고, 건조한 계절에는 수분 보충에 조금 더 신경 쓰면 편안해져요';
        case '수':
          return '수(水)의 기운이 깊은 편이라 신장과 방광 쪽 컨디션을 살피면 좋고, 몸을 따뜻하게 유지하는 습관이 활력을 지켜줘요';
        default:
          return '';
      }
    } else {
      switch (element) {
        case '목':
          return '목(木)의 기운이 다소 여백이 있는 편이라 근육과 관절이 뻣뻣해지기 쉬우니, 가벼운 산책이나 스트레칭을 꾸준히 하면 몸이 한결 가벼워져요';
        case '화':
          return '화(火)의 기운이 다소 여백이 있는 편이라 손발이 차거나 기운이 처지기 쉬우니, 따뜻한 차 한 잔과 햇볕을 쬐는 시간이 활력을 북돋아 줘요';
        case '토':
          return '토(土)의 기운이 다소 여백이 있는 편이라 소화 기능이 예민할 수 있으니, 자극적인 음식을 조금 줄이고 천천히 식사하는 습관이 도움이 돼요';
        case '금':
          return '금(金)의 기운이 다소 여백이 있는 편이라 호흡기가 예민할 수 있으니, 실내 환기를 자주 하고 미세먼지 관리에 신경 쓰면 좋아요';
        case '수':
          return '수(水)의 기운이 다소 여백이 있는 편이라 체력이 쉽게 떨어질 수 있으니, 무리하지 않는 선에서 꾸준히 체력을 기르는 습관이 큰 힘이 돼요';
        default:
          return '';
      }
    }
  }

  static String _luckyCharmParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final fe = interp.fiveElementsAnalysis;
    final colors = fe.recommendedColor.isNotEmpty
        ? _joinKo(fe.recommendedColor)
        : '차분한 색';
    return '개운이라는 관점에서 보면, $honorific의 타고난 기운을 가장 잘 북돋아 주는 색은 $colors 계열이고, 방향으로는 ${fe.recommendedDirection} 쪽 기운이 잘 맞아요. '
        '거창한 것이 아니어도, 즐겨 입는 옷이나 방 안의 작은 소품 하나를 이 기운에 맞춰보는 것만으로도 마음이 한결 편안해지는 걸 느낄 수 있을 거예요. '
        '결국 개운이라는 건 없던 복을 억지로 만드는 게 아니라, $honorific이 원래 갖고 있던 좋은 기운이 더 잘 흐르도록 살짝 물꼬를 터주는 일이에요.';
  }

  // ------------------------------------------------------------
  // 문단 4 — 신살 + 현재 대운을 인생 이야기로 녹인 조언 문단
  // ------------------------------------------------------------
  static String _luckParagraph(
    SajuFullInterpretation interp,
    String honorific,
  ) {
    final sinsal = interp.sinsalAnalysis.list;
    if (sinsal.isEmpty) return '';
    final lines = sinsal
        .map((s) => '${_sinsalEasyName(s.name)}의 기운도 함께 갖고 계셔서, ${s.meaning}')
        .toList();
    return '여기에 더해 $honorific의 사주에는 특별한 기운도 함께 자리하고 있어요. ${_joinKo(lines)} '
        '이런 기운들은 평소에는 잘 드러나지 않다가도, 정말 중요한 순간에 $honorific을 슬며시 도와주는 힘으로 작용하곤 해요.';
  }

  static String _sinsalEasyName(String raw) {
    // "天乙貴人(천을귀인)" → "천을귀인" 처럼 괄호 안 한글만 뽑아 우선
    // 노출하고, 원어는 자연스럽게 뒤에 남겨둔다.
    final start = raw.indexOf('(');
    final end = raw.indexOf(')');
    if (start != -1 && end != -1 && end > start) {
      return raw.substring(start + 1, end);
    }
    return raw;
  }

  // ------------------------------------------------------------
  // 문단 5 — 마무리: 카테고리 성격에 맞춘 다정한 격려
  // ------------------------------------------------------------
  static String _closingParagraph(
    SajuFullInterpretation interp,
    JeontongMajorCode major,
    String honorific,
  ) {
    final periodWord = switch (major) {
      JeontongMajorCode.a => '평생이라는 긴 여정',
      JeontongMajorCode.b => '앞으로의 10년',
      JeontongMajorCode.c => '올 한 해',
      JeontongMajorCode.d => '오늘과 이달',
      JeontongMajorCode.e => '앞으로 맺어갈 인연',
      JeontongMajorCode.f => '지금 마주한 이 고민',
      JeontongMajorCode.g => '앞으로의 몸과 마음',
      JeontongMajorCode.h => '앞으로 채워갈 하루하루',
    };
    return '사주는 정해진 운명을 통보하는 것이 아니라, $honorific이 타고난 결을 미리 알고 $periodWord을 더 지혜롭게 채워가라는 하나의 나침반이에요. '
        '오늘 이 풀이에 담긴 이야기들을 마음 한쪽에 잘 담아두었다가, 중요한 갈림길에 설 때마다 슬쩍 꺼내 보세요. '
        '만세력이 짚어준 $honorific의 사주는 이미 좋은 가능성을 충분히 품고 있으니, 그 가능성을 믿고 한 걸음씩 나아가면 분명 원하는 방향으로 흘러갈 거예요.';
  }

  // ------------------------------------------------------------
  // 공통 유틸 — 목록을 자연스러운 한국어 나열 문장으로, 표현 순화
  // ------------------------------------------------------------
  static String _joinKo(List<String> items) {
    final cleaned = items.where((e) => e.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return '';
    if (cleaned.length == 1) return cleaned.first;
    return '${cleaned.sublist(0, cleaned.length - 1).join(', ')}, 그리고 ${cleaned.last}';
  }

  /// 원본 message 문구 중 다소 딱딱하거나 경고성으로 들릴 수 있는
  /// 표현을 부드럽게 다듬는다(원본 의미는 유지, 톤만 순화).
  static String _soften(String raw) {
    var s = raw;
    const replacements = {
      '주의': '조금만 신경 쓰면 좋아요',
      '위험': '변수',
      '삼가': '천천히 살펴보',
      '조심': '신중하게 접근',
    };
    replacements.forEach((from, to) {
      s = s.replaceAll(from, to);
    });
    return s;
  }

  static String _wealthNarrative(
    WealthInterpretation wealth,
    String honorific,
  ) {
    // verdict별 "이야기체 재해석" — 원본 message는 다소 직설적인 진단문
    // 톤이라 그대로 노출하지 않고, 같은 의미를 더 다정하고 건설적인
    // 인생 조언 톤으로 다시 풀어쓴다(사용자 지시: "좋은 결과가 나오게
    // 조심해야 한 것도").
    switch (wealth.verdict) {
      case '재다신약':
        return '돈이 들어올 기회 자체는 꽤 많이 열려 있는 사주예요. 다만 그 기회를 한 번에 크게 움켜쥐려 하기보다, 신뢰할 수 있는 사람과 함께 나누어 관리하는 방식이 훨씬 안정적으로 재물을 지키는 길이 돼요.';
      case '재왕신강':
        return '재물운이 상당히 든든하게 자리 잡은 사주예요. 사업이든 투자든 스스로 판을 벌이고 이끌어가는 영역에서 특히 힘을 발휘할 수 있으니, 지금 가진 활동력과 야망을 적극적으로 펼쳐봐도 좋은 시기예요.';
      case '무재격':
        return '눈앞의 큰돈보다는 명예와 전문성, 배움을 통해 차곡차곡 가치를 쌓아가는 흐름이 훨씬 잘 맞는 사주예요. 조급하게 사업을 벌이기보다 자기만의 전문 영역을 다지면, 시간이 지날수록 오히려 더 단단한 결실을 맺을 거예요.';
      case '신강용재':
        return '들어온 재물을 스스로 잘 감당하고 불려나갈 힘을 갖춘 사주예요. 매달 꾸준히 모으는 안정적인 저축과, 여유 자금으로 도전해보는 투자를 균형 있게 병행하면 재물이 차분히 쌓여가는 걸 느낄 수 있을 거예요.';
      case '재약신약':
        return '큰돈을 좇기보다 꾸준하고 안정적인 소득 흐름을 만드는 편이 $honorific에게 훨씬 마음 편한 길이에요. 현금성 자산을 중심으로 차근차근 기반을 다지면, 오히려 그 안정감이 다른 모든 일에 든든한 밑거름이 되어줘요.';
      default:
        return wealth.message;
    }
  }

  static String _loveNarrative(LoveInterpretation love) {
    if (love.count == 0) {
      return '인연이 조금 늦게 찾아오는 흐름일 수 있지만, 그만큼 한 번 맺어진 인연은 깊고 진지하게 이어질 가능성이 높아요. 서두르지 않고 스스로를 먼저 채워가다 보면 자연스러운 때에 좋은 인연이 다가올 거예요.';
    } else if (love.count == 1) {
      return '한 사람과 정성껏 깊은 관계를 맺는 결이 뚜렷한 사주예요. 인연이 시작되면 오래도록 안정적으로 이어가는 힘이 있으니, 지금 곁에 있는(혹은 다가올) 인연을 소중히 가꿔가면 좋아요.';
    } else if (love.count == 2) {
      return '주변에 사람이 모여드는 매력이 있어 이성 인연이 비교적 활발한 편이에요. 다만 마음을 정하는 순간에는 조금 더 신중하게, 스스로의 진심을 찬찬히 들여다보고 결정하면 후회 없는 선택을 할 수 있어요.';
    }
    return '사람을 끌어당기는 인연의 기운이 풍부한 사주예요. 다양한 만남 속에서 자칫 마음이 흔들릴 수 있지만, 그럴수록 자신의 중심을 잘 잡고 한 사람에게 진심을 다하면 훨씬 깊고 만족스러운 관계로 이어질 거예요.';
  }
}
