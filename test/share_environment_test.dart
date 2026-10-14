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
  test('다운로드 안내 주소는 별도 설정이 없으면 API 환경을 따른다', () {
    expect(EnvConfig.appDownloadUrl, EnvConfig.adminApiBaseUrl);
  });
}
