/// [소원방 Riverpod 실험판] 한 번의 "정성 담기(기도)" 행위 기록.
class PrayerSession {
  final String id;
  final String wishId;
  final int pouchUsed;
  final DateTime prayedAt;
  final String resultMessage;

  const PrayerSession({
    required this.id,
    required this.wishId,
    required this.pouchUsed,
    required this.prayedAt,
    required this.resultMessage,
  });
}
