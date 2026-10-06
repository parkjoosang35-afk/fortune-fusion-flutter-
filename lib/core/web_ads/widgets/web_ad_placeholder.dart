import 'package:flutter/material.dart';

/// [웹 AdSense 광고 시스템 — STEP D 내부 전용 보조 위젯] 실제 광고 대신
/// 자리만 확보하는 더미 표시.
///
/// [이것은 광고가 아니다] 클릭 불가(순수 장식, `IgnorePointer`로 감쌈),
/// 어떤 콘텐츠도 로드하지 않는다. 오직 "이 위치에 나중에 AdSense 광고가
/// 들어갈 것"임을 개발자가 레이아웃 단계에서 눈으로 확인하기 위한
/// 용도이며, AdSense 미승인 상태([WebAdConfig.enabled]=false 또는
/// publisherId 미설정)일 때만 노출된다. 실제 광고가 활성화되면 이
/// 위젯은 더 이상 호출되지 않는다.
class WebAdPlaceholder extends StatelessWidget {
  const WebAdPlaceholder({
    super.key,
    required this.height,
    required this.label,
  });

  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.03),
        ),
        child: Text(
          'AD · $label',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.32),
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
