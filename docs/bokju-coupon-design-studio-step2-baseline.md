# 2단계 착수 전 회귀 검증 베이스라인

- 채취 시각: 2026-10-17 (02c 결정사항 문서 수령 직후, renderer.ts 작성 착수 전)
- 채취 방법: 기존 `bokju-coupon-image-service.ts`의 `renderPreviewCouponImage()` (export된 함수, 변경 대상 아님)를 고정 파라미터로 호출
- 입력 파라미터(고정):
  ```ts
  {
    designTemplate: 'CLASSIC',
    campaignTitle: '2단계-회귀검증-고정샘플',
    grantAmount: 100,
    guideText: '회귀검증용 고정 안내문구',
    validFrom: new Date('2026-01-01T00:00:00.000Z'),
    validTo: new Date('2026-12-31T00:00:00.000Z'),
  }
  ```
- 결과:
  - SHA256: `4e1cde4c0d2ecd64d895dcd8b24359f2b5e0b0d142969973e2c0195b59261578`
  - 크기: 64084 bytes
  - 재현성 검증: 동일 입력으로 2회 실행, 해시 동일 확인
- 용도: 2단계(renderer.ts 신규 생성) 완료 후, 동일 입력으로 동일 함수를 다시 호출해 해시가 그대로인지 확인한다.
  `bokju-coupon-image-service.ts`는 2단계에서 전혀 수정하지 않으므로 이론상 당연히 동일해야 하지만,
  "간접 영향(예: import 경로 공유 모듈의 의도치 않은 변경)"이 없었음을 증명하는 절대 기준선이다.
