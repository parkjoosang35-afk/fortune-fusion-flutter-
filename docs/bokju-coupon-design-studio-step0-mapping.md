# 복주머니 쿠폰 디자인 스튜디오 — 0단계 산출물: 매핑표

> 작성일: 2026-10-17
> 근거: `개발팀-지시서-2차.md`(정정본 `(1).md`) §0~§6, 실제 `prisma/schema.prisma` / 패키지 소스 대조

## 1. 미푸시 커밋 처리 결과

| 커밋 | 처리 전 | 처리 후 |
|---|---|---|
| `86993f9c26e891bc2732b85e90c2c9bcd3c1392f` | origin에 없음 | ✅ push 완료 (`git push origin feat/integration-20261013` 실행, 재검증으로 origin/HEAD 일치 확인) |
| `fdc2b06` | origin에 없음 | ✅ 위 push에 포함되어 함께 해소 |

## 2. 백업

| 대상 | 경로 | 결과 |
|---|---|---|
| 로컬 DB | `prisma/dev.db.backup_20261017_105648_pre_coupon_studio` | 5,619,712 bytes |
| 운영 DB | `ubuntu@sintong.kr:/var/www/admin_web/prisma/dev.db.backup_20261017_195651_pre_coupon_studio` | 4,694,016 bytes, `PRAGMA integrity_check`=ok |

## 3. 모델/필드 매핑표 — 기존 재사용 vs 신규 추가

| 구분 | 기존 모델/필드 (schema.prisma 실측) | 1차 패키지 대응 개념 | 처리 방침 |
|---|---|---|---|
| 회원 표시명 | `User.nickname` (unique) | `name`(패키지 가정) | **`nickname` 고정.** 패키지식 가정은 폐기 |
| 지갑 적립 | `Wallet`/`PointHistory`, `earnLuckPouch()` | `wallet.port.ts`(SameDbWallet/RemoteWallet) | **기존 `earnLuckPouch()` 그대로.** wallet.port.ts 이식 안 함 |
| 캠페인 | `BokjuCouponCampaign`(id,title,grantAmount,issueType,targetAudience,useLimitPerMember,sharedTotalLimit,validFrom,validTo,guideText,distributionMethod,**designTemplate**(4종 내장 CLASSIC/PREMIUM/KAKAO/MINIMAL),**customTemplateId**→BokjuCouponDesignTemplate,status,issuedCount,allocatedCount,redeemedCount,usedCount) | `campaign` 테이블(PG) | 그대로 재사용. `customTemplateId`가 이미 있어 **신규 템플릿 테이블 불필요** |
| 쿠폰 | `BokjuCoupon`(id,campaignId,couponNo,redeemToken,status,partnerId,allocationId,assignedUserId,issuedAt,expiresAt,redeemedAt,redeemedBy,revokedAt,revokedReason,**rowVersion**(낙관적락)) | `coupon` 테이블(PG, FOR UPDATE) | 그대로 재사용. **`designRevNo` 컬럼 1개만 3단계에서 추가** (현재 없음 — 실측 확인됨) |
| 디자인 템플릿 | `BokjuCouponDesignTemplate`(id,name,designAssetId→BokjuCouponDesignAsset,**visibility**(String/JSON 11항목),isDefault,isArchived,createdBy,createdAt,updatedAt) | 1차 패키지엔 대응 테이블 없음(신규 개념) | **확장만.** 새 테이블 금지. 필드 추가는 2~4단계에서 필요시 논의 |
| 디자인 자산 | `BokjuCouponDesignAsset`(id,prompt,imagePath,status,failReason,createdBy,createdAt) | - | 그대로 유지 |
| 표시·숨김 설정 | `CouponVisibilityConfig` (TS 인터페이스, 11항목: logo/title/amount/couponNo/qr/validFrom/validTo/guideText/ctaText/partnerName/decoration) | 없음(1차는 자유좌표라 개념 자체가 다름) | **삭제 금지, 유지.** 좌표 배치 에디터와 공존(4단계) |
| 업체 | `BokjuPartner`, `BokjuPartnerAccount` | `partner` 테이블 | 그대로 재사용 |
| 할인쿠폰(별개 도메인) | `Coupon`/`CouponIssue` → `coupons`/`coupon_issues` | 없음 | **절대 재사용·수정 금지** |
| 죽은 테이블 | `LuckPouchWallet`/`LuckPouchHistory`/`LuckPouchRule` → `luck_pouch_*` | - | **사용 금지 유지** |
| 리비전(신규) | 없음 | `sql/004_design_revision.up.sql` | **`BokjuCouponDesignRevision` 신규 테이블 추가 필요** (3단계) — 발행 시점 디자인 스냅샷 동결용 |

## 4. 이식 진행 현황 (1단계)

| 원본(1차 패키지) | 대상(실제 생성) | 상태 |
|---|---|---|
| `src/coupon/design/theme.ts` | `src/lib/bokju-coupon-design/theme.ts` | ✅ 이식 완료. DB 의존 0곳. import 경로 외 변경 없음 |
| `src/coupon/design/templates.ts` | `src/lib/bokju-coupon-design/templates.ts` | ✅ 이식 완료. `boxOf(c)` 구조가 이미 캔버스 크기를 매개변수로 받으므로 좌표계 별도 적응 불필요(원본 그대로) |
| `src/coupon/design/layout.ts` | `src/lib/bokju-coupon-design/layout.ts` | ✅ 이식 완료. 변경 없음 |

## 5. 렌더 파이프라인 (회신요청③)

| 항목 | 값 |
|---|---|
| 라이브러리 | `sharp`, `qrcode`, `archiver`, `exceljs` |
| 경로 | `src/lib/bokju-coupon-image-service.ts` |
| 캔버스 상수 | `IMG_WIDTH=720`, `IMG_HEIGHT=1280`, `BATCH_SIZE=20` (1차 패키지의 1080×1920과 다름 — 2단계에서 토큰 지원 시 유의) |
| 연동 모듈 | `src/lib/bokju-coupon-visibility.ts`의 `CouponVisibilityConfig`/`computeLayout`/`parseVisibilityJson`/`CANVAS_WIDTH`/`CANVAS_HEIGHT` |

## 6. 테스트 러너 (회신요청④ — 해결됨)

- 운영 프로젝트에 vitest/jest/mocha 등 표준 러너 **없음** (실측 확인, `package.json` 의존성 0건)
- 개발팀이 제공한 `scripts/run-design-tests.ts`(외부 의존 0, describe/it/expect 전역 주입) 설치 완료
- `package.json`에 `"test:coupon-design": "tsx scripts/run-design-tests.ts"` 추가 완료
