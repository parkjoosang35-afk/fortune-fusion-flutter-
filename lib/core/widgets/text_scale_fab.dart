import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/text_scale_provider.dart';

/// [결과페이지 글씨 확대 기능] 결과 화면 어디서든 바로 글씨 크기를 키우고
/// 줄일 수 있는 작은 플로팅 컨트롤. "가-" / "현재 배율(예: 130%)" / "가+"
/// 3개 버튼으로 구성된 캡슐 형태이며, 길게 누르면 100%로 즉시 초기화된다.
///
/// 결과 화면 본문 위에 [Positioned] + [SafeArea]로 얹어 쓰는 용도이며,
/// 화면 고유의 스크롤/레이아웃 구조를 전혀 건드리지 않는다. 탭 1번당
/// [TextScaleProvider.steps] 한 단계(15%p)씩 바뀌며, 바뀐 값은
/// MaterialApp.builder가 전체 화면에 즉시 반영한다(이 화면 자체도 포함).
class TextScaleFab extends StatelessWidget {
  const TextScaleFab({super.key, this.alignment = Alignment.bottomRight});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TextScaleProvider>();
    final percent = (provider.scale * 100).round();

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          elevation: 4,
          child: GestureDetector(
            onLongPress: provider.reset,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ScaleButton(
                    icon: Icons.text_decrease_rounded,
                    tooltip: '글씨 작게',
                    enabled: provider.canDecrease,
                    onTap: provider.decrease,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _ScaleButton(
                    icon: Icons.text_increase_rounded,
                    tooltip: '글씨 크게',
                    enabled: provider.canIncrease,
                    onTap: provider.increase,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScaleButton extends StatelessWidget {
  const _ScaleButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 19,
            color: enabled ? Colors.white : Colors.white30,
          ),
        ),
      ),
    );
  }
}
