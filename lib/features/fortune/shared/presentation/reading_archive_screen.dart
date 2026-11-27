// [v7 통합] "풀이만 보관하고 나가기"로 쌓인 로컬 보관함(최대 12개) 조회 화면.
//
// keepReadingForLater()가 저장만 하고 조회 UI가 없던 공백을 메운다. 각 항목을
// 열면 세부 풀이(부위별 해석)를 보여주고, "지금 내 소원에 봉인하기"를 눌러
// seal_reading_flow.dart의 sealReadingToWishRoom()을 그대로 재사용한다(로직
// 중복 금지 — 총결과 화면과 동일한 분기를 탄다).
//
// [마이페이지 리뉴얼 · DEV 2026-11-06 §S06/S08] design_handoff_mypage_
// minimal.zip README "S06 운세 보관함 목록(공용)" 스펙에 따라 바깥 틀
// ([MyPageArchiveScaffold]/[MyPageArchiveEmptyState])을 Minimal 테마로
// 리스킨한다. 확장/삭제/소원 봉인 등 이 화면만의 고유 상호작용이 있는
// 카드(`_ArchiveTile`)는 README의 범용 행 레이아웃으로 단순화하지 않고
// 구조를 유지한 채 Minimal 색상 토큰만 입힌다 — "로직은 그대로" 원칙.
library;

import 'package:flutter/material.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../mypage/presentation/theme/mypage_archive_widgets.dart';
import '../../../mypage/presentation/theme/mypage_minimal_theme.dart';
import '../data/reading_artifact_store.dart';
import '../domain/reading_artifact.dart';
import 'reading_disclosure_widgets.dart';
import 'seal_reading_flow.dart';

class ReadingArchiveScreen extends StatefulWidget {
  const ReadingArchiveScreen({super.key});

  @override
  State<ReadingArchiveScreen> createState() => _ReadingArchiveScreenState();
}

class _ReadingArchiveScreenState extends State<ReadingArchiveScreen> {
  List<ReadingArtifact>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ReadingArtifactStore.list();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _remove(String id) async {
    await ReadingArtifactStore.remove(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final isLoading = items == null;

    return MyPageArchiveScaffold(
      title: '보관한 풀이',
      itemCount: isLoading ? null : items.length,
      isLoading: isLoading,
      body: isLoading
          ? const MyPageArchiveLoadingPlaceholder()
          : items.isEmpty
          ? MyPageArchiveEmptyState(
              glyph: '藏\n解',
              title: '아직 보관한 풀이가 없어요',
              subtitle: '관상·손금 결과 화면에서 "풀이만 보관하고 나가기"를\n누르면 여기에 모여요(최대 12개)',
              ctaLabel: '풀이 보러 가기 ›',
              onCta: () =>
                  Navigator.of(context).pushNamed('/ai-fortune/face/capture'),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: ReadingFunDisclaimer(),
                ),
                for (final artifact in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ArchiveTile(artifact: artifact, onRemove: _remove),
                  ),
              ],
            ),
    );
  }
}

class _ArchiveTile extends StatefulWidget {
  const _ArchiveTile({required this.artifact, required this.onRemove});
  final ReadingArtifact artifact;
  final ValueChanged<String> onRemove;

  @override
  State<_ArchiveTile> createState() => _ArchiveTileState();
}

class _ArchiveTileState extends State<_ArchiveTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final artifact = widget.artifact;
    final onRemove = widget.onRemove;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MyPageColors.surface,
        borderRadius: BorderRadius.circular(MyPageRadius.card),
        boxShadow: MyPageShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MyPageColors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  artifact.total.key,
                  style: const TextStyle(
                    fontFamily: MyPageFonts.hanja,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFFFBF1DE),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${artifact.kind.label} · ${artifact.total.title}',
                      style: MyPageTextStyles.row.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${artifact.createdAt.year}.${artifact.createdAt.month}.${artifact.createdAt.day} · 해석 ${artifact.interpretedCount}건 · 사진 없이 보관',
                      style: MyPageTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: MyPageColors.ink3,
                ),
                onPressed: () => onRemove(artifact.id),
                tooltip: '보관함에서 삭제',
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  _expanded ? '세부 풀이 접기' : '세부 풀이 펼치기',
                  style: MyPageTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: MyPageColors.ink3,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            for (final step in artifact.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${step.chip} ${step.title}',
                            style: MyPageTextStyles.row.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        ReadingDetectionBadge(
                          confidence: step.detectionConfidence,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(step.body, style: MyPageTextStyles.body),
                    if (step.cite != null) ReadingCiteCard(cite: step.cite!),
                  ],
                ),
              ),
            if (artifact.total.cite != null)
              ReadingCiteCard(cite: artifact.total.cite!),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 10),
          PremiumButton.black(
            label: '🕯 지금 내 소원에 봉인하기',
            icon: Icons.auto_awesome_rounded,
            height: 44,
            onPressed: () => sealReadingToWishRoom(context, artifact),
          ),
        ],
      ),
    );
  }
}
