import 'package:flutter/material.dart';

import '../oz_theme.dart';
import 'oz_face_down_card.dart';

/// [타로 카드뽑기 화면 디자인 핸드오프 매핑 · T1] 상단 "뽑은 카드" 슬롯.
///
/// CSS 대응: `<PickedSlots>`(TarotApp.jsx). [target]개의 점선 박스가
/// 가로로 나열되고, [count]번째까지는 카드 뒷면 미니 썸네일 + 번호가
/// 채워진다. 새로 채워질 때 살짝 튀어오르는(overshoot) 팝인 연출을
/// [AnimatedSwitcher] + [Curves.elasticOut]으로 재현한다.
///
/// [핵심] 이 슬롯의 카드는 리딩을 시작하기 전까지 절대 정체가 공개되지
/// 않는다(뒷면 이미지만 노출) - 디자인 스펙 §5.3 "슬롯의 5장은 뒷면 유지"
/// 원칙 그대로.
class OzPickedSlots extends StatelessWidget {
  final int count;
  final int target;
  const OzPickedSlots({super.key, required this.count, required this.target});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(target, (i) {
        final filled = i < count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 38,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: filled
                    ? OzColors.gold.withValues(alpha: 0.9)
                    : OzColors.goldDeep.withValues(alpha: 0.55),
                width: 1,
              ),
              color: filled
                  ? Colors.transparent
                  : Colors.black.withValues(alpha: 0.2),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: filled
                  ? _FilledSlot(key: ValueKey('slot-filled-$i'), index: i)
                  : Text(
                      '${i + 1}',
                      key: ValueKey('slot-empty-$i'),
                      style: TextStyle(
                        color: OzColors.goldDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'serif',
                      ),
                    ),
            ),
          ),
        );
      }),
    );
  }
}

class _FilledSlot extends StatelessWidget {
  final int index;
  const _FilledSlot({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const OzFaceDownCard(width: 36, height: 52),
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: OzColors.gold,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                fontFamily: 'serif',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
