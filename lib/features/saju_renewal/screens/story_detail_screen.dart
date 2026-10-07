import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/web_ads/web_ad_config.dart';
import '../../../core/web_ads/widgets/web_ad_in_page.dart';
import '../data/models/interpret_result.dart';
import '../data/models/topic_card.dart';
import '../data/saju_recent_story_store.dart';
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
/// [블록 제목 — 서버 비전달 필드] [InterpretDetailBlock]에는 제목 필드가
/// 없다 — admin_web API 계약서(docs/11) 111/117행: "블록 제목은
/// 클라이언트 고정 문구(C-07-1~5) 사용 — 서버가 보내지 않음". 단,
/// **목차 칩(C-07-5a: "핵심/왜/생활/시기/포인트")과 블록 제목
/// 본문(C-07-1~5: "당신의 사주에서 보이는 핵심" 등 완전한 문장)은 서로
/// 다른 문구다** — 목차 칩은 [_kChipLabels](단어), 블록 제목은
/// [_kBlockTitles](완전한 문장)를 각각 써야 한다.
/// [버그 수정 — C-07a(docs/08) 결함 발견] 기존 코드는 이 둘을 구분하지
/// 않고 블록 제목에도 목차 칩과 동일한 단어 라벨을 재사용하던 결함이
/// 있었다(docs/06_카피덱.md C-07-1~5 위반). 완전한 문장으로 교체한다.
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

/// docs/06_카피덱.md C-07-5a — 목차 칩 전용 단어 라벨.
const List<String> _kChipLabels = ['핵심', '왜', '생활', '시기', '포인트'];

/// docs/06_카피덱.md C-07-1~C-07-5 — 블록 제목 전용 완전한 문장(T-block).
/// API 계약서(docs/11) 117행: "블록 제목은 클라이언트 고정 문구
/// (C-07-1~5) 사용 — 서버가 보내지 않음".
const List<String> _kBlockTitles = [
  '당신의 사주에서 보이는 핵심',
  '왜 이런 특징이 나타나는가',
  '실제 생활에서는',
  '어느 시기에 강한가',
  '당신에게 중요한 포인트',
];

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  SajuVisualProfile? _profile;

  // [버그 수정 — C-07d(docs/08) 결함 발견] docs/03_화면명세.md §07
  // 275행: "칩 탭 → 해당 블록으로 스크롤(상단바 높이 보정)" — 기존 코드는
  // 목차 칩에 onTap 핸들러가 전혀 없어 탭해도 아무 반응이 없던 결함.
  // 블록마다 GlobalKey를 부여해 Scrollable.ensureVisible로 스크롤한다.
  // blocks.length가 바뀌지 않는 한(데이터 로드 후 고정) 같은 키 인스턴스를
  // 재사용해야 GlobalKey가 동일 Element에 계속 연결된다.
  List<GlobalKey> _blockKeys = const [];

  void _ensureBlockKeys(int count) {
    if (_blockKeys.length != count) {
      _blockKeys = List.generate(count, (_) => GlobalKey());
    }
  }

  void _scrollToBlock(int index) {
    if (index < 0 || index >= _blockKeys.length) return;
    final ctx = _blockKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _profile = _buildProfile(user);
    _persistRecentStory();
  }

  /// docs/03 §01 "최근 본 이야기 카드" — 이 화면(화면⑦ 상세)에 도달했다는
  /// 것 자체가 "이 이야기를 끝까지(봉인 해제 후) 봤다"는 뜻이므로, 다음
  /// 번 화면①(메인) 재진입 때 재방문 카드로 보여줄 수 있도록 지금
  /// 시점에 로컬에 기록한다.
  void _persistRecentStory() {
    final provider = context.read<SajuRenewalProvider>();
    final topic = provider.currentTopic;
    if (topic == null) return;
    if (!provider.detailState.isSuccess) return;
    SajuRecentStoryStore.save(
      SajuRecentStory(
        topicId: topic.topicId,
        scene: topic.scene,
        title: topic.title,
        evidenceFactKeys: topic.evidenceFactKeys,
        viewedAt: DateTime.now(),
      ),
    );
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
    // [버그 수정 — C-09a] 05(미리보기)와 동일한 순번 계산 로직을
    // 재사용한다(provider.ordinalOf) — 과거에는 `viewedStoryCount + 1`
    // (상세보기 완료 횟수)을 썼는데, onAccessGranted()가 이 화면 렌더링
    // 직전에 `_viewedTopicIds`를 채우는 바람에 같은 이야기인데도 05에서
    // 본 순번보다 07에서 1 더 큰 값이 보이는 불일치가 있었다(재현
    // 테스트로 확인: 05 ordinal=1, 07 ordinal=2).
    final ordinal = topic != null ? provider.ordinalOf(topic.topicId) : 1;
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
                    _ensureBlockKeys(blocks.length);

                    return Column(
                      children: [
                        // 스크롤 아래에서도 떠 있는 상단바(JSX position:sticky
                        // + backdrop-blur(6px)). [버그 수정] 이전에는
                        // ColorFilter.mode(transparent, multiply)를 썼는데,
                        // 이 필터는 실질적으로 아무 흐림 효과를 내지 않는다
                        // (투명 색 x multiply = 결과가 항상 변화 없음) —
                        // 실제 블러는 ImageFilter.blur로만 구현된다.
                        ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
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
                                          ? _kChipLabels[b.n - 1]
                                          : '';
                                      return GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _scrollToBlock(i),
                                        child: Container(
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
                                        key: _blockKeys[i],
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
    super.key,
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
        ? _kBlockTitles[block.n - 1]
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
