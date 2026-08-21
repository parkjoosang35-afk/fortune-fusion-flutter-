import 'package:flutter/material.dart';
import '../oz_theme.dart';

/// [타로 오즈 리스킨] 공용 탑바. CSS 대응: .oz-topbar.
///
/// 기존 화면들의 AppBar를 대체하는 커스텀 위젯(투명 배경 + Oz 타이포).
/// [onBack]이 주어지면 뒤로가기 화살표를 보이고, 없으면(홈처럼 루트
/// 화면) 숨긴다. [actions]는 오른쪽 아이콘 버튼들(음소거/히스토리 등)을
/// 그대로 주입받아 기존 컨트롤러 연결 로직을 건드리지 않는다.
class OzTopbar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  const OzTopbar({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OzTokens.spaceLg,
        OzTokens.spaceSm,
        OzTokens.spaceMd,
        OzTokens.spaceSm,
      ),
      child: Row(
        children: [
          if (onBack != null)
            _CircleIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack!)
          else
            const SizedBox(width: 4),
          const SizedBox(width: OzTokens.spaceSm),
          Expanded(
            child: Text(
              title,
              style: OzTypography.sectionTitle(fontSize: 20),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(OzTokens.radiusPill),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: OzColors.fg),
      ),
    );
  }
}

/// 탑바 오른쪽에 붙는 원형 아이콘 버튼(음소거/히스토리 등 기존 기능을
/// 그대로 연결할 때 사용).
class OzTopbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const OzTopbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: _CircleIconButton(icon: icon, onTap: onTap),
    );
  }
}
