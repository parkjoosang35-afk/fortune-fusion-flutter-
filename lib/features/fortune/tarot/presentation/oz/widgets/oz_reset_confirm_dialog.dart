import 'package:flutter/material.dart';

import '../oz_theme.dart';

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1b] "처음부터 다시 뽑을까요?"
/// 확인 다이얼로그. CSS 대응: TarotApp.jsx의 `showConfirmReset` 인라인 모달.
class OzResetConfirmDialog extends StatelessWidget {
  final int pickedCount;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  const OzResetConfirmDialog({
    super.key,
    required this.pickedCount,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: OzColors.bgMid,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: OzColors.goldDeep.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: OzColors.gold.withValues(alpha: 0.15),
                  blurRadius: 40,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '처음부터 다시 뽑을까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OzColors.fg,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '지금까지 선택한 $pickedCount장의 카드가\n모두 사라집니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: OzColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OzColors.fg,
                          side: BorderSide(color: OzColors.goldDeep),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onCancel,
                        child: const Text('취소', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OzColors.gold,
                          foregroundColor: const Color(0xFF1A0D3D),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: onConfirm,
                        child: const Text(
                          '다시 뽑기',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
