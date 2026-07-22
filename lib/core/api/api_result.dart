/// 06단계 §2.1 공통 Envelope 패턴을 Dart로 반영
/// 10단계(Mock 우선 개발) 단계에서는 MockRepository가 이 형태로 즉시 결과를 반환하고,
/// 이후 실제 NestJS API 연동 시 ApiClient가 동일한 ApiResult를 생성하도록 인터페이스를 통일한다.
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String? errorMessage;

  const ApiResult._({required this.success, this.data, this.errorCode, this.errorMessage});

  factory ApiResult.ok(T data) => ApiResult._(success: true, data: data);
  factory ApiResult.fail(String message, {String? code}) =>
      ApiResult._(success: false, errorMessage: message, errorCode: code);
}
