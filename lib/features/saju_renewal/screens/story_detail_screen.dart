import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../data/models/interpret_result.dart';
import '../data/models/topic_card.dart';
import '../data/saju_term_dictionary.dart';
import '../data/saju_visual_adapter.dart';
import '../../auth/application/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../state/saju_renewal_provider.dart';
import '../theme/saju_dark_tokens.dart';
import '../widgets/saju_base_widgets.dart';
import '../widgets/saju_story_widgets.dart';
import '../widgets/saju_visual_widgets.dart';
import 'more_stories_screen.dart';

/// [신통방통 정통사주 리뉴얼 — 다크 디자인 핸드오프] 화면⑦ 상세 사주
/// 해석. `design_files/saju/screens-b.jsx`의 `ScreenDetail`을 재현한다 —
/// 5단 서사(핵심·왜·생활·시기·포인트) + 목차 칩 + 블록 사이 근거 +
/// 시기(n=4) 블록 전용 대운 스트림 카드.
///
/// [블록 제목 — 서버 비전달 필드] [InterpretDetailBlock]에는 제목(JSX의
/// `b.t`) 필드가 없다 — admin_web API 계약서(docs/11)에도 블록 제목은
/// `n`(1~5) 순번만 내려주고, 화면이 고정 라벨 ['핵심','왜','생활','시기',
/// '포인트']을 순번에 매핑해 표시하도록 설계되어 있다(JSX 원본도 동일하게
/// `['핵심','왜','생활','시기','포인트'][b.n-1]`로 인덱스 매핑). 서버가
/// 임의 문자열을 내려주는 게 아니므로 이 고정 라벨은 "Flutter 임의
/// 판단"이 아니라 디자인 핸드오프 사양 그대로다.
///
/// [내부 정보 비노출 — 절대 원칙] MONEY_002/LIFE_004 같은 topic_id,
/// FACT 키, score, 69종 코드, evaluator, "AI" 표현 등을 이 화면에 절대
/// 노출하지 않는다. 서버가 이미 `interpret-qa-check.ts`로 이런 표현을
/// 걸러내 보장하지만, 이 화면도 [InterpretDetailBlock.body] 텍스트만
/// 그대로 렌더링하고 별도의 내부 식별자를 화면에 추가하지 않는다.
class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({super.key});

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

const List<String> _kBlockLabels = ['핵심', '왜', '생활', '시기', '포인트'];

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  SajuVisualProfile? _profile;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _profile = _buildProfile(user);
  }

  SajuVisualProfile? _buildProfile(UserModel? user) {
    if (user == null || user.birthDate == null) return null;
    final parts = user.birthDate!.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final timeUnknown = user.birthTimeUnknown || user.birthTime == null;
    int hour = 0;
    if (!timeUnknown && user.birthTime != null) {
      final t = user.birthTime!.split(':');
      hour = int.tryParse(t.isNotEmpty ? t[0] : '') ?? 0;
    }
    return SajuVisualAdapter.build(
      kst: DateTime(y, m, d, hour, 0),
      gender: user.gender ?? 'female',
      isLunar: user.isLunar,
      timeUnknown: timeUnknown,
      referenceDate: DateTime.now(),
      isLeapMonth: user.isLeapMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SajuRenewalProvider>();
    final detailState = provider.detailState;
    final topic = provider.currentTopic;
    final ordinal = provider.viewedStoryCount + 1;
    final scene = topic?.scene;

    return Scaffold(
      body: SajuTermScope(
        onOpenTerm: (termKey) {
          final term = sajuTermLookup(termKey);
          if (term == null) return;
          showSajuTermSheet(
            context,
            termLabel: term.sheetTitle,
            definition: term.note,
          );
        },
        child: Container(
          color: SajuInk.i900,
          child: Stack(
            children: [
              if (scene != null)
                Positioned.fill(
                  child: SajuSceneBg(scene: scene, strength: 0.55),
                ),
              SafeArea(
                child: Builder(
                  builder: (context) {
                    if (detailState.isLoading || detailState.isInitial) {
                      return Column(
                        children: [
                          SajuTopBar(
                            left: SajuIconButton(
                              icon: '←',
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            title: 'DETAIL · 07',
                          ),
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: SajuGold.g300,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    if (detailState.isError) {
                      return Column(
                        children: [
                          SajuTopBar(
                            left: SajuIconButton(
                              icon: '←',
                              onTap: () => Navigator.of(context).maybePop(),
                            ),
                            title: 'DETAIL · 07',
                          ),
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Text(
                                  detailState.errorMessage ??
                                      '이야기를 불러오지 못했습니다.',
                                  style: SajuType.body14,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    final detail = detailState.data!;
                    // JSX: n===4인데 timing(luckIndex)이 없으면 그 블록은
                    // 서버가 애초에 시기 Fact를 못 찾은 것이므로 제외한다.
                    final blocks = detail.blocks
                        .where((b) => !(b.n == 4 && b.luckIndex == null))
                        .toList();

                    return Column(
                      children: [
                        // 스크롤 아래에서도 떠 있는 상단바(JSX position:sticky
                        // + backdrop-blur).
                        ClipRect(
                          child: BackdropFilter(
                            filter: const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.multiply,
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xEB111111),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: SajuTopBar(
                                left: SajuIconButton(
                                  icon: '←',
                                  onTap: () => Navigator.of(context).maybePop(),
                                ),
                                title: 'DETAIL · 07',
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 160),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    18,
                                    22,
                                    0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (scene != null)
                                        _SceneTag(
                                          scene: scene,
                                          ordinal: ordinal,
                                        ),
                                      const SizedBox(height: 12),
                                      Text(
                                        detail.title,
                                        style: const TextStyle(
                                          fontFamily: SajuType.serif,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 26,
                                          height: 1.35,
                                          color: SajuGold.g100,
                                          letterSpacing: -0.03 * 26,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 목차 칩.
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    18,
                                    22,
                                    6,
                                  ),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: List.generate(blocks.length, (i) {
                                      final b = blocks[i];
                                      final label = (b.n >= 1 && b.n <= 5)
                                          ? _kBlockLabels[b.n - 1]
                                          : '';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: SajuText.line,
                                          ),
                                        ),
                                        child: Text(
                                          '${(i + 1).toString().padLeft(2, '0')} $label',
                                          style: const TextStyle(
                                            fontFamily: SajuType.ui,
                                            fontSize: 11,
                                            color: SajuText.muted,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    10,
                                    22,
                                    0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: List.generate(blocks.length, (i) {
                                      final b = blocks[i];
                                      return _DetailBlockView(
                                        index: i,
                                        block: b,
                                        sceneTint: scene != null
                                            ? _tintOf(scene)
                                            : SajuGold.g300,
                                        profile: _profile,
                                        isLast: i == blocks.length - 1,
                                      );
                                    }),
                                  ),
                                ),
                                // [웹 AdSense — STEP E] 5단 서사 블록이 모두
                                // 끝난 뒤, "이 이야기는 당신의 원국에서..."
                                // 마무리 문구보다 앞에 배치한다. 해석 본문
                                // 블록 사이에는 넣지 않아 콘텐츠 가독 흐름을
                                // 끊지 않는다(지시서 §5 콘텐츠 비가림 원칙).
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    36,
                                    22,
                                    0,
                                  ),
                                  child: const WebAdInPage(
                                    surface: WebAdSurface.sajuRenewal,
                                    adSlot: '',
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(22, 28, 22, 0),
                                  child: Text(
                                    '◆ 이 이야기는 당신의 원국에서 찾은 근거로만 쓰였어요',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: SajuType.body,
                                      fontSize: 13.5,
                                      color: SajuText.faint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 36, 20, 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, SajuInk.i900],
                      stops: [0.0, 0.55],
                    ),
                  ),
                  child: SajuButton(
                    label: '또 다른 이야기 보기',
                    onTap: detailState.data == null
                        ? null
                        : () {
                            provider.showMoreTopics();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MoreStoriesScreen(),
                              ),
                            );
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _tintOf(SajuRenewalScene scene) {
    switch (scene) {
      case SajuRenewalScene.money:
        return SajuScene.money.tint;
      case SajuRenewalScene.talent:
        return SajuScene.talent.tint;
      case SajuRenewalScene.love:
        return SajuScene.love.tint;
      case SajuRenewalScene.life:
        return SajuScene.life.tint;
      case SajuRenewalScene.guin:
        return SajuScene.guin.tint;
    }
  }
}

class _SceneTag extends StatelessWidget {
  const _SceneTag({required this.scene, required this.ordinal});

  final SajuRenewalScene scene;
  final int ordinal;

  SajuScene get _token {
    switch (scene) {
      case SajuRenewalScene.money:
        return SajuScene.money;
      case SajuRenewalScene.talent:
        return SajuScene.talent;
      case SajuRenewalScene.love:
        return SajuScene.love;
      case SajuRenewalScene.life:
        return SajuScene.life;
      case SajuRenewalScene.guin:
        return SajuScene.guin;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _token;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t.glyph, style: TextStyle(color: t.tint, fontSize: 12)),
        const SizedBox(width: 8),
        Text(
          t.nameKo,
          style: TextStyle(
            fontFamily: SajuType.ui,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.tint,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 10, color: SajuText.line),
        const SizedBox(width: 8),
        Text(
          'STORY · N°${ordinal.toString().padLeft(2, '0')}',
          style: SajuType.mono9,
        ),
      ],
    );
  }
}

/// 블록 하나(제목·시기 카드·본문·근거·구분선).
class _DetailBlockView extends StatelessWidget {
  const _DetailBlockView({
    required this.index,
    required this.block,
    required this.sceneTint,
    required this.profile,
    required this.isLast,
  });

  final int index;
  final InterpretDetailBlock block;
  final Color sceneTint;
  final SajuVisualProfile? profile;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final label = (block.n >= 1 && block.n <= 5)
        ? _kBlockLabels[block.n - 1]
        : '';
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${(index + 1).toString().padLeft(2, '0')}.',
                style: TextStyle(
                  fontFamily: SajuType.mono,
                  fontSize: 12,
                  color: sceneTint,
                  letterSpacing: 0.1 * 12,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: SajuType.serif,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: SajuGold.g100,
                  letterSpacing: -0.02 * 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 시기(n=4) 전용 대운 스트림 카드.
          if (block.n == 4 && block.luckIndex != null && profile != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16, top: 4),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SajuText.lineGold),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    sceneTint.withValues(alpha: 0.094),
                    const Color(0x99201D31),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SajuTermText(
                        text: '[[daewoon|10년마다 바뀌는 바람]]',
                        style: const TextStyle(
                          fontFamily: SajuType.ui,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: SajuGold.g300,
                        ),
                      ),
                      const Text(
                        '◯ 주목할 시기',
                        style: TextStyle(
                          fontFamily: SajuType.ui,
                          fontSize: 11,
                          color: SajuText.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (profile!.luck.isNotEmpty)
                    SajuLuckStream(
                      luck: profile!.luck,
                      current: profile!.luckCurrentIndex,
                      highlight: block.luckIndex!.round(),
                      width: 300,
                    ),
                ],
              ),
            ),
          ],
          SajuTermText(
            text: block.body,
            style: SajuType.body16.copyWith(fontSize: 16, height: 1.85),
          ),
          if (block.evidence != null) ...[
            const SizedBox(height: 18),
            if (profile != null)
              SajuEvidenceCard(
                evidence: block.evidence!,
                profile: profile!,
                label: '근거',
                compact: true,
              ),
          ],
          if (!isLast)
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 28),
              color: SajuText.line,
            ),
        ],
      ),
    );
  }
}
