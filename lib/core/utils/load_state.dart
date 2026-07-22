/// 07단계 §2.1 상태관리 아키텍처 - LoadState enum 표준 패턴
/// 모든 기능별 Provider가 동일한 로딩상태 표현을 사용하도록 표준화
enum LoadStatus { initial, loading, success, error }

class LoadState<T> {
  final LoadStatus status;
  final T? data;
  final String? errorMessage;

  const LoadState({required this.status, this.data, this.errorMessage});

  const LoadState.initial() : this(status: LoadStatus.initial);
  const LoadState.loading({T? previousData}) : this(status: LoadStatus.loading, data: previousData);
  const LoadState.success(T data) : this(status: LoadStatus.success, data: data);
  const LoadState.error(String message, {T? previousData})
      : this(status: LoadStatus.error, errorMessage: message, data: previousData);

  bool get isInitial => status == LoadStatus.initial;
  bool get isLoading => status == LoadStatus.loading;
  bool get isSuccess => status == LoadStatus.success;
  bool get isError => status == LoadStatus.error;
  bool get hasData => data != null;
}
