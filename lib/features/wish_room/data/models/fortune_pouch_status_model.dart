/// [소원방 Riverpod 실험판] "정성 담기"에 쓰이는 복주머니 보유/사용 현황.
///
/// 주의: 이 모델은 wish_room(신규 Riverpod 모듈) 내부 전용 표시값이며,
/// 앱 전역 자산인 features/luckpouch(LuckPouchProvider)와는 별개의
/// 독립 mock 데이터다. 실제 프로젝트에 통합할 때는 이 값을 LuckPouchProvider
/// 잔액으로부터 매핑해서 채우는 것을 권장한다(⑭ 개발 시 유의사항 참고).
class FortunePouchStatus {
  final int totalCount;
  final int usedToday;
  final int earnedToday;
  final int dailyFreeQuota;

  const FortunePouchStatus({
    required this.totalCount,
    this.usedToday = 0,
    this.earnedToday = 0,
    this.dailyFreeQuota = 1,
  });

  FortunePouchStatus copyWith({
    int? totalCount,
    int? usedToday,
    int? earnedToday,
  }) {
    return FortunePouchStatus(
      totalCount: totalCount ?? this.totalCount,
      usedToday: usedToday ?? this.usedToday,
      earnedToday: earnedToday ?? this.earnedToday,
      dailyFreeQuota: dailyFreeQuota,
    );
  }
}
