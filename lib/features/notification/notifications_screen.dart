import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_empty_state.dart';
import '../wish_room/presentation/wish_room_detail_screen.dart';
import 'notification_provider.dart';

/// 03단계 §3.3 마이 탭 - NotificationsScreen(인앱 알림 목록)
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<NotificationProvider>().items;

    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: SafeArea(
        child: items.isEmpty
            ? const AppEmptyState(
                icon: Icons.notifications_none_rounded,
                title: '알림이 없어요',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: () => _handleTap(context, item),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.body,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.createdAt.month}.${item.createdAt.day} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// [알림 실제 발송 연동] 탭 시 서버가 내려준 deepLink("wish:w_123")를 파싱해
  /// 소원 상세 화면으로 이동한다. 형식이 다르거나 알 수 없는 타입이면 아무
  /// 동작도 하지 않는다(안전한 무시 — 존재하지 않는 화면으로 이동 시도 금지).
  void _handleTap(BuildContext context, NotificationItem item) {
    context.read<NotificationProvider>().markRead(item.id);
    final deepLink = item.deepLink;
    if (deepLink == null || deepLink.isEmpty) return;
    final parts = deepLink.split(':');
    if (parts.length != 2) return;
    final type = parts[0];
    final targetId = parts[1];
    if (type == 'wish' && targetId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WishRoomDetailScreen(wishId: targetId),
        ),
      );
    }
  }
}
