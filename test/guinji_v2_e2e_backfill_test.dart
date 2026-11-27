// [귀인지도 V2 통합 — ④단계 E2E 검증] 실제 DB에 백필된 relationship 4건
// (JORYEOK/JAGEUKJE→V2 6종 재계산 결과)을 그대로 서버 응답 포맷으로
// 재현해, Flutter `GuinjiPerson.fromServerJson()` → `guinjiRelationMetaOf()`
// → `person.note` 까지 깨지지 않고 안전하게 흐르는지 검증한다.
//
// 샘플 데이터는 `admin_web`에서 실제 DB를 조회해 생성한
// `guinji_e2e_samples.json`(4건, relationType: SANG_SAENG/BI_HWA/HAP)이며,
// 이 테스트는 "실제 운영 데이터가 화면에서 깨지지 않는지"를 보장하는
// 회귀 테스트 역할을 한다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/guinji/domain/guinji_person.dart';
import 'package:flutter_app/features/guinji/domain/guinji_relation_meta.dart';

// V2 6종만 존재해야 하며, 구형 12종(JORYEOK/JAGEUKJE 등)은 전혀 없어야
// 한다 — 병행노출 금지 원칙의 최종 확인. (두 테스트에서 공용으로 사용)
const v2Types = {
  'CHEON_GWII',
  'HAP',
  'SANG_SAENG',
  'SANG_GEUK',
  'BI_HWA',
  'CHUNG',
};

void main() {
  test('실제 DB 백필 데이터 4건이 GuinjiPerson으로 안전하게 매핑된다', () {
    final raw = File('test/fixtures/guinji_e2e_samples.json').readAsStringSync();
    final List<dynamic> samples = jsonDecode(raw) as List<dynamic>;

    expect(samples.length, 4, reason: '백필된 relationship 레코드는 4건이어야 함');

    for (final sample in samples) {
      final map = sample as Map<String, dynamic>;
      final member = map['member'] as Map<String, dynamic>;
      final relation = map['relation'] as Map<String, dynamic>;

      // 1) relationType이 V2 6종 중 하나인지(구형 12종 완전 소멸 확인).
      final relationType = relation['relationType'] as String;
      expect(
        v2Types.contains(relationType),
        isTrue,
        reason: '구형 12종 코드가 섞여 있으면 안 됨: $relationType',
      );

      // 2) GuinjiPerson.fromServerJson()이 크래시 없이 매핑되는지.
      final person = GuinjiPerson.fromServerJson(member: member, relation: relation);

      // 3) person.note(= ohaengEvidence.reason)가 빈 문자열이 아니고,
      //    "대충 만든 문장"이 아니라 최소 길이를 가진 실제 서술인지.
      expect(person.note, isNotEmpty, reason: 'note(reason)가 비어있으면 안 됨');
      expect(
        person.note.length,
        greaterThan(10),
        reason: 'note가 너무 짧으면 "대충 만든 문장" 의심: ${person.note}',
      );
      expect(person.note, isNot(contains('null')));
      expect(person.note, isNot(contains('undefined')));
      expect(person.note, isNot(contains('NaN')));

      // 4) person.relation이 guinjiRelationMetaOf()로 안전하게 메타
      //    조회가 되는지(절대 크래시하지 않고 항상 non-null 반환).
      final meta = guinjiRelationMetaOf(person.relation);
      expect(meta.key, isNotEmpty);
      expect(v2Types.contains(meta.key), isTrue);

      // 5) score가 0~100 범위의 정수인지.
      expect(person.score, inInclusiveRange(0, 100));

      // ignore: avoid_print
      print(
        '[OK] ${person.name} · ${meta.label}(${meta.hanja}) · ${person.score}점 · note="${person.note}"',
      );
    }
  });

  test('신규 사주 입력→참여→판정 흐름(judgeGuinjiRelationV2 실시간 호출 결과)도 안전하게 매핑된다', () {
    // admin_web에서 judgeGuinjiRelationV2()를 실시간 호출해 생성한
    // "신규 참여" 시나리오 1건 — 기존 백필 데이터가 아니라 이번 턴에
    // 새로 계산된 결과로, 전체 사용자 흐름(사주 입력→생성→참여→판정)의
    // 마지막 구간(판정 결과 → Flutter 화면)을 검증한다.
    final raw = File('test/fixtures/guinji_e2e_new_join.json').readAsStringSync();
    final List<dynamic> samples = jsonDecode(raw) as List<dynamic>;
    expect(samples.length, 1);

    final map = samples.first as Map<String, dynamic>;
    final member = map['member'] as Map<String, dynamic>;
    final relation = map['relation'] as Map<String, dynamic>;

    final person = GuinjiPerson.fromServerJson(member: member, relation: relation);
    expect(v2Types.contains(person.relation), isTrue);
    expect(person.note, isNotEmpty);
    expect(person.note.length, greaterThan(10));

    final meta = guinjiRelationMetaOf(person.relation);
    expect(meta.key, person.relation);

    // ignore: avoid_print
    print(
      '[신규참여 OK] ${person.name} · ${meta.label}(${meta.hanja}) · ${person.score}점 · note="${person.note}"',
    );
  });

  test('알 수 없는 relation 키가 들어와도 guinjiRelationMetaOf가 크래시하지 않는다', () {
    // 혹시 모를 과거 레거시 값(JORYEOK 등)이나 알 수 없는 값이 들어와도
    // 반드시 'BI_HWA'로 안전하게 폴백해야 한다(non-null assertion 제거
    // 검증의 핵심 — 과거에는 `guinjiRelationTypes[key]!`로 즉시 크래시).
    for (final badKey in ['JORYEOK', 'JAGEUKJE', 'UNKNOWN_KEY', '', 'NA_SALRIDA']) {
      final meta = guinjiRelationMetaOf(badKey);
      expect(meta.key, 'BI_HWA', reason: '알 수 없는 키($badKey)는 BI_HWA로 폴백해야 함');
    }
  });

  test('GuinjiPerson.fromServerJson은 relation이 null이어도 안전하게 폴백한다', () {
    final person = GuinjiPerson.fromServerJson(
      member: {
        'memberId': 'm_test',
        'name': '테스트',
        'birthDate': '2000-01-01',
        'unlocked': false,
      },
      relation: null,
    );
    expect(person.relation, 'BI_HWA');
    expect(person.score, 0);
    expect(person.note, '');
    // relation이 없어도 메타 조회는 여전히 안전해야 한다.
    final meta = guinjiRelationMetaOf(person.relation);
    expect(meta.key, 'BI_HWA');
  });
}
