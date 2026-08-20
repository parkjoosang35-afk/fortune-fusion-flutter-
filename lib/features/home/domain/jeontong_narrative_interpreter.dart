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
  /// "핵심해석" 1개 문단(+ 행동지침이 있을 때만 1개 문단 추가, 총 1~2개
  /// 문단)으로 구성된 이야기체 해석을 반환한다.
  ///
  /// [data]는 [runJeontongCategory](jeontong_eighty_calculator.dart)가 이미
  /// 계산해둔 이 소카테고리 전용 결과 맵(예: A07이면 child_god/count,
  /// G05면 foods_to_limit)이다. 이 값이 있으면 [_categoryParagraph]가
  /// `entry.id` 단위로 실제 계산된 값을 문장에 반영해, 같은 대카테고리
  /// (major) 안의 여러 소카테고리가 서로 다른 진짜 내용을 이야기하게
  /// 한다("올해 건강운을 보면 건강 얘기가 나와야지, 다른 것도 마찬가지"
  /// 사용자 지시). [data]가 없으면(예: 방어적 호출) 기존 major 단위
  /// 공통 문단으로 안전하게 폴백한다 — 새로 계산하지 않는다.
  ///
  /// [2026-08-21 공통 문단 3종 제거 — 사용자 재지적: "b그룹부터 전체 다
  /// 나오는 얘기 같은데 이렇게 하면 소비자가 뭐라고 하겠어" · 확정
  /// 지시(선택지 1) "B~H그룹 70종 전체에 한 번에 적용"] 기존엔 이 문단
  /// 뒤에 오프닝(일간, `_openingParagraph`)·성향(오행/십신,
  /// `_traitsParagraph`)·신살(`_luckParagraph`) 3개 문단이 항상 따라붙었다.
  /// 이 3개는 카테고리와 무관하게 "같은 사주 주인공"이라는 이유만으로
  /// 70종 어디서나 거의 동일한 문구(§9 금지 문구 "사주 뿌리부터"/
  /// "오행의 흐름을"/"여기에 더해" 포함)를 반복 생성해, 재물운을 봐도
  /// 전환점운을 봐도 직업운을 봐도 "다 같은 말"로 읽히는 근본 원인이었다.
  /// 계산 로직은 전혀 바꾸지 않고(§2/§7), 카테고리마다 실제로 달라지는
  /// 유일한 문단인 [_categoryParagraph]("핵심해석")만 남기고, 그 아래에는
  /// 이미 각 카테고리 계산이 산출해 둔 advice/message를 재료로 하는 짧은
  /// 행동지침 한 줄([_closingActionSentence], §9 금지 문구 없는 기존
  /// 로직 재사용)만 있을 때만 덧붙인다. 행동지침 재료가 없으면 핵심해석
  /// 한 문단만 보여준다 — 모든 카테고리에서 항상 똑같이 뜨던 3개 문단은
  /// 완전히 제거한다.
  static List<String> paragraphs(
    SajuFullInterpretation interp,
    JeontongCategoryEntry entry, {
    String? name,
    Map<String, dynamic>? data,
  }) {
    final honorific = _honorific(name);
    final core = _categoryParagraph(interp, entry, honorific, data);
    // [2026-08-21 추가 수정 — 대표 카테고리 출력 검증 중 재발견] C01~C05
    // (`_yearFortuneToResult`가 focusField와 무관하게 항상 같은
    // `getYearFortune().advice`를 담음)와 D09/G04/H01~H05/H07/H10
    // (`_luckyItemsToResult`가 전부 같은 `getLuckyItems().advice`를 공유)는
    // advice 재료 자체가 카테고리와 무관하게 같은 사용자에게 항상 동일한
    // 값이라, 행동지침 문단을 그대로 붙이면 5~9개 카테고리가 다시
    // 완전히 같은 문장을 반복하게 된다(사용자가 지적한 "다 같은 말"
    // 문제의 축소 재발). 이런 "공유 재료" 카테고리는 행동지침 문단을
    // 붙이지 않고 핵심해석 1문단만 노출한다.
    final action = _sharesAdviceAcrossCategories(entry.id)
        ? null
        : _closingActionSentence(data);
    return [
      core,
      if (action != null) action,
    ].where((p) => p.trim().isNotEmpty).toList(growable: false);
  }

  /// [entry.id]가 카테고리와 무관하게 동일한 advice 재료를 공유하는
  /// 그룹(연간 총운 4분야 C01~C05, 개운 아이템 계열 D09/G04/H01~H05/
  /// H07/H10)에 속하는지 판별한다. 이 그룹은 행동지침 문단을 생략해
  /// 카테고리 간 문구 중복을 막는다.
  static bool _sharesAdviceAcrossCategories(String categoryId) {
    const sharedAdviceIds = {
      'C01', 'C02', 'C03', 'C04', 'C05',
      'D09', 'G04', 'H01', 'H02', 'H03', 'H04', 'H05', 'H07', 'H10',
    };
    return sharedAdviceIds.contains(categoryId);
  }

  /// 이름이 있으면 "○○님", 없으면 "이 사주의 주인공"으로 호칭한다.
  /// 문장 맨 앞에 올 때와 문장 중간에 올 때 모두 자연스럽도록 단일
  /// 명사구로 통일한다.
  static String _honorific(String? name) {
    if (name == null || name.trim().isEmpty) return '이 사주의 주인공';
    return '$name님';
  }

  // ------------------------------------------------------------
  // [2026-08-21 삭제됨] 기존 오프닝(일간)/성향(오행·십신) 공통 문단 —
  // `_openingParagraph`/`_traitsParagraph`/`_elementExcessPositive`/
  // `_elementLackPositive`. B~H그룹 70종 전체가 카테고리와 무관하게
  // 거의 동일한 문구("사주 뿌리부터"/"오행의 흐름을")를 반복 노출하는
  // 근본 원인이었기에, 사용자 지적에 따라 완전히 제거했다(§9 금지
  // 문구 정리 포함, 계산 로직 변경 없음 — 애초에 이 함수들은 순수
  // 서술용이었을 뿐 어떤 카테고리 계산에도 관여하지 않았다).
  // ------------------------------------------------------------

  // ------------------------------------------------------------
  // 핵심해석 — 카테고리 관점(평생/대운/세운/오늘/궁합/특수주제/건강/개운)에
  // 맞춰 재물/직업/애정/건강 중 관련 있는 것을 자연스럽게 녹인 핵심 문단.
  //
  // [2026-08-18 A/B/E/F/G/H 소카테고리 차별화] 사용자가 "올해 건강운을
  // 봐도 재물 얘기만 나온다"를 C/D그룹에서 이미 한 차례 지적했고(2026-08-17
  // 수정 완료), 이번엔 A05(평생 건강운)에서 동일 패턴이 재발했다고
  // 스크린샷으로 재차 지적했다("모가 틀리다는거야" 원문). 원인은 A/B/E/F/G/
  // H 6개 대카테고리가 여전히 `entry.major` 단위로만 뭉뚱그려져 있었기
  // 때문 — [data]([runJeontongCategory]가 이미 계산해둔 이 소카테고리
  // 전용 결과)가 주어지면 `entry.id` 단위로 실제 값을 반영한다. [data]가
  // 없는 방어적 호출에서는 기존 major 단위 공통 문단으로 안전하게
  // 폴백한다(새로 계산하지 않음, 회귀 없음).
  // ------------------------------------------------------------
  static String _categoryParagraph(
    SajuFullInterpretation interp,
    JeontongCategoryEntry entry,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    switch (entry.major) {
      case JeontongMajorCode.a:
        return _lifetimeParagraphById(interp, entry.id, honorific, data);
      case JeontongMajorCode.b:
        return _daewoonParagraphById(interp, entry.id, honorific, data);
      case JeontongMajorCode.c:
        // [2026-08-17] C01~C05는 "올해 재물/직업/애정/건강운"처럼 서로
        // 다른 주제인데도 기존엔 전부 재물 이야기(_thisYearParagraph)만
        // 나왔다("건강운을 봐도 재물 얘기가 나온다"는 사용자 지적과 동일
        // 패턴). entry.id로 소카테고리 주제를 가려 그에 맞는 문단을 쓴다.
        return _thisYearParagraph(interp, entry.id, honorific, data);
      case JeontongMajorCode.d:
        return _todayParagraph(interp, entry.id, honorific, data);
      case JeontongMajorCode.e:
        return _loveParagraphById(interp, entry.id, honorific, data);
      case JeontongMajorCode.f:
        return _topicParagraphById(interp, entry.id, honorific, data);
      case JeontongMajorCode.g:
        return _healthParagraphById(interp, entry.id, honorific, data);
      case JeontongMajorCode.h:
        return _luckyCharmParagraphById(interp, entry.id, honorific, data);
    }
  }

  /// A그룹(평생운, A01~A10) 이야기체 — [data]가 있으면 `runJeontongCategory`가
  /// 계산해둔 해당 소카테고리 전용 값(예: A07의 child_god/count, A08의
  /// parent_message/sibling_message)을 문장에 직접 반영한다.
  static String _lifetimeParagraphById(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    switch (categoryId) {
      case 'A03':
        final assetStyle = data?['asset_style'] as String?;
        if (assetStyle != null) {
          // [j7 WealthAnalyzer 신규 필드 반영] wealthPattern/riskPattern이
          // 있으면(신규 엔진 경로) 재물 "구조"와 리스크까지 함께 서술해
          // 같은 A03/F01이라도 사람마다 다른 근거(§5)가 문장에 드러나게
          // 한다. 없으면(레거시 폴백) 기존 문장을 그대로 유지한다.
          final wealthPattern = data?['wealthPattern'] as String?;
          final riskPattern = data?['riskPattern'] as String?;
          final peakDaewoon = data?['wealthPeakDaewoonLabel'] as String?;
          if (wealthPattern != null) {
            return '평생 재물운이라는 주제로 좁혀서 보면, $honorific의 사주는 $wealthPattern 구조예요. '
                '자산을 굴리는 방식으로는 $assetStyle 흐름이 잘 맞아요. '
                '${riskPattern != null && riskPattern.isNotEmpty && riskPattern != '두드러진 재물 리스크 신호는 확인되지 않음' ? '${_soften(riskPattern)} ' : ''}'
                '${peakDaewoon != null && peakDaewoon.isNotEmpty ? '$peakDaewoon 시기에 재물운이 특히 활발해질 가능성이 높으니 참고해 두면 좋아요. ' : ''}'
                '평생에 걸쳐 이 흐름을 이해하고 있으면, 큰돈이 오갈 때마다 훨씬 침착하게 판단할 수 있을 거예요.';
          }
          return '평생 재물운이라는 주제로 좁혀서 보면, $honorific의 사주는 ${_soften(_wealthNarrative(interp.wealthFortune, honorific))} '
              '자산을 굴리는 방식으로는 $assetStyle 흐름이 잘 맞아요. '
              '평생에 걸쳐 이 흐름을 이해하고 있으면, 큰돈이 오갈 때마다 훨씬 침착하게 판단할 수 있을 거예요.';
        }
        break;
      case 'A04':
        final career = interp.careerFortune;
        final jobs = (data?['recommended_jobs'] as List?)
            ?.map((e) => e.toString())
            .toList();
        final growthPath = data?['growth_path'] as String?;
        if (jobs != null) {
          // [j7 CareerAnalyzer 신규 필드 반영] careerPattern/workStyle이
          // 있으면(신규 엔진 경로) 직업 "구조"와 일하는 방식까지 함께
          // 서술해 같은 A04/F02라도 사람마다 다른 근거(§5)가 문장에
          // 드러나게 한다. 없으면(레거시 폴백) 기존 문장을 그대로 유지.
          final careerPattern = data?['careerPattern'] as String?;
          final workStyle = data?['workStyle'] as String?;
          final riskPattern = data?['careerRiskPattern'] as String?;
          if (careerPattern != null) {
            return '평생 직업·명예운이라는 주제로 보면, $honorific은 $careerPattern 구조라서 '
                '${workStyle != null ? '$workStyle 방식이 잘 맞아요. ' : ''}'
                '${jobs.isNotEmpty ? '특히 ${_joinKo(jobs)} 같은 분야에서 두각을 나타낼 가능성이 높아요. ' : ''}'
                '${riskPattern != null && riskPattern.isNotEmpty && riskPattern != '두드러진 직업상 리스크 신호는 확인되지 않음' ? '${_soften(riskPattern)} ' : ''}'
                '${growthPath != null ? '$growthPath 흐름을 알아두면 진로를 정할 때 큰 힌트가 될 거예요.' : ''}';
          }
          return '평생 직업·명예운이라는 주제로 보면, $honorific은 ${career.structure} 성향이 뚜렷해서 ${_soften(career.message)} '
              '${jobs.isNotEmpty ? '특히 ${_joinKo(jobs)} 같은 분야에서 두각을 나타낼 가능성이 높아요. ' : ''}'
              '${growthPath != null ? '$growthPath 흐름을 알아두면 진로를 정할 때 큰 힌트가 될 거예요.' : ''}';
        }
        break;
      case 'A05':
        return _healthNarrativeFromLifeData(interp, honorific, data);
      case 'A06':
        final message = data?['message'] as String?;
        if (message != null) {
          final style = data?['style'] as String?;
          final marriageTiming = data?['marriage_timing'] as String?;
          // [j7 LoveAnalyzer 신규 필드 반영] spousePalaceCondition/
          // romanceRiskPattern이 있으면(신규 엔진 경로) 배우자궁 상태와
          // 리스크까지 함께 서술해 같은 A06이라도 사람마다 다른 근거
          // (§5)가 문장에 드러나게 한다. 없으면(레거시 폴백) 기존 문장을
          // 그대로 유지한다.
          final spousePalaceCondition = data?['spousePalaceCondition'] as String?;
          final romanceRiskPattern = data?['romanceRiskPattern'] as String?;
          final advice = data?['advice'] as String?;
          if (spousePalaceCondition != null) {
            return '평생 배우자·결혼운으로 보면, $honorific의 사주는 ${style != null ? '$style 성향이 뚜렷해요. ' : ''}'
                '${_soften(message)} '
                '${_soften(spousePalaceCondition)} '
                '${romanceRiskPattern != null && romanceRiskPattern.isNotEmpty && romanceRiskPattern != '두드러진 애정상 리스크 신호는 확인되지 않음' ? '${_soften(romanceRiskPattern)} ' : ''}'
                '${marriageTiming != null ? '${_soften(marriageTiming)} ' : ''}'
                '${advice != null ? _soften(advice) : ''}';
          }
          return '평생 배우자·결혼운으로 보면, ${_soften(message)} '
              '${style != null ? '전체적인 결로는 $style 성향이 뚜렷해요. ' : ''}'
              '${marriageTiming != null ? _soften(marriageTiming) : ''}';
        }
        break;
      case 'A07':
        final childGod = data?['child_god'] as String?;
        final message = data?['message'] as String?;
        if (childGod != null && message != null) {
          final timingHint = data?['timing_hint'] as String?;
          return '평생 자녀운으로 살펴보면, $honorific의 사주에서 자녀를 뜻하는 기운은 $childGod이에요. '
              '${_soften(message)} '
              '${timingHint != null ? _soften(timingHint) : ''}';
        }
        break;
      case 'A08':
        final parentMessage = data?['parent_message'] as String?;
        final siblingMessage = data?['sibling_message'] as String?;
        if (parentMessage != null && siblingMessage != null) {
          return '평생 부모·형제운으로 보면, 부모님과의 인연은 ${_soften(parentMessage)} '
              '형제·자매나 동료와의 인연은 ${_soften(siblingMessage)} '
              '가족이라는 울타리 안에서 $honorific이 서 있는 자리를 이해하면, 관계를 대하는 마음이 한결 편안해질 거예요.';
        }
        break;
      case 'A09':
        final message = data?['message'] as String?;
        if (message != null) {
          final style = data?['style'] as String?;
          return '평생 학업·시험운으로 보면, $honorific은 ${style ?? ''} 성향이 뚜렷해요. '
              '${_soften(message)} '
              '이 성향을 미리 알고 자신에게 맞는 공부 방식을 택하면, 훨씬 적은 노력으로도 좋은 결과를 얻을 수 있어요.';
        }
        break;
      case 'A10':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '인생의 큰 전환점이라는 주제로 보면, ${_soften(summary)} '
              '이런 전환점은 위기가 아니라 $honorific이 새로운 국면으로 들어서는 문이라고 생각하면, 그 시기를 훨씬 여유롭게 맞이할 수 있어요.';
        }
        break;
      case 'A01':
      case 'A02':
        // [j7 LifeOverallAnalyzer 신규 필드 반영] dominantTenGodCategory가
        // 있으면(신규 엔진 경로) 중심 기운·인생 테마·타고난 성향을 직접
        // 서술해, 같은 A01이라도 사람마다 다른 근거(§5)가 드러나는 문장을
        // 만든다. A02(성격·기질)는 data를 그대로 재사용하지만
        // categoryTitle이 다르므로 강조점만 살짝 다르게 서술한다.
        final dominantCategory = data?['dominantTenGodCategory'] as String?;
        final lifeTheme = data?['life_theme'] as String?;
        if (dominantCategory != null && lifeTheme != null) {
          final coreNature = data?['coreNatureDescription'] as String?;
          final strengthVerdict = data?['strengthVerdict'] as String?;
          final notableSinsal = (data?['notableSinsal'] as List?)
              ?.map((e) => e.toString())
              .toList();
          if (categoryId == 'A02') {
            return '타고난 성격·기질이라는 주제로 좁혀서 보면, ${coreNature != null ? '$honorific은 $coreNature. ' : ''}'
                '${strengthVerdict != null ? '기운의 세기로는 $strengthVerdict 편이라 ' : ''}'
                '$dominantCategory 기운이 두드러지게 성격에 묻어나요. '
                '${notableSinsal != null && notableSinsal.isNotEmpty ? '특히 ${_joinKo(notableSinsal)}(이)가 성격의 특이한 색깔을 더해줘요. ' : ''}'
                '이런 기질을 미리 알고 있으면, 스스로를 이해하고 다스리는 데 큰 도움이 될 거예요.';
          }
          return '평생 총운이라는 주제로 보면, $honorific의 삶은 $lifeTheme 쪽으로 흘러가는 경우가 많아요. '
              '${coreNature != null ? '타고난 바탕을 보면 $coreNature. ' : ''}'
              '$dominantCategory 기운이 인생 전반에서 가장 자주 반복되는 중심 기운이에요. '
              '${notableSinsal != null && notableSinsal.isNotEmpty ? '${_joinKo(notableSinsal)}(이)가 특이한 기운으로 함께 작용하고요. ' : ''}'
              '이 흐름을 이해하고 있으면, 인생의 크고 작은 선택 앞에서 훨씬 자기다운 결정을 내릴 수 있을 거예요.';
        }
        break;
      default:
        break;
    }
    // A01/A02(총운·성격) 및 위에서 data가 없어 break한 경우의 공통 폴백 —
    // 기존에 검증된 "평생 재물·직업·애정" 3축 총론 문단을 그대로 유지한다.
    final wealth = interp.wealthFortune;
    final career = interp.careerFortune;
    final love = interp.loveFortune;
    return '평생의 흐름이라는 큰 틀에서 보면, $honorific의 재물운은 ${_soften(_wealthNarrative(wealth, honorific))} '
        '일과 진로 쪽으로는 ${career.structure} 성향이 뚜렷해서, ${_soften(career.message)} '
        '사람과 인연을 맺는 방식에서는 ${_soften(_loveNarrative(love))} '
        '이 세 가지 흐름이 서로 맞물리며 $honorific만의 고유한 인생 그림을 그려가고 있는 거예요.';
  }

  /// B그룹(대운, B01~B10) 이야기체 — 대운은 10년 단위 흐름이므로 각
  /// 소카테고리(재물/직업/건강/애정/전환기/미리보기/최고·최악 시기/세운
  /// 조합)가 서로 다른 시계열 계산 결과([data])를 갖고 있다.
  static String _daewoonParagraphById(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    switch (categoryId) {
      case 'B02':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '대운별 재물 흐름이라는 주제로 보면, ${_soften(summary)} '
              '10년 단위로 찾아오는 이 흐름을 미리 알아두면, 큰 재물 결정을 내릴 때 훨씬 좋은 타이밍을 잡을 수 있어요.';
        }
        break;
      case 'B03':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '대운별 직업 변화라는 주제로 보면, ${_soften(summary)} '
              '이직·승진 같은 큰 결정을 앞두고 있다면, 지금이 어떤 흐름의 대운인지 함께 참고하면 도움이 될 거예요.';
        }
        break;
      case 'B04':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '대운별 건강 변화라는 주제로 보면, ${_soften(summary)} '
              '이건 의학적 진단이 아니라 사주 오행의 흐름을 기준으로 한 생활 참고 정보이니, 해당 시기에는 평소보다 조금 더 컨디션을 챙기는 정도로 편안하게 받아들이면 좋아요.';
        }
        break;
      case 'B05':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '대운별 애정 변화라는 주제로 보면, ${_soften(summary)} '
              '인연의 흐름도 계절처럼 오가니, 지금 이 시기의 결을 알아두면 관계를 대하는 마음가짐에 도움이 될 거예요.';
        }
        break;
      case 'B06':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '대운 전환기 주의사항이라는 주제로 보면, ${_soften(summary)} '
              '전환기는 흐름이 한 번 크게 바뀌는 시점이라, 그 앞뒤로는 서두르기보다 차분히 상황을 지켜보는 편이 좋아요.';
        }
        break;
      case 'B07':
        final message = data?['message'] as String?;
        if (message != null) {
          final ganZhiKr = data?['gan_zhi_kr'] as String?;
          return '다음 대운 미리보기로 보면, ${ganZhiKr != null ? '다음으로 다가올 대운은 $ganZhiKr예요. ' : ''}'
              '${_soften(message)} '
              '미리 알고 준비하는 것만으로도 새로운 흐름을 훨씬 여유롭게 맞이할 수 있어요.';
        }
        break;
      case 'B08':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '인생 최고 대운 시기라는 주제로 보면, ${_soften(summary)} '
              '이 시기가 오면 평소보다 조금 더 적극적으로 기회를 잡아봐도 좋은 흐름이에요.';
        }
        break;
      case 'B09':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '인생에서 조금 더 신중해야 할 대운 시기로 보면, ${_soften(summary)} '
              '이런 시기는 피할 수 없는 위기가 아니라, 평소보다 한 박자 천천히 움직이면 충분히 잘 지나갈 수 있는 흐름이에요.';
        }
        break;
      case 'B10':
        final message = data?['message'] as String?;
        if (message != null) {
          final synergy = data?['synergy'] as String?;
          return '지금의 대운과 올해 세운이 만나는 조합으로 보면, ${synergy != null ? '두 흐름은 $synergy 관계예요. ' : ''}'
              '${_soften(message)}';
        }
        break;
      case 'B01':
      default:
        break;
    }
    // B01(현재 대운 총평) 및 data 미확보 시 공통 폴백.
    final luck = interp.currentLuckAnalysis;
    if (luck.message == null) {
      return '지금 이 시기에 해당하는 대운 정보는 조금 더 정밀한 계산이 필요해서, 우선은 타고난 사주의 결을 중심으로 풀이해 드렸어요.';
    }
    return '지금 $honorific이 지나고 있는 큰 흐름, 즉 대운은 ${luck.title}${luck.ageRange != null ? '(${luck.ageRange})' : ''}이에요. '
        '이 10년은 ${_soften(luck.message!)} '
        '대운은 계절이 바뀌듯 자연스럽게 찾아오는 흐름이라, 지금 이 시기의 기운을 미리 알고 준비하는 것만으로도 훨씬 여유롭게 지나갈 수 있어요.';
  }

  /// A05/G01/G02가 공유하는 건강 데이터(core_organs/lifetime_warnings/
  /// advice_food/lifestyle)를 재료로 건강 문단을 만든다.
  /// [emphasis]가 'warnings'이면 G02(평생 조심할 병)처럼 lifetime_warnings에
  /// 방점을, 기본값(organs)이면 A05/G01(취약장기)처럼 core_organs에
  /// 방점을 찍어 같은 원본 데이터라도 서로 다른 강조점으로 서술한다.
  ///
  /// [2026-08 A05 HealthAnalyzer 전환] `_a05()`가 이제 [HealthAnalyzer]
  /// 결과를 소비하면서 `data`에 `healthConstitutionPattern`/
  /// `healthVitality`/`healthRiskPattern`(사람마다 달라지는 체질 편중
  /// 구조·체력 그릇·리스크 서술) 원본을 함께 보존해 둔다(§7 필드 삭제
  /// 금지 원칙과 대칭 — 새 필드 추가는 항상 허용). 이 필드들이 존재하면
  /// (신규 엔진 경로) 기존 4개 필드만 쓰던 것보다 한층 더 개인화된 문단을
  /// 만든다 — 같은 core_organs를 가진 두 사람이라도 healthConstitutionPattern/
  /// healthVitality/healthRiskPattern은 오행 편중·신강신약·신살·기신 조합에
  /// 따라 사람마다 달라진다(§4/§15 "완전 동일 문장 금지").
  static String _healthNarrativeFromLifeData(
    SajuFullInterpretation interp,
    String honorific,
    Map<String, dynamic>? data, {
    String emphasis = 'organs',
  }) {
    final coreOrgans = (data?['core_organs'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final warnings = (data?['lifetime_warnings'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final adviceFood = (data?['advice_food'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final lifestyle = data?['lifestyle'] as String?;
    final constitutionPattern = data?['healthConstitutionPattern'] as String?;
    final vitality = data?['healthVitality'] as String?;
    final riskPattern = data?['healthRiskPattern'] as String?;

    if (coreOrgans != null && constitutionPattern != null) {
      // ── HealthAnalyzer 신규 경로(§4/§15 개인화 강화) ──
      final organsText = coreOrgans.isNotEmpty ? _joinKo(coreOrgans) : '몸 전반';
      final constitutionSentence = '$honorific의 체질을 살펴보면 $constitutionPattern에 가까워요.';
      final vitalitySentence = vitality != null ? ' 타고난 체력 면에서는 $vitality 흐름이에요.' : '';
      if (emphasis == 'warnings' && warnings != null && warnings.isNotEmpty) {
        return '평생 조심하면 좋은 부분으로 보면, $constitutionSentence$vitalitySentence '
            '특히 ${_joinKo(warnings)} 쪽에 신경을 쓰면 도움이 될 거예요. '
            '${riskPattern != null && riskPattern.isNotEmpty && riskPattern != '두드러진 건강상 리스크 신호는 확인되지 않음' ? '${_soften(riskPattern)} ' : ''}'
            '이건 의학적 진단이 아니라 명리 체질론에 근거한 생활 속 참고일 뿐이니 너무 무겁게 받아들이지 않아도 돼요. '
            '${adviceFood != null && adviceFood.isNotEmpty ? '${_joinKo(adviceFood)} 같은 음식을 가까이하면 도움이 될 거예요. ' : ''}';
      }
      return '평생 건강운의 핵심 장기로 보면, $constitutionSentence$vitalitySentence '
          '$organsText 쪽과 특히 인연이 깊은 편이에요. '
          '${warnings != null && warnings.isNotEmpty ? '평소 ${_joinKo(warnings)} 쪽을 챙기면 도움이 돼요. ' : ''}'
          '이건 의학적 진단이 아니라 명리 체질론에 근거한 생활 속 참고이니 가볍게 받아들이면 돼요. '
          '${adviceFood != null && adviceFood.isNotEmpty ? '${_joinKo(adviceFood)} 같은 음식이 잘 맞아요. ' : ''}';
    }
    if (coreOrgans == null) {
      // data 미확보 — 기존 인터프리터 재료만으로 안전 폴백.
      final health = interp.healthFortune;
      final organs = health.coreOrgans.isNotEmpty
          ? _joinKo(health.coreOrgans)
          : '몸 전반';
      return '평생 건강운으로 보면, $honorific의 사주는 타고난 기운상 $organs 쪽과 특히 인연이 깊어요. '
          '이건 의학적 진단이 아니라 명리 체질론에 근거한 생활 속 참고이니 가볍게 받아들이면 돼요. '
          '몸을 아끼는 마음으로 평소 컨디션을 살피는 습관만 들여도 한결 편안해질 거예요.';
    }
    final organsText = coreOrgans.isNotEmpty ? _joinKo(coreOrgans) : '몸 전반';
    if (emphasis == 'warnings' && warnings != null && warnings.isNotEmpty) {
      return '평생 조심하면 좋은 부분으로 보면, $honorific의 사주는 $organsText 쪽 흐름과 인연이 깊어서 이 부분을 평소에 잘 챙기면 좋아요. '
          '${_joinKo(warnings)} 쪽에 특히 신경을 쓰면 도움이 될 거예요. '
          '이건 의학적 진단이 아니라 명리 체질론에 근거한 생활 속 참고일 뿐이니 너무 무겁게 받아들이지 않아도 돼요. '
          '${adviceFood != null && adviceFood.isNotEmpty ? '${_joinKo(adviceFood)} 같은 음식을 가까이하면 도움이 될 거예요. ' : ''}'
          '${lifestyle ?? ''}';
    }
    return '평생 건강운의 핵심 장기로 보면, $honorific의 사주는 $organsText 쪽과 특히 인연이 깊어요. '
        '${warnings != null && warnings.isNotEmpty ? '평소 ${_joinKo(warnings)} 쪽을 챙기면 도움이 돼요. ' : ''}'
        '이건 의학적 진단이 아니라 명리 체질론에 근거한 생활 속 참고이니 가볍게 받아들이면 돼요. '
        '${adviceFood != null && adviceFood.isNotEmpty ? '${_joinKo(adviceFood)} 같은 음식이 잘 맞아요. ' : ''}'
        '${lifestyle ?? '몸을 아끼는 마음으로 평소 컨디션을 살피는 습관만 들여도 한결 편안해질 거예요.'}';
  }

  /// [2026-08-17 C01~C10 이야기체 차별화] `entry.id`로 이 해의 어느 영역을
  /// 이야기할지 가른다. C02~C05는 총운 계산 안의 focusField를,
  /// C06~C10은 각자의 실계산(이사·시험·소송·인간관계·월별개관) [data]를 쓴다.
  static String _thisYearParagraph(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    final luck = interp.currentLuckAnalysis;
    final base = luck.message != null
        ? '올해는 ${luck.title}의 큰 흐름 안에 놓여 있는 해예요. ${_soften(luck.message!)} '
        : '올해는 타고난 사주 본연의 기운이 비교적 뚜렷하게 드러나는 시기예요. ';

    switch (categoryId) {
      case 'C06':
      case 'C07':
      case 'C08':
      case 'C09':
        final overall = data?['overall'] as String?;
        if (overall != null) {
          final topicWord = switch (categoryId) {
            'C06' => '이사·이동수',
            'C07' => '시험·자격운',
            'C08' => '소송·관재수',
            _ => '인간관계',
          };
          final advice = data?['advice'] as String?;
          return '$base'
              '특히 올해 $topicWord 쪽 흐름을 함께 짚어보면, ${_soften(overall)} '
              '${advice != null ? _soften(advice) : ''}';
        }
        break;
      case 'C10':
        final overall = data?['overall'] as String?;
        if (overall != null) {
          final monthlySummary = (data?['monthly_summary'] as List?)
              ?.map((e) => e.toString())
              .toList();
          return '$base'
              '한 해를 열두 달로 나누어 짚어보면, ${_soften(overall)} '
              '${monthlySummary != null && monthlySummary.isNotEmpty ? '${_joinKo(monthlySummary.take(3).toList())} 같은 흐름이 달마다 이어져요. ' : ''}'
              '달마다 결이 조금씩 달라지니, 큰 계획을 세울 때는 이 흐름을 참고하면 도움이 될 거예요.';
        }
        break;
      default:
        break;
    }

    final String focusLine;
    switch (categoryId) {
      case 'C02':
        focusLine =
            '특히 올해 재물 쪽 흐름을 함께 짚어보면, ${_soften(_wealthNarrative(interp.wealthFortune, honorific))} ';
        break;
      case 'C03':
        final career = interp.careerFortune;
        focusLine =
            '특히 올해 직업·진로 쪽 흐름을 함께 짚어보면, ${career.structure} 성향이 이 시기에 더 뚜렷하게 드러나요. ${_soften(career.message)} ';
        break;
      case 'C04':
        focusLine =
            '특히 올해 애정·인연 쪽 흐름을 함께 짚어보면, ${_soften(_loveNarrative(interp.loveFortune))} ';
        break;
      case 'C05':
        final health = interp.healthFortune;
        final organs = health.coreOrgans.isNotEmpty
            ? _joinKo(health.coreOrgans)
            : '몸 전반';
        focusLine =
            '특히 올해 건강 쪽 흐름을 함께 짚어보면, 타고난 기운상 $organs 쪽을 평소보다 조금 더 챙기면 좋은 해예요. 무리하지 않는 선에서 꾸준히 컨디션을 관리하면 한 해가 훨씬 편안해질 거예요. ';
        break;
      case 'C01':
      default:
        focusLine = '한 해 전체를 아우르는 총운으로 보면, 재물·일·인연 여러 흐름이 골고루 맞물려 흘러가는 해예요. ';
    }

    return '$base'
        '$focusLine'
        '한 해를 통째로 보면 잔잔한 흐름 속에서도 분명 변화의 순간들이 있을 텐데, 그 순간마다 $honorific이 원래 갖고 있던 기질대로 차분히 대응하면 좋은 결과로 이어질 가능성이 높아요.';
  }

  /// [2026-08-17 D01~D10 이야기체 차별화] `categoryId`로 오늘/이달/이번 주
  /// 등 어느 시점·영역(월운/총운/재물/애정/건강/시간대/주간/개운아이템/
  /// 피할일)을 이야기할지 가른다.
  static String _todayParagraph(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    final dm = interp.dayMasterAnalysis;

    // D01(이달의 운세), D04(이번 주 운세), D09(개운 아이템), D10(피해야
    // 할 일)은 각각 고유한 data 구조를 가져 전용 문단이 필요하다.
    switch (categoryId) {
      case 'D01':
        final overall = data?['overall'] as String?;
        if (overall != null) {
          final work = data?['work'] as String?;
          final advice = data?['advice'] as String?;
          return '이달의 흐름으로 보면, ${_soften(overall)} '
              '${work != null ? _soften(work) : ''} '
              '${advice != null ? _soften(advice) : ''}';
        }
        break;
      case 'D04':
        final overall = data?['overall'] as String?;
        if (overall != null) {
          final dailySummary = (data?['daily_summary'] as List?)
              ?.map((e) => e.toString())
              .toList();
          return '이번 주의 흐름으로 보면, ${_soften(overall)} '
              '${dailySummary != null && dailySummary.isNotEmpty ? '${_joinKo(dailySummary.take(3).toList())} 같은 흐름이 요일마다 이어져요. ' : ''}'
              '한 주 전체의 흐름을 미리 알아두면, 일정을 짜는 데도 큰 도움이 될 거예요.';
        }
        break;
      case 'D09':
        final colors = (data?['colors'] as List?)
            ?.map((e) => e.toString())
            .toList();
        if (colors != null) {
          final items = (data?['items'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final food = (data?['food'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final activities = (data?['activities'] as List?)
              ?.map((e) => e.toString())
              .toList();
          return '지금 $honorific의 기운을 보충해줄 개운 아이템으로 보면, '
              '${colors.isNotEmpty ? '${_joinKo(colors)} 계열 색을 가까이하면 좋아요. ' : ''}'
              '${items != null && items.isNotEmpty ? '${_joinKo(items)} 같은 소품을 곁에 두면 도움이 돼요. ' : ''}'
              '${food != null && food.isNotEmpty ? '${_joinKo(food)} 같은 음식을 가끔씩 챙겨보세요. ' : ''}'
              '${activities != null && activities.isNotEmpty ? '${_joinKo(activities)} 같은 활동도 기운을 밝혀줄 거예요.' : ''}';
        }
        break;
      case 'D10':
        final overall = data?['overall'] as String?;
        if (overall != null) {
          final advice = data?['advice'] as String?;
          return '오늘 하루, 피하면 좋은 일이라는 주제로 보면, ${_soften(overall)} '
              '${advice != null ? _soften(advice) : ''}';
        }
        break;
      default:
        break;
    }

    final String focusLine;
    switch (categoryId) {
      case 'D05':
        focusLine =
            '오늘은 특히 재물 흐름을 살펴보면 좋은 날이에요. ${_soften(_wealthNarrative(interp.wealthFortune, honorific))} ';
        break;
      case 'D06':
        focusLine =
            '오늘은 특히 인연·애정 흐름을 살펴보면 좋은 날이에요. ${_soften(_loveNarrative(interp.loveFortune))} ';
        break;
      case 'D07':
        final health = interp.healthFortune;
        final organs = health.coreOrgans.isNotEmpty
            ? _joinKo(health.coreOrgans)
            : '몸 전반';
        focusLine =
            '오늘은 특히 컨디션을 살펴보면 좋은 날이에요. 타고난 기운상 $organs 쪽에 평소보다 조금 더 신경을 쓰면, 하루를 훨씬 가뿐하게 보낼 수 있어요. ';
        break;
      case 'D08':
        focusLine =
            '오늘 하루 중에서도 유독 흐름이 잘 맞는 시간대와, 반대로 조금 조심하면 좋은 시간대가 나뉘어 있어요. ';
        break;
      case 'D02':
      case 'D03':
      default:
        focusLine = '';
    }
    return '가까운 오늘과 이달의 흐름은 타고난 일간의 기질이 특히 도드라지는 시점이에요. '
        '${_soften(dm.personality)} '
        '$focusLine'
        '이런 날에는 큰 결정을 서두르기보다, $honorific 본연의 리듬에 맞춰 하루하루를 채워가는 편이 오히려 더 좋은 흐름을 만들어줘요. 작은 선택 하나가 며칠 뒤 뜻밖의 좋은 결과로 이어질 수 있으니, 지금 이 순간의 감각을 믿어봐도 좋아요.';
  }

  /// E그룹(궁합, E08~E10) 이야기체 — E08(띠궁합)/E09(오행궁합)/E10(겉속궁합)은
  /// 서로 다른 계산 결과([data])를 가진 별개 주제라, 실계산이 없는 경우에만
  /// 기존 애정운 총론으로 폴백한다.
  static String _loveParagraphById(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    switch (categoryId) {
      case 'E08':
        final myAnimal = data?['my_animal'] as String?;
        final summary = data?['summary'] as String?;
        if (myAnimal != null && summary != null) {
          final best = (data?['best_matches'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final worst = (data?['worst_matches'] as List?)
              ?.map((e) => e.toString())
              .toList();
          return '띠 궁합이라는 주제로 보면, $honorific의 띠는 $myAnimal예요. '
              '${_soften(summary)} '
              '${best != null && best.isNotEmpty ? '특히 ${_joinKo(best)}띠와는 서로 편안하게 어우러지는 결이 있어요. ' : ''}'
              '${worst != null && worst.isNotEmpty ? '반대로 ${_joinKo(worst)}띠와는 서로 다른 결이라 조금 더 배려하는 마음이 필요할 수 있어요.' : ''}';
        }
        break;
      case 'E09':
        final myElement = data?['my_element'] as String?;
        final summary = data?['summary'] as String?;
        if (myElement != null && summary != null) {
          final supportive = data?['supportive_element'] as String?;
          final clashing = data?['clashing_element'] as String?;
          return '오행 궁합이라는 주제로 보면, $honorific의 타고난 기운은 $myElement예요. '
              '${_soften(summary)} '
              '${supportive != null ? '$supportive 기운을 가진 상대와는 서로 도와주는 관계가 되기 쉬워요. ' : ''}'
              '${clashing != null ? '$clashing 기운을 가진 상대와는 부딪히는 지점이 있을 수 있으니, 서로 다름을 이해하는 자세가 관계를 더 단단하게 만들어줘요.' : ''}';
        }
        break;
      case 'E10':
        final relation = data?['relation'] as String?;
        final summary = data?['summary'] as String?;
        if (relation != null && summary != null) {
          final outer = data?['outer_element'] as String?;
          final inner = data?['inner_element'] as String?;
          return '겉궁합과 속궁합이라는 주제로 보면, $honorific은 겉으로 드러나는 결과 마음속 진짜 결이 '
              '${outer != null && inner != null ? '($outer과(와) $inner)' : ''} $relation 관계에 있어요. '
              '${_soften(summary)}';
        }
        break;
      default:
        break;
    }
    final love = interp.loveFortune;
    final tg = interp.tenGodsAnalysis;
    return '인연이라는 주제로 $honorific의 사주를 들여다보면, ${_soften(_loveNarrative(love))} '
        '사주 안에서 우세한 기운인 ${tg.dominantEasy}의 성향이 관계 안에서도 그대로 드러나곤 하는데, 이는 상대방과의 궁합을 볼 때도 중요한 열쇠가 돼요. '
        '결국 좋은 인연은 억지로 맞추는 것이 아니라, $honorific 고유의 기운을 편안하게 받아줄 수 있는 상대를 만났을 때 가장 자연스럽게 이어진답니다.';
  }

  /// F그룹(특수 주제, F01~F10) 이야기체 — 재물/직업/투자/결혼/출산/해외 등
  /// 서로 다른 실전 주제이므로 각 [data] 구조를 그대로 반영한다. F01/F02는
  /// A03/A04를 그대로 재사용하는 카테고리라 `_lifetimeParagraphById`에
  /// 위임한다.
  static String _topicParagraphById(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    switch (categoryId) {
      case 'F01':
        return _lifetimeParagraphById(interp, 'A03', honorific, data);
      case 'F02':
        return _lifetimeParagraphById(interp, 'A04', honorific, data);
      case 'F03':
        final message = data?['message'] as String?;
        if (message != null) {
          final items = (data?['items'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final style = data?['style'] as String?;
          return '$honorific에게 맞는 사업 아이템이라는 주제로 보면, ${_soften(message)} '
              '${style != null ? '전체적으로는 $style 방식이 잘 맞아요. ' : ''}'
              '${items != null && items.isNotEmpty ? '구체적으로는 ${_joinKo(items)} 같은 분야를 살펴보면 좋아요.' : ''}';
        }
        break;
      case 'F04':
        final message = data?['message'] as String?;
        if (message != null) {
          final verdict = data?['verdict'] as String?;
          return '창업이냐 직장이냐 하는 고민으로 보면, ${verdict != null ? '$honorific의 사주는 $verdict 쪽에 조금 더 무게가 실려요. ' : ''}'
              '${_soften(message)}';
        }
        break;
      case 'F05':
        final message = data?['message'] as String?;
        if (message != null) {
          final verdict = data?['verdict'] as String?;
          return '이직 타이밍이라는 주제로 보면, ${verdict != null ? '$honorific의 지금 흐름은 $verdict예요. ' : ''}'
              '${_soften(message)}';
        }
        break;
      case 'F06':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '부동산 매매 타이밍이라는 주제로 보면, ${_soften(summary)} '
              '큰 자산이 오가는 결정인 만큼, 이 흐름을 참고해 서두르지 않고 움직이면 좋은 결과로 이어질 가능성이 높아요.';
        }
        break;
      case 'F07':
        final message = data?['message'] as String?;
        if (message != null) {
          final style = data?['style'] as String?;
          return '투자 성향이라는 주제로 보면, $honorific은 ${style ?? ''} 성향이 뚜렷해요. '
              '${_soften(message)}';
        }
        break;
      case 'F08':
        final message = data?['message'] as String?;
        if (message != null) {
          final nearestPeriod = data?['nearest_period'] as String?;
          return '결혼 적령기라는 주제로 보면, ${_soften(message)} '
              '${nearestPeriod != null ? '가까운 시기로는 $nearestPeriod 무렵이 특히 눈에 띄어요.' : ''}';
        }
        break;
      case 'F09':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '자녀를 갖기 좋은 해라는 주제로 보면, ${_soften(summary)} '
              '이 흐름은 절대적인 기준이 아니라 참고할 만한 하나의 결이니, 부부가 함께 상의하며 편안한 때를 찾아가면 좋아요.';
        }
        break;
      case 'F10':
        final message = data?['message'] as String?;
        if (message != null) {
          final style = data?['style'] as String?;
          return '유학·해외 진출운이라는 주제로 보면, $honorific은 ${style ?? ''} 흐름을 갖고 있어요. '
              '${_soften(message)}';
        }
        break;
      default:
        break;
    }
    final wealth = interp.wealthFortune;
    final career = interp.careerFortune;
    return '구체적인 주제로 들어가 보면, 재물 쪽으로는 ${_soften(_wealthNarrative(wealth, honorific))} '
        '진로나 직업 쪽으로는 ${career.structure} 기운이 강하게 흘러서, ${_soften(career.message)} '
        '${career.recommended.isNotEmpty ? '특히 ${_joinKo(career.recommended)} 같은 분야가 $honorific의 타고난 결과 잘 맞아떨어질 가능성이 높아요.' : ''}';
  }

  /// G그룹(건강, G01~G10) 이야기체 — G01/G02는 A05와 완전히 같은 원본
  /// 데이터([LifeHealthResult])를 공유하므로 `_healthNarrativeFromLifeData`의
  /// emphasis 파라미터로만 서로 다르게 서술한다. 나머지(G03~G10)는 각자
  /// 고유한 계산 결과를 반영한다.
  static String _healthParagraphById(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    switch (categoryId) {
      case 'G01':
        return _healthNarrativeFromLifeData(
          interp,
          honorific,
          data,
          emphasis: 'organs',
        );
      case 'G02':
        return _healthNarrativeFromLifeData(
          interp,
          honorific,
          data,
          emphasis: 'warnings',
        );
      case 'G03':
        final summary = data?['summary'] as String?;
        if (summary != null) {
          return '대운별로 건강을 챙기면 좋은 시기라는 주제로 보면, ${_soften(summary)} '
              '이건 의학적 진단이 아니라 사주 오행 흐름에 근거한 생활 참고이니, 해당 시기엔 평소보다 조금 더 컨디션을 돌보는 정도로 편안하게 받아들이면 돼요.';
        }
        break;
      case 'G04':
        final food = (data?['food'] as List?)
            ?.map((e) => e.toString())
            .toList();
        if (food != null) {
          final advice = data?['advice'] as String?;
          return '$honorific에게 좋은 음식이라는 주제로 보면, '
              '${food.isNotEmpty ? '${_joinKo(food)} 같은 음식을 가까이하면 몸의 균형을 잡는 데 도움이 돼요. ' : ''}'
              '${advice != null ? _soften(advice) : ''}';
        }
        break;
      case 'G05':
        final message = data?['message'] as String?;
        if (message != null) {
          final foodsToLimit = (data?['foods_to_limit'] as List?)
              ?.map((e) => e.toString())
              .toList();
          return '$honorific에게 조금 덜어내면 좋은 음식이라는 주제로 보면, ${_soften(message)} '
              '${foodsToLimit != null && foodsToLimit.isNotEmpty ? '${_joinKo(foodsToLimit)} 같은 음식은 평소보다 양을 줄여보면 몸이 한결 가벼워질 거예요.' : ''}';
        }
        break;
      case 'G06':
        final message = data?['message'] as String?;
        if (message != null) {
          final organs = (data?['organs'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final personality = data?['personality'] as String?;
          return '사주 체질이라는 주제로 보면, $honorific은 ${personality ?? ''} 체질에 가까워요. '
              '${organs != null && organs.isNotEmpty ? '${_joinKo(organs)} 쪽과 특히 인연이 깊고요. ' : ''}'
              '${_soften(message)}';
        }
        break;
      case 'G07':
        final message = data?['message'] as String?;
        if (message != null) {
          final verdict = data?['verdict'] as String?;
          return '마음 건강이라는 주제로 보면, ${verdict != null ? '$honorific은 $verdict 편이에요. ' : ''}'
              '${_soften(message)} '
              '이건 진단이 아니라 참고이니, 마음이 힘든 날엔 주변에 기대는 것도 좋은 선택이에요.';
        }
        break;
      case 'G08':
        final message = data?['message'] as String?;
        if (message != null) {
          final verdict = data?['verdict'] as String?;
          return '사고·수술 조심이라는 주제로 보면, ${verdict != null ? '$honorific의 사주는 $verdict예요. ' : ''}'
              '${_soften(message)} '
              '평소보다 조금만 더 안전에 신경 쓰면 충분히 편안하게 지나갈 수 있어요.';
        }
        break;
      case 'G10':
        final message = data?['message'] as String?;
        if (message != null) {
          final verdict = data?['verdict'] as String?;
          return '회복력과 면역이라는 주제로 보면, ${verdict != null ? '$honorific은 $verdict 편이에요. ' : ''}'
              '${_soften(message)}';
        }
        break;
      default:
        break;
    }
    return _healthNarrativeFromLifeData(interp, honorific, data);
  }

  /// H그룹(개운·풍수, H01~H10) 이야기체 — H01/H02/H03/H04/H05/H07/H10은
  /// 계산 레이어에서 전부 동일한 [LuckyItemsResult]를 재사용하므로("행운의
  /// 색"/"행운의 방향"/"행운의 숫자"/"행운의 보석"/"부적" 등 category
  /// 라벨만 다름), narrative 레이어에서 categoryId별로 그 데이터의 서로
  /// 다른 필드(colors/directions/numbers/items/activities)를 강조해야만
  /// 실제로 다른 문장이 나온다.
  static String _luckyCharmParagraphById(
    SajuFullInterpretation interp,
    String categoryId,
    String honorific,
    Map<String, dynamic>? data,
  ) {
    final colors = (data?['colors'] as List?)?.map((e) => e.toString()).toList();
    final directions = (data?['directions'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final numbers = (data?['numbers'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final items = (data?['items'] as List?)?.map((e) => e.toString()).toList();
    final activities = (data?['activities'] as List?)
        ?.map((e) => e.toString())
        .toList();
    final advice = data?['advice'] as String?;

    if (colors != null) {
      switch (categoryId) {
        case 'H01':
          return '$honorific의 개운색이라는 주제로 보면, 타고난 기운을 가장 잘 북돋아 주는 색은 '
              '${colors.isNotEmpty ? '${_joinKo(colors)} 계열이에요. ' : ''}'
              '거창하게 바꿀 필요 없이, 즐겨 입는 옷이나 자주 쓰는 소품 하나를 이 색으로 골라보는 것만으로도 기운이 한결 편안하게 흐를 거예요.';
        case 'H02':
        case 'H07':
          final label = categoryId == 'H07' ? '집·사무실 방향' : '행운의 방향';
          return '$honorific에게 맞는 $label이라는 주제로 보면, '
              '${directions != null && directions.isNotEmpty ? '${_joinKo(directions)} 방향의 기운이 특히 잘 맞아요. ' : ''}'
              '${categoryId == 'H07' ? '책상이나 침대 머리를 이 방향으로 두면, 공간의 기운이 훨씬 안정적으로 자리 잡을 거예요.' : '중요한 자리에 앉거나 이동할 때 이 방향을 살짝 의식해보면 도움이 돼요.'}';
        case 'H03':
          return '$honorific에게 맞는 행운의 숫자라는 주제로 보면, '
              '${numbers != null && numbers.isNotEmpty ? '${_joinKo(numbers)} 같은 숫자와 인연이 깊어요. ' : ''}'
              '중요한 날짜를 고르거나 비밀번호, 좌석 번호를 정할 때 이 숫자를 살짝 참고해보면 마음이 한결 편안해질 거예요.';
        case 'H04':
          return '$honorific에게 맞는 보석이라는 주제로 보면, '
              '${items != null && items.isNotEmpty ? '${_joinKo(items)} 같은 보석이 기운을 잘 북돋아 줘요. ' : ''}'
              '몸에 지니는 작은 장신구 하나로도 타고난 기운이 한결 안정적으로 흐르는 걸 느낄 수 있을 거예요.';
        case 'H05':
          return '$honorific에게 맞는 부적·개운 아이템이라는 주제로 보면, '
              '${items != null && items.isNotEmpty ? '${_joinKo(items)} 같은 물건이 기운을 지켜주는 역할을 해줘요. ' : ''}'
              '${advice != null ? _soften(advice) : '이런 물건을 가까이 두는 것 자체가 스스로에게 안정감을 주는 좋은 습관이 될 거예요.'}';
        case 'H10':
          return '$honorific에게 맞는 개운 습관이라는 주제로 보면, '
              '${activities != null && activities.isNotEmpty ? '${_joinKo(activities)} 같은 활동을 꾸준히 실천하면 좋아요. ' : ''}'
              '작은 습관 하나를 매일 반복하는 것만으로도, 타고난 좋은 기운이 삶 속에 훨씬 자연스럽게 스며들 거예요.';
        default:
          break;
      }
    }
    final fe = interp.fiveElementsAnalysis;
    final fallbackColors = fe.recommendedColor.isNotEmpty
        ? _joinKo(fe.recommendedColor)
        : '차분한 색';
    return '개운이라는 관점에서 보면, $honorific의 타고난 기운을 가장 잘 북돋아 주는 색은 $fallbackColors 계열이고, 방향으로는 ${fe.recommendedDirection} 쪽 기운이 잘 맞아요. '
        '거창한 것이 아니어도, 즐겨 입는 옷이나 방 안의 작은 소품 하나를 이 기운에 맞춰보는 것만으로도 마음이 한결 편안해지는 걸 느낄 수 있을 거예요. '
        '결국 개운이라는 건 없던 복을 억지로 만드는 게 아니라, $honorific이 원래 갖고 있던 좋은 기운이 더 잘 흐르도록 살짝 물꼬를 터주는 일이에요.';
  }

  // ------------------------------------------------------------
  // [2026-08-21 삭제됨] 기존 신살 문단(`_luckParagraph`/`_sinsalEasyName`)
  // — §9 금지 문구 "여기에 더해"로 시작하며 B~H그룹 전체에서 신살
  // 유무만으로 거의 동일하게 반복되던 문단. 카테고리 고유 정보가 아니라
  // 완전히 제거했다(계산 로직 변경 없음 — 순수 서술용이었을 뿐이다).
  //
  // [2026-08-21 마무리 문단 축소] 기존 `_closingParagraph`는 major(A~H)
  // 8종 단위로만 문구가 갈리는 "나침반" 비유(§9 금지 문구 "사주는
  // 정해진 운명"으로 시작)를 항상 붙였는데, 이 역시 카테고리 고유
  // 정보가 아니라 8종류로만 돌려쓰는 고정 문구였다. 이제
  // [_closingActionSentence]가 만들어내는, 각 카테고리 계산이 실제로
  // 산출한 advice/message 기반 "짧은 행동지침 한 줄"만 (있을 때만)
  // 핵심해석 문단 아래에 덧붙인다 — 고정 나침반 비유 문구는 완전히
  // 제거했다.
  // ------------------------------------------------------------

  /// [data]의 `advice`(우선) 또는 `message`의 마지막 문장(조언 성격이
  /// 뚜렷할 때만)을 골라, 마무리 문단에 붙일 완결된 행동지침 문장을
  /// 반환한다. 적절한 값이 없으면 null(폴백은 호출부에서 처리).
  ///
  /// [2026 그룹③ 마무리 보강 · 2차 수정] 1차 구현("advice 있으면 그대로
  /// '그러니 지금은 ~' 뒤에 붙인다")을 실제 69종 전체에 대해 샘플 출력
  /// 해보니, advice/message의 원본 스타일이 소스 JSON/모듈마다 완전히
  /// 달라 그대로 이어붙이면 부자연스러운 문장이 나오는 경우가 있었다:
  ///   - `monthly_fortune_rules.json`(D01 등): "방어적 태세" 같은 2~6자
  ///     짧은 키워드 → "그러니 지금은 방어적 태세."는 문장이 안 됨.
  ///   - `lucky_items_rules.json`(D09/G04/H01~H10 등): "물 많이 마시기,
  ///     목욕·사우나, 조용한 시간 확보" 같은 쉼표 나열형 활동 리스트 →
  ///     "그러니 지금은 [나열]."은 다소 어색함.
  ///   - `getNextDaewoonPreview`(B07): message의 마지막 문장이 "이
  ///     대운의 십신은 ~이에요." 같은 순수 정보 전달문이라, 조언이 아닌
  ///     내용이 "그러니 지금은 ~"에 붙어버림.
  /// 계산 로직은 그대로 두고([_wrapAdviceForClosing] 참고, 문자열
  /// 구조만으로 판별), advice/message 원문은 그대로 재료로 쓰되 이어
  /// 붙이는 연결어만 원문 형태(완결문/나열형/키워드형)에 맞게 고른다.
  /// message 폴백은 "조언 의도"가 뚜렷한 마커가 있을 때만 사용해, B07
  /// 같은 순수 정보문이 조언인 것처럼 붙는 것을 막는다.
  static String? _closingActionSentence(Map<String, dynamic>? data) {
    final advice = data?['advice'] as String?;
    if (advice != null && advice.trim().isNotEmpty) {
      return _wrapAdviceForClosing(advice.trim());
    }
    final message = data?['message'] as String?;
    if (message != null && message.trim().isNotEmpty) {
      final sentences = message
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (sentences.length > 1) {
        final last = sentences.last;
        // message의 마지막 문장은 advice와 달리 "조언"이 아니라 그냥
        // 정보 전달로 끝나는 경우가 많다(예: B07 "이 대운의 십신은
        // ~이에요."). 아래 마커 중 하나라도 포함되어 있을 때만 조언성
        // 문장으로 판단해 채택하고, 그렇지 않으면 추가하지 않는다.
        const adviceMarkers = [
          '좋아요',
          '좋을',
          '해보세요',
          '해보면',
          '하세요',
          '권해요',
          '추천',
          '도움이',
          '챙기',
          '신경 쓰면',
          '살펴보면',
          '필요해요',
          '유리해요',
          '나아가',
          '준비하면',
          '가꿔가면',
          '다지면',
        ];
        if (adviceMarkers.any((m) => last.contains(m))) {
          return _wrapAdviceForClosing(last);
        }
      }
    }
    return null;
  }

  /// advice/message 소스별로 다른 원문 스타일(완결된 조언 문장 / 쉼표
  /// 나열형 활동 리스트 / 짧은 키워드)을 구분해, 마무리 문단에 자연스럽게
  /// 이어붙일 수 있는 완결된 문장으로 감싼다. 원문 내용(판단·조언)은
  /// 손대지 않고 앞뒤에 붙이는 연결어만 고른다(문자열 조합만, 새 판단
  /// 없음).
  static String _wrapAdviceForClosing(String raw) {
    final s = _soften(raw);
    // 흔한 한국어 문장 종결 어미(요/다/것/함/음, 마침표 유무 무관)로
    // 끝나면 이미 완결된 문장으로 보고 그대로 이어붙인다.
    final endsAsSentence = RegExp(r'(요|다|것|함|음)[.!?]?$').hasMatch(s);
    if (endsAsSentence) {
      final ending = (s.endsWith('.') || s.endsWith('!') || s.endsWith('?'))
          ? s
          : '$s.';
      return '그러니 지금은 $ending';
    }
    if (s.contains(',')) {
      // 쉼표로 나열된 활동/항목 리스트 — "그러니 지금은 ~" 대신 나열임을
      // 알려주는 연결어로 감싼다.
      return '오늘은 이 중 하나라도 챙겨보면 좋아요 — $s.';
    }
    // 짧은 키워드형 — "오늘의 키워드는 '~'" 형태로 감싼다.
    return "오늘의 키워드는 '$s'예요. 이 마음가짐으로 하루를 보내보면 좋아요.";
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
