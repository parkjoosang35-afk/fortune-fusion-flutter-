import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/domain/access/access_checker.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../domain/jeontong_eighty_matrix.dart';

/// [정통사주 80종 개편] 홈 화면 "운세" 카드를 탭했을 때 열리는 전용 화면 —
/// 라우트 `/jeontong/eighty`.
///
/// [사용자 최종 확정 요구사항] "ai관상 ai손금 ai타로는 상담은 다 살려놓고
/// 나머지 운세는 다삭제 후 정통사주 80가지로 대체" + "운세섹션 클릭시 요
/// 80종을 대카테고리 소카테고리 나눠서 진열". 기존 `jeontong_saju_section.dart`
/// (8종 고정 바텀시트)를 대체하는 화면으로, 대카테고리(A~H, 8개) 아코디언 안에
/// 소카테고리(각 10개, 총 80개)를 2열 그리드로 진열한다.
///
/// [백엔드 결정 - A안] 사용자가 "a"(클라이언트 룰베이스, 백엔드 미배포)를
/// 선택했으므로 이 화면은 신규 서버 API를 호출하지 않는다. 데이터는
/// [JeontongEightyMatrix](정적 카탈로그)만 사용하고, 실제 결과 콘텐츠는
/// [JeontongEightyResultScreen]에서 [JeontongReportBuilder](결정론적 룰베이스
/// 생성기)로 만든다.
///
/// [게이트/네비게이션 원칙] 신규 Provider/게이트 클래스를 추가하지 않고 기존
/// `navigateWithPassGate`(요청 시 프리패스 게이트 체크 → 로그인 유도/프리패스
/// 유도 → 통과 시 라우팅)를 그대로 재사용한다. 80종 전부 `requiresPass: true`로
/// 통일한다(기존 8종 바텀시트에 있던 "80가지 운세 · 프리패스 하나로 무제한"
/// 문구와 동일한 정책).
///
/// [영향 범위 안전망] AI 타로/관상/손금/상담, 결제/구독/지갑/광고,
/// 사용자 기록/프로필/북마크 데이터는 이 화면에서 전혀 참조하지 않는다.
/// 기존 "정통사주" 진입점 2곳(all_categories_screen의 2x2 그리드,
/// home_screen 칩 로우의 '정통사주' 칩)은 계속 `/ai-fortune/saju/input`으로만
/// 이동하며 이 화면과 무관하다(별도 진입점 유지, 변경 없음).
class JeontongEightyScreen extends StatefulWidget {
  const JeontongEightyScreen({super.key});

  @override
  State<JeontongEightyScreen> createState() => _JeontongEightyScreenState();
}

class _JeontongEightyScreenState extends State<JeontongEightyScreen> {
  /// 처음 진입 시 A(평생운) 그룹만 펼쳐두고, 나머지는 접어서 80개 항목이
  /// 한 화면에 쏟아지지 않게 한다(사용자가 원하는 대/소카테고리 탐색 흐름).
  JeontongMajorCode _expanded = JeontongMajorCode.a;

  Future<void> _onTapItem(JeontongCategoryEntry entry) async {
    await navigateWithPassGate(
      context,
      title: entry.title,
      route: JeontongEightyMatrix.resultRoute,
      requiresPass: true,
      arguments: entry.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPass = context.watch<AccessChecker>().isOpenPassActive();

    return Scaffold(
      backgroundColor: _JStyle.inkBlack,
      body: SafeArea(
        child: Column(
          children: [
            _Header(hasPass: hasPass),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: JeontongEightyMatrix.groups.length,
                itemBuilder: (context, index) {
                  final group = JeontongEightyMatrix.groups[index];
                  final isOpen = _expanded == group.code;
                  return _MajorGroupSection(
                    group: group,
                    isOpen: isOpen,
                    hasPass: hasPass,
                    // 이미 열려있는 그룹을 다시 탭해도 그대로 유지한다(항상
                    // 최소 1개 그룹은 펼쳐져 있게 해 "전부 닫힘"인 빈 화면
                    // 상태를 만들지 않는다).
                    onToggle: () => setState(() => _expanded = group.code),
                    onTapItem: _onTapItem,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JStyle {
  _JStyle._();
  static const inkBlack = Color(0xFF0A0A0F);
  static const deepNight = Color(0xFF12121A);
  static const royalGold = Color(0xFFD4AF37);
  static const amethyst = Color(0xFF6B4E9E);
  static const starWhite = Color(0xFFF8F5E6);
  static const moonSilver = Color(0xFFC0C0C8);
}

class _Header extends StatelessWidget {
  const _Header({required this.hasPass});
  final bool hasPass;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _JStyle.deepNight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _JStyle.starWhite,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '정통사주 80종',
                  style: GoogleFonts.nanumMyeongjo(
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _JStyle.royalGold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPass ? '프리패스로 자유 이용 중' : '프리패스 하나로 80가지 전부 무제한',
                  style: GoogleFonts.notoSansKr(
                    textStyle: const TextStyle(
                      fontSize: 12,
                      color: _JStyle.moonSilver,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 대카테고리 1개 섹션 — 헤더(한자+이름+설명+개수+화살표) 탭 시 펼침/접힘,
/// 펼쳐진 상태에서만 소카테고리 10개를 2열 그리드로 렌더링한다.
class _MajorGroupSection extends StatelessWidget {
  const _MajorGroupSection({
    required this.group,
    required this.isOpen,
    required this.hasPass,
    required this.onToggle,
    required this.onTapItem,
  });

  final JeontongMajorGroup group;
  final bool isOpen;
  final bool hasPass;
  final VoidCallback onToggle;
  final void Function(JeontongCategoryEntry entry) onTapItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _JStyle.deepNight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _JStyle.royalGold.withValues(alpha: isOpen ? 0.35 : 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _JStyle.inkBlack,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _JStyle.royalGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      group.code.hanja,
                      style: GoogleFonts.nanumMyeongjo(
                        textStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _JStyle.royalGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${group.code.letter}. ${group.code.title}',
                              style: GoogleFonts.notoSansKr(
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _JStyle.starWhite,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _JStyle.amethyst.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${group.items.length}개',
                                style: GoogleFonts.notoSansKr(
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    color: _JStyle.moonSilver,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          group.code.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSansKr(
                            textStyle: const TextStyle(
                              fontSize: 11,
                              color: _JStyle.moonSilver,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _JStyle.moonSilver,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isOpen
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: group.items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                ),
                itemBuilder: (context, i) {
                  final entry = group.items[i];
                  return _MinorCategoryCard(
                    entry: entry,
                    locked: !hasPass,
                    onTap: () => onTapItem(entry),
                  );
                },
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

/// 소카테고리 1개 카드 — 코드(A01) + 제목, 좁은 가로형 카드(2.4 가로세로비).
class _MinorCategoryCard extends StatelessWidget {
  const _MinorCategoryCard({
    required this.entry,
    required this.locked,
    required this.onTap,
  });

  final JeontongCategoryEntry entry;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _JStyle.inkBlack,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _JStyle.royalGold.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Text(
              entry.id,
              style: GoogleFonts.notoSansKr(
                textStyle: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _JStyle.royalGold.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSansKr(
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _JStyle.starWhite,
                  ),
                ),
              ),
            ),
            if (locked)
              const Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: _JStyle.moonSilver,
              ),
          ],
        ),
      ),
    );
  }
}
