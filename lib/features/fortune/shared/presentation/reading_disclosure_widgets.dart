// [v7.2 원칙] "재미와 자기성찰을 위한 풀이"라는 고지문과, 전통 상법/서양
// 수상 전통 출전을 "(요지)" 배지 + "원문 인용이 아닙니다" 설명과 함께 보여주는
// 공용 위젯 2종. 디자인 핸드오프 CiteCard.jsx(빨간 점선 테두리 + "(요지)" 배지)
// 1:1 포팅. ResultCardStack 등 기존 공용 컴포넌트는 건드리지 않고, 이 위젯들은
// 그 "바깥"(섹션 리스트에 끼워 넣거나 보관함 화면 등)에서 독립적으로 쓴다.
library;

import 'package:flutter/material.dart';
import '../domain/reading_artifact.dart';

/// 화면 상단/하단에 붙이는 공용 고지문. v7.2: 모든 관상/손금 관련 화면에
/// 반드시 표시해야 한다("정통 사주처럼 결정론적 계산이 아니라 전통 상법에
/// 기반한 해석적 콘텐츠"임을 분명히 함 — 오인 방지).
class ReadingFunDisclaimer extends StatelessWidget {
  const ReadingFunDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x0F8A8880),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x268A8880)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: Color(0xFF8A8880),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '재미와 자기성찰을 위한 풀이예요. 전통 상법의 일반론을 바탕으로 한 해석적 콘텐츠이며, 의학적·과학적 사실 판정이 아니에요.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: const Color(0xFF8A8880),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 출전(CiteRef)을 "(요지)" 배지와 함께 보여주는 카드. v7.2: 빨간 점선
/// 테두리 + "원문을 그대로 인용한 것이 아니라 요지를 정리한 것"이라는
/// 고지를 항상 동반한다 — 전통 문헌의 권위를 빌리되 오인용 책임을 지지
/// 않도록 하는 핵심 안전장치.
class ReadingCiteCard extends StatelessWidget {
  const ReadingCiteCard({super.key, required this.cite});
  final CiteRef cite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0x99C94A3B),
          style: BorderStyle.solid,
          width: 1,
        ),
        color: const Color(0x08C94A3B),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                cite.srcKo != null ? '${cite.src} · ${cite.srcKo}' : cite.src,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC94A3B),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1FC94A3B),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '(요지)',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC94A3B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            cite.text,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: Color(0xFF6B5B52),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '원문을 그대로 인용한 것이 아니라 요지를 정리한 것입니다.',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFFB0A89E),
            ),
          ),
        ],
      ),
    );
  }
}

/// [v7 통합 — TotalScreens.jsx 포팅] 총결과 화면 히어로 카드 하단에 붙이는
/// "KeySeal(총평 인장) + ProofStrip(근거 요약) + 출전" 블록. 사진/좌표 없이
/// 텍스트 집계값(검출 부위 수·관찰 건수·문헌 수)만 사용한다(Option B 원칙).
/// face_result_screen.dart/palm_result_screen.dart의 heroExtra에 쓰인다.
class ReadingTotalHeroExtra extends StatelessWidget {
  const ReadingTotalHeroExtra({super.key, required this.artifact});
  final ReadingArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final total = artifact.total;
    final citeCount = artifact.steps.where((s) => s.cite != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFC94A3B),
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40C94A3B),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                total.key,
                style: const TextStyle(
                  fontFamily: 'NotoSerifKR',
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Color(0xFFFFF9E8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                total.keyKo,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B5B52),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '◈ 엔진 관찰 · 전통 문헌 요지로 풀이해요',
          style: const TextStyle(
            fontSize: 9.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7BA896),
          ),
        ),
        const SizedBox(height: 8),
        _ProofStrip(
          items: [
            ('검출 부위', '${artifact.interpretedCount}'),
            ('관찰 항목', '${artifact.measuredCount}'),
            ('출전', '$citeCount건'),
          ],
        ),
        if (total.cite != null) ...[
          const SizedBox(height: 10),
          ReadingCiteCard(cite: total.cite!),
        ],
      ],
    );
  }
}

class _ProofStrip extends StatelessWidget {
  const _ProofStrip({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1F3C2D1E)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    left: i == 0
                        ? BorderSide.none
                        : const BorderSide(color: Color(0x1F3C2D1E)),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      items[i].$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF2A1F14),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$1,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: Color(0xFF8A8880),
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

/// 부위 검출(구 "일치도") 배지 — v7.2 라벨 교정: 랜드마크 검출 신뢰도라는
/// 가장 보수적인 의미로만 표시한다. null이면 아무것도 그리지 않는다(없는
/// 통계를 만들어내지 않는다는 원칙).
class ReadingDetectionBadge extends StatelessWidget {
  const ReadingDetectionBadge({super.key, required this.confidence});
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final c = confidence;
    if (c == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1F8A8880),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '부위 검출 ${(c * 100).round()}%',
        style: const TextStyle(fontSize: 10, color: Color(0xFF6B5B52)),
      ),
    );
  }
}
