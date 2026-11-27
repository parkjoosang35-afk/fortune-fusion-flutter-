// [MORE·08 버그 수정 개발지시서 2026-10-11 REQ-08] "비로그인 사용자의
// 저장 처리: 기기 로컬 저장 후 로그인 시 히스토리로 이관(동기화)" 로직
// 단위 테스트. 실제 로그인은 서버 API 호출이 필요해 위젯 테스트로 흉내낼
// 수 없으므로, REQ-08의 핵심 — [MyFortuneRecordStore]의 게스트 버킷
// 분리/이관 동작 — 을 저장소 레이어에서 직접 검증한다
// (`AuthProvider.login/signup/loginWithSocial`은 이 저장소의
// [migrateGuestRecordsToAccount]만 호출하는 얇은 배선이므로, 저장소
// 동작이 맞으면 배선도 맞다).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/data/my_fortune_record_store.dart';

SavedFortuneRecord _record(String id, {DateTime? savedAt}) {
  final now = savedAt ?? DateTime(2026, 10, 11, 12, 0, 0);
  return SavedFortuneRecord(
    id: id,
    categoryLabel: '사주',
    title: '테스트 이야기 $id',
    summary: '요약 $id',
    date: now,
    savedAt: now,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('REQ-08: 게스트 저장 버킷 분리', () {
    test('asGuest: true로 저장하면 메인 목록(list)에는 보이지 않는다', () async {
      await MyFortuneRecordStore.save(_record('saju_a'), asGuest: true);
      final main = await MyFortuneRecordStore.list();
      expect(main, isEmpty);
    });

    test('asGuest: true 저장도 exists()로는 조회된다(REQ-07 중복 저장 방지용)', () async {
      await MyFortuneRecordStore.save(_record('saju_a'), asGuest: true);
      expect(await MyFortuneRecordStore.exists('saju_a'), isTrue);
    });

    test('asGuest: false(기본값) 저장은 기존처럼 메인 목록에 바로 보인다(회귀 없음)', () async {
      await MyFortuneRecordStore.save(_record('saju_b'));
      final main = await MyFortuneRecordStore.list();
      expect(main.map((e) => e.id), contains('saju_b'));
    });
  });

  group('REQ-08: 로그인 시 이관(migrateGuestRecordsToAccount)', () {
    test('게스트 버킷이 비어 있으면 이관 0건, 메인 목록도 그대로', () async {
      final migrated = await MyFortuneRecordStore.migrateGuestRecordsToAccount();
      expect(migrated, 0);
      expect(await MyFortuneRecordStore.list(), isEmpty);
    });

    test('게스트로 저장한 기록이 로그인 시 메인 목록으로 이관된다', () async {
      await MyFortuneRecordStore.save(_record('saju_c'), asGuest: true);
      await MyFortuneRecordStore.save(_record('saju_d'), asGuest: true);

      final migrated = await MyFortuneRecordStore.migrateGuestRecordsToAccount();
      expect(migrated, 2);

      final main = await MyFortuneRecordStore.list();
      expect(main.map((e) => e.id).toSet(), {'saju_c', 'saju_d'});
    });

    test('이관 후 게스트 버킷은 비워진다(다른 계정 재로그인 시 혼선 방지)', () async {
      await MyFortuneRecordStore.save(_record('saju_e'), asGuest: true);
      await MyFortuneRecordStore.migrateGuestRecordsToAccount();

      // 게스트 버킷이 비었으므로 두 번째 이관 시도는 0건이어야 한다.
      final secondMigrated =
          await MyFortuneRecordStore.migrateGuestRecordsToAccount();
      expect(secondMigrated, 0);
    });

    test(
      '메인 저장소에 이미 같은 id가 있으면 게스트 쪽을 버리고 메인 레코드를 유지한다'
      '(데이터 손실 방지 — 로그인 사용자의 정식 기록을 게스트 임시 기록으로 덮어쓰지 않음)',
      () async {
        final mainVersion = _record(
          'saju_f',
          savedAt: DateTime(2026, 1, 1),
        );
        final guestVersion = SavedFortuneRecord(
          id: 'saju_f',
          categoryLabel: '사주',
          title: '게스트가 쓴 다른 제목',
          summary: '게스트 요약',
          date: DateTime(2026, 10, 11),
          savedAt: DateTime(2026, 10, 11),
        );

        await MyFortuneRecordStore.save(mainVersion); // 이미 로그인 상태로 저장된 정식 기록.
        await MyFortuneRecordStore.save(guestVersion, asGuest: true);

        await MyFortuneRecordStore.migrateGuestRecordsToAccount();

        final main = await MyFortuneRecordStore.list();
        final merged = main.firstWhere((e) => e.id == 'saju_f');
        expect(merged.title, '테스트 이야기 saju_f'); // 메인(기존) 레코드 그대로 유지.
      },
    );

    test('이관 후에도 기존 메인 레코드는 그대로 남아 있다(병합이지 교체가 아님)', () async {
      await MyFortuneRecordStore.save(_record('saju_existing'));
      await MyFortuneRecordStore.save(_record('saju_guest_new'), asGuest: true);

      await MyFortuneRecordStore.migrateGuestRecordsToAccount();

      final main = await MyFortuneRecordStore.list();
      expect(main.map((e) => e.id).toSet(), {'saju_existing', 'saju_guest_new'});
    });
  });

  group('REQ-08 보조: hasPendingGuestRecords', () {
    test('게스트 저장 전에는 false', () async {
      expect(await MyFortuneRecordStore.hasPendingGuestRecords(), isFalse);
    });

    test('게스트 저장 후에는 true, 이관 후에는 다시 false', () async {
      await MyFortuneRecordStore.save(_record('saju_g'), asGuest: true);
      expect(await MyFortuneRecordStore.hasPendingGuestRecords(), isTrue);

      await MyFortuneRecordStore.migrateGuestRecordsToAccount();
      expect(await MyFortuneRecordStore.hasPendingGuestRecords(), isFalse);
    });
  });
}
