/// 04A 도메인 D `missions` 대응 모델 (06단계 §4.13 `/v1/missions` 대응)
enum MissionPeriod { daily, weekly }

class MissionModel {
  final String id;
  final String title;
  final String description;
  final int rewardPoints;
  final MissionPeriod period;
  final bool isCompleted;

  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.period,
    required this.isCompleted,
  });

  MissionModel copyWith({bool? isCompleted}) => MissionModel(
        id: id,
        title: title,
        description: description,
        rewardPoints: rewardPoints,
        period: period,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}
