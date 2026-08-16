// ============================================================
// 정통사주 전용 · 저장/공유 CTA (Hanji 디자인)
// 원본: flutter_handoff.zip theme의 _ActionButtons/_ActionBtn을
// 이식하되, TODO였던 저장/공유 로직을 기존 프로젝트의 실제 저장소
// (MyFortuneRecordStore, core/data/my_fortune_record_store.dart)와
// 공유 패키지(share_plus, 이미 tarot_result_screen.dart에서 사용 중)로
// 실제 구현한다 — 새 저장 로직을 만들지 않고 기존 것을 재사용.
// ============================================================

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/data/my_fortune_record_store.dart';
import 'hanji_design_tokens.dart';

class HanjiActionButtons extends StatelessWidget {
  /// 저장 시 생성할 레코드(카테고리 라벨/제목/요약/점수/날짜 등).
  final SavedFortuneRecord Function() buildRecord;

  /// 공유 시 사용할 텍스트.
  final String Function() buildShareText;

  const HanjiActionButtons({
    super.key,
    required this.buildRecord,
    required this.buildShareText,
  });

  Future<void> _onSave(BuildContext context) async {
    await MyFortuneRecordStore.save(buildRecord());
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('내 운세 기록에 저장되었습니다')));
  }

  Future<void> _onShare(BuildContext context) async {
    await Share.share(buildShareText());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HanjiSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              icon: '◇',
              label: '저장하기',
              onTap: () => _onSave(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              icon: '◇',
              label: '공유하기',
              onTap: () => _onShare(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HanjiRadii.chip),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: HanjiColors.card,
          border: Border.all(color: HanjiColors.line),
          borderRadius: BorderRadius.circular(HanjiRadii.chip),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(color: HanjiColors.accent)),
            const SizedBox(width: 8),
            Text(
              label,
              style: HanjiTextStyles.bodyTitle().copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
