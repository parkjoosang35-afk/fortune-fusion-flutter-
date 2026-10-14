import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/util/image_gallery_saver_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('빈 이미지 저장은 권한이나 저장 호출 없이 실패한다', () async {
    expect(await saveImageBytesToGallery(Uint8List(0),name:'empty'),false);
  });
  for (final scenario in ['허용됨','요청 후 허용','권한 거부','저장 오류']) {
    test('갤러리 저장 $scenario: 실제 권한·저장 호출과 반환값', () async {
      final calls=<String>[];
      var permitted=scenario=='허용됨'||scenario=='저장 오류';
      final bytes=Uint8List.fromList([1,2,3]);
      final messenger=TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('gal'),(call) async {
        calls.add(call.method);
        if(call.method=='hasAccess') return permitted;
        if(call.method=='requestAccess') {
          if(scenario=='요청 후 허용') permitted=true;
          return permitted;
        }
        if(call.method=='putImageBytes') {
          if(scenario=='저장 오류') throw PlatformException(code:'unexpected');
          expect((call.arguments as Map)['bytes'],bytes);
          expect((call.arguments as Map)['name'],'qa-result');
        }
        return null;
      });
      addTearDown(()=>messenger.setMockMethodCallHandler(const MethodChannel('gal'),null));
      final ok=await saveImageBytesToGallery(bytes,name:'qa-result');
      expect(ok,scenario=='허용됨'||scenario=='요청 후 허용');
      if(scenario=='권한 거부') {
        expect(calls,contains('requestAccess'));
        expect(calls, isNot(contains('putImageBytes')));
      } else {
        expect(calls,contains('putImageBytes'));
      }
    });
  }
}
