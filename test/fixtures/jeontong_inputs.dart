/// 2026-08-13 결정 — 정통사주 결정론 골든 픽스처.
/// 값이 바뀌면 골든이 함께 재캡처되어야 한다.
class JeontongInput {
  final String userId;
  final DateTime birthDateTimeUtc;
  final bool isLunar;
  final String gender; // 'M' | 'F'
  const JeontongInput({
    required this.userId,
    required this.birthDateTimeUtc,
    required this.isLunar,
    required this.gender,
  });
}

DateTime _dt(int y, int m, int d, int h) => DateTime.utc(y, m, d, h, 0, 0);

final kJeontongTestInputs = <JeontongInput>[
  JeontongInput(
    userId: 'seed-user-A',
    birthDateTimeUtc: /*1972-02-12 17:00Z = 1972-02-13 02:00 KST*/
        _dt(1972, 2, 12, 17),
    isLunar: false,
    gender: 'M',
  ),
  JeontongInput(
    userId: 'seed-user-B',
    birthDateTimeUtc: _dt(1990, 6, 15, 3),
    isLunar: false,
    gender: 'F',
  ),
  JeontongInput(
    userId: 'seed-user-C',
    birthDateTimeUtc: _dt(2005, 11, 30, 21),
    isLunar: false,
    gender: 'F',
  ),
];
