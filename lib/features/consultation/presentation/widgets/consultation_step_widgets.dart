import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../fortune/tarot/domain/tarot_text_engine.dart';
import 'consultation_type_style.dart';

/// 07단계(추가) §3.5 - 사주/타로 채팅형 정보 수집 단계에서 InputBar 대신 표시되는
/// 버튼형 입력 위젯 모음. ConsultationChatScreen이 [ConsultationStep]에 따라
/// 이 파일의 위젯들과 기존 InputBar 사이를 동적으로 전환한다.
///
/// 모든 위젯은 InputBar와 동일한 하단 고정 바 스타일
/// (SafeArea + 흰 배경 + 상단 divider)을 공유해 시각적 일관성을 유지한다.
class _StepBarShell extends StatelessWidget {
  final Widget child;
  const _StepBarShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: child,
      ),
    );
  }
}

/// 07단계(추가) §3.5 - 성별 선택 버튼 2개(남성/여성).
/// [enabled]가 false면(계산 중 등) 버튼이 비활성화된다.
class GenderSelectionBar extends StatelessWidget {
  final ConsultationTypeStyle typeStyle;
  final bool enabled;
  final ValueChanged<String> onSelect;

  const GenderSelectionBar({
    super.key,
    required this.typeStyle,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _StepBarShell(
      child: Row(
        children: [
          Expanded(
            child: _ChoiceButton(
              label: '남성',
              icon: Icons.male_rounded,
              color: typeStyle.primaryColor,
              enabled: enabled,
              onTap: () => onSelect('male'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _ChoiceButton(
              label: '여성',
              icon: Icons.female_rounded,
              color: typeStyle.accentColor,
              enabled: enabled,
              onTap: () => onSelect('female'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 07단계(추가) §3.6 - 20개 주제(연애/재물/취업 등) 선택 버튼 목록.
/// 타로 고민 입력 직후, 카드를 뽑기 전에 표시된다. Wrap 레이아웃의
/// 칩(Chip) 형태로 배치해 20개 항목도 한 화면에 자연스럽게 들어가도록 한다.
class TarotTopicSelectionBar extends StatelessWidget {
  final ConsultationTypeStyle typeStyle;
  final bool enabled;
  final ValueChanged<String> onSelect;

  const TarotTopicSelectionBar({
    super.key,
    required this.typeStyle,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _StepBarShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '궁금한 주제를 골라주세요',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: tarotTopics.map((topic) {
                  return GestureDetector(
                    onTap: enabled ? () => onSelect(topic.id) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: enabled
                            ? typeStyle.primaryColor.withValues(alpha: 0.08)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: enabled
                              ? typeStyle.primaryColor.withValues(alpha: 0.4)
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        topic.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? typeStyle.primaryColor
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 07단계(추가) §3.5 - 타로 카드 선택 버튼 3개.
/// 실제 카드의 정체는 선택 이후 TarotProvider.draw() 결과로 결정되므로,
/// 여기서는 "카드 뒷면" 형태의 동일한 3개 버튼으로 선택 경험만 제공한다.
/// [selectedIndex]로 탭 즉시 시각적 피드백(배경색 반전 + 체크 아이콘)을 준다.
class TarotCardSelectionBar extends StatefulWidget {
  final ConsultationTypeStyle typeStyle;
  final bool enabled;
  final ValueChanged<String> onSelect;

  const TarotCardSelectionBar({
    super.key,
    required this.typeStyle,
    required this.enabled,
    required this.onSelect,
  });

  @override
  State<TarotCardSelectionBar> createState() => _TarotCardSelectionBarState();
}

class _TarotCardSelectionBarState extends State<TarotCardSelectionBar> {
  int? _selectedIndex;

  static const _labels = ['첫번째 카드', '두번째 카드', '세번째 카드'];

  void _handleTap(int index) {
    if (!widget.enabled || _selectedIndex != null) return;
    setState(() => _selectedIndex = index);
    widget.onSelect(_labels[index]);
  }

  @override
  Widget build(BuildContext context) {
    return _StepBarShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '마음이 가는 카드를 한 장 골라주세요',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(3, (index) {
              final isSelected = _selectedIndex == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : AppSpacing.sm / 2,
                    right: index == 2 ? 0 : AppSpacing.sm / 2,
                  ),
                  child: GestureDetector(
                    onTap: () => _handleTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: isSelected ? widget.typeStyle.gradient : null,
                        color: isSelected ? null : AppColors.background,
                        borderRadius: BorderRadius.circular(
                          AppRadius.cardSmall,
                        ),
                        border: Border.all(
                          color: isSelected
                              ? widget.typeStyle.primaryColor
                              : AppColors.divider,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.style_rounded,
                            color: isSelected
                                ? Colors.white
                                : widget.typeStyle.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// 07단계(추가) §3.5 - 사주 계산/타로 카드 해석 중(비동기 대기) 표시되는
/// 비활성 상태 바. 사용자가 입력할 수 없음을 명확히 알린다.
class CalculatingIndicatorBar extends StatelessWidget {
  final ConsultationTypeStyle typeStyle;
  final String label;

  const CalculatingIndicatorBar({
    super.key,
    required this.typeStyle,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return _StepBarShell(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: typeStyle.primaryColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.10) : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: enabled ? color : AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: enabled ? color : AppColors.textHint),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? color : AppColors.textHint,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
