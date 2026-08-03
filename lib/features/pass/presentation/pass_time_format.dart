/// [프리패스 단순화 - 쿠팡파트너스 전용] §6 실시간 카운트다운 공통 포맷터.
///
/// 여러 화면(_AlarmPassStatusBar, _PassHeroCard, _OpenPassBottomBar,
/// my_screen 상태 영역 등)에 흩어져 있던 "남은 시간 문자열" 로직을 하나로
/// 통일한다. 요구사항(§6)대로 시(HH):분(MM):초(SS) 형태로 항상 2자리
/// 0-padding하여 표시한다 — 예: 00:59:59, 01:00:00.
///
/// [OpenPassState.remainingLabel](분 단위, "1시간 20분 남음")은 기존 호출부
/// 회귀 방지를 위해 그대로 두고, 이 함수는 신규/갱신 대상 화면에서만 사용한다.
String formatPassHms(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  final h = clamped.inHours;
  final m = clamped.inMinutes % 60;
  final s = clamped.inSeconds % 60;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

/// 프리패스 이용시간(분) 설정값을 "30분"/"1시간"/"1시간 30분"/"24시간" 형태로
/// 표시하는 공통 포맷터. 관리자 드롭다운 옵션(30/60/120/180/1440)에 맞춰
/// 시간 단위가 딱 떨어지면 "N시간"만, 아니면 "N시간 M분"으로 표시한다.
String formatPassDuration(int durationMin) {
  if (durationMin < 60) return '$durationMin분';
  final h = durationMin ~/ 60;
  final m = durationMin % 60;
  return m == 0 ? '$h시간' : '$h시간 $m분';
}
