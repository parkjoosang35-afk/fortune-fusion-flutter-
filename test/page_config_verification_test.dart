// 메인화면 관리자 편집기 - Flutter 측 모델/평가기 검증 테스트
//
// 목적: `dart run` (plain Dart VM)에서는 section_visibility_evaluator.dart가
// package:flutter/foundation.dart -> dart:ui 를 임포트하는 체인 때문에
// "Dart library 'dart:ui' is not available on this platform" 오류로 실행이
// 불가능하다. `flutter test`는 Flutter 엔진의 dart:ui shim을 제공하므로
// 이 테스트는 위젯 pump 없이도 순수 Dart 로직(JSON 파싱, 표시 규칙 평가,
// 캐시 라운드트립)을 정상적으로 검증할 수 있다.
//
// [버그 수정] 이 픽스처(`/api/public/page-configs/home` 응답 스냅샷)를 예전에는
// `/tmp/page_config_sample.json`에 저장해 두고 읽었는데, `/tmp`는 샌드박스가
// 재시작되면 비워지는 휘발성 경로라서 다음 세션에서 "PathNotFoundException"으로
// setUpAll 자체가 실패했다. 저장소 내부(`test/fixtures/`)에 고정 픽스처로
// 커밋해 두면 어떤 환경에서도 항상 동일하게 로드된다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/home/domain/page_config_model.dart';
import 'package:flutter_app/features/home/application/section_visibility_evaluator.dart';

void main() {
  late Map<String, dynamic> decoded;

  setUpAll(() {
    final raw = File(
      'test/fixtures/page_config_sample.json',
    ).readAsStringSync();
    decoded = jsonDecode(raw) as Map<String, dynamic>;
  });

  group('PageConfigData.fromJson', () {
    test('실제 /api/public/page-configs/home 응답을 정상적으로 파싱한다', () {
      final data = PageConfigData.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );

      expect(data.pageKey, 'home');
      expect(data.sections, isNotEmpty);

      for (final s in data.sections) {
        // 13종 화이트리스트 밖의 blockType이 들어와도 unknown으로
        // 안전하게 폴백되는지 확인 (서버가 새로운 타입을 내려줘도 크래시 없음).
        expect(s.blockType, isNotNull);
        if (s.blockType == PageBlockType.unknown) {
          // 라우터의 default fallback과 동일한 철학: 모르는 값은
          // 조용히 무시(unknown)하되 앱이 죽지 않아야 한다.
          expect(s.blockTypeRaw, isNotEmpty);
        }
      }
    });

    test('toJson -> fromJson 라운드트립 시 섹션 수가 보존된다 (캐시 스토어 대응)', () {
      final data = PageConfigData.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      final roundTrip = PageConfigData.fromJson(
        jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
      );

      expect(roundTrip.sections.length, data.sections.length);
      expect(roundTrip.versionNumber, data.versionNumber);
      expect(
        roundTrip.sections.map((s) => s.sectionKey).toList(),
        data.sections.map((s) => s.sectionKey).toList(),
      );
    });
  });

  group('SectionVisibilityEvaluator', () {
    late List<PageSectionModel> sections;

    setUp(() {
      final data = PageConfigData.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      sections = data.sections;
    });

    test('open_pass_inactive 규칙: 열림패스 미사용 상태면 pass_promo 섹션이 보인다', () {
      const evaluator = SectionVisibilityEvaluator();
      final ctx = HomeVisibilityContext(
        isLoggedIn: true,
        now: DateTime.now(),
        openPassActive: false,
        happyMoneyBalance: 500,
        luckPouchBalance: 2,
        platform: 'android',
      );

      final visible = evaluator.filterVisible(sections, ctx);
      final visibleKeys = visible.map((s) => s.sectionKey).toSet();

      // pass_promo 계열 섹션이 존재한다면 openPassActive=false일 때 보여야 한다.
      final passSections = sections.where(
        (s) => s.displayRules.any((r) => r.ruleType == 'open_pass_inactive'),
      );
      for (final s in passSections) {
        expect(
          visibleKeys.contains(s.sectionKey),
          isTrue,
          reason: '${s.sectionKey}는 openPassActive=false일 때 노출되어야 한다',
        );
      }
    });

    test('open_pass_inactive 규칙: 열림패스 활성 상태면 해당 섹션이 숨겨진다', () {
      const evaluator = SectionVisibilityEvaluator();
      final ctx = HomeVisibilityContext(
        isLoggedIn: true,
        now: DateTime.now(),
        openPassActive: true,
        platform: 'android',
      );

      final visible = evaluator.filterVisible(sections, ctx);
      final visibleKeys = visible.map((s) => s.sectionKey).toSet();

      final passSections = sections.where(
        (s) => s.displayRules.any((r) => r.ruleType == 'open_pass_inactive'),
      );
      for (final s in passSections) {
        expect(
          visibleKeys.contains(s.sectionKey),
          isFalse,
          reason: '${s.sectionKey}는 openPassActive=true일 때 숨겨져야 한다',
        );
      }
    });

    test('isVisible=false로 강제 비활성화된 섹션은 항상 제외된다', () {
      const evaluator = SectionVisibilityEvaluator();
      final ctx = HomeVisibilityContext(
        isLoggedIn: true,
        now: DateTime.now(),
        platform: 'android',
      );
      final visible = evaluator.filterVisible(sections, ctx);
      for (final s in visible) {
        expect(s.isVisible, isTrue);
      }
    });
  });
}
