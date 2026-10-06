# 웹 광고 적용 범위 최종 정책 (고정)

> 이 문서는 코드가 아닌 정책 기록용입니다. 신규로 광고를 어느 화면에 넣을지 판단할 때
> 반드시 이 표를 먼저 확인하고, 아래 "소원방 제외" 원칙을 절대 깨지 않습니다.

## 서비스별 적용 범위

| 서비스 | 웹 일반 AdSense (WebAdBanner/InPage/Vignette) | 웹 Rewarded(광고 보고 무료로 보기) |
|---|---|---|
| 정통사주 (saju_renewal) | ✅ 적용 완료 (STEP E) | ⏸ 보류 (SSV 미지원으로 확정 보류) |
| 타로 (tarot) | ✅ 적용 (STEP G) | ⏸ 보류 |
| 귀인지도 | ✅ 적용 예정 | ⏸ 보류 |
| 관상 | ✅ 적용 예정 | ⏸ 보류 |
| 손금 | ✅ 적용 예정 | ⏸ 보류 |
| **소원방 (wishroom)** | **❌ 적용하지 않음 (완전 제외)** | **❌ 적용하지 않음 (완전 제외)** |

## 소원방 제외 원칙 (고정, 변경 금지)

- 소원방은 광고 적용 대상에서 **완전히 제외**한다.
- `WebAdBanner`, `WebAdInPage`, `WebAdVignette`, `WebAdAnchor` 등 WebAdService 계열
  위젯을 소원방 화면(`lib/features/wishroom/**`)에 **추가하지 않는다**.
- 소원방의 기존 UI, 캐릭터, 소원 작성, 응원, 복주머니, 상점 및 관련 UX에는
  광고를 삽입하지 않는다.
- 향후 타로 → 귀인지도 → 관상 → 손금으로 일반 AdSense 광고를 확장하더라도,
  **소원방은 자동 적용 대상에 포함시키지 않는다.** 이 서비스를 포함하려면
  반드시 사용자의 별도의 명시적 지시가 있어야 한다.

## 웹 Rewarded("광고 보고 무료로 보기") 보류 사유 (고정)

Google 공식 문서(`support.google.com/admanager/answer/9116812`)에
"Server-side verification is an app only feature and it is unavailable for
web use."라고 명시되어 있어, AdMob 앱과 동일한 수준의 신뢰 가능한 서버 검증
체인을 웹에서 구성할 수 없음이 확인됨. 향후 Google이 웹용 공식 서버 검증
방식을 제공하거나 더 안전한 대안이 확보되면 재검토한다. 그 전까지는
`WebRewardedAccess`, `REWARDED_WEB`, `rewardedSlotGranted` 연동,
`adBreak()`, AdSense Offerwall 연동을 구현하지 않는다.
