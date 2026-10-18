// [v7 통합] "이 풀이를 내 소원에 봉인하기" 플로우 — 디자인 핸드오프
// FlowsV6.jsx `keepReading()`(=sealReading 호출) + WishRoomV6.jsx
// `RoomPickWish`/`RoomSealing`의 Flutter 포팅.
//
// [아키텍처 차이에 따른 재설계 — 가장 중요한 설계 결정]
// 디자인 원본은 "여러 개의 소원 중 하나를 고르는" RoomPickWish 화면을
// 두지만, 실제 Flutter 앱의 WishRoomProvider는 사용자당 활성 소원이
// 최대 1개(WishRoom? room)인 구조다(완료되면 archiveRooms로 이관).
// CHANGES_v7.md 자체가 "소원방을 복제하지 말 것"을 경고하므로, 이
// 구현은 디자인을 글자 그대로 재구현하지 않고 기존 1-소원 구조에 맞춰
// 단순화한다:
//   - 활성 소원이 있으면 → "고르기" 화면 없이 그 소원에 바로 확인 후 동봉
//     (고를 대상이 하나뿐이므로 고르기 UI 자체가 불필요하다).
//   - 활성 소원이 없으면 → v7.1이 명시한 유일한 예외 경로를 그대로 따라
//     ComposeScreen(pendingReading: artifact)으로 보내 "새로 쓰면서 함께
//     봉인"한다.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../wishroom/application/wishroom_provider.dart';
import '../../../wishroom/features/compose/compose_screen.dart';
import '../data/reading_artifact_store.dart';
import '../data/reading_wish_link_store.dart';
import '../domain/reading_artifact.dart';

/// 총결과 화면 CTA에서 호출한다. 아티팩트를 먼저 "확정"(로컬 저장)한 뒤,
/// 활성 소원 유무에 따라 분기한다.
Future<void> sealReadingToWishRoom(
  BuildContext context,
  ReadingArtifact artifact,
) async {
  // sealReading() — 풀이를 확정(저장)한다. 사진/좌표는 저장하지 않는다.
  await ReadingArtifactStore.save(artifact);
  if (!context.mounted) return;

  final wishRoom = context.read<WishRoomProvider>();
  final room = wishRoom.room;
  final hasActiveWish = room != null && !room.readOnly;

  if (hasActiveWish) {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _AttachToExistingWishSheet(artifact: artifact, wishText: room.text),
    );
    if (confirmed != true || !context.mounted) return;
    await ReadingWishLinkStore.attach(room.id, artifact.id);
    if (!context.mounted) return;
    _showSealedToast(context, '소원에 풀이를 얹었어요. 소원방에서 확인해보세요.');
    Navigator.of(context).pushNamed('/wish-room');
    return;
  }

  // v7.1 예외 경로 — 소원이 아예 없을 때만 새로 쓴다.
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ComposeScreen(pendingReading: artifact),
    ),
  );
}

/// "풀이만 보관하고 나가기" — localStorage(여기선 로컬 저장소)에 최대 12개
/// 보관하고 화면을 나간다. 나중에 보관함에서 동봉할 수 있다(v7 README 명시).
Future<void> keepReadingForLater(
  BuildContext context,
  ReadingArtifact artifact,
) async {
  await ReadingArtifactStore.save(artifact);
  if (!context.mounted) return;
  _showSealedToast(context, '풀이를 보관했어요. 나중에 소원방에서 동봉할 수 있어요.');
  Navigator.of(context).pop();
}

void _showSealedToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

/// 활성 소원이 1개뿐이므로 "고르기" 대신 "확인" 시트만 보여준다
/// (WishRoomV6.jsx RoomSealing의 "얹기 연출" 분기에 대응하는 확인 단계).
class _AttachToExistingWishSheet extends StatelessWidget {
  const _AttachToExistingWishSheet({
    required this.artifact,
    required this.wishText,
  });
  final ReadingArtifact artifact;
  final String wishText;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0D2E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x1FFFEBC8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC94A3B),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    artifact.total.key,
                    style: const TextStyle(
                      fontFamily: 'NotoSerifKR',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFFFFF9E8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🕯 이 풀이를 내 소원에 얹을까요?',
                    style: const TextStyle(
                      fontFamily: 'NotoSerifKR',
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFFF8F2E6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x0DFFEBC8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1FFFEBC8)),
              ),
              child: Text(
                wishText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'GowunBatang',
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFFF8F2E6),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '소원 문구·빛깔·기간은 바뀌지 않아요. 풀이가 이 소원에 함께 봉인돼요.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: const Color(0xFFF8F2E6).withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF8F2E6),
                      side: const BorderSide(color: Color(0x33FFEBC8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5CF6A),
                      foregroundColor: const Color(0xFF3A2515),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '얹어서 봉인',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
