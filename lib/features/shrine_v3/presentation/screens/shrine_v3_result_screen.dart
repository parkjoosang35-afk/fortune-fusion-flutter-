import 'package:flutter/material.dart';

import '../../../../core/router/main_bottom_nav_bar.dart';
import '../../../../core/util/image_gallery_saver.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../domain/shrine_order.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/talisman_save_image.dart';
import '../widgets/unique_talisman_overlay.dart';
import 'shrine_v3_box_screen.dart';

/// 신당(THE SHRINE) v3 — 08 결과. [order]는 서버가 이미 계산한 唯一
/// 값(일련번호/사주/만료일/남은일수)을 그대로 표시만 한다.
class ShrineV3ResultScreen extends StatefulWidget {
  const ShrineV3ResultScreen({super.key, required this.order});

  final ShrineOrder order;

  @override
  State<ShrineV3ResultScreen> createState() => _ShrineV3ResultScreenState();
}

class _ShrineV3ResultScreenState extends State<ShrineV3ResultScreen> {
  bool _saving = false;

  /// README §6/§7 "사진첩 저장" — 10 부적함 상세와 동일한 합성/저장 경로를
  /// 그대로 재사용한다([buildTalismanSaveImageBytes] + 기존
  /// saveImageBytesToGalleryDetailed).
  Future<void> _saveToGallery() async {
    final order = widget.order;
    setState(() => _saving = true);
    try {
      final bytes = await buildTalismanSaveImageBytes(order);
      final result = await saveImageBytesToGalleryDetailed(
        bytes,
        name: '신당_${order.talisman.name}_${order.serial.replaceFirst('神堂 ', '')}',
      );
      if (!mounted) return;
      if (result.isSuccess) {
        AppToast.show(context, gallerySaveSuccessMessage());
      } else {
        AppToast.show(
          context,
          result.failureMessage ?? '저장하지 못했어요 · 잠시 뒤 다시',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, '저장하지 못했어요 · 잠시 뒤 다시', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final t = order.talisman;
    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('成 · 부적이 완성되었어요', style: ShrineV3TextStyles.mono.copyWith(fontSize: 12)),
                const SizedBox(height: 16),
                UniqueTalismanOverlay(order: order, width: 112),
                const SizedBox(height: 16),
                Text(t.name, style: ShrineV3TextStyles.title.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text('唯一 · 세상에 한 장뿐인 부적', style: ShrineV3TextStyles.ui.copyWith(fontSize: 12)),
                const SizedBox(height: 16),
                UniqueRecordCard(order: order),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: ShrineV3Colors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ShrineV3Colors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('소지 기간', style: ShrineV3TextStyles.ui.copyWith(fontSize: 11)),
                          Text(
                            '${order.daysRemaining}일 · ${order.expiresDateKey}까지',
                            style: ShrineV3TextStyles.body.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                      Text('소지 중', style: ShrineV3TextStyles.body.copyWith(fontSize: 13, color: ShrineV3Colors.jade)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _saveToGallery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ShrineV3Colors.seal,
                      side: const BorderSide(color: ShrineV3Colors.seal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('⤓ 사진첩에 저장'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const ShrineV3BoxScreen()),
                      (route) => route.isFirst,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ShrineV3Colors.seal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('부적함에 보관하기 ›'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
