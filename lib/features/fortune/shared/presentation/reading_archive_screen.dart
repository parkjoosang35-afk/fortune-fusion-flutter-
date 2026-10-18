// [v7 통합] "풀이만 보관하고 나가기"로 쌓인 로컬 보관함(최대 12개) 조회 화면.
//
// keepReadingForLater()가 저장만 하고 조회 UI가 없던 공백을 메운다. 각 항목을
// 열면 세부 풀이(부위별 해석)를 보여주고, "지금 내 소원에 봉인하기"를 눌러
// seal_reading_flow.dart의 sealReadingToWishRoom()을 그대로 재사용한다(로직
// 중복 금지 — 총결과 화면과 동일한 분기를 탄다).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_unified_style.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/premium_card.dart';
import '../data/reading_artifact_store.dart';
import '../domain/reading_artifact.dart';
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
    return Scaffold(
      backgroundColor: UnifiedColors.bg,
      appBar: AppBar(
        backgroundColor: UnifiedColors.bg,
        elevation: 0,
        title: Text('보관한 풀이', style: UnifiedText.titleLarge()),
      ),
      body: SafeArea(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
            ? const AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: '아직 보관한 풀이가 없어요',
                description: '관상·손금 결과 화면에서 "풀이만 보관하고 나가기"를\n누르면 여기에 모여요(최대 12개).',
              )
            : ListView.separated(
                padding: EdgeInsets.all(UnifiedTokens.screenPadding),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: UnifiedTokens.spaceMd),
                itemBuilder: (context, index) =>
                    _ArchiveTile(artifact: items[index], onRemove: _remove),
              ),
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.artifact, required this.onRemove});
  final ReadingArtifact artifact;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      backgroundColor: UnifiedColors.cardSection,
      borderColor: Colors.transparent,
      showShadow: false,
      borderRadius: BorderRadius.circular(UnifiedTokens.radiusLg),
      padding: const EdgeInsets.all(UnifiedTokens.spaceLg),
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
                  color: const Color(0xFFC94A3B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  artifact.total.key,
                  style: const TextStyle(
                    fontFamily: 'NotoSerifKR',
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFFFFF9E8),
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
                      style: UnifiedText.bodyStrong(),
                    ),
                    Text(
                      '${artifact.createdAt.year}.${artifact.createdAt.month}.${artifact.createdAt.day} · 해석 ${artifact.interpretedCount}건 · 사진 없이 보관',
                      style: UnifiedText.caption(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: UnifiedColors.textCaption,
                ),
                onPressed: () => onRemove(artifact.id),
                tooltip: '보관함에서 삭제',
              ),
            ],
          ),
          const SizedBox(height: 12),
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
