// ============================================================
// [정통사주 69종 · Dawn Hanji 디자인 통합] 실계산 원국 상세 섹션.
//
// [절대 원칙] 이 파일은 새로운 사주 계산을 하지 않는다. 이미 검증된
// PHASE1~4 파이프라인(JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4)
// → SajuInterpreter.fullInterpretation() 결과만 조회해, 13개 Hanji 디자인
// 위젯(PillarBoard/DayMasterCard/WuxingBalance/SipShinGrid/DaewoonTimeline/
// CurrentDaewoonCard/SeunGrid/TodayCard×2/AdviceScroll×3/HanjiActionButtons)
// 에 그대로 전달해 렌더링한다.
//
// [프로필 없음 방어] birthDateTimeUtc가 없거나(아직 입력 전) 계산 도중
// 어떤 이유로든 예외가 발생하면 SizedBox.shrink()를 반환해 기존
// FortuneReport 기반 렌더링만 보여준다 — 결과 화면이 절대 깨지지 않는다
// (jeontong_eighty_report_builder.dart의 _tryBuildRealReport와 동일한
// 방어적 안전망 패턴).
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/jeontong_eighty_report_builder.dart';
import '../../domain/manseryeok/saju_profile.dart' show SajuProfile;
import '../../domain/saju_engine.dart' show SajuResult;
import '../../domain/saju_fortune_modules.dart'
    show getMonthlyFortune, getDailyFortune;
import '../../domain/saju_fortune_rules.dart';
import '../../domain/saju_interpreter.dart'
    show SajuInterpreter, SajuFullInterpretation, SajuRules;
import '../../../../core/data/my_fortune_record_store.dart';
import 'advice_scroll.dart';
import 'daewoon_timeline.dart';
import 'day_master_card.dart';
import 'hanji_action_buttons.dart';
import 'hanji_design_tokens.dart';
import 'pillar_board.dart';
import 'saju_seal.dart';
import 'seun_grid.dart';
import 'sip_shin_grid.dart';
import 'today_card.dart';
import 'wuxing_balance.dart';

/// [entry.title]/[categoryLabel]은 저장 레코드용, [birthDateTimeUtc]/
/// [gender]/[isLunar]는 4축 그대로, [referenceDate]는 "오늘" 기준 시점.
///
/// 하나라도 준비가 안 됐거나(rules 미로드, birthDateTimeUtc null) 계산이
/// 실패하면 아무것도 렌더링하지 않는다(SizedBox.shrink()).
class JeontongSajuDetailSection extends StatelessWidget {
  const JeontongSajuDetailSection({
    super.key,
    required this.categoryLabel,
    required this.birthDateTimeUtc,
    required this.gender,
    required this.isLunar,
    required this.referenceDate,
  });

  final String categoryLabel;
  final DateTime? birthDateTimeUtc;
  final String? gender;
  final bool? isLunar;
  final DateTime referenceDate;

  @override
  Widget build(BuildContext context) {
    final built = _tryBuild();
    if (built == null) return const SizedBox.shrink();
    final (saju, profile, interp) = built;

    final fortuneRules = SajuFortuneRules.cachedOrNull;
    final monthly = fortuneRules != null
        ? getMonthlyFortune(
            saju,
            fortuneRules,
            year: referenceDate.year,
            month: referenceDate.month,
          )
        : null;
    final daily = fortuneRules != null
        ? getDailyFortune(
            saju,
            fortuneRules,
            year: referenceDate.year,
            month: referenceDate.month,
            day: referenceDate.day,
          )
        : null;

    final children = <Widget>[
      Row(children: [MonoLabel('◈ 사주 원국 · 실계산 상세', color: HanjiColors.accent)]),
      const SizedBox(height: HanjiSpacing.md),
      PillarBoard(pillarsByPosition: profile.pillarsByPosition),
      const SizedBox(height: HanjiSpacing.lg),
      DayMasterCard(
        dayMaster: saju.dayMaster,
        analysis: interp.dayMasterAnalysis,
      ),
      const SizedBox(height: HanjiSpacing.lg),
      WuxingBalance(counts: saju.fiveElementsCount),
      const SizedBox(height: HanjiSpacing.lg),
      SipShinGrid(items: interp.tenGodsAnalysis.details),
      const SizedBox(height: HanjiSpacing.lg),
    ];

    if (saju.luckPillars.isNotEmpty) {
      children.addAll([
        MonoLabel('◈ 대운 · DAEWOON TIMELINE', color: HanjiColors.accent),
        const SizedBox(height: HanjiSpacing.sm),
        DaewoonTimeline(daewoon: saju.luckPillars, currentAge: saju.currentAge),
        const SizedBox(height: HanjiSpacing.md),
        if (saju.currentLuck != null) ...[
          CurrentDaewoonCard(d: saju.currentLuck!),
          const SizedBox(height: HanjiSpacing.lg),
        ],
      ]);
    }

    final yongsin = profile.yongsin;
    final wolwoon = profile.wolwoon;
    if (yongsin != null && wolwoon != null && wolwoon.isNotEmpty) {
      children.addAll([
        SeunGrid(wolwoon: wolwoon, yongsin: yongsin, year: wolwoon.first.year),
        const SizedBox(height: HanjiSpacing.lg),
      ]);

      if (monthly != null) {
        final mChars = monthly.monthGanZhi.split(' ').first;
        final mGan = mChars.isNotEmpty ? mChars.substring(0, 1) : '';
        final mZhi = mChars.length >= 2 ? mChars.substring(1, 2) : '';
        children.addAll([
          TodayCard(
            period: '이달 · ${referenceDate.month}월',
            ganjiLabel: '$mChars月',
            text: monthly.overall,
            tone: toneForGanZhiHanja(mGan, mZhi, yongsin),
          ),
          const SizedBox(height: HanjiSpacing.md),
        ]);
      }
      if (daily != null) {
        final dChars = daily.dayGanZhi.split(' ').first;
        final dGan = dChars.isNotEmpty ? dChars.substring(0, 1) : '';
        final dZhi = dChars.length >= 2 ? dChars.substring(1, 2) : '';
        children.addAll([
          TodayCard(
            period:
                '오늘 · ${referenceDate.month.toString().padLeft(2, '0')}.${referenceDate.day.toString().padLeft(2, '0')}',
            ganjiLabel: '$dChars日',
            text: daily.overall,
            tone: toneForGanZhiHanja(dGan, dZhi, yongsin),
          ),
          const SizedBox(height: HanjiSpacing.lg),
        ]);
      }
    }

    final advice = buildAdviceItemsFrom(interp);
    for (final item in advice) {
      children.addAll([
        AdviceScroll(advice: item),
        const SizedBox(height: HanjiSpacing.md),
      ]);
    }
    children.add(const SizedBox(height: HanjiSpacing.sm));

    children.add(
      HanjiActionButtons(
        buildRecord: () => SavedFortuneRecord(
          id: 'jeontong80_hanji_${categoryLabel}_${DateTime.now().toIso8601String().substring(0, 10)}',
          categoryLabel: categoryLabel,
          title: '${saju.dayMaster.kr}(${saju.dayMaster.image}) 일간 원국',
          summary: interp.dayMasterAnalysis.personality,
          score: 0,
          date: referenceDate,
          savedAt: DateTime.now(),
        ),
        buildShareText: () =>
            '[$categoryLabel] ${saju.dayMaster.kr}(${saju.dayMaster.image}) 일간 · '
            '${interp.dayMasterAnalysis.personality}',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  (SajuResult, SajuProfile, SajuFullInterpretation)? _tryBuild() {
    final utc = birthDateTimeUtc;
    if (utc == null) return null;
    try {
      final rules = SajuRules.cachedOrNull;
      if (rules == null) return null;
      final kst = utc.add(const Duration(hours: 9));
      final sajuGender = gender == 'F' || gender == 'female'
          ? 'female'
          : 'male';
      final built = JeontongReportBuilder.buildProfileAndSajuResultViaPhase1to4(
        kst: kst,
        gender: sajuGender,
        isLunar: isLunar ?? false,
        referenceDate: referenceDate,
      );
      final interp = SajuInterpreter.fullInterpretation(built.saju);
      return (built.saju, built.profile, interp);
    } catch (_) {
      return null;
    }
  }
}
