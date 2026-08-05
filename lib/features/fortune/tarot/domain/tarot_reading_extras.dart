/// [AI 타로 리딩 UX/UI 개선] 결과 화면 연출(§6 "리딩 결과" 7단계)에 필요한
/// "한 줄 운세 / 오늘의 조언 / 행운의 색 / 행운의 숫자 / AI 한마디" 부가 콘텐츠를
/// 서버 응답([TarotResultModel])만으로 클라이언트에서 파생 생성한다.
///
/// [설계 원칙] 신규 백엔드 API/필드를 추가하지 않고(과설계 방지), 이미 존재하는
/// [TarotTextEngine]의 ADVICE_LINES/CLOSERS 문장 풀과 [AppColors.luckColorPalette]를
/// 그대로 재사용한다. 모든 값은 [TarotResultModel.id]를 시드로 하는 결정론적
/// 난수로 고정되어, 같은 결과를 히스토리에서 다시 열어도 항상 동일하게 재현된다.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'tarot_model.dart';
import 'tarot_text_engine.dart';

class TarotReadingExtras {
  TarotReadingExtras._();

  static Random _rngFor(String id, int salt) => Random(id.hashCode ^ salt);

  /// 총평(summary, 서버 LLM 생성 텍스트)의 첫 문장을 "한 줄 운세"로 추출한다.
  static String oneLiner(String summary) {
    final trimmed = summary.trim();
    if (trimmed.isEmpty) return '카드가 조용히 메시지를 전하고 있어요.';
    final match = RegExp(r'[^.!?\n]+[.!?]?').firstMatch(trimmed);
    var line = (match?.group(0) ?? trimmed).trim();
    if (line.length > 46) line = '${line.substring(0, 46)}...';
    return line;
  }

  /// [topic]에 대응하는 기존 [TarotTextEngine.ADVICE_LINES] 풀에서 "오늘의
  /// 조언" 한 줄을 결정론적으로 선택한다(신규 문장 풀을 만들지 않는다).
  static String advice(String id, String topic) {
    final pools = TarotTextEngine.ADVICE_LINES;
    final pool = pools[topic] ?? pools['general']!;
    return pool[_rngFor(id, 0x41).nextInt(pool.length)];
  }

  /// 기존 [TarotTextEngine.CLOSERS](공용 마무리 문장 5개, 확정적 미래예단
  /// 표현 없음이 이미 검증된 문구 풀)를 "AI 한마디"로 재사용한다.
  static String aiClosing(String id) {
    final pool = TarotTextEngine.CLOSERS;
    return pool[_rngFor(id, 0x43).nextInt(pool.length)];
  }

  /// 기존 [AppColors.luckColorPalette](보라/골드/블루/그린) 중 하나를
  /// "행운의 색"으로 선택한다.
  static ({String name, Color color}) luckyColor(String id) {
    final entries = AppColors.luckColorPalette.entries.toList();
    final picked = entries[_rngFor(id, 0x4C).nextInt(entries.length)];
    return (name: picked.key, color: picked.value);
  }

  /// 1~99 사이의 "행운의 숫자"를 결정론적으로 생성한다.
  static int luckyNumber(String id) => 1 + _rngFor(id, 0x4E).nextInt(99);

  /// [타로 섹션 전면 개편 §11 P4] "내 운세 기록"/공유카드에 표시할 62~97
  /// 사이의 점수. 타로 결과에는 원래 숫자 점수 개념이 없으므로, 다른
  /// 파생값과 동일하게 결과 id를 시드로 하는 결정론적 난수로 생성해
  /// 저장/공유할 때마다 같은 결과가 항상 같은 점수를 보이게 한다.
  static int readingScore(String id) => 62 + _rngFor(id, 0x50).nextInt(36);

  /// [타로 섹션 전면 개편 §11 P4 심화해석] 히어로 카드 1장을 "감정/현실/
  /// 미래"라는 3가지 다른 관점으로 다시 풀어본 해석 3개를 생성한다.
  /// 신규 문장 풀을 만들지 않고, 이미 검증된
  /// [TarotTextEngine.generateCardInterpretation]을 결과 id 기반의 서로
  /// 다른 시드 3개로 호출해 "같은 카드, 다른 결"이라는 심화해석 컨셉을
  /// 구현한다(과설계 방지 - 서버 API 추가 없이 클라이언트에서 파생).
  static List<({String label, String text})> deepDivePerspectives(
    TarotCard card,
    String topic,
    String id,
  ) {
    const labels = ['마음의 관점', '현실의 관점', '흐름의 관점'];
    return List.generate(3, (i) {
      final seed = id.hashCode ^ (0x60 + i * 7) ^ card.name.hashCode;
      final text = TarotTextEngine.generateCardInterpretation(
        card,
        topic,
        seed: seed,
      );
      return (label: labels[i], text: text);
    });
  }

  /// [§11 P4 심화해석] 기존 [TarotTextEngine.CAUTION_LINES] 풀에서 "주의할
  /// 점" 한 줄을 결정론적으로 선택한다(신규 문장 풀 없음).
  static String caution(String id, String topic) {
    final pools = TarotTextEngine.CAUTION_LINES;
    final pool = pools[topic] ?? pools['general']!;
    return pool[_rngFor(id, 0x66).nextInt(pool.length)];
  }
}
