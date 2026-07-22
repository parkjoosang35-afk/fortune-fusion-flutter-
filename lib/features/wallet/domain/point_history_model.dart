/// 04A 도메인 C `point_histories` 대응 모델
enum PointHistoryType { earn, spend }

class PointHistoryModel {
  final String id;
  final PointHistoryType type;
  final int amount;
  final String reason;
  final DateTime createdAt;

  const PointHistoryModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });
}
