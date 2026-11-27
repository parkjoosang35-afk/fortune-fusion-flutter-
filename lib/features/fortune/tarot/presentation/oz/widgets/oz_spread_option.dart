import 'package:flutter/material.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨] 스프레드(1카드/3카드/YES·NO) 선택 카드.
/// CSS 대응: .oz-spread / .oz-spread.active / .oz-spread-vis /
/// .oz-spread-card / .oz-spread-yn / .oz-spread-name / .oz-spread-desc.
///
/// 화면03(카테고리 상세)의 "몇 장으로 볼까요?"와 화면04(질문 입력)의
/// "스프레드 선택"에서 공유하는 위젯. [cardCount]가 1~3이면 미니 카드
/// 실루엣을 그 개수만큼 그리고, [ynLabel]이 주어지면 카드 실루엣 대신
/// "Y/N" 모노라벨을 보여준다(YES·NO 스프레드 전용).
class OzSpreadOption extends StatelessWidget {
  final String label;
  final String desc;
  final int cardCount;
  final String? ynLabel;
  final bool active;
  final VoidCallback onTap;

  const OzSpreadOption({
    super.key,
    required this.label,
    required this.desc,
    this.cardCount = 1,
    this.ynLabel,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(OzTokens.radiusMd),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
        decoration: BoxDecoration(
          color: active ? const Color(0x1AF5D98A) : OzColors.cardSoft,
          borderRadius: BorderRadius.circular(OzTokens.radiusMd),
          border: Border.all(
            color: active
                ? OzColors.gold.withValues(alpha: 0.5)
                : OzColors.borderSoft,
          ),
          boxShadow: active ? OzColors.goldGlow(alpha: 0.16, blur: 16) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 42,
              child: ynLabel != null
                  ? Center(
                      child: Text(
                        ynLabel!,
                        style: OzTypography.monoLabel(
                          fontSize: 20,
                          letterSpacing: 1,
                          color: active
                              ? OzColors.gold
                              : OzColors.fg.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      // [65종 타로 리딩엔진] 5카드 옵션 추가로 실루엣이 4장을
                      // 초과할 수 있어, 카드 폭/간격을 줄여 좁은 Expanded
                      // 영역에서도 오버플로우 없이 표시되도록 한다(시각적
                      // 조정만, cardCount 자체 의미는 변경하지 않음).
                      children: List.generate(cardCount, (i) {
                        final compact = cardCount > 3;
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 1 : 2,
                          ),
                          child: Container(
                            width: compact ? 13 : 20,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF4A3378), Color(0xFF2A1A5C)],
                              ),
                              border: Border.all(
                                color: OzColors.gold.withValues(
                                  alpha: active ? 0.6 : 0.35,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: OzTypography.cardName(
                fontSize: 13,
                color: active ? OzColors.gold : OzColors.fg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: OzTypography.body(fontSize: 10.5, color: OzColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}
