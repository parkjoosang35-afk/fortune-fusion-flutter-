// 신통방통 정통사주 v3 — L1 팩트 계층 표시 위젯
// 팔자(지장간·십이운성 포함) · 신강약 점수 바 · 용신/희신/기신 · 합충형파해 · 신살·공망
//
// [Option 2 이식] 순수 StatelessWidget(riverpod/dio 의존 없음) - 원본 그대로 이식하되,
// Flutter 3.35.4 코드 표준에 맞춰 deprecated된 withOpacity()만 withValues(alpha:)로 교체.

import 'package:flutter/material.dart';

import '../domain/saju_result.dart' show Pillar;
import '../domain/saju_result_v3.dart';
import 'jeontong_v3_theme.dart';

class Jt3Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Jt3Card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Jt3Colors.deepNight,
        borderRadius: BorderRadius.circular(Jt3Radii.card),
        border: Border.all(color: Jt3Colors.royalGold.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }
}

class Jt3SectionTitle extends StatelessWidget {
  final String text;
  const Jt3SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Jt3Colors.royalGold,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 4주 카드: 간지(한자+한글) · 지장간 · 십이운성
class Jt3PillarGrid extends StatelessWidget {
  final SajuResultV3 facts;
  const Jt3PillarGrid({super.key, required this.facts});

  @override
  Widget build(BuildContext context) {
    final pillars = {
      'year': facts.year,
      'month': facts.month,
      'day': facts.day,
      'hour': facts.hour,
    };
    final qigan = {
      'year': facts.zhiQigan.year,
      'month': facts.zhiQigan.month,
      'day': facts.zhiQigan.day,
      'hour': facts.zhiQigan.hour,
    };
    return Row(
      children: pillars.entries.map((e) {
        final Pillar p = e.value;
        final qg = (qigan[e.key] ?? []).join('·');
        final stage = facts.tenGods['${e.key}_gan'] ?? '';
        return Expanded(
          child: Jt3Card(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Text(
                  _posKr(e.key),
                  style: const TextStyle(
                    color: Jt3Colors.moonSilver,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.kr,
                  style: const TextStyle(
                    color: Jt3Colors.starWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  p.gan + p.zhi,
                  style: const TextStyle(
                    color: Jt3Colors.softGold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  qg.isEmpty ? '—' : qg,
                  style: const TextStyle(
                    color: Jt3Colors.moonSilver,
                    fontSize: 10,
                  ),
                ),
                Text(
                  '십신 $stage',
                  style: const TextStyle(
                    color: Jt3Colors.antiqueGold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _posKr(String k) =>
      {'year': '연주', 'month': '월주', 'day': '일주', 'hour': '시주'}[k] ?? k;
}

/// 신강/신약 100점 바
class Jt3StrengthBar extends StatelessWidget {
  final Strength strength;
  const Jt3StrengthBar({super.key, required this.strength});

  @override
  Widget build(BuildContext context) {
    final score = strength.score.clamp(0, 100);
    return Jt3Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '일간 세력',
                style: TextStyle(color: Jt3Colors.moonSilver, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '${strength.verdict} · $score점',
                style: const TextStyle(
                  color: Jt3Colors.starWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Jt3Colors.charcoal,
              valueColor: const AlwaysStoppedAnimation(Jt3Colors.royalGold),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '판정선: 신강 50↑ · 중화 35~49 · 신약 35↓',
            style: TextStyle(color: Jt3Colors.moonSilver, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// 용신·희신·기신·구신 카드 (사유 포함)
class Jt3YongshinCard extends StatelessWidget {
  final Yongshin ys;
  const Jt3YongshinCard({super.key, required this.ys});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String el, {bool outline = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: outline
            ? Colors.transparent
            : Jt3Colors.element(el).withValues(alpha: 0.2),
        border: Border.all(color: Jt3Colors.element(el)),
        borderRadius: BorderRadius.circular(Jt3Radii.chip),
      ),
      child: Text(
        '$label $el',
        style: TextStyle(color: Jt3Colors.element(el), fontSize: 12),
      ),
    );

    return Jt3Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('용신', ys.yong),
              if (ys.hee != null) chip('희신', ys.hee!),
              chip('기신', ys.gi, outline: true),
              chip('구신', ys.gu, outline: true),
            ],
          ),
          if (ys.yongGroup.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '용신 그룹: ${ys.yongGroup}'
                '${ys.heeGroup != null ? ' · 희신 그룹: ${ys.heeGroup}' : ''}',
                style: const TextStyle(
                  color: Jt3Colors.moonSilver,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 8),
          ...ys.reasons.map(
            (r) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✦ ',
                    style: TextStyle(
                      color: Jt3Colors.antiqueGold,
                      fontSize: 11,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(
                        color: Jt3Colors.moonSilver,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 합·충·형·파·해·원진 배지
class Jt3RelationsChips extends StatelessWidget {
  final Relations relations;
  const Jt3RelationsChips({super.key, required this.relations});

  @override
  Widget build(BuildContext context) {
    final rows = <List<Object>>[
      ['천간합', relations.ganHe],
      ['육합', relations.liuhe],
      ['삼합', relations.sanhe],
      ['반합', relations.sanheHalf],
      ['충', relations.chong],
      ['형', relations.xing],
      ['자형', relations.xingSelf],
      ['파', relations.po],
      ['해', relations.hai],
      ['원진', relations.yuanjin],
    ].where((r) => (r[1] as List<String>).isNotEmpty).toList();

    if (rows.isEmpty) {
      return const Jt3Card(
        child: Text(
          '원국 지지 관계: 특기 관계 없음',
          style: TextStyle(color: Jt3Colors.moonSilver, fontSize: 12),
        ),
      );
    }
    return Jt3Card(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final r in rows)
            for (final item in (r[1] as List<String>))
              _chip('${r[0]} · $item'),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Jt3Colors.amethyst.withValues(alpha: 0.2),
      border: Border.all(color: Jt3Colors.amethyst),
      borderRadius: BorderRadius.circular(Jt3Radii.chip),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Jt3Colors.starWhite, fontSize: 11),
    ),
  );
}

/// 신살·공망 요약
class Jt3SinsalRow extends StatelessWidget {
  final List<String> sinsal;
  final String gongmang;
  const Jt3SinsalRow({
    super.key,
    required this.sinsal,
    required this.gongmang,
  });

  @override
  Widget build(BuildContext context) {
    return Jt3Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '신살: ${sinsal.isEmpty ? '해당 없음' : sinsal.join(', ')}',
            style: const TextStyle(color: Jt3Colors.starWhite, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '공망: $gongmang',
            style: const TextStyle(color: Jt3Colors.moonSilver, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
