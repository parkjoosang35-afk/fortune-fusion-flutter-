/// 04A 도메인 C `point_histories` 대응 모델
enum PointHistoryType { earn, spend }

class PointHistoryModel {
  final String id;
  final PointHistoryType type;
  final int amount;
  final String reason;
  final DateTime createdAt;

  /// [소원방 3대 개선 - 10채널 재설계] 서버 PointHistory.sourceType 원본값
  /// (예: 'altar_visit', 'daily_candle'). [reason]은 memo로 뭉쳐 나와
  /// 채널별 "오늘 완료 여부" 판단에 신뢰도가 낮으므로, "받기" 팝업에서는
  /// 이 필드로 오늘자 완료 채널을 판정한다. 과거 응답(필드 없음)과의
  /// 하위호환을 위해 null 허용.
  final String? sourceType;

  const PointHistoryModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.sourceType,
  });
}
