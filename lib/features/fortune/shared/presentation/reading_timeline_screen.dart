// [v7 통합 — Option B 포팅] 디자인 핸드오프 ReadingScreenV2.jsx/ReadingStageV2.jsx의
// "정신"을 사진·좌표 없이 포팅한 화면.
//
// [왜 사진·좌표가 없는가 — 아키텍처 결정 기록]
// 원본 v7 디자인은 사진 위에 랜드마크 좌표(ellipse/path/diamond)를 SVG로
// 실시간으로 그리며, 숫자 실측값(W/H비 0.73, 하관각도 126° 등)을 함께 보여준다.
// 그러나 실제 Flutter 앱의 엔진(face-judgment.ts 등)은:
//   1) 분석 완료 즉시 사진 바이트를 파기한다(09단계 §7 개인정보보호 원칙,
//      face_provider.dart/palm_provider.dart의 `_selectedImageBytes = null`).
//   2) 픽셀 좌표(랜드마크)를 전혀 반환하지 않는다(FaceResultModel.features는
//      `Map<String,String>` 텍스트일 뿐).
//   3) 숫자 실측값(%, °, 비율)을 전혀 반환하지 않는다(범주형 텍스트만 반환).
// 좌표·숫자를 날조해서 채우면 "Mock 데이터로 실패 가리지 않기" 표준 제약을
// 정면으로 위반하고, 사진을 결과 화면까지 들고 있으면 기존 개인정보 파기
// 정책을 위반한다. 따라서 이 화면은 "사진+좌표 드로잉"을 과감히 제외하고,
// v7이 의도한 나머지 핵심 경험 — 부위별 타이핑 리빌, 진행 인장(SealRail),
// 엔진 관찰/전통 문헌 출전의 분리 표기 — 을 정직하게 재구현한다
// (2024-사용자 승인 "b" = 옵션 B 선택).
//
// [배치] FaceAnalyzingScreen/PalmAnalyzingScreen이 실제 분석 API 성공 직후
// 이 화면으로 이동하고(최초 1회만), 사용자가 각 부위를 넘겨보며 "총평" 단계
// (artifact.total)까지 본 뒤 "총결과 보기"를 누르면 기존 FaceResultScreen/
// PalmResultScreen(TotalScreens.jsx 역할)으로 이동한다. 히스토리에서 바로
// 열람하는 경로(FaceHistoryScreen 등)는 이 화면을 거치지 않고 기존처럼
// 결과 화면으로 직행한다(변경 없음).
library;

import 'package:flutter/material.dart';
import '../../sintong/theme/sintong_colors.dart';
import '../../sintong/theme/sintong_typography.dart';
import '../../sintong/widgets/hanja_stamp.dart';
import '../../sintong/widgets/sintong_screen_bg.dart';
import '../domain/reading_artifact.dart';
import 'reading_disclosure_widgets.dart';

/// 관상/손금 공용 — 부위별(features/lines) + 주제별(topicResults) + 총평을
/// 하나의 타임라인으로 묶어 순서대로 "타이핑 리빌"한다.
class ReadingTimelineScreen extends StatefulWidget {
  const ReadingTimelineScreen({
    super.key,
    required this.artifact,
    required this.onFinished,
  });

  final ReadingArtifact artifact;

  /// 마지막 단계(총평)에서 "총결과 보기"를 눌렀을 때 호출. 보통 기존
  /// FaceResultScreen/PalmResultScreen으로 pushReplacement한다.
  final VoidCallback onFinished;

  @override
  State<ReadingTimelineScreen> createState() => _ReadingTimelineScreenState();
}

class _TimelineItem {
  const _TimelineItem({
    required this.chip,
    required this.title,
    required this.body,
    this.cite,
    this.measures = const [],
    this.isTotal = false,
  });

  final String chip;
  final String title;
  final String body;
  final CiteRef? cite;
  final List<MeasureRow> measures;
  final bool isTotal;
}

class _ReadingTimelineScreenState extends State<ReadingTimelineScreen>
    with TickerProviderStateMixin {
  late final List<_TimelineItem> _items;
  int _index = 0;

  AnimationController? _typeCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _stampCtrl;

  @override
  void initState() {
    super.initState();
    _items = [
      ...widget.artifact.steps.map(
        (s) => _TimelineItem(
          chip: s.chip,
          title: s.title,
          body: s.body,
          cite: s.cite,
          measures: s.measures,
        ),
      ),
      _TimelineItem(
        chip: widget.artifact.total.key,
        title: widget.artifact.total.title,
        body: widget.artifact.total.body,
        cite: widget.artifact.total.cite,
        isTotal: true,
      ),
    ];
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _stampCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _setupStep();
  }

  bool get _isLast => _index == _items.length - 1;
  _TimelineItem get _current => _items[_index];

  void _setupStep() {
    final item = _current;
    final totalLen = (item.title.length + item.body.length).clamp(1, 100000);
    // 글자당 약 24ms — 전체 분량에 비례하되 너무 길거나 짧지 않게 clamp.
    final ms = (totalLen * 24).clamp(700, 4200);
    _typeCtrl?.dispose();
    _typeCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
    _typeCtrl!.addListener(() => setState(() {}));
    _typeCtrl!.forward();
    _stampCtrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _typeCtrl?.dispose();
    _pulseCtrl.dispose();
    _stampCtrl.dispose();
    super.dispose();
  }

  void _skipTyping() {
    final c = _typeCtrl;
    if (c != null && c.value < 1.0) {
      c.value = 1.0;
    }
  }

  void _goNext() {
    if (_isLast) return;
    setState(() => _index += 1);
    _setupStep();
  }

  void _jumpTo(int i) {
    if (i == _index) {
      _skipTyping();
      return;
    }
    // 이미 지나온 단계로만 되돌아갈 수 있다(아직 안 본 내용 스포일러 방지).
    if (i > _index) return;
    setState(() => _index = i);
    _setupStep();
  }

  void _restart() {
    setState(() => _index = 0);
    _setupStep();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.artifact.kind;
    final canGoBack = Navigator.canPop(context);
    final typeValue = _typeCtrl?.value ?? 1.0;
    final typingDone = typeValue >= 1.0;

    final item = _current;
    final totalChars = item.title.length + item.body.length;
    final titleFrac = totalChars == 0 ? 0.0 : item.title.length / totalChars;
    final titleProgress = titleFrac <= 0
        ? 1.0
        : (typeValue / titleFrac).clamp(0.0, 1.0);
    final bodyProgress = titleFrac >= 1.0
        ? 0.0
        : ((typeValue - titleFrac) / (1 - titleFrac)).clamp(0.0, 1.0);
    final visibleTitle = item.title.substring(
      0,
      (item.title.length * titleProgress).round(),
    );
    final visibleBody = item.body.substring(
      0,
      (item.body.length * bodyProgress).round(),
    );

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SintongScreenBg()),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  label: '${kind.hanja} · READING',
                  stepLabel: '${_index + 1} / ${_items.length}',
                  onBack: canGoBack ? () => Navigator.of(context).pop() : null,
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _skipTyping,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: _stampCtrl,
                                  curve: Curves.elasticOut,
                                ),
                                child: HanjaStamp(
                                  text: item.chip,
                                  size: 48,
                                  color: item.isTotal
                                      ? SintongColors.accent
                                      : SintongColors.stampGuan,
                                  rotation: -6,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.isTotal
                                          ? '${kind.hanja} · 總評'
                                          : '${kind.label} · 부위 풀이',
                                      style: SintongType.monoSm.copyWith(
                                        color: SintongColors.glow,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            visibleTitle,
                            style: SintongType.displayLg.copyWith(
                              fontSize: 23,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(visibleBody, style: SintongType.bodyText),
                          // v7.2: 엔진이 실제로 잰 수치가 있을 때만 표시한다
                          // (없는 통계를 만들어내지 않는다 — measures는 현재
                          // 엔진이 범주형 텍스트만 반환하므로 대부분 비어
                          // 있으며, 빈 경우 이 블록 전체가 생략된다).
                          if (item.measures.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            AnimatedOpacity(
                              opacity: typingDone ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: _MeasureBox(measures: item.measures),
                            ),
                          ],
                          if (item.cite != null) ...[
                            const SizedBox(height: 14),
                            AnimatedOpacity(
                              opacity: typingDone ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: ReadingCiteCard(cite: item.cite!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _SealRail(
                  items: _items,
                  currentIndex: _index,
                  pulse: _pulseCtrl,
                  onTap: _jumpTo,
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: ReadingFunDisclaimer(),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  child: _isLast
                      ? Row(
                          children: [
                            _GhostIconButton(
                              icon: Icons.replay_rounded,
                              onTap: _restart,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GlowButton(
                                label:
                                    '◈ ${kind.label} 총결과 보기 ›',
                                onTap: widget.onFinished,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: widget.onFinished,
                                style: TextButton.styleFrom(
                                  foregroundColor: SintongColors.muted,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text('건너뛰고 총결과 보기'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _GlowButton(
                                label: '다음 ›',
                                onTap: _goNext,
                              ),
                            ),
                          ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label, required this.stepLabel, this.onBack});
  final String label;
  final String stepLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          if (onBack != null)
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SintongColors.card,
                  border: Border.all(color: SintongColors.line),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 17,
                  color: SintongColors.fg,
                ),
              ),
            )
          else
            const SizedBox(width: 34),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: SintongType.monoSm.copyWith(color: SintongColors.muted),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              stepLabel,
              textAlign: TextAlign.right,
              style: SintongType.monoSm.copyWith(
                color: SintongColors.glow,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v7.2: 엔진이 실제로 범주형/수치 판정을 반환한 경우에만 노출되는
/// "엔진 관찰" 박스. ReadingStageV2.jsx MeasureRow의 포팅(분포 막대 없음).
class _MeasureBox extends StatelessWidget {
  const _MeasureBox({required this.measures});
  final List<MeasureRow> measures;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SintongColors.line),
        color: SintongColors.card,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Text(
                  '◈ 엔진 관찰 · 사진에서 본 내용',
                  style: SintongType.monoSm.copyWith(
                    color: SintongColors.crystal,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < measures.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: SintongColors.line),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      measures[i].label,
                      style: SintongType.caption,
                    ),
                  ),
                  Text(
                    measures[i].unit != null
                        ? '${measures[i].value}${measures[i].unit}'
                        : measures[i].value,
                    style: SintongType.cardTitle.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 부위별 진행 인장 레일 — 완료=금색, 현재=호흡 애니메이션, 대기=흐림.
/// ReadingStageV2.jsx `SealRail` 포팅(사진 없이 하단 고정 바 형태로 단순화).
class _SealRail extends StatelessWidget {
  const _SealRail({
    required this.items,
    required this.currentIndex,
    required this.pulse,
    required this.onTap,
  });

  final List<dynamic> items;
  final int currentIndex;
  final AnimationController pulse;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i] as dynamic;
          final isDone = i < currentIndex;
          final isCurrent = i == currentIndex;
          final isVisitable = i <= currentIndex;
          Widget chip = Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: (isDone || isCurrent)
                  ? (item.isTotal as bool
                        ? SintongColors.accent
                        : SintongColors.glow)
                  : Colors.transparent,
              border: Border.all(
                color: (isDone || isCurrent)
                    ? Colors.transparent
                    : SintongColors.line,
              ),
            ),
            child: Opacity(
              opacity: isCurrent ? 1 : (isDone ? 1 : 0.4),
              child: Text(
                item.chip as String,
                style: TextStyle(
                  fontFamily: SintongType.display,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: (isDone || isCurrent)
                      ? const Color(0xFFFFF9E8)
                      : SintongColors.fg,
                ),
              ),
            ),
          );
          if (isCurrent) {
            chip = AnimatedBuilder(
              animation: pulse,
              builder: (context, child) => Transform.scale(
                scale: 1.0 + pulse.value * 0.08,
                child: child,
              ),
              child: chip,
            );
          }
          return GestureDetector(
            onTap: isVisitable ? () => onTap(i) : null,
            child: chip,
          );
        },
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: SintongColors.glow,
            boxShadow: [
              BoxShadow(
                color: SintongColors.glowShadow,
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            label,
            style: SintongType.button.copyWith(
              color: const Color(0xFF2A1A14),
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: SintongColors.card,
          border: Border.all(color: SintongColors.line),
        ),
        child: Icon(icon, size: 18, color: SintongColors.fg),
      ),
    );
  }
}
