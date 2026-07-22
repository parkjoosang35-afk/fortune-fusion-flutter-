/// Mock Repository 공용 유틸 - 실제 네트워크 호출과 유사한 지연을 재현
/// (09단계 §5 예외처리/로딩 UX가 실제 환경과 유사하게 동작하도록)
Future<void> mockDelay({int ms = 600}) => Future.delayed(Duration(milliseconds: ms));
