/// [열림패스/복주머니/복주머니 통합정책] 복주머니 적립/사용 이력 모델.
/// [features/wallet/domain/point_history_model.dart]의 복주머니 이력 모델과
/// 구조는 동일하지만, 두 자산이 하나의 클래스를 공유하지 않도록 의도적으로
/// 별도 타입으로 분리했다(§8 금지 원칙: 자산별 로직/모델을 뒤섞지 않는다).
enum LuckPouchHistoryType { earn, spend }

class LuckPouchHistoryModel {
  final String id;
  final LuckPouchHistoryType type;
  final int amount;
  final String reason;
  final DateTime createdAt;

  const LuckPouchHistoryModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LuckPouchHistoryModel.fromJson(Map<String, dynamic> json) {
    return LuckPouchHistoryModel(
      id: json['id'] as String,
      type: LuckPouchHistoryType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LuckPouchHistoryType.earn,
      ),
      amount: json['amount'] as int,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
