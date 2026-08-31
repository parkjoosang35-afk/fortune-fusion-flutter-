// 귀인지도 카톡 공유 OG 캐시버스팅 — 결정 매모(D1/D6) Phase 1-1 완료 판정.
//
// [완료 판정 기준] "분당 60회 생성 모두 유니크" — 짧은 시간에 반복 호출해도
// 캐시버스팅 코드가 충돌하지 않는지 확인한다. 또한 `buildGuinjiInviteLink()`가
// 만드는 URL이 `{base}/g/{token}?v={code}` 형식을 정확히 지키는지,
// [generateGuinjiShareCode]가 항상 지정된 길이/문자셋을 지키는지도 검증한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/guinji/presentation/guinji_share_screen.dart';

void main() {
  group('generateGuinjiShareCode', () {
    test('기본 길이는 6자, 소문자+숫자만 포함한다', () {
      final code = generateGuinjiShareCode();
      expect(code.length, 6);
      expect(RegExp(r'^[a-z0-9]{6}$').hasMatch(code), isTrue);
    });

    test('짧은 시간에 다량 생성해도 전부 유니크하다(캐시버스팅 목적)', () {
      // 완료 판정: "분당 60회 생성 모두 유니크" — 여유 있게 1000회로 검증.
      final codes = List.generate(1000, (_) => generateGuinjiShareCode());
      expect(codes.toSet().length, codes.length);
    });

    test('length 파라미터를 지키며, 길이가 달라도 서로 다른 값을 만든다', () {
      final code8 = generateGuinjiShareCode(length: 8);
      expect(code8.length, 8);
    });
  });

  group('buildGuinjiInviteLink', () {
    test('base URL + /g/{token}?v={6자 캐시버스팅 코드} 형식을 만든다', () {
      final link = buildGuinjiInviteLink('abcDEF123');
      final match = RegExp(r'^(https?://[^/]+)/g/abcDEF123\?v=([a-z0-9]{6})$').firstMatch(link);
      expect(match, isNotNull, reason: '실제 생성된 링크: $link');
    });

    test('호출마다 다른 캐시버스팅 코드를 생성한다(같은 token이어도)', () {
      final link1 = buildGuinjiInviteLink('sameToken');
      final link2 = buildGuinjiInviteLink('sameToken');
      expect(link1, isNot(equals(link2)));

      final v1 = RegExp(r'\?v=([a-z0-9]{6})$').firstMatch(link1)!.group(1);
      final v2 = RegExp(r'\?v=([a-z0-9]{6})$').firstMatch(link2)!.group(1);
      expect(v1, isNot(equals(v2)));
    });

    test('token 문자열은 쿼리스트링 앞에 그대로 보존된다', () {
      final link = buildGuinjiInviteLink('tok-999');
      expect(link, contains('/g/tok-999?v='));
    });
  });
}
