// [v7 통합] "담겨온 풀이" — 소원방 제단 카드(WishRoomV6.jsx 참고)에서 현재
// 소원에 동봉된 ReadingArtifact 목록을 보여주는 패널. ReadingWishLinkStore
// (로컬 매핑)와 ReadingArtifactStore(실제 아티팩트)를 조합해 읽기 전용으로
// 표시한다. 비어 있으면 아무것도 그리지 않아 기존 제단 카드 레이아웃에
// 영향을 주지 않는다.
library;

import 'package:flutter/material.dart';
import '../data/reading_artifact_store.dart';
import '../data/reading_wish_link_store.dart';
import '../domain/reading_artifact.dart';
import 'reading_disclosure_widgets.dart';

class AttachedReadingsPanel extends StatefulWidget {
  const AttachedReadingsPanel({super.key, required this.wishRoomId});
  final String wishRoomId;

  @override
  State<AttachedReadingsPanel> createState() => _AttachedReadingsPanelState();
}

class _AttachedReadingsPanelState extends State<AttachedReadingsPanel> {
  List<ReadingArtifact>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AttachedReadingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wishRoomId != widget.wishRoomId) _load();
  }

  Future<void> _load() async {
    final ids = await ReadingWishLinkStore.readingsOf(widget.wishRoomId);
    final items = <ReadingArtifact>[];
    for (final id in ids) {
      final a = await ReadingArtifactStore.get(id);
      if (a != null) items.add(a);
    }
    if (mounted) setState(() => _items = items);
  }

  void _openDetail(ReadingArtifact artifact) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A0D2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            Text(
              '◈ 담겨온 풀이 · ${artifact.kind.hanja}',
              style: const TextStyle(
                fontFamily: 'NotoSerifKR',
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFFF5CF6A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              artifact.total.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFFF8F2E6),
              ),
            ),
            const SizedBox(height: 10),
            const ReadingFunDisclaimer(),
            const SizedBox(height: 14),
            Text(
              artifact.total.body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFFF8F2E6),
              ),
            ),
            if (artifact.total.cite != null)
              ReadingCiteCard(cite: artifact.total.cite!),
            const Divider(color: Color(0x1FFFEBC8), height: 32),
            for (final step in artifact.steps) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${step.chip} ${step.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFFF8F2E6),
                      ),
                    ),
                  ),
                  ReadingDetectionBadge(confidence: step.detectionConfidence),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                step.body,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFFD9D0C6),
                ),
              ),
              if (step.cite != null) ReadingCiteCard(cite: step.cite!),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x33FFEBC8), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '◈ 담겨온 풀이',
            style: TextStyle(
              fontFamily: 'GowunBatang',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Color(0xFFF5CF6A),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (a) => GestureDetector(
                    onTap: () => _openDetail(a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFE08A), Color(0xFFFFB0C8)],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${a.kind.label} · ${a.total.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'GowunBatang',
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          color: Color(0xFF3A1A14),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
