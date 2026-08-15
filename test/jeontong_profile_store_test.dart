// [정통사주 80종 · MVP 라스트 마일 - Mission 1] JeontongProfileStore 저장/복원
// 라운드트립 검증. 기존 jeontong_bookmark_store_test.dart와 동일한 테스트
// 관례(평면 test/*.dart, package:flutter_app/... import, SharedPreferences
// mock 초기화)를 따른다.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/home/data/jeontong_profile_store.dart';
import 'package:flutter_app/features/home/domain/jeontong_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('저장된 적 없는 사용자 조회 = null', () async {
    final s = JeontongProfileStore();
    final r = await s.get('pj');
    expect(r, null);
  });

  test('save → get 라운드트립 (같은 인스턴스, in-memory 캐시)', () async {
    final s = JeontongProfileStore();
    final input = JeontongInput(
      birthDateTimeLocal: DateTime(1990, 5, 15, 14, 30),
      gender: 'M',
      isLunar: false,
      name: '홍길동',
    );
    await s.save('pj', input);

    final loaded = await s.get('pj');
    expect(loaded, isNotNull);
    expect(loaded!.birthDateTimeLocal, input.birthDateTimeLocal);
    expect(loaded.gender, 'M');
    expect(loaded.isLunar, false);
    expect(loaded.name, '홍길동');
  });

  test('영속화 라운드트립 — 새 인스턴스에서도 동일 데이터 로드(KST 왕복 보존)',
      () async {
    final s1 = JeontongProfileStore();
    final input = JeontongInput(
      birthDateTimeLocal: DateTime(1988, 12, 25, 23, 45),
      gender: 'F',
      isLunar: true,
      name: '김철수',
    );
    await s1.save('user_a', input);

    final s2 = JeontongProfileStore();
    final loaded = await s2.get('user_a');
    expect(loaded, isNotNull);
    expect(loaded!.birthDateTimeLocal, DateTime(1988, 12, 25, 23, 45));
    expect(loaded.gender, 'F');
    expect(loaded.isLunar, true);
    expect(loaded.name, '김철수');
  });

  test('사용자별 분리 저장 — 서로 다른 userId는 독립적으로 보관', () async {
    final s = JeontongProfileStore();
    await s.save(
      'user_a',
      JeontongInput(
        birthDateTimeLocal: DateTime(1990, 1, 1, 0, 0),
        gender: 'M',
      ),
    );
    await s.save(
      'user_b',
      JeontongInput(
        birthDateTimeLocal: DateTime(2000, 6, 6, 12, 0),
        gender: 'F',
      ),
    );

    final a = await s.get('user_a');
    final b = await s.get('user_b');
    expect(a!.gender, 'M');
    expect(b!.gender, 'F');
    expect(a.birthDateTimeLocal, isNot(b.birthDateTimeLocal));
  });

  test('save 후 덮어쓰기 — 동일 userId 재저장 시 최신값으로 교체', () async {
    final s = JeontongProfileStore();
    await s.save(
      'pj',
      JeontongInput(
        birthDateTimeLocal: DateTime(1990, 1, 1, 0, 0),
        gender: 'M',
      ),
    );
    await s.save(
      'pj',
      JeontongInput(
        birthDateTimeLocal: DateTime(1995, 7, 7, 8, 0),
        gender: 'F',
      ),
    );

    final loaded = await s.get('pj');
    expect(loaded!.gender, 'F');
    expect(loaded.birthDateTimeLocal, DateTime(1995, 7, 7, 8, 0));
  });

  test('clear — 저장된 프로필 삭제 후 조회하면 null', () async {
    final s = JeontongProfileStore();
    await s.save(
      'pj',
      JeontongInput(
        birthDateTimeLocal: DateTime(1990, 1, 1, 0, 0),
        gender: 'M',
      ),
    );
    expect(await s.get('pj'), isNotNull);

    await s.clear('pj');
    expect(await s.get('pj'), null);
  });

  test('getSync — get() 호출 전에는 캐시 미스로 null, get() 이후에는 동기 조회 가능',
      () async {
    final s = JeontongProfileStore();
    expect(s.getSync('pj'), null);

    await s.save(
      'pj',
      JeontongInput(
        birthDateTimeLocal: DateTime(1990, 1, 1, 0, 0),
        gender: 'M',
      ),
    );
    expect(s.getSync('pj'), isNotNull);
    expect(s.getSync('pj')!.gender, 'M');
  });

  test('이름 미입력(null) 라운드트립도 안전', () async {
    final s = JeontongProfileStore();
    await s.save(
      'pj',
      JeontongInput(
        birthDateTimeLocal: DateTime(1990, 1, 1, 0, 0),
        gender: 'M',
      ),
    );
    final loaded = await s.get('pj');
    expect(loaded!.name, null);
  });
}
