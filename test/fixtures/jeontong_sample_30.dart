/// [정통사주 69종 개인화 해석 엔진 — §24] A01 기준 모델 확장 검증용
/// 20~30명 샘플 픽스처.
///
/// [목적] `test/fixtures/jeontong_inputs.dart`의 3명(seed-user-A/B/C)은
/// 골든 스냅샷 테스트(`jeontong_eighty_golden_test.dart`)가 동시에
/// 참조하므로 값을 바꾸거나 늘리면 골든 재캡처가 필요해진다. §24 검증은
/// 골든과 무관한 순수 "개인화가 실제로 되는가" 확인이 목적이므로, 별도
/// 파일에 서로 다른 생년월일시·성별을 30명 분량으로 마련한다.
///
/// [절대 원칙] 여기 값은 실존 인물이 아닌 임의의 생년월일시 조합이며,
/// 오직 "서로 다른 입력 → 서로 다른 사주 8글자 → 서로 다른 분석 결과"를
/// 확인하기 위한 테스트 데이터다.
library;

import 'jeontong_inputs.dart';

DateTime _dt(int y, int m, int d, int h) => DateTime.utc(y, m, d, h, 0, 0);

/// 1950~2015년 사이, 월/일/시/성별을 고르게 흩어 30명을 구성한다.
final List<JeontongInput> kJeontongSample30 = <JeontongInput>[
  JeontongInput(userId: 'sample-01', birthDateTimeUtc: _dt(1955, 1, 5, 0), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-02', birthDateTimeUtc: _dt(1958, 3, 17, 4), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-03', birthDateTimeUtc: _dt(1961, 5, 22, 8), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-04', birthDateTimeUtc: _dt(1963, 7, 9, 12), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-05', birthDateTimeUtc: _dt(1965, 9, 30, 16), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-06', birthDateTimeUtc: _dt(1967, 11, 11, 20), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-07', birthDateTimeUtc: _dt(1969, 2, 2, 2), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-08', birthDateTimeUtc: _dt(1971, 4, 14, 6), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-09', birthDateTimeUtc: _dt(1973, 6, 25, 10), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-10', birthDateTimeUtc: _dt(1975, 8, 6, 14), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-11', birthDateTimeUtc: _dt(1977, 10, 18, 18), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-12', birthDateTimeUtc: _dt(1979, 12, 29, 22), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-13', birthDateTimeUtc: _dt(1981, 1, 20, 1), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-14', birthDateTimeUtc: _dt(1983, 3, 3, 5), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-15', birthDateTimeUtc: _dt(1985, 5, 15, 9), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-16', birthDateTimeUtc: _dt(1987, 7, 27, 13), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-17', birthDateTimeUtc: _dt(1989, 9, 8, 17), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-18', birthDateTimeUtc: _dt(1991, 11, 19, 21), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-19', birthDateTimeUtc: _dt(1993, 2, 28, 3), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-20', birthDateTimeUtc: _dt(1995, 4, 12, 7), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-21', birthDateTimeUtc: _dt(1997, 6, 24, 11), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-22', birthDateTimeUtc: _dt(1999, 8, 5, 15), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-23', birthDateTimeUtc: _dt(2001, 10, 17, 19), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-24', birthDateTimeUtc: _dt(2003, 12, 28, 23), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-25', birthDateTimeUtc: _dt(2006, 1, 9, 0), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-26', birthDateTimeUtc: _dt(2008, 3, 21, 4), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-27', birthDateTimeUtc: _dt(2010, 5, 2, 8), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-28', birthDateTimeUtc: _dt(2012, 7, 14, 12), isLunar: false, gender: 'F'),
  JeontongInput(userId: 'sample-29', birthDateTimeUtc: _dt(2014, 9, 25, 16), isLunar: false, gender: 'M'),
  JeontongInput(userId: 'sample-30', birthDateTimeUtc: _dt(2016, 11, 6, 20), isLunar: false, gender: 'F'),
];
