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

## 7. 1단계 완료 (커밋 `ec9257c`, 사용자 최종 승인 완료)

| 항목 | 값 |
|---|---|
| 테스트 결과 | `npm run test:coupon-design` → **통과 50건 · 실패 0건 · 스킵 0건** |
| 테스트 수 보존 | 원본 57건(39+18) = step1 50건(38+12) + step2 7건(1+6), 유실 0건 |
| tsc 잔존 에러 | 1건(`design.step2-renderer.test.ts`의 `renderer` 모듈 미존재) — **2단계 작업 대상, 의도된 정상 상태** |
| PARTS 자동 비교 | `node scripts/checks/compare-parts.mjs` → ui-목업 17종 vs 이식본 17종 순서까지 완전 일치 |
| 산출물 커밋 | `ec9257c`(테스트 하네스 skip/todo 지원 + step1/step2 분리 + globals.d.ts), 선행 `301355b`(디자인 코어 이식) |

### 7.1 검증 과정에서 발견한 사항 (코드 변경 없음, 기록용)

- **명세서 오탈자**: `개발명세서.html` 50장 제목 "부품 16종"은 오탈자. 코드 기준(ui-목업 `data.js`의 `PARTS`, 이식본 `templates.ts`의 `PARTS`) **17종이 정확**하며 양쪽 완전 일치 확인(`compare-parts.mjs`). 명세서 파일(참고자료, admin_web 소스 아님) 자체는 수정하지 않음.
- **테스트 영향 측정 시 발생한 2건의 측정 오류(사용자 셀프 교정, 기록 보존 목적)**:
  1. "globals.d.ts 설치로 tsc 에러 161건→0건"(v4 패키지 주장) — admin_web에 실제 트라이얼 적용 결과 **13건 잔존**이 정답이었음(`expect(x, label)` 2인자 호출 12건 + `redeemModeOf` 존재하지 않는 메서드 호출 1건). v5에서 이 13건을 정확히 타깃 수정(`expect` 2인자 시그니처 추가, `redeemModeOf` 체이닝 제거) → tsc 재검증 결과 **1건**(2단계 대상, 정상)으로 감소, 실측 확인 완료.
  2. 위 1번과 별개로, 외부(사용자) 환경에서 "tsc 0건"으로 측정된 것은 외부 `sintong-coupon/tsconfig.json`의 `"exclude": ["...", "test"]` 설정 때문에 테스트 파일이 애초에 타입 검사 대상에서 제외되어 있었던 것으로 확인됨. **admin_web 실제 환경(테스트 포함 검사)에서 트라이얼 적용으로 얻은 결과가 정본**이며, 이 매핑표 및 완료보고서는 그 정본 수치(13→1)를 기준으로 작성됨.

### 7.2 2단계 착수 전 필요 자료 (아래 §8, §9 참고)

- `BokjuCouponDesignTemplate` 현재 필드 목록 → §8
- `CouponVisibilityConfig` 11항목 → §9
- 매핑표 → 본 문서 §3 (위 작성됨, 갱신 불필요 — 2단계 범위에 영향받는 필드 없음)

## 8. BokjuCouponDesignTemplate 현재 필드 목록 (schema.prisma 실측, 2단계 참고용)

```prisma
model BokjuCouponDesignTemplate {
  id            Int      @id @default(autoincrement())
  name          String                                    // 관리자가 붙인 템플릿 이름
  designAssetId Int?     @map("design_asset_id")           // null이면 흰 배경(기존 MINIMAL과 유사) 기본 렌더링
  visibility    String   @map("visibility")                // JSON: CouponVisibilityConfig 11항목(§9) 직렬화
  isDefault     Boolean  @default(false) @map("is_default")
  isArchived    Boolean  @default(false) @map("is_archived") // true면 선택 목록에서만 숨김, 기존 발행 이미지엔 영향 없음
  createdBy     String?  @map("created_by")
  createdAt     DateTime @default(now()) @map("created_at")
  updatedAt     DateTime @updatedAt @map("updated_at")

  designAsset BokjuCouponDesignAsset? @relation(fields: [designAssetId], references: [id], onDelete: SetNull)
  campaigns   BokjuCouponCampaign[]

  @@index([designAssetId])
  @@map("bokju_coupon_design_templates")
}
```

> 2단계(토큰 렌더러 지원) 영향 범위 검토: 현재 `visibility` 컬럼은 좌표 자유배치가 아닌 "11항목 on/off + reflow" 방식(§9)이며, 이식 대상 레이아웃(`DesignLayout`, 자유좌표+템플릿+팔레트)과 **데이터 모델이 다름**. 2단계에서 이 두 방식을 어떻게 공존시킬지(신규 컬럼 추가 여부 등)는 매핑표(§3) 상 "표시·숨김 설정 — 삭제 금지, 유지. 좌표 배치 에디터와 공존(4단계)" 방침에 따라 **4단계(관리자 에디터 화면)에서 구체화** 예정이며, 2단계(렌더러) 자체는 `BokjuCouponDesignTemplate`을 읽거나 쓰지 않음(렌더러는 `DesignLayout` 객체만 입력받음).

## 9. CouponVisibilityConfig 11항목 (src/lib/bokju-coupon-visibility.ts 실측, 2단계 참고용)

```ts
export interface CouponVisibilityConfig {
  logo: boolean;        // 신통방통 로고
  title: boolean;       // 쿠폰명
  amount: boolean;      // 지급 복주머니 수량
  couponNo: boolean;    // 쿠폰번호
  qr: boolean;          // QR코드
  validFrom: boolean;   // 사용 시작일
  validTo: boolean;     // 사용 만료일
  guideText: boolean;   // 쿠폰 안내 문구
  ctaText: boolean;     // '쿠폰 등록하러 가기' 안내
  partnerName: boolean; // 이벤트명 또는 제휴업체명
  decoration: boolean;  // 장식 요소 및 테두리
}
```

- 캔버스 상수: `CANVAS_WIDTH=720`, `CANVAS_HEIGHT=1280` (기존 `bokju-coupon-image-service.ts`와 동일, 1차 패키지의 1080×1920과 다름 — §5에 이미 기록됨, 2단계에서 토큰 렌더러의 `CANVAS_PRESETS`와 별도 네임스페이스로 유지해야 충돌 없음)
- `computeLayout(visibility)`가 11항목 중 표시(`true`)된 블록만 세로 1열로 순서대로 재배치(reflow)하는 **기존 쿠폰 100장 렌더링 로직**이며, 이 로직은 `bokju-coupon-image-service.ts`에서만 사용됨 — 2단계 토큰 렌더러(`renderer.ts`)는 이 함수를 호출하지 않고 완전히 별도 경로로 동작해야 함(금지목록②와 동일 원칙: 기존 파이프라인 불가침).
