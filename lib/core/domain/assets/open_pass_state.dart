import '../../../features/pass/domain/pass_model.dart';

/// [열림패스/복주머니/복주머니 통합정책 §7] 열림패스 상태값.
/// PassStatusModel(서버 응답)을 이 3분류로 정규화해서, 화면단이 서버 필드를
/// 직접 들여다보지 않고 이 상태값만으로 분기하도록 강제한다.
enum OpenPassStatus {
  /// 발급된 열림패스가 없음(한 번도 발급받지 않았거나, 서버가 비활성으로 응답).
  inactive,

  /// 열림패스가 활성 상태이며 남은 시간이 있음.
  active,

  /// 열림패스가 있었지만 만료 시각이 지남(activatedAt/expiresAt은 남아있음).
  expired,
}

/// [OpenPassStatus] + 남은 시간을 함께 담는 값 객체.
/// [PassStatusModel]에서 파생 생성하며, 화면/AccessChecker는 이 객체만 본다.
class OpenPassState {
  const OpenPassState({
    required this.status,
    required this.remaining,
    this.policyName,
    this.expiresAt,
  });

  final OpenPassStatus status;

  /// 남은 시간(0 이하이면 만료/비활성).
  final Duration remaining;
  final String? policyName;
  final DateTime? expiresAt;

  bool get isActive => status == OpenPassStatus.active;

  /// [프리패스 테스트 인프라] §7 — 서버가 내려준 `remainingSec`은 응답 시점에
  /// 고정된 스냅샷이라, 이 값을 그대로 신뢰하면 서버를 다시 호출하기 전까지는
  /// 만료 시각이 지나도 앱이 계속 "활성"으로 오판한다(자동 재잠금 실패).
  /// 그래서 [model.expiresAt]이 있으면 항상 `expiresAt - DateTime.now()`로
  /// **호출 시점마다 실시간 재계산**하고, `remainingSec`은 expiresAt이 없을 때만
  /// (레거시 응답 호환용) 폴백으로 사용한다. 이렇게 하면 화면이 이 상태를
  /// 다시 읽는 즉시(예: 다음 게이트체크, 1초 타이머 tick) 정확히 만료/재잠금이
  /// 반영된다 — 별도의 서버 폴링 없이도 정확하다.
  factory OpenPassState.fromModel(PassStatusModel model) {
    if (!model.isActive) {
      // expiresAt이 과거인데 서버가 isActive=false로 내려주는 경우 = 만료,
      // expiresAt 자체가 없으면 = 발급 이력 없음(inactive).
      final hasExpiry = model.expiresAt != null;
      return OpenPassState(
        status: hasExpiry ? OpenPassStatus.expired : OpenPassStatus.inactive,
        remaining: Duration.zero,
        policyName: model.policyName,
        expiresAt: model.expiresAt,
      );
    }

    final Duration remaining;
    if (model.expiresAt != null) {
      remaining = model.expiresAt!.difference(DateTime.now());
    } else {
      remaining = Duration(seconds: model.remainingSec);
    }

    return OpenPassState(
      status: remaining > Duration.zero
          ? OpenPassStatus.active
          : OpenPassStatus.expired,
      remaining: remaining > Duration.zero ? remaining : Duration.zero,
      policyName: model.policyName,
      expiresAt: model.expiresAt,
    );
  }

  /// "42분 남음" 형태의 표시용 라벨(만료/비활성이면 null).
  String? get remainingLabel {
    if (status != OpenPassStatus.active || remaining <= Duration.zero) {
      return null;
    }
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    if (h > 0) return '$h시간 $m분 남음';
    return '$m분 남음';
  }
}
