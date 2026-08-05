/// [소원방 Riverpod 실험판] 오늘의 한 줄 메시지 무드.
enum MessageMood { calm, hopeful, warm, encouraging }

/// 오늘의 한 줄 메시지.
class DailyMessage {
  final String id;
  final DateTime date;
  final String text;
  final MessageMood mood;

  const DailyMessage({
    required this.id,
    required this.date,
    required this.text,
    required this.mood,
  });
}
