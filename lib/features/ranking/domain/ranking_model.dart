/// 06단계 §4.13 `/v1/ranking` 대응 모델
class RankingEntryModel {
  final int rank;
  final String nickname;
  final int points;
  final bool isMe;

  const RankingEntryModel({
    required this.rank,
    required this.nickname,
    required this.points,
    this.isMe = false,
  });
}
