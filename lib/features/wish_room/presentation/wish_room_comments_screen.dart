import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../luckpouch/application/luck_pouch_provider.dart';
import '../application/wish_wall_provider.dart';
import '../domain/wish_wall_models.dart';
import '../theme/wish_room_theme.dart';
import '../widgets/wish_room_buttons.dart';

/// 소원방(Wish Room) — 응원 전체 목록 화면(신설).
///
/// [소원방 마무리 - Phase A] bokjumeoni-plan §06 COMMENTS "LIST · 전체 목록"
/// 스펙 대응. 구버전 wish_wall_detail_screen의 댓글 로직(fetchComments/
/// createComment, [WishComment] 모델)을 신 브랜드 톤(WishRoomColors/
/// WishRoomTextStyles)으로 이식했다. 신규 API/모델은 추가하지 않았다
/// (기존 [WishWallProvider]만 사용).
///
/// 제약(§06 그대로 반영):
/// - 60자 제한(서버도 동일하게 강제 — comments/route.ts COMMENT_MAX_LENGTH)
/// - 답글 없음(스레드 X)
/// - 15자 미만은 복주머니 지급 안 함(서버가 판정, 클라이언트는 안내만)
/// - 응원 문구 프리셋 7개(§06 텍스트 그대로, ko-KR 하드코딩)
/// - 프리셋 사용 시에도 +2 복 지급(글자 수가 15자 이상인 프리셋만 지급 대상 —
///   프리셋 문구들은 모두 15자 이상이므로 실질적으로 항상 지급됨)
///
/// [발명 금지] §06이 요구하는 "지역+연령대 마스킹"은 User 모델에 해당
/// 필드가 없어 구현하지 않는다(authorName 닉네임 표시를 그대로 유지).
class WishRoomCommentsScreen extends StatefulWidget {
  const WishRoomCommentsScreen({
    super.key,
    required this.wishId,
    required this.wishText,
  });

  final String wishId;

  /// 상단에 원본 소원 문구를 짧게 보여주기 위한 참고용 텍스트.
  final String wishText;

  @override
  State<WishRoomCommentsScreen> createState() => _WishRoomCommentsScreenState();
}

/// bokjumeoni-plan §06 "응원 문구 프리셋" 7종 — ko-KR 하드코딩(서버 i18n 아님).
const List<String> _wishCommentPresets = [
  '함께 빌고 있어요.',
  '당신의 마음, 닿기를.',
  '오늘도 그 촛불 흔들리지 않기를.',
  '저도 같은 소원을 담아본 적이 있어요.',
  '멀리서 응원합니다.',
  '부디, 이루어지기를.',
  '당신의 밤이 조용하기를.',
];

const int _kCommentMaxLength = 60;
const int _kCommentMinLengthForReward = 15;

class _WishRoomCommentsScreenState extends State<WishRoomCommentsScreen> {
  final _controller = TextEditingController();
  List<WishComment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final comments = await context.read<WishWallProvider>().fetchComments(
      widget.wishId,
    );
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    if (trimmed.length > _kCommentMaxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('응원 한 마디는 $_kCommentMaxLength자 이하로 남겨 주세요.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final result = await context
          .read<WishWallProvider>()
          .addCommentWithReward(widget.wishId, trimmed);
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _comments = [result.comment, ..._comments];
        _sending = false;
      });
      // [절대 원칙] 서버가 트랜잭션 안에서 이미 지급을 확정했으므로 여기서
      // earn()을 다시 호출하지 않고, 잔액 표시만 새로고침한다(중복 지급 방지).
      if (result.grantedAmount > 0) {
        unawaited(context.read<LuckPouchProvider>().load());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('응원을 남기고 복 ${result.grantedAmount}알을 받았어요.')),
        );
      } else if (trimmed.length < _kCommentMinLengthForReward) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('응원을 남겼어요. 15자 이상이면 복을 받을 수 있어요.')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('응원을 남겼어요.')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('응원 작성에 실패했습니다. 잠시 후 다시 시도해주세요.')),
      );
    }
  }

  void _showPresetSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WishRoomColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '응원 문구를 골라보세요',
                  style: WishRoomTextStyles.sectionTitle,
                ),
              ),
              ..._wishCommentPresets.map(
                (preset) => ListTile(
                  title: Text(
                    preset,
                    style: WishRoomTextStyles.bodyMd.copyWith(
                      color: WishRoomColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _send(preset);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 신고 사유를 실제로 고를 수 있는 선택지 시트. 이전 버전은
  /// `wishReportReasons.first`를 즉시 전송해 사용자가 사유를 선택할 수
  /// 없었던 버그가 있었다.
  void _showReportSheet(WishComment comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WishRoomColors.backgroundMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '신고 사유를 선택해주세요',
                  style: TextStyle(
                    color: WishRoomColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...wishReportReasons.map(
                (reason) => ListTile(
                  title: Text(
                    reason,
                    style: const TextStyle(color: WishRoomColors.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await context.read<WishWallProvider>().reportComment(
                        comment.id,
                        reason,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('신고가 접수되었습니다.')),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '신고 처리 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WishRoomColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  WishRoomIconButton(
                    icon: '←',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '응원을 남기시겠어요?',
                      style: WishRoomTextStyles.sectionTitle,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                widget.wishText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: WishRoomTextStyles.bodySm,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: WishRoomColors.glow,
                      ),
                    )
                  : _comments.isEmpty
                  ? const Center(
                      child: Text(
                        '아직 응원이 없어요.\n첫 응원을 남겨보세요.',
                        textAlign: TextAlign.center,
                        style: WishRoomTextStyles.bodyMd,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        return _CommentCard(
                          comment: _comments[index],
                          onReport: () => _showReportSheet(_comments[index]),
                        );
                      },
                    ),
            ),
            _CommentComposer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
              onPresetTap: _showPresetSheet,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.onReport});

  final WishComment comment;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WishRoomColors.surfaceCard,
        border: Border.all(color: WishRoomColors.surfaceCardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: comment.isMine
                  ? WishRoomColors.glowShadow
                  : WishRoomColors.surfaceCardBorder,
            ),
            alignment: Alignment.center,
            child: Text(
              comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
              style: const TextStyle(
                fontFamily: 'GowunBatangWish',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WishRoomColors.glow,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: WishRoomTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: WishRoomColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${_timeAgo(comment.createdAt)}',
                      style: WishRoomTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontFamily: 'GowunBatangWish',
                    fontSize: 15,
                    height: 1.5,
                    color: WishRoomColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_horiz,
              size: 18,
              color: WishRoomColors.textTertiary,
            ),
            onPressed: onReport,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPresetTap,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;
  final VoidCallback onPresetTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: WishRoomColors.backgroundMid,
        border: Border(
          top: BorderSide(color: WishRoomColors.surfaceCardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onPresetTap,
              icon: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: WishRoomColors.glow,
              ),
              label: const Text(
                '문구 골라 남기기',
                style: TextStyle(
                  fontFamily: 'GowunBatangWish',
                  fontSize: 12,
                  color: WishRoomColors.glow,
                ),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLength: _kCommentMaxLength,
                  maxLines: 1,
                  style: const TextStyle(color: WishRoomColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: '따뜻한 응원 한 마디를 남겨보세요',
                    hintStyle: TextStyle(color: WishRoomColors.textTertiary),
                    counterText: '',
                    filled: true,
                    fillColor: WishRoomColors.surfaceCard,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: sending ? null : onSend,
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty && !sending;
                  return WishRoomIconButton(
                    icon: sending ? '…' : '↑',
                    onPressed: canSend ? () => onSend(value.text) : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  final mins = diff.inMinutes;
  if (mins < 1) return '방금';
  if (mins < 60) return '$mins분';
  if (mins < 60 * 24) return '${diff.inHours}시간';
  return '${diff.inDays}일';
}
