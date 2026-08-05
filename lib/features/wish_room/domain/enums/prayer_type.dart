/// [치성 시스템] 소원방에서 올릴 수 있는 치성(기도) 종류.
///
/// 정책표 ②③ 참고. "차감"이라는 표현은 UI에 절대 노출하지 않고 항상
/// "정성을 담다/더하다"로 표현한다(마이크로카피 가이드 참고).
enum PrayerType {
  /// 오늘의 치성 — 하루 1회 무료. 복주머니 소비 없음, 성장치 소폭 증가.
  daily,

  /// 깊은 치성 — 복주머니 사용. 성장치 대폭 증가 + 강한 시각 보상.
  deep,

  /// 집중 치성 — 특정 소원에 복주머니를 더 많이 사용해 성장치를 크게 올림.
  /// 깊은 치성보다 사용량이 크고 성장치도 그에 비례해 크다(고배율).
  focused,

  /// 감사 치성 — [고도화] 소원이 이뤄졌다고 사용자가 표시할 때 사용하는
  /// 특별 치성. 복주머니 소비 없이 완료 처리 + 특별 연출/뱃지 지급.
  gratitude,
}

extension PrayerTypeX on PrayerType {
  /// 이 치성 1회 실행에 필요한 복주머니 수량(MVP 기본값, 정책표 ③ 기준값).
  int get pouchCost {
    switch (this) {
      case PrayerType.daily:
        return 0;
      case PrayerType.deep:
        return 1;
      case PrayerType.focused:
        return 3;
      case PrayerType.gratitude:
        return 0;
    }
  }

  /// 이 치성 1회 실행으로 대상 소원에 더해지는 성장 포인트(정책표 ⑥ 기준값).
  int get growthPointGain {
    switch (this) {
      case PrayerType.daily:
        return 5;
      case PrayerType.deep:
        return 15;
      case PrayerType.focused:
        return 40;
      case PrayerType.gratitude:
        return 0; // 성장이 아니라 "완료 처리"이므로 성장치 개념이 적용되지 않음.
    }
  }

  String get label {
    switch (this) {
      case PrayerType.daily:
        return '오늘의 치성';
      case PrayerType.deep:
        return '깊은 치성';
      case PrayerType.focused:
        return '집중 치성';
      case PrayerType.gratitude:
        return '감사 치성';
    }
  }

  String get ctaLabel {
    switch (this) {
      case PrayerType.daily:
        return '오늘의 정성 올리기';
      case PrayerType.deep:
        return '정성 더하기';
      case PrayerType.focused:
        return '이 소원에 집중하기';
      case PrayerType.gratitude:
        return '소원이 이뤄졌어요';
    }
  }
}
