import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/config/env_config.dart';

void main() {
  test('재공유 결과 주소는 선택한 API 환경의 웹 전용 경로를 따른다', () {
    final api = Uri.parse(EnvConfig.adminApiBaseUrl);
    final link = Uri.parse(EnvConfig.webResultUrl('qa-share-123'));
    expect(link.origin, api.origin);
    expect(link.path, '/web-result/qa-share-123');
    expect(link.query, isEmpty);
    expect(link.fragment, isEmpty);
  });
  test('스토어 미설정은 홈페이지 주소로 대체하지 않는다', () {
    expect(EnvConfig.appDownloadUrl, isEmpty);
  });
}
