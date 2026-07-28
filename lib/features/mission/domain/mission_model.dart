/// 04A 도메인 D `missions` 대응 모델 (06단계 §4.13 `/v1/missions` 대응)
enum MissionPeriod { daily, weekly }

class MissionModel {
  final String id;
  final String title;
  final String description;
  final int rewardPoints;
  final MissionPeriod period;
  final bool isCompleted;

  /// [Phase5 - 게임화 최소연동] 서버(admin_web)가 실제 진행률을 반환한다.
  /// 기존 Mock 단계에는 없던 필드로, 기본값(0/1)을 둬 기존 생성 코드와 호환한다.
  final int progressCount;
  final int targetCount;

  const MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    required this.period,
    required this.isCompleted,
    this.progressCount = 0,
    this.targetCount = 1,
  });

  MissionModel copyWith({bool? isCompleted}) => MissionModel(
    id: id,
    title: title,
    description: description,
    rewardPoints: rewardPoints,
    period: period,
    isCompleted: isCompleted ?? this.isCompleted,
    progressCount: progressCount,
    targetCount: targetCount,
  );
}
