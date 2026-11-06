import 'package:flutter/material.dart';

import '../../domain/shrine_order.dart';
import '../../domain/talisman_item.dart';
import 'unique_talisman_overlay.dart';
import 'shrine_asset_path.dart';
import '../theme/shrine_v3_theme.dart';

/// README/HTML 프로토타입 `Zoom()` 컴포넌트 — "부적 크게 보기" 전체화면
/// 오버레이. 05(상세)/09(부적함)/10(부적함 상세) 세 화면이 공용으로 쓴다.
///
/// [order]가 주어지면("내 부적") 唯一 오버레이([UniqueTalismanOverlay])를
/// 얹어 보여준다 — 05 상세처럼 아직 주문하지 않은 카탈로그 미리보기는
/// [order]를 넘기지 않아 원본 이미지만 보여준다.
///
/// 수능 부적(category == 'suneung')만 README §1 "「부적만 / 설명 포함」
/// 전환" 탭을 갖는다 — 그 외 카테고리는 이미지 1장만 보여준다.
Future<void> showTalismanZoomOverlay(
  BuildContext context, {
  required TalismanItem talisman,
  ShrineOrder? order,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => _TalismanZoomDialog(talisman: talisman, order: order),
    transitionBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  );
}

class _TalismanZoomDialog extends StatefulWidget {
  const _TalismanZoomDialog({required this.talisman, this.order});
  final TalismanItem talisman;
  final ShrineOrder? order;

  @override
  State<_TalismanZoomDialog> createState() => _TalismanZoomDialogState();
}

class _TalismanZoomDialogState extends State<_TalismanZoomDialog> {
  // 'bj'(부적만) | 'full'(설명 포함) — 수능 부적에서만 의미를 갖는다.
  String _mode = 'bj';

  bool get _isSuneung => widget.talisman.category == 'suneung';

  /// 唯一 오버레이를 보여줄지 — "내 부적"이고, 수능이 아니거나 수능이어도
  /// 「부적만」 모드일 때만(설명 포함 모드는 원본 그대로 보여준다).
  bool get _showUnique => widget.order != null && (!_isSuneung || _mode == 'bj');

  String get _plainImagePath {
    if (_isSuneung) {
      return _mode == 'full'
          ? widget.talisman.imagePath
          : (widget.talisman.thumbPath ?? widget.talisman.imagePath);
    }
    return widget.talisman.imagePath;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.talisman;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () {}, // 이미지 영역 탭은 닫히지 않게 막는다.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _showUnique
                          ? UniqueTalismanOverlay(
                              order: widget.order!,
                              width: 200,
                              useThumb: _isSuneung,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                shrineAssetPath(_plainImagePath),
                                width: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 220,
                                  height: 220 * 2.3,
                                  color: ShrineV3Colors.paperDark,
                                  alignment: Alignment.center,
                                  child: Text(
                                    t.hanja,
                                    style: ShrineV3TextStyles.title.copyWith(
                                      fontSize: 72,
                                      color: ShrineV3Colors.seal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 18),
                      Text(
                        t.name,
                        style: ShrineV3TextStyles.title.copyWith(
                          fontSize: 18,
                          color: ShrineV3Colors.paper,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.sub?.isNotEmpty == true ? t.sub! : t.aim,
                        textAlign: TextAlign.center,
                        style: ShrineV3TextStyles.ui.copyWith(
                          fontSize: 12.5,
                          color: ShrineV3Colors.paper.withValues(alpha: 0.75),
                        ),
                      ),
                      if (_isSuneung) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _modeTab('bj', '부적만'),
                                _modeTab('full', '설명 포함'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String key, String label) {
    final on = _mode == key;
    return GestureDetector(
      onTap: () => setState(() => _mode = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on ? ShrineV3Colors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: on ? ShrineV3Colors.seal : Colors.white70,
          ),
        ),
      ),
    );
  }
}
