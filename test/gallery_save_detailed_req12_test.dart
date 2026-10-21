// [REQ-12 — 신통방통_저장기능_정상화_개발지시서_v1.0] "저장 유틸 단위 테스트
// (빈 바이트 → 실패, 권한 거부 → 저장 미호출, 저장 오류 → 실패 반환)를 유지할
// 것"을 상세 버전 API에도 적용한다.
//
// [배경] 기존 `gallery_permission_flow_test.dart`는 bool을 반환하는
// `saveImageBytesToGallery()`만 검증했다. 그러나 REQ-05에서 도입되어 현재
// 전체 저장 호출부(8개 화면 + 공유 시트)가 실제로 사용 중인
// `saveImageBytesToGalleryDetailed()`(실패 원인 구분 반환)에는 단위 테스트가
// 전혀 없었다 — 원인별 분기(GallerySaveFailureReason)가 회귀해도 테스트가
// 잡아내지 못하는 공백이었다. 이 파일은 그 공백을 메운다.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/util/gallery_save_result.dart';
import 'package:flutter_app/core/util/image_gallery_saver_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('gal');

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('saveImageBytesToGalleryDetailed — REQ-12 단위 테스트', () {
    test('빈 바이트 → emptyBytes 실패, 권한/저장 채널 호출 자체가 없다', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });

      final result = await saveImageBytesToGalleryDetailed(
        Uint8List(0),
        name: 'empty',
      );

      expect(result.isSuccess, false);
      expect(result.failureReason, GallerySaveFailureReason.emptyBytes);
      expect(result.failureMessage, isNotNull);
      // bytes.isEmpty 가드가 네이티브 호출 전에 걸러야 한다 — 빈 이미지로
      // 권한을 묻거나 저장을 시도하면 안 된다.
      expect(calls, isEmpty);
    });

    test('권한 거부 → accessDenied 실패, putImageBytes는 호출되지 않는다', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'hasAccess') return false;
        if (call.method == 'requestAccess') return false; // 거부 유지
        return null;
      });

      final result = await saveImageBytesToGalleryDetailed(
        Uint8List.fromList([1, 2, 3]),
        name: 'denied',
      );

      expect(result.isSuccess, false);
      expect(result.failureReason, GallerySaveFailureReason.accessDenied);
      expect(calls, contains('requestAccess'));
      // [REQ-12 핵심 요구] 권한 거부 시 저장(putImageBytes) 자체를 시도하지
      // 않아야 한다 — 불필요한 네이티브 호출·예외를 막는다.
      expect(calls, isNot(contains('putImageBytes')));
    });

    test('권한 허용(기허용) → success, putImageBytes가 정확한 인자로 호출된다', () async {
      final calls = <String>[];
      final bytes = Uint8List.fromList([9, 9, 9]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        if (call.method == 'hasAccess') return true;
        if (call.method == 'putImageBytes') {
          expect((call.arguments as Map)['bytes'], bytes);
          expect((call.arguments as Map)['name'], 'ok-result');
        }
        return null;
      });

      final result = await saveImageBytesToGalleryDetailed(
        bytes,
        name: 'ok-result',
      );

      expect(result.isSuccess, true);
      expect(result.failureReason, isNull);
      expect(result.failureMessage, isNull);
      expect(calls, contains('putImageBytes'));
    });

    // [REQ-05/REQ-12] 저장 오류 원인별로 GallerySaveFailureReason이 정확히
    // 매핑되는지 — gal 패키지는 PlatformException.code(ACCESS_DENIED 등)를
    // GalExceptionType으로 변환하므로, 네이티브 채널이 그 code로
    // PlatformException을 던지는 상황을 그대로 재현한다.
    final causeMatrix = <String, GallerySaveFailureReason>{
      'NOT_ENOUGH_SPACE': GallerySaveFailureReason.notEnoughSpace,
      'NOT_SUPPORTED_FORMAT': GallerySaveFailureReason.notSupportedFormat,
      'UNEXPECTED': GallerySaveFailureReason.unexpected,
      'SOME_UNKNOWN_NATIVE_CODE': GallerySaveFailureReason.unexpected,
    };

    for (final entry in causeMatrix.entries) {
      test('저장 오류(${entry.key}) → ${entry.value.name} 실패로 매핑되고 호출부는 '
          '성공으로 오처리하지 않는다', () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'hasAccess') return true;
          if (call.method == 'putImageBytes') {
            throw PlatformException(code: entry.key, message: 'mock failure');
          }
          return null;
        });

        final result = await saveImageBytesToGalleryDetailed(
          Uint8List.fromList([1, 2, 3]),
          name: 'fail-result',
        );

        expect(result.isSuccess, false);
        expect(result.failureReason, entry.value);
        expect(result.failureMessage, isNotEmpty);
      });
    }

    test('bool 반환 호환 API(saveImageBytesToGallery)도 동일한 실패/성공 '
        '판정을 그대로 위임한다', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'hasAccess') return false;
        if (call.method == 'requestAccess') return false;
        return null;
      });

      final ok = await saveImageBytesToGallery(
        Uint8List.fromList([1, 2, 3]),
        name: 'legacy-api',
      );

      expect(ok, false);
    });
  });
}
