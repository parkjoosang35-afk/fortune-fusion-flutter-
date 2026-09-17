// ============================================================
// 정통사주 전용 · 저장/공유 CTA (Hanji 디자인)
// 원본: flutter_handoff.zip theme의 _ActionButtons/_ActionBtn을
// 이식하되, TODO였던 저장/공유 로직을 기존 프로젝트의 실제 저장소
// (MyFortuneRecordStore, core/data/my_fortune_record_store.dart)와
// 공유 패키지(share_plus, 이미 tarot_result_screen.dart에서 사용 중)로
// 실제 구현한다 — 새 저장 로직을 만들지 않고 기존 것을 재사용.
// ============================================================

import 'package:flutter/material.dart';

import '../../../../core/data/my_fortune_record_store.dart';
import '../../../../core/util/safe_share.dart';
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

  // [공유 페이지 net::ERR_UNKNOWN_URL_SCHEME 버그수정 — 2026-12] 기존에는
  // 아무 가드/폴백 없이 `Share.share()`를 곧바로 호출했다. `share_plus_web
  // .dart`가 웹에서 canShare() 미지원 브라우저(카톡/삼성인터넷 인앱 등)를
  // 만나면 `mailto:` 스킴을 자체적으로 새 탭에 열려고 시도해 정확히 이
  // 에러 화면을 유발하는 것을 확인했다(core/util/safe_share.dart 문서
  // 참고). 공통 헬퍼로 교체해 웹에서는 클립보드 복사로 안전하게 폴백한다.
  Future<void> _onShare(BuildContext context) async {
    await safeShareText(context, buildShareText());
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
