import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_token_store.dart';
import '../../../core/domain/access/access_checker.dart';
import '../../pass/presentation/pass_gate_helper.dart';
import '../data/jeontong_profile_store.dart';
import '../domain/jeontong_eighty_matrix.dart';
import 'jeontong_design/hanji_background.dart';
import 'jeontong_design/hanji_design_tokens.dart';
import 'jeontong_design/saju_seal.dart';

/// [정통사주 개편] 홈 화면 "운세" 카드를 탭했을 때 열리는 전용 화면 —
/// 라우트 `/jeontong/eighty`.
///
/// [2026 · 운세 섹션 Dawn Hanji 디자인 통합] 사용자가 실제로 접하는 진입
/// 화면(이 화면 → 결과 화면)이 옛 잉크블랙+골드 다크 테마로 남아 있어
/// `flutter_handoff.zip`(신통방통 디자인 이관본) 디자인이 반영되지 않은
/// 것처럼 보이는 문제를 해결하기 위해, 이 화면 자체를 handoff 원본
/// `screens/saju_list_screen.dart`와 동일한 Dawn Hanji 팔레트/컴포넌트
/// (HanjiBackground/SajuSeal/MonoLabel)로 재스킨한다. 라우팅·게이트 로직
/// (`navigateWithPassGate`)과 카테고리 데이터([JeontongEightyMatrix])는
/// 전혀 변경하지 않는다 — 오직 시각적 표현만 교체한다.
///
/// [프로필 관통 배선] 기존에는 이 화면에서 결과 화면으로 곧장 이동하며
/// 4축(생년월일시/성별/음양력)을 전혀 전달하지 않아, 결과 화면의 실계산
/// 상세 섹션([JeontongSajuDetailSection])이 항상 숨겨지는 문제가 있었다.
/// 이제 카테고리를 탭하면 저장된 프로필([jeontongProfileStore])이 있는지
/// 먼저 확인해, 없으면 입력 화면(`/jeontong/input`)으로 먼저 보내고(선택한
/// 카테고리 id를 그대로 넘겨 입력 완료 후 자동으로 이어지게 함), 있으면
/// 기존과 동일하게 `navigateWithPassGate`로 결과 화면으로 바로 이동한다.
///
/// [백엔드 결정 - A안] 사용자가 "a"(클라이언트 룰베이스, 백엔드 미배포)를
/// 선택했으므로 이 화면은 신규 서버 API를 호출하지 않는다. 데이터는
/// [JeontongEightyMatrix](정적 카탈로그)만 사용하고, 실제 결과 콘텐츠는
/// [JeontongEightyResultScreen]에서 [JeontongReportBuilder](결정론적 룰베이스
/// 생성기)로 만든다.
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
  /// 처음 진입 시 A(평생운) 그룹만 펼쳐두고, 나머지는 접어서 전체 항목이
  /// 한 화면에 쏟아지지 않게 한다(사용자가 원하는 대/소카테고리 탐색 흐름).
  JeontongMajorCode _expanded = JeontongMajorCode.a;

  String get _userId =>
      (AuthTokenStore.cachedUserIdOrNull ?? AuthTokenStore.fallbackUserId)
          .toString();

  Future<void> _onTapItem(JeontongCategoryEntry entry) async {
    // [프로필 관통 배선] 아직 생년월일시를 입력한 적이 없으면 결과 화면
    // 대신 입력 화면으로 먼저 보낸다 — 게이트 체크(로그인/프리패스)는
    // 입력 완료 뒤 실제 결과로 넘어가는 시점에 그대로 수행된다(아래
    // JeontongInputScreen._onSubmit 참고).
    final profile = await jeontongProfileStore.get(_userId);
    if (!mounted) return;
    if (profile == null) {
      await Navigator.of(
        context,
      ).pushNamed('/jeontong/input', arguments: entry.id);
      return;
    }
    // [운세 섹션 4단계 흐름 - 화면3 로딩] 게이트 체크를 통과한 뒤 결과로
    // 곧장 가지 않고, 반드시 로딩 화면(JeontongEightyLoadingScreen)을 먼저
    // 보여준다. 로딩 화면이 애니메이션 완료 후 스스로 결과 화면으로
    // `pushReplacementNamed`한다(navigateWithPassGate 로직 자체는 무변경 —
    // 목적지 라우트만 resultRoute → loadingRoute로 교체).
    await navigateWithPassGate(
      context,
      title: entry.title,
      route: JeontongEightyMatrix.loadingRoute,
      requiresPass: true,
      arguments: entry.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPass = context.watch<AccessChecker>().isOpenPassActive();

    return Scaffold(
      body: HanjiBackground(
        sigilOpacity: 0.14,
        child: SafeArea(
          child: Column(
            children: [
              _Header(hasPass: hasPass),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    HanjiSpacing.lg,
                    HanjiSpacing.sm,
                    HanjiSpacing.lg,
                    HanjiSpacing.xxl,
                  ),
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.hasPass});
  final bool hasPass;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HanjiSpacing.lg,
        HanjiSpacing.sm,
        HanjiSpacing.lg,
        HanjiSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkResponse(
            onTap: () => Navigator.of(context).maybePop(),
            radius: 22,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HanjiColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: HanjiColors.line),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: HanjiColors.fg,
              ),
            ),
          ),
          const SizedBox(width: HanjiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MonoLabel('◈ SINTONG · 정통사주'),
                const SizedBox(height: 4),
                Text(
                  '정통사주 ${JeontongEightyMatrix.all.length}종',
                  style: HanjiTextStyles.display2().copyWith(fontSize: 22),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPass
                      ? '프리패스로 자유 이용 중'
                      : '프리패스 하나로 ${JeontongEightyMatrix.all.length}가지 전부 무제한',
                  style: HanjiTextStyles.bodySmall(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 대카테고리 1개 섹션 — 헤더(인장+이름+설명+개수+화살표) 탭 시 펼침/접힘,
/// 펼쳐진 상태에서만 소카테고리를 2열 그리드로 렌더링한다.
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
      margin: const EdgeInsets.only(bottom: HanjiSpacing.md),
      decoration: BoxDecoration(
        color: HanjiColors.card,
        borderRadius: BorderRadius.circular(HanjiRadii.hero),
        border: Border.all(
          color: isOpen
              ? HanjiColors.glow.withValues(alpha: 0.55)
              : HanjiColors.line,
          width: isOpen ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(HanjiRadii.hero),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(HanjiSpacing.md),
              child: Row(
                children: [
                  SajuSeal(glyph: group.code.hanja, size: 40),
                  const SizedBox(width: HanjiSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${group.code.letter}. ${group.code.title}',
                              style: HanjiTextStyles.bodyTitle().copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: HanjiColors.glow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  HanjiRadii.pill,
                                ),
                              ),
                              child: Text(
                                '${group.items.length}개',
                                style: HanjiTextStyles.monoSmall(
                                  color: HanjiColors.accent,
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
                          style: HanjiTextStyles.bodySmall(),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: HanjiColors.muted,
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
              padding: const EdgeInsets.fromLTRB(
                HanjiSpacing.md,
                0,
                HanjiSpacing.md,
                HanjiSpacing.md,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: group.items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: HanjiSpacing.sm,
                  crossAxisSpacing: HanjiSpacing.sm,
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

/// 소카테고리 1개 카드 — 코드(A01) + 제목, 좁은 가로형 카드.
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
        padding: const EdgeInsets.symmetric(
          horizontal: HanjiSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: HanjiColors.bg1,
          borderRadius: BorderRadius.circular(HanjiRadii.chip),
          border: Border.all(color: HanjiColors.line),
        ),
        child: Row(
          children: [
            Text(
              entry.id,
              style: HanjiTextStyles.monoSmall(color: HanjiColors.accent),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HanjiTextStyles.ui(weight: FontWeight.w600),
              ),
            ),
            if (locked)
              const Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: HanjiColors.muted,
              ),
          ],
        ),
      ),
    );
  }
}
