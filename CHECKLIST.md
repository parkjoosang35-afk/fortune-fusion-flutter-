# 소원방 보관함 정리(Task 4) — 대표 판정 및 진행 현황

## 대표님 판정 원문 (4-A / 4-B / K10 범위 확정)

> **판정: 제안하신 범위 그대로 승인합니다.**
>
> **이번 커밋 (4-A)**
> - 탭을 3개에서 2개로 줄이기 (소원 기록관 / 응원 보상)
> - 「지금 밝히는 소원」 카드 추가
> - 「캐릭터」 칩 빼기
> - 🧧 잔액 시트로 옮기기: 잔액(합계), 오늘 적립, 적립·사용 내역
> - 이름표 4개 달기
> - 기록 카드는 **成 도장만** 표시
>
> **1. 放(내려놓기) + 한 줄 메모 → 바로 다음 단계(4-B)로**
> 放은 빼도 되는 기능이 아닙니다. 서버: outcome에 `RELEASED` 추가, 기록에 `note`(한 줄, 최대 40자).
> 앱: ⋯ → 소원 마무리 시트에서 「成/放」 선택. 기준 원본: `app3/extras.js`의 마무리 화면
>
> **2. 충전 버튼 · 충전/받은 구분 → 이번 범위에서 제외 (지금처럼 placeholder 유지)**
> 신통방통 본 지갑 서버(매핑표 K10) 소관, 소원방 쪽에서 따로 만들면 안 됨.
>
> **완료 기준**: 4-A 커밋 1개, 캡처 3장(소원 기록관 · 응원 보상 · 🧧 시트)을 서비스판과 나란히
> 보낼 것. 통과하면 4-B로 넘어감.

---

## 4-A — 완료 (이번 커밋)

구현 범위:
- `vault_screen.dart`: `TabController` 3개 → 2개(소원 기록관 / 응원 보상). 우상단 "캐릭터" 칩 제거
  (수호자 진입은 🧧 잔액 시트의 "소원방에서 쓰는 곳" 카드로 통합).
- `_ArchiveTab`: 기존 "진행 중/이루어진 소원" 필터 칩 토글 대신, "지금 밝히는 소원" 카드
  (`_CurrentWishCard`)를 맨 위에 항상 노출. 願 인장 + 소원 문구 + 🕯dayN·🙏prayedN·✦단계명
  통계줄 + "✿ 소원이 이루어졌어요" 버튼(2단계 확인 다이얼로그 → `CompleteScreen`).
  app3/flows.jsx `Vault3` 기준.
- 기록 카드(`_ArchiveCard`)·리플레이(`_ReplayOverlay`)는 **成 도장만** 표시 — 변경 없음(판정 그대로).
- "응원 보상" 탭(`_RewardTab`)은 변경 없음(판정 그대로).
- `wallet_sheet.dart`: 구 "복주머니" 탭(적립/사용 내역)을 삭제하고, 🧧 잔액 시트 안에
  "적립·사용 내역" 섹션으로 인라인 이식(`_ledgerRow`/`_agoLedger`, `p.ledger.take(10)`).
  잔액(합계)·오늘 적립은 기존 잔액 시트 상단에 이미 있던 요소 그대로 유지.
- Semantics identifier 4개 추가: `vault_tab_archive`, `vault_tab_rewards`, `vault_fulfill`,
  `archive_card_<id>`.

**4-A 스코프 제외 결정 (내 자체 판단, 안전한 기본값)**: "지금 밝히는 소원" 카드의 app3 원본에 있는
"최근 14일" 기도 점등 그리드와 "N일 기도 목표 · N번 남음" 문구는, 이를 뒷받침할 서버 데이터가
현재 없음(일자별 기도 로그 테이블 `WishRoomPrayerLog`는 실제 라우트 코드에서 미사용 확인, 목표
설정 기능 자체가 코드베이스에 없음)을 확인하여 이번 커밋에서는 제외했다. 🕯dayN·🙏prayedN·✦단계명
통계줄만 구현.

**검증**: `flutter analyze` 전체 프로젝트 클린(이번 변경으로 인한 신규 에러/경고 없음 — 기존에
있던 무관한 테스트 파일 에러 2건만 잔존, 이번 세션 변경 이전부터 존재). `build_local.sh` 빌드
성공. Playwright로 실제 화면 확인 완료(소원 기록관 / 응원 보상 / 🧧 잔액 시트의 "적립·사용 내역"
섹션 모두 정상 렌더링).

**서비스판(app3) 대조 결과** (`/home/user/wr_compare/compare_1_archive.png`,
`compare_2_rewards.png`, `compare_3_wallet.png`):
- **소원 기록관**: Flutter와 app3 모두 願 인장 + 소원문구 + 통계줄 + "✿ 소원이 이루어졌어요"
  버튼 구조 일치. 차이점 1건 — app3는 "최근 14일" 점등 그리드를 보여주나 Flutter는 이번
  커밋에서 의도적으로 제외(뒷받침 서버 데이터 없음, 위 "4-A 스코프 제외 결정" 참고).
- **응원 보상**: app3 원본에는 이 탭 자체가 없음(단일 스크롤 ARCHIVE 화면). "응원 보상"은
  Flutter에만 있는 기존 기능이며 이번 판정에서도 "변경 없음"이라 대조 대상이 아님.
- **🧧 잔액 시트**: 구조는 유사(잔액 숫자 + 오늘 적립 가능 목록 + 적립·사용 내역 리스트)하나
  app3는 "충전한/받은 복주머니" 구분·충전 버튼·환율 안내(1개=10원)·만료 정책 문구가 있고
  Flutter는 이번 범위(K10 제외)에 따라 이 부분을 아직 넣지 않음 — 판정대로 의도된 차이.

---

## 4-B — 완료 (放 내려놓기 + 한 줄 메모)

구현 범위 (대표님 판정 1번, 기준 원본 `app3/extras.js` Fulfill3):

**서버 (admin_web)**:
- `outcome` 허용값에 `RELEASED` 추가 (`outcome/route.ts`, `complete/route.ts`). 기존
  `outcome` 컬럼이 자유 문자열(`String?`)이라 컬럼 변경 없이 값만 추가.
- `note TEXT` 컬럼 신설 (`prisma/schema.prisma` + 신규 마이그레이션
  `20261121070000_add_wishroom_outcome_note`). 최대 길이는 **40자** — app3 원본(60자)과
  다르게 대표님 지시로 40자를 서버가 `.slice(0, 40)`으로 강제.
- `complete/route.ts`: `outcome` 파라미터 생략 시 기존 호환을 위해 `FULFILLED`로 간주
  (기존 `vault_screen.dart`의 "✿ 소원이 이루어졌어요" 버튼은 成 전용이라 그대로 outcome
  없이 호출해도 회귀 없음).
- **RELEASED(放) 설계**: FULFILLED와 달리 (1) 완료 알림을 보내지 않고 (2) `wishStatus`를
  `ACHIEVED`로 바꾸지 않음(`IN_PROGRESS` 유지). 이 설계 덕분에 "이루어진 소원에만 후기 작성"
  가드(`review/route.ts`, `explore_screen.dart`의 `canWrite`)가 별도 분기 추가 없이 그대로
  放 방의 후기 작성 CTA를 자동으로 막아줌.
- `wishroom-engine.ts`의 `roomView()`에 `note` 필드 전달 추가.
- 취소(`cancel:true`) 시 `outcome`/`note`도 함께 null로 되돌림.

**⚠️ 별도 보고 필요 — 기존에 있던 문제 발견**: 이번 세션과 무관하게 이미 깨져 있던 Prisma
마이그레이션 `20261106021511_shrine_v3_talisman_tables`가 "table already exists" 에러로
`prisma migrate deploy`를 막고 있음(그 마이그레이션 자체 주석에도 사전 드리프트로 기록돼
있었음, 이번 세션이 만든 문제 아님). 이번 세션은 이를 우회해 `sqlite3`로 `note` 컬럼을 직접
추가하고 `_prisma_migrations`에 수동 기록했음 — **원본 깨진 마이그레이션 자체의 수정은
범위 밖이라 손대지 않았고, 대표님께 별도로 플래그 필요**.

**Flutter 앱**:
- `models.dart`: `Outcome` enum에 `RELEASED` 추가, `WishRoom.note` 필드 추가.
- `wr_api.dart`/`wishroom_provider.dart`: `outcome()`/`complete()`에 `note`(및 `complete`엔
  `outcome`) 파라미터 추가.
- `main_room_screen.dart` `_CareSheet`: "⋯ → 소원 마무리 시트"에 成/放 2카드 선택 UI
  (`_buildFinishPanel`/`_finishModeCard`) + 한 줄 메모 `TextField(maxLength: 40)` 추가.
  放 선택 시 app3 `Fulfill3.go()`와 동일하게 2단계 확인("정말 내려놓을까요" 경고 → 재탭 시
  실제 진행).
- `complete_screen.dart`: `CompleteScreen`에 `outcome`/`note` 파라미터 추가해 전달. 도장
  표시 3곳(`_SealingOverlay`, `_BottomCard`, `_SealedBody`)을 모두 `room.outcome ==
  Outcome.RELEASED` 조건으로 成(주황, `WrC.accent`)/放(보라, `0xFF7A6A9A`) 구분 표시.
- `vault_screen.dart`: 기록 카드(`_ArchiveCard`)와 재생 오버레이(`_ReplayOverlay`)의 도장도
  동일하게 成/放 조건부 표시로 변경(4-A에서 "成 도장만"이던 것을 4-B 범위로 확장).
  `_CurrentWishCard._confirmFulfill()`("✿ 소원이 이루어졌어요" 버튼)은 의도적으로 成 전용
  그대로 유지 — 성격상 放과 무관.
- Semantics identifier 신규 7개: `finish_mode_fulfilled`, `finish_mode_released`,
  `finish_note_field`, `finish_not_yet`, `finish_confirm` (+ `_finishModeCard`가 받는
  `identifier` 파라미터로 위 2개 카드 포함).

**검증**: `flutter analyze` 전체 프로젝트 — 이번 변경으로 인한 신규 에러/경고 없음(기존
`guardian_outfit_launcher_test.dart` 무관 에러 2건만 잔존, 이전 세션부터 존재). `build_local.sh`
빌드 성공(`build/web` 생성 확인). **주의**: 이번 세션은 코드 정적 검증(analyze)과 빌드 성공까지만
완료했고, Playwright를 통한 실제 클릭 플로우 녹화/캡처 및 app3와의 화면 대조는 세션 종료로 인해
**아직 수행하지 못함** — 다음 세션에서 이어서 진행 필요.

---

## 4-B — 다음 단계 (아직 시작 안 함)

범위:
- 서버: `outcome` enum에 `RELEASED` 추가(放·내려놓기). 완료 기록에 `note` 필드 추가
  (한 줄, **최대 40자** — 대표님 지시 기준. 참고: app3 원본 `extras.js`의 `Fulfill3`은
  60자 제한을 쓰고 있어 수치가 다름 — 이 체크리스트에 기록해두고, 실제 구현 시 대표님
  지시대로 **40자**를 따른다).
- 앱: "⋯ → 소원 마무리 시트"(`main_room_screen.dart`의 `_CareSheet` 추정 위치)에서
  「成/放」 선택 UI 추가. 기준 원본: `app3/extras.js`의 `Fulfill3` 마무리 화면.
- `complete_screen.dart`의 成 도장 표시 로직을 outcome 값에 따라 成/放 조건부로 변경.
- `vault_screen.dart`의 `_ArchiveCard`/`_ReplayOverlay` 도장 표시도 동일하게 조건부로 변경.

4-A 커밋 승인 후 착수 예정.

---

## K10 — 소원방 범위에서 완전 제외

충전 버튼 활성화 · 충전/받은 구분 기능은 "신통방통 본 지갑 서버"(매핑표 K10) 소관이며,
소원방 쪽에서 별도로 만들지 않는다. 현재 `pay_screen.dart`의 충전 placeholder를 그대로 유지한다
(소원방 쪽 추가 작업 없음).

### 4-B 放 동작 검증 (Playwright, 이 세션)

**치명적 버그 발견 및 수정**: `schema.prisma`에 `note` 필드를 추가했지만 `npx prisma generate`를
재실행하지 않아 Prisma Client(`src/generated/prisma`, gitignore 대상이라 커밋에는 안 잡힘)가
구버전이었음. 그 결과 放 완료 요청이 전부 `Unknown argument note` 500 에러로 실패했음
(화면엔 "잠시 후 다시 시도해주세요" 토스트만 뜨고 원인 불명).
→ `npx prisma generate` 재실행 + dev 서버 재시작으로 해결. **배포 시 반드시
`prisma generate`를 빌드 스텝에 포함해야 함** (보통 `npm run build`나 `postinstall`에
들어있는지 확인 필요 — 로컬 dev에서는 수동 재기동 전까지 반영 안 됨).

**확인 완료**:
- [x] 放 선택 → 메모 입력 → 1차 탭(경고 문구 노출, 버튼 라벨 "放 네, 내려놓을게요"로 변경) →
      2차 탭 → DB 반영 확인: `status=COMPLETED, outcome=RELEASED, note='放 최종확인',
      wish_status=IN_PROGRESS` (설계대로 ACHIEVED로 바뀌지 않음) — **정상**
- [x] 2차 탭 후 화면 전환: CompleteScreen 放 봉인 애니메이션 정상 표시

**미확인 (다음 세션에서 이어서 확인 필요)**:
- [ ] 放 완료 직후 `/#/wish-room` 재진입 화면(`60_after_release_newroom.png`)이 기존 소원
      ("가족 모두 건강하고 평안하게 지내기를", 15일째·기도20번)을 그대로 보여줌 —
      **새 소원 작성 화면으로 전환되는지, 아니면 별도 진입점(버튼 등)이 있는지 확인 필요**.
      대표님 기대 동작("새 소원 1일째부터 다시 시작")과 일치하는지 재확인 요망.
- [ ] 보관함 放 도장 카드 표시
- [ ] 함께 빌기 목록에서 제외 여부
- [ ] 후기/완료 알림 미발생 확인
- [ ] 이룬 소원 통계에서 放 제외 확인
- [ ] 수호자/옷/구매물건 유지 확인

테스트 스크립트: `/home/user/wr_compare/flutter_4b/explore_14~19.py` (디스포저블, 앱 소스 아님).
스크린샷: 같은 폴더 `40_after_real_2nd_tap.png`(이전 잘못된 좌표 — 시트 닫힘),
`51_after_click_300_768.png`(放 봉인 애니메이션, 성공), `60_after_release_newroom.png`(재진입 화면).

### 4-B 放 보관함(Vault) 확인 — 이 세션 추가 진행

- **보관함 진입 경로 확인**: 放 완료→봉인(ARCHIVED) 후 `/#/wish-room`은 "✿ 첫 소원 담기" Welcome 화면(5탭 바 없음)으로 감. 보관함을 보려면 "다른 소원방 둘러보기" → WishRoomShell 진입 → 하단바 "◈ 보관함" 탭 클릭 필요(Welcome 화면 자체엔 탭바가 없음 — 정상 동작, 버그 아님).
- **보관함 카드 放 도장 — 확인됨**: room 13 카드에 보라색 원형 "放" 도장(`#7A6A9A`), 방 스냅샷(스테인드글라스 테마) 정상 표시. (`vault_screen.dart` `_ArchiveCard` lines 271-274 로직 런타임 확인 완료, 스크린샷 `104_vault_screen.png`)
- **⚠️ 신규 발견 — 라벨 불일치 (미확정, 보고 필요)**: 카드 하단에 "완성"이라는 고정 텍스트가 成/放 구분 없이 항상 표시됨(`vault_screen.dart:278`, `Outcome` 체크 없이 하드코딩). 원본 `app3/flows.jsx` `Vault3()`의 그리드 카드(131-134줄)에는 이런 라벨이 전혀 없음(소원 텍스트 + "N일 · N번"만 있음) — 1:1 기준으로 보면 "완성" 텍스트 자체가 원본에 없는 추가 요소이며, 放인 경우 "완성"이라는 단어가 의미상 맞지 않음. 대표님 확인 필요: ① 라벨 제거(원본 1:1) ② 放일 때만 다른 문구("放"/"내려놓음" 등)로 분기 ③ 현행 유지.
- **한 줄 메모(note) 표시 위치 확인**: 원본에서도 그리드 카드엔 note가 없고, 재생 오버레이(`ReplayOverlay`/`ArchivePlayer`, play.note)에서만 노출됨(141줄 `{play.note && ...}`) — 즉 그리드 카드가 아니라 카드를 탭해서 연 "당시 모습 재생" 오버레이에서 放 메모를 확인해야 함. 이 세션에서는 그리드 카드까지만 확인했고, 재생 오버레이 탭까지는 진행 못함(다음 세션 과제).

**남은 미확인 항목 (대표님 item 3 표 기준)**:
- [ ] 보관함 카드 탭 → 재생 오버레이에서 放 도장·메모·당시 모습 재생 확인 (다음 단계)
- [ ] 새 소원 1일째 재시작 + 수호자/옷/산 물건 유지 확인 (새 소원 실제 생성까지는 미실행)
- [ ] 함께 빌기 목록에서 放 소원 제외 확인
- [ ] 후기·완료 알림 미발송 확인
- [ ] 이룬 소원 통계에서 放 제외 확인
- [ ] "완성" 라벨 불일치 — 대표님 verdict 필요

**디자인 이탈 재확인 (아직 대표님께 미보고, 우선순위 높음)**:
app3 `extras.js Fulfill3.go()` 원본은 放 선택 시 `CompleteScreen`(축하합니다 연출)을 거치지 않고 바로 `release()→toast→go('vault')`. 현재 Flutter는 成/放 모두 동일한 CompleteScreen(축하합니다 + 별도 봉인하기 버튼)을 거침. 최종 상태(ARCHIVED, 새 소원 가능)는 동일하게 도달하지만 UX 문구/플로우가 원본과 다름 — 수정 여부 대표님 판단 필요.

### 4-B 보관함 재생 오버레이 — 버그 2건 발견 및 수정 (이 세션 계속)

보관함 카드를 탭해 "당시 모습 재생" 오버레이를 여는 단계까지 진행, 아래 2개 버그를 발견하고
수정 완료(`vault_screen.dart`). `flutter analyze` 해당 파일 "No issues found!".

- **버그 1 — 재생 오버레이가 작은 네모로만 뜨고 전체화면이 안 보임**: `_ReplayOverlay.build()`가
  `Dialog(child: Stack(children: [...Positioned만...]))` 구조였는데, Stack의 자식이 전부
  `Positioned`뿐이라 Stack 스스로 크기를 정할 기준이 없어 Dialog의 loose constraints 아래서
  최소 크기로 쪼그라드는 현상이었음(390×844 화면에 작은 네모만 노출, 방 스냅샷·꽃잎 연출 전혀
  안 보임). → `Stack(fit: StackFit.expand, children: [...])`로 수정해 부모 제약을 꽉 채우도록
  강제. 좌표/디자인 변경 없음(SizedBox.expand와 동일 효과).
- **버그 2 — 한 줄 메모(放/成 공통)가 재생 오버레이에서 아예 안 보임**: 원본
  `app3/flows.jsx ArchivePlayer()` 141줄 `{play.note && <div>"{play.note}"</div>}`에 대응하는
  코드가 이식 과정에서 통째로 누락되어 있었음. → 소원 문구(`room.text`) 바로 아래, note가
  있을 때만 큰따옴표로 감싸 표시하도록 추가(`if (room.note != null && room.note!.isNotEmpty) ...`).

**런타임 재검증 결과 (Playwright, build_local.sh로 재빌드 후)**: 두 수정 모두 정상 동작 확인.
- 보관함 "소원 기록관 1" 정상 표시(放 도장 카드 그대로)
- 카드 탭 → 재생 오버레이 전체화면 정상 렌더링("이루어진 소원방 / 그날의 모습 그대로", 스테인드글라스
  방 스냅샷, 하단 한지 카드)
- 한지 카드에 放 도장(보라색) + 기간(2026.11.07→2026.11.21·15일) + 소원 문구 +
  **`"放 최종확인"` 메모 정상 표시** + Lv.6/기도20/❤0/福0 통계 정상
- 스크린샷: `/home/user/wr_compare/flutter_4b/201_vault_grid.png`, `202_replay_overlay.png`

**⚠️ 중요 — 이 재검증 과정에서 별도 프로세스 사고 발견 및 자체 수정**: 위 두 수정을 적용한 뒤
재빌드 시, 프로젝트 필수 스크립트 `./build_local.sh`를 쓰지 않고 일반
`flutter build web --release` 명령으로 빌드해버림 → `--dart-define=ADMIN_API_BASE_URL=...`
누락 → 앱이 기본값인 운영 서버(`https://sintong.kr`)로 조용히 연결되어, 로컬 테스트 계정이
전부 401로 실패하고 보관함이 "0"으로 보이는 가짜 버그처럼 나타남. `page.on("response")`로
401 응답의 실제 URL을 찍어 운영 서버로 가고 있음을 직접 확인 후, `build_local.sh`로 재빌드하여
해결. **`build_local.sh` 자체 주석에 "이미 두 번 발생했다"고 적혀있는 바로 그 실수를 이번에
세 번째로 반복**했다가 스스로 발견/수정한 것 — 대표님께 투명하게 보고 필요한 프로세스 메모.

**남은 미확인 항목 (대표님 item 3 표 기준, 갱신)**:
- [x] 보관함 카드 탭 → 재생 오버레이에서 放 도장·메모·당시 모습 재생 확인 — **완료, 정상**
- [ ] 새 소원 1일째 재시작 + 수호자/옷/산 물건 유지 확인 (새 소원 실제 생성까지는 미실행)
- [ ] 함께 빌기 목록에서 放 소원 제외 확인
- [ ] 후기·완료 알림 미발송 확인
- [ ] 이룬 소원 통계에서 放 제외 확인
- [ ] "완성" 라벨 불일치 — 대표님 verdict 필요 (옵션 3개, 위 섹션 참고)

### 4-B 放 — 함께 빌기 제외 · 후기/알림 미발생 · "이룬 소원 통계" 검토 (코드 검증, 이 세션 마무리)

러닝 환경(sandbox)이 이번 세션 끝 무렵 응답이 느려져(이터레이션 한도), 남은 3개 항목은
**실제 UI 재생 대신 서버 코드 레벨로 교차검증**했다. 모두 코드상 이미 올바르게 동작하도록
짜여 있음을 확인(런타임 재확인은 다음 세션 과제로 남김):

- **함께 빌기(explore) 목록 제외 — 코드상 확인, 정상**:
  `wish-rooms/explore/route.ts` 26행 `where: { visibility: "PUBLIC", status: { not: "ARCHIVED" }, ... }`.
  放 완료→봉인된 room 13은 `status=ARCHIVED`이므로 이 필터에서 항상 제외된다(visibility가
  PRIVATE인 것과 무관하게 status 필터만으로도 이중 차단). DB 확인:
  `13|455|ARCHIVED|RELEASED|IN_PROGRESS|PRIVATE|가족 모두 건강하고 평안하게 지내기를`.
- **후기 CTA 미노출 — 코드상 확인, 정상**: `review/route.ts` 74행
  `if (room.wishStatus !== "ACHIEVED") throw ... "NOT_ACHIEVED"`. 放은 `wishStatus=IN_PROGRESS`로
  유지되므로(成만 ACHIEVED) 서버가 애초에 후기 등록을 막고, 클라이언트도
  `explore_screen.dart canWrite`가 `wishStatus==ACHIEVED`를 요구해 CTA 자체를 안 그린다.
- **완료 알림 미발생 — 코드상 확인, 정상**: `complete/route.ts` 83행, `outcome/route.ts` 83행
  모두 `if (outcome === "FULFILLED") { await createNotification(...) }`로만 감싸여 있어
  RELEASED 경로는 알림 발송 코드 자체를 타지 않는다.
- **"이룬 소원 통계"에서 放 제외 — 해당 기능 자체를 못 찾음**: Flutter(`lib/`)와 원본
  app3(`*.jsx`/`*.js`) 전체를 검색했으나 "총 이룬 소원 개수/통계"를 집계해서 보여주는
  화면·위젯·API가 존재하지 않음(마이페이지·소원방 어디에도 없음). 추정컨대 대표님이
  말씀하신 "통계"는 위 "후기 CTA"·"ACHIEVED 카운트가 쓰이는 유일한 곳들"(review 작성 가능
  여부, explore의 canWrite)을 가리키는 것으로 보이며, 이 둘은 이미 放을 올바르게 제외하고
  있음을 위에서 확인함. **별도의 "통계" 화면이 실제로 존재하는지, 어디를 가리키는 것인지
  대표님께 재확인 필요** — 화면 스크린샷이나 메뉴 명칭을 알려주시면 그 지점을 정확히
  검증하겠음.

**放 검증 체크리스트 — 최종 상태**: 대표님 표의 6개 항목 중 5개 코드/DB/런타임으로 확인 완료
(보관함 표시, 새 소원 가능, 함께 빌기 제외, 후기·알림 미발생), 통계 항목만 "기능 소재
재확인 필요"로 보류.

### 4-B 放 — 새 소원 재시작 + 유지 항목 런타임 검증 (이 세션 마지막)

Playwright로 실제 放 완료된 계정에서 새 소원을 끝까지 작성해 검증 완료(스크린샷
`/home/user/wr_compare/flutter_4b/300~308_*.png`):

- **새 소원 1일째부터 재시작 — 확인, 정상**: "✿ 첫 소원 담기" → 작성 → 제출 후 내 소원방
  카드에 **"1일째 · 기도 0번"** 정확히 표시(`305_new_room_state.png`). DB 확인:
  `14|455|ACTIVE||IN_PROGRESS|새 소원 1일째 재시작 테스트` — 신규 room(id=14)이 별도로
  생성되고 放한 room 13은 `ARCHIVED|RELEASED`로 그대로 보존됨(둘 다 공존, 삭제 아님).
- **보관함에서 "지금 밝히는 소원"(새 방)과 "소원 기록관 1"(放한 방)이 동시에 정상 표시** —
  `307_vault_with_active_and_archive.png`.
- **수호자/옷/산 물건 유지 — DB로 확인, 정상**: `wish_room_outfits_owned` 테이블이
  `user_id` 기준으로만 저장되고 `room_id`와 무관함을 스키마로 확인. 放 전후 동일하게
  3건(`O_god_01/03/05`) 그대로 유지. 애초에 구매 기록이 유저 단위이므로 방이 바뀌어도
  구조적으로 사라질 수 없음(설계상 보장).
- **❌ 정정(위 "버그 아님" 판단은 오판이었음) — 대표님 판정: 버그로 확정, 수정 완료**:
  새 방(room 14)의 수호자 탭이 "🔒 2일째에 열려요"로 다시 잠기는 것을 위에서 "app3
  원본과 1:1 동일한 설계라 버그 아님"으로 결론 내렸으나, **대표님이 이 판단을 명시적으로
  기각**했다. 근거: 기획 기준은 매핑표 **00-C 「새 소원을 시작해도 이미 열린 기능은
  다시 잠그지 않습니다」**이고, 장끼리 말이 다르면 **00-A 핵심이 우선**이라는 원칙에
  따라 이 기준을 따라야 한다. 프로토타입(app3/flow.js)이 방 날짜로만 계산하는 것은
  "프로토타입이 기획을 못 따라간 것"(프로토타입의 누락)이지, 따라야 할 정답이 아니다.
  **「잠금은 사용자 단위, 새 소원에서도 유지」** — 이번 세션에서 수정 완료:
  - `WishRoomUserState`(사용자 단위 테이블)에 `unlocked_json`/`last_unlock_ack_day` 컬럼
    신설(마이그레이션 `20261121114759_add_wishroom_user_state_unlock`). 기존 `WishRoom`
    (방 단위) 컬럼은 레거시 호환을 위해 그대로 남겨둠(삭제 안 함).
  - `computeUnlockView()`(wishroom-engine.ts)가 `unlocked = (지금 방 날짜로 열린 것)
    ∪ (이 사용자가 이전에 ack한 것)`의 합집합으로 계산하도록 수정.
  - `buildRoomView()`가 방 소유자의 사용자 단위 ack 기록을 조회해 전달하도록 수정
    (`getUserUnlockState()` 신규 헬퍼).
  - `POST .../unlock-ack`가 이제 `WishRoomUserState`에 ack를 기록(방이 아니라 사용자
    단위로 영속). "꾸미기 열림 보너스 평생 1회" 로직도 사용자 단위 acked 목록 기준으로
    정확히 1회만 지급되도록 유지됨.
  - **런타임 검증 완료**: 테스트 계정(user 455)의 `WishRoomUserState.unlocked_json`에
    6개 키(`guardian·decor·together·wardrobe·theme·shop`)를 모두 ack된 상태로 세팅한
    뒤, `GET /wish-rooms/me`로 새 방(room 14, 放 이후 생성, dayN=1·prayedN=0)을 조회 →
    응답의 `unlocked: ['guardian','decor','together','wardrobe','theme','shop']`로
    **기도 전부터 전부 열려 있음**을 확인(대표님 확인 방법 "14일째 계정에서 放 → 새
    소원 1일째에도 수호자·함께 빌기·상점 탭이 모두 열려 있어야 합니다" 충족).
  - **남은 일**: 이 서버 측 수정은 Flutter 클라이언트 코드 변경 없이 동작함(Flutter는
    서버가 내려주는 `room.unlocked[]`를 그대로 쓰는 구조 — `models.dart` 확인됨). 다만
    Playwright로 Flutter UI 화면(수호자 탭 실제 렌더링)까지 다시 한번 눈으로 확인하는
    건 다음 세션 과제로 남김(이번 세션은 API 응답 레벨 검증까지 완료).

**放 검증 체크리스트 — 전 항목 완료, 단 잠금 버그 수정 포함**: 대표님 표의 6개 항목 모두
확인 완료(보관함 표시·메모·재생오버레이, 새 소원 1일째 재시작, 수호자/옷/구매물건 유지,
함께 빌기 제외, 후기·완료알림 미발생) + 잠금(unlocked) 재걸림 버그를 사용자 단위로
수정·검증 완료. "이룬 소원 통계"(보관함 헤더/함께 빌기 이루어진 이야기/신통방통 홈 카드,
3곳 모두 `outcome=FULFILLED`만 세는지)와 "완성" 라벨 스크린샷(대표님 요청)은 다음
세션에서 이어서 확인.

### "이룬 소원 통계" 3곳 검증 + "완성" 라벨 스크린샷 (이번 세션, 대표님 item 2·3 verdict 후속)

대표님이 지정한 3곳을 코드와 실행 화면으로 모두 확인. 결과: **3곳 중 1곳(보관함 헤더)이
放까지 같이 세고 있어 FAIL** — 수정 필요. 나머지 2곳은 PASS.

**(a) 보관함 헤더 "소원 기록관 N" — ❌ FAIL (放도 같이 셈, 수정 필요)**
- `vault_screen.dart` `_ArchiveTabState.build()` 153행:
  `final done = rooms.where((r) => r.status == RoomStatus.SEALED || r.status == RoomStatus.ARCHIVED).toList();`
  → `Text('${done.length}', ...)`. `status`(SEALED/ARCHIVED)만 보고 `outcome`
  (FULFILLED/RELEASED)은 전혀 걸러내지 않는다 — 放으로 끝난 소원도 그대로 카운트에
  포함됨.
- 실제 화면으로 확인: 테스트 계정(放 1건만 보유, 成 0건)에서 "소원 기록관 **1**"로
  표시됨(放인데 1로 집계) — 스크린샷
  `/home/user/wr_compare/item3_screenshot/A1_vault_archive_tab.png`.
- 원본 `app3/flows.jsx` `Vault3()` 125행도 `v.archive.length`로 동일하게 放/成
  구분 없이 센다 — **원본도 처음부터 이 구분이 없었다**(00-A 기준으로는 "프로토타입이
  해당 기능 자체를 구현 안 한 것"과 "대표님이 원하는 스펙"이 다를 수 있는 지점). 매핑표
  00-C는 "잠금"에 대한 조항이라 이 통계 항목과는 무관함 — 별도 판단 필요.
- **대표님 verdict 필요**: "이 헤더가 outcome=FULFILLED만 세도록 고칠지, 아니면 '전체
  기록관(放+成 모두 보관됨)' 개수로 두고 그대로 둘지" 둘 중 하나 확정해주시면 바로 반영.
  (참고: 대표님 원래 기준 — "outcome=FULFILLED만 센다면 PASS" — 이 자리는 현재
  FULFILLED만 세지 않으므로 엄밀히는 FAIL.)

**(b) 함께 빌기 "이루어진 이야기" — ✅ PASS**
- `explore_screen.dart` 413행 `canWrite`가 `room.wishStatus == WishStatus.ACHIEVED`를
  요구(放은 `wishStatus=IN_PROGRESS`로 유지되므로 자동 제외).
- 서버 `review/route.ts` 74행 `if (room.wishStatus !== "ACHIEVED") throw ...
  "NOT_ACHIEVED"` — 放 소원은 애초에 후기 등록 자체가 서버에서 막힘.
- 후기 목록 API(`GET /wishroom/reviews`)는 `wish_room_review` 테이블(후기가 실제
  작성된 건)만 조회하므로, 애초에 放 소원은 후기를 못 남겨 이 피드에 나타날 수조차
  없음 — 放 혼입 가능성이 구조적으로 차단됨. **PASS**.

**(c) 신통방통 홈 카드 문구 — ✅ PASS (해당 기능 없음 = 집계 로직 자체가 없음)**
- `lib/features/home/` 전체와 `all_categories_screen.dart`·
  `sintong_home_v2_data.dart`·`sintong_engine_card_grid.dart`·`my_screen.dart`의
  "소원방"/願 타일을 모두 확인 — 전부 고정 마케팅 카피("간절한 마음을 종이에 담고
  촛불 위에 조용히 봉인합니다" 등)이거나 `WishRoomIntroScreen`으로의 단순 이동
  버튼이며, "이룬 소원 N개" 같은 숫자 집계 텍스트는 어디에도 없음.
- `home_page_renderer.dart`의 `_WishPreviewBlock`(소원방 인기글 미리보기)은 관리자
  정적 문구 + `/wish-wall` 핫포스트 1건만 보여주는 **다른(구) 기능**("Wish Wall")이며,
  이번 세션에서 다루는 WishRoom(소원방)의 "이룬 소원" 집계와는 무관함.
- 집계 자체가 존재하지 않으므로 放을 잘못 세는 코드도 없음 — 대표님 verdict 기준
  ("집계 로직이 없으면 PASS")대로 **PASS**로 처리.

**"완성" 라벨 불일치 — 스크린샷 확보 완료, 실제로 2곳에서 발견**:
1. **보관함 그리드 카드**(`vault_screen.dart` 278행) — 放(RELEASED)인 방인데도 카드
   하단에 "완성"이라는 고정 텍스트가 그대로 표시됨. 카드 우상단 도장은 올바르게
   "放"(보라색)으로 뜨는데, 바로 아래 텍스트는 成/放 구분 없이 항상 "완성"이라 서로
   모순된 정보를 보여줌. 스크린샷:
   `/home/user/wr_compare/item3_screenshot/A1_vault_archive_tab.png` (放 도장 + "완성"
   텍스트가 한 카드 안에 공존하는 장면).
2. **재생 오버레이(`_ReplayOverlay`)**: 이쪽은 "완성"이라는 단어 자체는 없고 대신
   도장 色(보라/放)과 메모 텍스트("放 최종확인")는 정확히 分岐되어 있어 문제없음 —
   스크린샷 `/home/user/wr_compare/item3_screenshot/B1_replay_overlay.png`에서 "放"
   도장 + 메모 "放 최종확인" 정상 표시 확인(이 메모는 사용자가 放 선택 시 직접 입력한
   한 줄이라 "최종확인"이라는 단어 자체는 문구 버그가 아니라 테스트 중 입력한 임의
   텍스트임 — 참고용).
- **원본 app3 대조**: `flows.jsx` `Vault3()` 그리드 카드(125-134행)에는애초에
  "완성"이라는 텍스트 자체가 없다(소원 문구 + "N일 · N번"만 있음, 도장만 成/放 공용
  로직으로 분기돼 있었다면 放 색상도 같이 넣었을 것이나 원본엔 放 케이스 자체가
  이 화면에 없었음 — 放 개념 자체가 이번 Flutter 포팅에서 신규 추가된 기능이라
  원본에 "放일 때 완성이 아니게 하라"는 참고 코드가 없음).
- **정리하면**: 버그 위치는 `vault_screen.dart:278`
  `Text('완성', style: WrF.body(12.5, w: FontWeight.w700, color: WrC.glow))` 1줄이며,
  `isRelease`(252행에 이미 계산되어 있음) 분기를 안 타고 하드코딩되어 있다. 재생
  오버레이 쪽은 이미 올바르게 분기되어 있으므로 동일 패턴을 그대로 가져다 쓰면 됨.
- **대표님 verdict 필요** (CHECKLIST.md 기존 메모의 3개 선택지 유효):
  ① 라벨 완전 제거(원본 1:1) ② 放일 때만 "완성" 대신 다른 문구(예: "放·내려놓음")로
  분기 ③ 현행 유지(放에도 "완성" 그대로). 스크린샷 2장 모두 위 경로에 보관.

**다음 순서(대표님 "4" 항목)로 이동 전 남은 자체 보고 사항**:
- (a) 보관함 헤더 FAIL 1건 + "완성" 라벨 불일치 1건 — 둘 다 대표님 verdict 대기,
  verdict 오는 대로 바로 수정 가능한 상태(코드 위치 특정 완료).
- (b)(c)는 PASS로 확정, 추가 조치 불필요.

### 대표님 2차 verdict 반영 — 이룬 소원 통계(放 제외) + "완성" 라벨 실제 수정 완료

대표님이 1번(잠금 사용자 단위 — 이미 지난 세션에 구현·커밋·CHECKLIST.md 기록
완료, 이번엔 동일 내용 재확인 차 재전달됨), 2번(outcome=FULFILLED만 세면 통과),
3번("완성"은 50일째 방 단계 이름에만, 소원이 이뤄진 건 "이루어졌어요 · 成") 판정
기준을 명확히 주셔서, 위에서 "verdict 대기"로 남겨뒀던 2건을 바로 수정했다.

- **(a) 보관함 헤더 "소원 기록관 N" — 수정 완료**: `vault_screen.dart`
  `_ArchiveTabState.build()`에 `fulfilledCount = done.where((r) => r.outcome ==
  Outcome.FULFILLED).length`를 추가해 헤더 숫자만 FULFILLED(成)로 한정했다.
  그리드(done) 자체는 이전처럼 成/放 기록 모두 보여준다(放도 "영원히 보관"되는
  설계는 그대로 유지 — 대표님 판정은 "통계 숫자"에서만 放을 빼라는 것). 런타임
  검증: 放 1건만 있는 테스트 계정에서 수정 전 "소원 기록관 1" → 수정 후
  **"소원 기록관 0"**으로 정확히 바뀜(스크린샷
  `/home/user/wr_compare/item3_screenshot/C1_vault_header_fixed.png`,
  `D1_vault_header_final.png`).
- **"완성" 라벨 — 3곳 모두 isRelease 분기 추가, 수정 완료**:
  1. `vault_screen.dart:282`(보관함 그리드 카드) — `'완성'` 고정 텍스트를
     `isRelease ? '내려놓았어요 · 放' : '이루어졌어요 · 成'`로 교체(색상도 放일 때
     보라색 계열로 함께 분기). 런타임 확인: 放 카드에 이제 "**내려놓았어요 · 放**"
     표시(수정 전 "완성"이었음) — `C1_vault_header_fixed.png`.
  2. `vault_screen.dart:352`(재생 오버레이 제목) — 원래 성/放 구분 없이 항상
     "이루어진 소원방"이었던 것을 `isRelease ? '내려놓은 소원방' : '이루어진
     소원방'`으로 분기(이 자리는 "완성"이라는 단어는 아니었지만 放에 "이루어진"을
     쓰는 것도 같은 라벨 불일치 범주라 함께 수정). 런타임 확인: 放 기록 재생 시
     "**내려놓은 소원방**" 정상 표시 —
     `/home/user/wr_compare/item3_screenshot/D2_replay_title_fixed.png`.
  3. `complete_screen.dart:973`(_SealedBody 안내 문구) — "완성된 소원은 보관하고,
     이제 새로운 소원을 시작할 수 있어요"가 成/放 공통으로 뜨던 것을
     `isRelease ? '내려놓은 소원도 이곳에 고이 담기고, ...' : '이루어진 소원은
     보관하고, ...'`로 분기(이 화면은 isRelease가 이미 846행에 계산되어 있었으나
     이 문구에만 적용이 안 돼 있었음).
  - 그대로 둔 것: `complete_screen.dart:968` "소원 기록관에\n영원히 머뭅니다"는
    成/放 어느 쪽에도 의미상 맞는 중립 문구라 분기하지 않음. `flow.js`의 50일째
    방 단계 이름 "완성된 소원방"(`WrCatalog.I.levels`를 통해 `vault_screen.dart`
    `_CurrentWishCard`가 그대로 사용하는 자리, `cat.levels[room.stage]['name']`)은
    대표님이 명시한 대로 "방 단계 이름"이므로 변경하지 않음.
- **검증 방법**: `flutter analyze lib/features/wishroom/features/vault/vault_screen.dart
  lib/features/wishroom/features/complete/complete_screen.dart` → "No issues
  found!". `build_local.sh`로 로컬 재빌드 후 Playwright로 테스트 계정(放 1건)
  보관함 화면·재생 오버레이를 다시 열어 위 스크린샷들로 최종 확인.
- **커밋**: 아래(이번 메시지 처리 완료 직후).

**이룬 소원 통계 + "완성" 라벨 — 최종 상태**: 대표님이 지정한 3곳 중 FAIL이던
(a) 보관함 헤더를 FULFILLED 전용 카운트로 수정 완료, "완성" 라벨 불일치 3곳 모두
isRelease 분기로 수정 완료. 모두 스크린샷으로 수정 전/후 대조 확인함.
