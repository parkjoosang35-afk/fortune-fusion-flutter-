// [STEP 0 raw 확인] 미션 템플릿은 `test/features/home/`(서브디렉토리) +
// `package:your_app/...` 를 가정했으나, 실제 프로젝트 관례는:
//   1) 테스트 파일이 test/goldens, test/fixtures 두 예외를 빼면 전부 평면
//      `test/*.dart`에 위치한다(다른 jeontong_* 테스트 12종 전부 동일 패턴).
//   2) pubspec.yaml의 실제 패키지명은 `flutter_app`이다(`your_app`이 아님).
// 두 사항을 실제 관례에 맞춰 교정했다(그 외 테스트 로직은 미션 원안 그대로).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/features/home/data/jeontong_bookmark_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('빈 사용자 조회 = 빈 Set (null 아님)', () async {
    final s = JeontongBookmarkStore();
    final r = await s.get('pj');
    expect(r, isA<Set<String>>());
    expect(r.isEmpty, true);
    expect(await s.count('pj'), 0);
  });

  test('add → contains → toggle 제거 라운드트립', () async {
    final s = JeontongBookmarkStore();
    expect(await s.add('pj', 'A01'), true);
    expect(await s.contains('pj', 'A01'), true);
    expect(await s.count('pj'), 1);

    final t = await s.toggle('pj', 'A01');
    expect(t, false); // 제거됨
    expect(await s.contains('pj', 'A01'), false);
    expect(await s.count('pj'), 0);
  });

  test('dedup — 동일 카테고리 재추가는 idempotent, count 증가 없음', () async {
    final s = JeontongBookmarkStore();
    expect(await s.add('pj', 'A01'), true);
    expect(await s.add('pj', 'A01'), true); // idempotent
    expect(await s.add('pj', 'A01'), true);
    expect(await s.count('pj'), 1);
  });

  test('하드캡 20건 — 21번째 add 는 false, Snack 문구 상수 잠금 확인', () async {
    final s = JeontongBookmarkStore();
    for (var i = 1; i <= 20; i++) {
      final code = 'C${i.toString().padLeft(2, '0')}';
      expect(
        await s.add('pj', code),
        true,
        reason: '20건 이내 add 성공해야 함 ($code)',
      );
    }
    expect(await s.count('pj'), 20);

    // 21번째
    final r = await s.add('pj', 'X99');
    expect(r, false);
    expect(await s.count('pj'), 20);

    // toggle 로 시도해도 null (하드캡)
    final t = await s.toggle('pj', 'X99');
    expect(t, null);

    // 문구 상수 raw 잠금
    expect(JeontongBookmarkStore.kSnackFullMessage, '즐겨찾기는 최대 20개까지');
  });

  test('LinkedHashSet 삽입 순서 유지 (결정론)', () async {
    final s = JeontongBookmarkStore();
    final input = ['A01', 'B03', 'D02', 'H07', 'C05'];
    for (final c in input) {
      await s.add('pj', c);
    }
    final ordered = (await s.get('pj')).toList();
    expect(ordered, input);
  });

  test('영속화 라운드트립 — 인스턴스 재생성 후 동일 데이터 로드', () async {
    final s1 = JeontongBookmarkStore();
    await s1.add('pj', 'A01');
    await s1.add('pj', 'B03');
    await s1.add('test_a', 'D02');

    // 새 인스턴스에서 다시 로드
    final s2 = JeontongBookmarkStore();
    expect((await s2.get('pj')).toList(), ['A01', 'B03']);
    expect((await s2.get('test_a')).toList(), ['D02']);
    expect(await s2.contains('pj', 'A01'), true);
    expect(await s2.count('test_a'), 1);
  });
}
