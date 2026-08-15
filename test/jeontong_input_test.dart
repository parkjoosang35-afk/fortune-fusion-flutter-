// [정통사주 80종 · MVP 라스트 마일 - Mission 1] JeontongInput 값 객체 검증.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';

void main() {
  test('KST 벽시계 시각 → UTC 변환은 -9시간', () {
    final input = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 5, 15, 14, 30),
      gender: 'M',
    );
    final utc = input.birthDateTimeUtc;
    expect(utc, DateTime.utc(1990, 5, 15, 5, 30));
  });

  test('UTC 변환 → 다시 +9시간 하면 원래 KST 로컬 시각으로 왕복 복원', () {
    final input = JeontongInput(
      birthDateTimeLocal: DateTime(2000, 1, 1, 0, 10),
      gender: 'F',
      isLunar: true,
    );
    final restored = input.birthDateTimeUtc.add(const Duration(hours: 9));
    expect(restored.year, 2000);
    expect(restored.month, 1);
    expect(restored.day, 1);
    expect(restored.hour, 0);
    expect(restored.minute, 10);
  });

  test('isLunar 기본값은 false(양력)', () {
    final input = JeontongInput(
      birthDateTimeLocal: DateTime(1985, 3, 3, 9, 0),
      gender: 'M',
    );
    expect(input.isLunar, false);
  });

  test('normalizedName — 빈 문자열/공백만 있으면 null, 앞뒤 공백은 trim', () {
    final withEmpty = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 1, 1),
      gender: 'M',
      name: '',
    );
    expect(withEmpty.normalizedName, null);

    final withSpaces = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 1, 1),
      gender: 'M',
      name: '   ',
    );
    expect(withSpaces.normalizedName, null);

    final withPadding = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 1, 1),
      gender: 'M',
      name: '  홍길동  ',
    );
    expect(withPadding.normalizedName, '홍길동');

    final withNull = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 1, 1),
      gender: 'M',
    );
    expect(withNull.normalizedName, null);
  });

  test('copyWith — 지정한 필드만 교체, 나머지는 유지', () {
    final original = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 5, 15, 14, 30),
      gender: 'M',
      isLunar: false,
      name: '홍길동',
    );
    final copied = original.copyWith(gender: 'F', isLunar: true);
    expect(copied.gender, 'F');
    expect(copied.isLunar, true);
    expect(copied.birthDateTimeLocal, original.birthDateTimeLocal);
    expect(copied.name, original.name);
  });

  test('== / hashCode — 동일 필드값이면 동등, 하나라도 다르면 비동등', () {
    final a = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 5, 15, 14, 30),
      gender: 'M',
      isLunar: false,
      name: '홍길동',
    );
    final b = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 5, 15, 14, 30),
      gender: 'M',
      isLunar: false,
      name: '홍길동',
    );
    final c = a.copyWith(gender: 'F');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, false);
  });
}
