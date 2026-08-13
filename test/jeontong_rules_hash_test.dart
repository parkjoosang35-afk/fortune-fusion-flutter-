// 정통사주 80종 "진리 소스"(룰 데이터가 인라인된 카테고리 정의 파일)
// byte-stable 체크섬 골든 테스트. 무단 수정 시 이 테스트가 붉게 뜬다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// FNV-1a 64bit — 새 dependency 0. sha256 대체.
String _fnv1aHex(List<int> bytes) {
  const int prime = 0x100000001b3;
  int hash = 0xcbf29ce484222325;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
  }
  final s = (hash & 0x7fffffffffffffff).toRadixString(16).padLeft(16, '0');
  return s;
}

void main() {
  test('jeontong truth-source files are byte-stable (hash golden)', () {
    // STEP 0-D raw 결과 그대로: JeontongCategoryEntry 80종이 인라인 정의된
    // 단일 진리 소스 파일.
    final files = <String>[
      'lib/features/home/domain/jeontong_eighty_matrix.dart',
    ];

    if (files.isEmpty) {
      fail('체크섬 대상 파일이 비어 있음. STEP 0-D raw 결과로 교체 필요.');
    }

    final result = <String, String>{};
    for (final path in files..sort()) {
      final f = File(path);
      if (!f.existsSync()) {
        fail('룰 진리 소스가 사라졌다: $path');
      }
      result[path] = _fnv1aHex(f.readAsBytesSync());
    }
    final actual = const JsonEncoder.withIndent('  ').convert(result);

    const goldenPath = 'test/goldens/jeontong_rules_hash.json';
    final gf = File(goldenPath);
    if (!gf.existsSync()) {
      gf.createSync(recursive: true);
      gf.writeAsStringSync(actual);
      return; // 최초 캡처
    }
    final expected = gf.readAsStringSync();
    expect(
      actual,
      expected,
      reason: '룰 진리 소스 무단 변경 감지. 의도된 변경이면 골든을 명시적으로 갱신하라.',
    );
  });
}
