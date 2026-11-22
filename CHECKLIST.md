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

### 대표님 3차 verdict 반영 — (1) 잠금 사용자 단위 재확인 + (2) 3-B 수호자 탭 디버그 검증·캡처 완료

대표님이 이번 verdict에서 두 가지를 다시 확인해 달라고 하셨다: ① "잠금은
사용자 단위로 유지"가 실제로 되어 있는지(放 후 새 소원 1일째에 기존에 열었던
기능이 전부 열려 있어야 함), ② 수호자 탭 "빈 화면 버그" 수정이 커밋됐는지 —
디버그 콘솔 에러 0건, 커밋 1개, 캡처 2장(수호자 탭·자세히 시트)을 서비스판과
나란히 보여달라는 통과 조건.

**① 잠금 사용자 단위 유지 — 서버·DB·API 3중으로 이미 완료돼 있음을 재확인**
(지난 세션에 구현·커밋까지 끝난 내용이라 이번엔 새로 구현한 것은 없고, 대표님이
요청한 정확한 검증 시나리오로 다시 확인만 했다):
- `admin_web` 저장소(`/home/user/admin_web`, 커밋 `f6b20531`)에 이미
  `WishRoomUserState` 모델(`unlocked_json`, `last_unlock_ack_day`)과
  `computeUnlockView()`/`getUserUnlockState()` 함수가 구현돼 있고
  `buildRoomView()`에 연결돼 있음을 코드로 재확인.
- DB 직접 조회(`dev.db`, sqlite3): 테스트 계정(user_id=455)의
  `wish_room_user_states.unlocked_json`에
  `["guardian","decor","together","wardrobe","theme","shop"]` 6개 전부 저장돼
  있고, `wish_rooms`는 room 13(ARCHIVED/RELEASED·放)과 room 14(ACTIVE, 放 이후
  새로 생성된 방) 두 개가 있음을 확인.
- API 직접 호출(`GET /api/public/wishroom/wish-rooms/me`, Bearer 토큰):
  room 14(放 이후 새 방, `dayN: 1`)의 응답이
  `"unlocked": ["guardian","decor","together","wardrobe","theme","shop"]`로
  **1일째인데도 6개 기능 모두 열려 있음을 확인** — 대표님이 말씀하신 검증
  방법("放 후 새 소원 1일째에도 탭이 모두 열려 있어야 한다")을 그대로
  충족한다.
- Flutter UI 레벨에서도 동일 계정·room 14로 로그인해 수호자 탭을 직접 열어
  정상 렌더링 확인(아래 ② 항목 캡처와 동일 세션에서 확인됨).
- **결론**: 잠금 사용자 단위 유지는 서버·DB·API·UI 4개 레벨 모두에서 이미
  정상 동작 중이며 추가 구현이 필요 없다. 이번 세션은 "새로 고친 것"이 아니라
  "대표님이 요청한 정확한 시나리오로 증거를 다시 모아 확인한 것"이다.

**② 3-B 수호자 탭 빈 화면 버그 — 코드는 이미 커밋돼 있었고, 디버그 검증만
새로 수행**:
- `character_shop_screen.dart`의 `CustomScrollView` + `Sliver` 전환(중첩
  스크롤뷰로 인한 `RenderBox was not laid out` 크래시 수정)은 git log 확인
  결과 커밋 `80a4b304`, `14606f9b`로 **이미 커밋돼 있었다**(현재 HEAD
  `dc9bd8af`의 조상임을 `git merge-base --is-ancestor`로 확인). 즉 대표님이
  "보류/미커밋"으로 알고 계셨던 것과 달리 이미 적용·저장된 상태였다.
- 대표님이 요구하신 통과 조건을 디버그 빌드로 다시 검증:
  - `build_local.sh --debug`로 디버그 빌드(화면 좌상단에
    "LOCAL·http://localhost:3100" 배지로 디버그 빌드임을 시각적으로 확인 가능).
  - Playwright로 로그인 → 수호자 탭 클릭 → "자세히" 시트 열기까지 진행하며
    콘솔 에러(`pageerror`/`console.error`)를 베이스라인 클리어 후 집계.
  - **결과: 수호자 탭 오픈 0건, 자세히 시트 오픈 0건 — 총 콘솔 에러 0건.**
  - 캡처: `item3_screenshot/I1_guardian_tab_debug.png`(수호자 탭),
    `item3_screenshot/I3_guardian_detail_sheet_debug.png`(자세히 시트).
- **app3 서비스판 비교 캡처 — 버튼 셀렉터 버그 2건 수정 후 성공**: app3는
  `dev.day()`/`dev.prayDays()`가 백엔드 상태만 바꾸고 화면 전환(`scr` state)은
  안 바꾸기 때문에 실제 소원 작성 → 촛불 선택 → 기도 버튼 3초 홀드까지 진짜
  UI 흐름을 그대로 재현해야 했다. 이 과정에서 두 가지 버그를 찾아 고쳤다:
  1. 기도 버튼은 `onPointerDown`/`onPointerUp`(React Pointer Event)을 쓰는데
     Playwright `mouse.down()/up()`이 헤드리스 환경에서 포인터 이벤트로
     합성되지 않아 기도가 전혀 등록되지 않고 있었다 → `PointerEvent`를 JS로
     직접 디스패치하도록 수정해 해결(수정 후 `S.prayed`에 정상 기록됨).
  2. 하단 네비게이션 "수호자" 버튼을 찾을 때 셀렉터가 `.nav button, button`으로
     돼 있어 홈 화면 "돌보기 메뉴" 목록의 동명 "수호자" 항목(클릭 시
     `MenuInfo3` 잠금 안내 팝업만 뜸)을 먼저 집어버려 항상 잠금 화면만
     보였다 → `.nav` 컨테이너 안에서만 찾도록 셀렉터 한정해 해결.
  - 수정 후 app3에서 실제 수호자 탭(캐릭터 그리드: 하린/준/월하/설화/홍연/청아,
    필터 전체/내 수호자/여성/남성)과 "자세히" 상세 시트(프로필·성향·성격·좋아하는
    것·지켜주는 소원)가 정상적으로 캡처됨:
    `app3/M01_guardian_tab_20261121_1406.png`,
    `app3/M02_guardian_detail_sheet_20261121_1406.png`.
- **최종 비교 이미지(대표님 제출용)**:
  `/home/user/wr_compare/FINAL_compare_guardian_tab.png`,
  `/home/user/wr_compare/FINAL_compare_guardian_detail.png` — Flutter(디버그
  빌드, 콘솔 에러 0건 확인됨)와 app3 서비스판을 나란히 배치. 레이아웃·캐릭터
  목록·상세 정보 텍스트(이름/직업/성향/성격/좋아하는 것/지켜주는 소원 문구까지)
  모두 일치함을 육안으로 확인.
- **커밋**: 코드 자체는 이미 커밋돼 있어 새로 커밋할 코드 변경은 없음. 이번
  검증·캡처 결과를 기록한 이 CHECKLIST.md 갱신을 "통과 조건의 커밋 1개"로
  갈음해 커밋한다(아래).

**3-B 통과 조건 충족 여부**: 디버그 콘솔 에러 0건 ✅ · 캡처 2장(수호자 탭·
자세히 시트) 서비스판과 나란히 ✅ · 커밋 1개(이 문서 갱신) ✅ — **PASS**.

## S5 경제 — "맡기기(entrust)도 공용 결제창으로 통일" (이번 세션)

- **작업**: `entrust_sheet.dart`의 "맡기기" 버튼이 직접 `entrustGuardian()`을
  호출하던 것을 app3 원본(`entrust.jsx go()` → `app.checkout({kind:'entrust',...})`)과
  동일하게 공용 `PayScreen`(`openPayScreen`)을 거치도록 리팩토링. `pay_screen.dart`
  `PayOrder._kindLabel`에 `'entrust': '대신 기도'` 키 추가.
- **"보내기"(visit) 범위 확정**: app3 `flow.js` `visit()`은 `price: 0`(무료)으로
  디스패치 객체를 생성하며 `kind: 'visit'`로 `entrust`/`char`/`outfit`/`dispatch`/
  `item`과 별도 분류된다. **보내기는 app3 원본에서 무료 기능이므로 S5 "공용
  결제창 통일" 대상에서 제외한다** — 현재 Flutter 구현도 보내기에 결제창을
  붙이지 않은 상태이며 이는 원본과 일치함. 추가 조치 불필요.
- **부수 발견·수정(버그)**: `care_menu_info_sheet.dart`의 168px 히어로 이미지가
  `margin: EdgeInsets.symmetric(horizontal: -18)`(음수 마진)로 바깥 Container의
  좌우 padding을 상쇄해 폭 전체를 채우려 했는데, Flutter `Container`는
  `assert(margin == null || margin.isNonNegative)`로 음수 마진을 금지해 돌보기
  메뉴 10개 항목(수호자/맡기기/찾아온 수호자/옷/꾸미기/분위기/배경화면/상점/
  함께빌기/고쳐쓰기) 공용 안내 시트를 열 때마다("?" 아이콘 또는 잠긴 행 탭)
  항상 "Assertion failed" 크래시가 났다. 바깥 Container 좌우 padding을 제거하고
  히어로 아래 콘텐츠만 별도 `Padding(horizontal: 18)`으로 감싸 음수 마진 없이
  동일한 시각 결과를 재현. 같은 파일의 "기다릴게요"/"닫기"/"바로 가기" 버튼에도
  Semantics identifier(`care_info_wait`/`care_info_close`/`care_info_go`) 부여.
- **검증(Playwright, `flutter_entrust_payscreen5.py`)**: `flt-semantics-identifier`
  기반 클릭(`care_info_go` → `entrust_checkout` → `pay_confirm`)으로 로그인
  테스트 계정(`wr_compare_test@test.local`, room 14)에서 전체 흐름을 끝까지
  실행. 결과:
  - 안내 시트 정상 렌더링(크래시 없음, `pageerror` 0건) — 버그 수정 확인.
  - entrust 폼 → "맡기기" 버튼 클릭 시 `PayScreen` confirm 화면
    (`PAY · 대신 기도`, 복주머니 내역 310/120/190) 정상 진입.
  - "결제하기" 클릭 → `paying`(1.5초 연출) → **`done` 단계 정확히 도달**
    (poll 2.0s에 전환 확인): 영수증 "하린이 당신의 소원을 지켜요", 주문번호
    WRMWQK4FJV, 사용한 복주머니 🧧120, 남은 복주머니 🧧190.
  - 서버 DB(`wish_room_entrusts`) 직접 조회로 실제 레코드 생성 확인:
    `id=2, room_id=14, days=3, price=120, start_day=1, end_day=4, status=active`
    — `onConfirmPay()`(`entrustGuardian()`) API 호출이 서버에서 실제로
    성공 처리됨을 최종 확인.
  - (테스트 중 1회, 이전 세션이 남긴 `wish_room_entrusts`의 `cancelled` 레코드가
    `CONSECUTIVE` 서버 검증에 걸려 409로 confirm 롤백되는 것을 관찰 — 이는
    버그가 아니라 설계된 에러 롤백 흐름이 정상 동작한 것. 테스트 DB에서 해당
    레코드를 삭제한 뒤 재실행해 done까지 도달함을 재확인.)
- **flutter analyze**: 수정 3개 파일 모두 `No issues found!`.
- **빌드**: `./build_local.sh --debug` 2회 성공(각 약 167초, `timeout 600000ms`
  필요 — 기본 120000ms로는 타임아웃).
- **커밋**: `pay_screen.dart`, `entrust_sheet.dart`, `care_menu_info_sheet.dart`
  3개 파일 + 이 CHECKLIST.md 갱신을 함께 커밋한다(아래).

**S5 "맡기기 공용 결제창 통일" 통과 조건 충족 여부**: PayScreen 진입 ✅ ·
done(영수증) 단계 도달 ✅ · 서버 DB 반영 확인 ✅ · 기존 버그(안내 시트 크래시)
발견·수정 ✅ · flutter analyze 통과 ✅ — **PASS**.

**S5 남은 작업(미착수)**: 동일 결제 중복 처리 방지, 광고 보상 SSV + 1일 5회
상한, 복주머니 보상 "v5" 수치(기도 +5·7일 연속 +20·함께 빌기 +1×5·광고 +2×5)
전수 재확인, 출석/미션 보상 완전 제거.

---

## S5 경제 — "동일 결제 중복 처리 방지" (이번 세션)

- **배경**: 위 "맡기기도 공용 결제창으로" 작업 완료 보고 직후 대표님 "진행" 지시로
  착수. app3 원본(`flow.js` `API.once(reqId,fn)` · `pay(order,reqId)`)과
  admin_web 기존 선례(`BokjuCouponRedemption.requestId`,
  `OpenPassAdRewardLog.idempotencyKey`)를 참고해 설계 — 클라이언트가 이미 만들고
  있던 주문번호(`pay_screen.dart`의 `_oid`, `'WR'+timestamp.toRadixString(36)`)를
  그대로 서버 멱등키로 재사용한다.
- **핵심 판단**: 캐릭터/아이템/옷은 이미 `@@unique([userId, ...])` 제약이 있어
  "같은 걸 두 번 사면 OWNED 409"로 막혀 있다(이중 지급 위험 자체가 낮음). 반면
  **맡기기(entrust)는 "같은 걸 여러 번 사는 게 정상"**이라 그런 유니크 제약을
  걸 수 없어, 버튼 연타·네트워크 재전송 시 진짜로 중복 결제가 날 수 있다 —
  따라서 entrust가 가장 시급하고, 나머지 3곳은 일관성 차원에서 같은 패턴을
  적용했다(에러 대신 "재전송이면 최초 성공 결과를 그대로 반환"하는 사용자
  경험 개선 목적).

### 서버(admin_web) 작업
- **Prisma**: `WishRoomEntrust`/`WishRoomCharacterOwned`/`WishRoomItemOwned`/
  `WishRoomOutfitOwned` 4개 테이블에 `idempotencyKey String? @unique` 컬럼
  추가. 마이그레이션 `20261121130000_add_wishroom_purchase_idempotency_key`
  작성 → `dev.db` 적용 + `prisma generate` 완료.
- **4개 route.ts 전부 동일 패턴 적용**(`wish-rooms/[id]/entrust`,
  `items/[id]/purchase`, `characters/[id]/purchase`, `outfits/purchase`):
  1) body에서 `idempotencyKey` 추출 → 있으면 먼저 `findUnique`로 재전송 여부
     확인, 있으면 복주머니 재차감 없이 최초 결과를 `idempotent: true`로 그대로
     반환. 2) 신규 처리 시 생성 row에 키 저장. 3) 동시 요청 레이스는 `P2002`
     (UNIQUE 위반)를 잡아 409 `ALREADY_PROCESSED`로 응답(SQLite 트랜잭션
     직렬화 전제 — `bokju-coupon-service.ts` `redeemCoupon()`과 동일 설계).
- **타입체크**: `npx tsc --noEmit` 전체 통과(0 에러).
- **서버 검증(curl, 실제 DB 확인)**:
  - entrust 동일 키 재요청(순차 2~3회): 1회차만 복주머니 차감(270→220),
    2·3회차는 `idempotent:true`로 220 그대로 유지, `wish_room_entrusts`
    row는 정확히 1개만 생성됨을 SQLite로 직접 확인.
  - **entrust 진짜 동시 레이스**(`curl ... & curl ... & wait`로 완전 병렬
    발사): 두 요청 모두 200대 응답, 하나는 성공(220→170), 다른 하나는
    `idempotent:true`, row는 여전히 1개만 생성 — 레이스 컨디션 방어 확인.
  - items 구매(`c_lotus`, 60개)도 동일 패턴 재검증: 1회차만 차감
    (170→110), 2회차 `idempotent:true`로 110 유지, `wish_room_items_owned`
    row 1개만 생성.
  - (주의 — 세션 중 1회 발견/해결: `prisma generate` 직후에도 이미 떠
    있던 `next dev` 프로세스가 구 Prisma Client를 메모리에 캐싱해
    `Unknown argument idempotencyKey` 에러가 발생했다. `next dev` 재시작으로
    해결 — 앞으로 Prisma 스키마 변경 시 `prisma generate` 뒤 dev 서버
    재시작을 빠뜨리지 말 것.)

### 클라이언트(Flutter) 작업
- `wr_api.dart`: `WrRepository` 인터페이스의 5개 구매 메서드
  (`buyItem`/`buyCharacter`/`buyOutfit`/`buyNamedOutfit`/`entrust`)에
  `{String? idempotencyKey}` 파라미터 추가, `ApiRepository` 구현부에서
  body에 `if (idempotencyKey != null) 'idempotencyKey': idempotencyKey`로 전달.
- `wishroom_provider.dart`: `buyItem`/`buyCharacter`/`buyOutfit`/
  `buyNamedOutfitOnly`/`entrustGuardian` 5개 메서드에 동일 파라미터 추가해
  리포지토리로 그대로 관통.
- `pay_screen.dart`: `PayOrder.onConfirmPay` 시그니처를
  `Future<bool> Function()` → `Future<bool> Function(String idempotencyKey)`로
  변경, `_pay()`에서 화면이 이미 갖고 있던 `_oid`(영수증 "주문번호"로 표시되는
  값)를 그대로 콜백에 전달 — app3 `F.pay(order, oid)`와 동일하게 "화면에
  보이는 주문번호 = 서버 멱등키" 원칙을 지킴.
- **5개 `onConfirmPay:` 호출부 전부 수정**: `guardian_detail_sheet.dart`,
  `entrust_sheet.dart`, `shop_screen.dart`×3(캐릭터 탭·옷 탭·꾸미기 탭).
- **테스트 파일 2곳 시그니처 동기화**(인터페이스 변경의 직접 결과):
  `character_shop_screen_overflow_test.dart`의 가짜 `buyCharacter`,
  `outfits20_test.dart`의 가짜 `buyNamedOutfit`에 `{String? idempotencyKey}`
  파라미터 추가.
- `flutter analyze` 전체 프로젝트 기준 **에러 0건**(기존부터 있던
  `WrGuardianOutfitLauncher` undefined 에러 2건은 본 작업과 무관 — 사전에
  `git log`로 확인).
- `build_local.sh --debug`(타임아웃 600000ms) 빌드 **성공**(167초).

### UI 단 종단 검증(Playwright, 네트워크 요청 캡처)
- `/home/user/wr_compare/flutter_idempotency_verify.py` 작성 — 로그인 →
  돌보기 메뉴 → 수호자에게 맡기기 → PayScreen → 결제하기 버튼까지
  `flt-semantics-identifier` 로케이터로 클릭하면서, Playwright
  `page.on("request", ...)`로 `/entrust` POST 요청의 실제 body를 가로채
  콘솔에 출력.
- **결과**: 캡처된 요청 body가 정확히
  `{"days":3,"startsToday":true,"idempotencyKey":"WRMWQMD749"}` —
  화면에 표시되는 주문번호와 서버로 전송되는 멱등키가 동일한 값임을 직접
  확인. `paying`→`done` 전환도 정상(poll 2.0s에 `done` 도달).
- 서버 DB 재확인: `wish_room_entrusts` row(`id=5`)의
  `idempotency_key='WRMWQMD749'`, `price=120`으로 UI 클릭이 실제로 이
  멱등키와 함께 persist됐음을 교차 검증.
- 테스트로 변경된 지갑 잔액/구매 기록은 전부 되돌려 원래 문서화된 기준값
  (복주머니 190, room 14 entrust 없음)으로 복원 완료.

**검증 요약 — 3중 확인(서버 curl 단위 테스트 → 서버 curl 동시성 테스트 →
브라우저 UI 종단 네트워크 캡처)으로 "같은 결제를 두 번 보내도 한 번만
처리된다"를 confirmed — PASS.**

**다음 세션에 이어갈 것**: S5 나머지 — 광고 보상 SSV + 1일 5회 상한,
복주머니 보상 "v5" 수치 전수 재확인, 출석/미션 보상 완전 제거. S6 마무리는
완전 미착수.

---

## S5 경제 — "광고 보상 SSV + 1일 5회 상한" 조사 → "소원방 광고 보고
## 복주머니 기능 삭제"로 전환 (이번 세션)

- **배경**: "진행" 지시로 위 체크리스트의 다음 항목("광고 보상 SSV + 1일
  5회 상한")에 착수. 조사 결과를 대표님께 보고했으나, 대표님이 이 방향
  자체를 기각하고 기능을 통째로 삭제하라고 지시 — 이 섹션은 그 조사
  결과와 이어진 삭제 작업을 함께 기록한다.

### 1단계 — 조사 결과 (SSV는 보류/폐기, 1일 5회 상한은 이미 정상)
- **"1일 5회" 일일 상한**: `me/earn/route.ts`가 `wish_room_earn_logs`의
  `(userId, source, dateKey)` 카운팅을 `$transaction` 안에서 수행 —
  이미 올바르게 구현되어 있었다.
  - 순차 테스트: 6회 호출 중 5회만 성공(복주머니 190→200), 6회차는
    `EARN_LIMIT`으로 정상 거부.
  - **동시성 레이스 테스트**(신규 검증): curl 7개를 완전 병렬(`&`/`wait`)로
    발사 — 정확히 5개만 성공, 2개는 거부, DB에 정확히 5행만 생성됨을
    확인. 레이스 컨디션에도 안전함을 이번에 처음 확인.
- **진짜 AdMob SSV(Google 공식 암호화 서버 콜백 검증)**: 코드베이스
  어디에도 구현되어 있지 않음(별개 시스템인 `fortune-ad-service.ts`의
  "FortuneAd"도 세션 기반 PENDING→COMPLETED 재전송 방지일 뿐, 진짜
  암호화 SSV는 아님). 앱이 아직 테스트용 광고 단위 ID를 쓰고 있어 실제
  SSV 도입이 검증하기 어려운 대규모 작업이라는 점과 함께 3가지 대안을
  제시 → **대표님이 이 방향 전체를 기각**하고 기능 삭제를 지시.

### 2단계 — "소원방 광고 보고 복주머니" 기능 삭제 (대표님 지시로 전환)
- **제약**: `wishroom_data.json`(admin_web `src/data/`, flutter_app
  `assets/wishroom/data/` 양쪽 다 동일, 바이트 단위로 diff 확인)의
  `EARN[]`에 있는 `{id:'ad', ...}` 항목과 `POUCH.ad/adMax`는 **이 파일
  자체가 수정 금지 대상**이라 데이터에서 제거할 수 없음. 따라서
  "데이터는 그대로 두고 서버 라우트 레벨에서 차단 + 클라이언트에서
  호출/노출 경로 전부 제거"하는 방식으로 설계.

#### 서버(admin_web) — `me/earn/route.ts`
- `DISABLED_EARN_SOURCES = new Set(['ad'])` 블록리스트 추가, 기존
  카탈로그 조회(`WR.EARN.find(...)`)보다 먼저 `source==='ad'`를
  `404 NOT_FOUND`("더 이상 지원하지 않는 획득처예요")로 거부.
- 검증: `npx tsc --noEmit` 0 에러. curl로 `{"source":"ad"}` 요청 →
  `404 NOT_FOUND` 확인, 지갑 잔액(190)·`wish_room_earn_logs` 모두
  변동 없음 확인. 회귀 테스트로 `{"source":"pray"}`(auto 항목) 호출 →
  기존과 동일하게 `400 AUTO` 응답, 정상 동작에 영향 없음 확인.
- 커밋 `5d3d5b24` — `git status --short`/`git diff --cached --stat`로
  이 1개 파일만 staged됐음을 커밋 전후 재확인, 5개 수정 금지 파일은
  그대로 unstaged 보존.

#### 클라이언트(flutter_app) — 6개 파일
- `wr_ad_earn_button.dart` **삭제**(재사용 버튼 위젯 전체, `git rm`).
- `pay_screen.dart`: `WrAdEarnButton` import·호출 제거("활동으로
  모으기" 라벨과 "다른 방법으로 모으기"(WalletSheet 열기) 버튼은
  유지).
- `decor_screen.dart`: 실제로 쓰이지 않던 죽은 import 제거.
- `wallet_sheet.dart`(가장 큰 변경): 광고 카드 UI 블록(그라데이션
  컨테이너, "짧은 영상 보고 복주머니 받기" 문구, 진행도 점, "+2" 뱃지
  등 약 38줄) 전체 삭제, `_watchAd()` 메서드(RewardedAd load/show/
  콜백, 약 33줄) 삭제, `google_mobile_ads`/`AdmobAdIds` import 삭제,
  `_adLoading` 상태 삭제, `_kEarnIcon` 맵의 `'ad'` 항목 삭제. 일일
  미션 목록 렌더링에 이미 있던
  `earn.where((e) => e['id'] != 'ad')` 필터는 그대로 유지 —
  `wishroom_data.json`에 'ad'가 남아있어도 화면에 노출되지 않게 하는
  유일한 장치로 남음.
- `guide_data.dart`: `kGuide['ad']` 항목, `kGuideOrder`의 `'ad'` 삭제,
  `'pouch'` 안내 문구에서 "짧은 영상" 언급 제거.
- `guardian_detail_sheet.dart`: "복주머니는 기도 · 함께 빌기 · 짧은
  영상으로 적립돼요" → "복주머니는 기도 · 함께 빌기로 적립돼요".
- `test/wallet_sheet_overflow_test.dart`: 삭제된 광고 카드 텍스트
  ("짧은 영상 보고 복주머니 받기")를 찾아 스크롤하던 검증 단계를
  제거하고, 그 자리의 "일일 미션" 첫 항목 텍스트("오늘 모을 수 있는
  복")로 대체.
- **스코프 확인(그렙으로 확정, 변경 안 함)**: `character_shop_screen.dart`는
  애초에 `WrAdEarnButton`/'ad' 참조가 없음. `pouch_box/.../
  pouch_ad_overlay.dart`는 "행운상자"라는 완전히 별개 기능의 강제
  대기 광고 오버레이로, 소원방과 무관 — 범위 밖으로 확정하고 건드리지
  않음.
- **검증**:
  - `flutter analyze`: 118 issues 중 신규 에러 0건, 기존부터 있던
    `WrGuardianOutfitLauncher` undefined 에러 2건만 그대로(본 작업과
    무관, `git stash`로 이전 커밋 기준 재현 확인).
  - 그렙 재스윕: `lib/features/wishroom` 전체에서 `'ad'`/`"ad"` 검색 시
    `wallet_sheet.dart`의 주석 2줄 + 필터 코드 1줄만 남음(의도된 잔존).
    `WrAdEarnButton`/`RewardedAd`/`AdmobAdIds` 실제 사용 코드는
    전무(주석 언급 제외).
  - `flutter test test/wallet_sheet_overflow_test.dart`: 5개 중 4개
    테스트가 `_FakeWrRepository`의 `ledger` getter 미모킹으로 실패 —
    `git stash`로 확인한 결과 **이번 변경 전(커밋 e1345647)부터 이미
    동일하게 실패하던 사전 존재 버그**(`WalletSheet.initState()`가
    `loadLedger()`를 호출하는데 가짜 레포지토리가 `noSuchMethod`로
    막혀 있음). 본 작업 범위 밖의 별도 이슈로 남겨둠(수정하지 않음,
    텍스트 치환만 정확히 반영됐는지가 본 작업의 책임 범위).
  - `build_local.sh --debug`: 빌드 성공(156.3초), 프리뷰 서버(`:5060`)
    재기동 후 HTTP 200 확인.
- 커밋 `3bee5c72`(6개 소스 + 1개 테스트 파일, 25 insertions(+),
  206 deletions(-)).

**검증 요약 — 서버 404 차단 확인(curl) + 서버 회귀 없음 확인(curl) +
flutter analyze 신규 에러 0건 + 그렙 재스윕으로 잔존 참조 없음 확인 +
빌드 성공 — PASS. (단, wallet_sheet_overflow_test.dart의 4개 테스트
실패는 본 작업과 무관한 사전 존재 버그로 별도 과제로 남음.)**

**중요 — 이 섹션으로 위의 "S5 남은 작업"의 "광고 보상 SSV + 1일 5회
상한" 항목은 폐기/대체된다.** 기능 자체가 삭제됐으므로 SSV를 추가로
구현할 필요가 없어졌다. 아래 "다음 세션에 이어갈 것"에서 해당 항목을
제거하고 갱신한다.

**다음 세션에 이어갈 것(갱신)**: S5 나머지 — 복주머니 보상 "v5" 수치
전수 재확인(기도 +5 · 7일 연속 +20 · 함께 빌기 +1×5 — **광고 +2×5
항목은 기능 삭제로 이 체크리스트에서 제외**), 출석/미션 보상 완전
제거(`luck-pouch-engine.ts`의 `ACTIVITY_SCORE_WEIGHTS.attendance: 1`
미조사 상태). S6 마무리는 완전 미착수.

---

## S5 경제 — "복주머니 보상 v5 수치 전수 재확인" → "함께 빌기(cheer)
## 복주머니 미지급 버그" 발견·수정 (이번 세션)

- **배경**: "진행" 지시로 위 "다음 세션에 이어갈 것"의 "v5 수치 전수
  재확인" 항목에 착수. 카탈로그(`wishroom_data.json`) 값과 실제 지급
  코드를 하나씩 대조 검증.

### 검증 결과
| 항목 | 카탈로그 값 | 실제 지급 로직 | 결과 |
|---|---|---|---|
| 기도 | `pray: 5` | `devotions/route.ts` — pouchOn 조건에서 정확히 지급 | ✅ 정상 |
| 7일 연속 | `streak7: 20` | 같은 라우트 — `newStreak>=DEVOTION_RULE.streakAt(7)`일 때 `streakBonus(20)+fx.pouch` 지급 | ✅ 정상 |
| 함께 빌기 | `cheer: 1, cheerMax: 5` | `/wish-rooms/{id}/supports` — `supportCount` 증가 + 마일스톤 아이템 보상(`SUPPORT_REWARDS`)만 체크, **cheer 복주머니 지급 코드 자체가 없음** | ❌ **버그** |

### 🐛 발견한 버그 — "함께 빌기" 복주머니 평생 미지급
- `me/earn/route.ts` 주석에는 "cheer는 S4(함께 빌기) 전용 엔드포인트가
  직접 지급한다"고 적혀 있었지만, 실제 `/supports` 라우트를 열어보니
  그 지급 코드가 전혀 존재하지 않았다.
- curl로 실측: 응원 1회 보내서 `supportCount` 0→1 증가 확인했지만
  지갑 잔액은 190→190 그대로, `wish_room_earn_logs`에도 `cheer` 기록
  없음 — 응원(하루 최대 `cheerMax`=5회)을 아무리 해도 복주머니 +1×5가
  **한 번도 지급된 적이 없는** 상태였음을 확인(테스트 흔적은 원복).
- 대표님께 보고 후 **"고쳐"** 지시로 즉시 수정 진행.

### 수정 내용

#### 서버(admin_web) — `/wish-rooms/{id}/supports/route.ts` (커밋 `20e5527d`)
- `devotions/route.ts`(기도 pray/streak7)와 동일한 패턴으로
  `earnLuckPouch()` + `wishRoomEarnLog.create(source:'cheer')` 추가.
- 일일 상한: `wish_room_earn_logs`의 `(userId, source='cheer', dateKey)`
  카운트가 `POUCH.cheerMax(5)` 미만일 때만 지급 — 상한 도달 후에도
  응원 자체(`supportCount` 증가·마일스톤 카운트)는 계속 가능하되
  복주머니만 지급 중단.
- 응답에 `cheerEarned`/`me` 필드 추가(클라이언트가 바로 pouch 갱신
  반영 가능하도록 — `devotions`의 `pouchEarned`, `gifts`의 `me`와
  동일한 설계 원칙).
- **검증(curl, 실제 DB)**: 1회차 `cheerEarned:1`, 지갑 190→191.
  서로 다른 방 4곳에 추가 응원 → 191→195까지 정상 누적(5회 전부
  `cheerEarned:1`). 6회차(6번째 방) → `cheerEarned:0`, 지갑 195
  그대로(상한 정상 동작), `support` 자체는 계속 성공.
  `npx tsc --noEmit` 0 에러. 테스트 흔적 전부 원복(지갑 190,
  `wish_room_earn_logs` 0건, 각 방 `support_count`/`points`/`level`
  원상복구, `wish_room_supports` 삭제) — 단 `point_histories`는
  append-only 트리거라 과거 테스트 5건이 원장에 남으나 운영 로직에는
  영향 없음(삭제 자체가 설계상 불가능한 원장 테이블).
- `wishroom_data.json` 등 5개 수정 금지 파일은 이번 커밋에 포함되지
  않음(git status/diff --cached로 확인).

#### 클라이언트(flutter_app) — 커밋 `4bb97d3f`
- `wr_api.dart`: `WrRepository.support()` 반환 타입을
  `(WishRoom, Map<String,dynamic>?)` → `(WishRoom, Map<String,dynamic>?, Me)`
  3-tuple로 확장(`gift()`의 `(WishRoom, Me)` 패턴과 동일).
- `wishroom_provider.dart`: `support()`에서 서버가 돌려준 `me`로
  `WishRoomProvider.me`를 갱신 — 응원할 때마다 지급되는 복주머니가
  지갑 pill·지갑 시트 등 `me.pouch`를 구독하는 모든 화면에 즉시
  반영되도록 함.
- **검증**: `flutter analyze` 신규 에러 0건(기존 무관 에러 2건만
  그대로). 모든 `_FakeWrRepository`/`Repo` 테스트 더블은
  `noSuchMethod` 폴백이라 시그니처 변경 영향 없음(그렙으로 확인).
  `build_local.sh --debug` 빌드 성공(151.7초), 프리뷰 재기동 확인.

**검증 요약 — 카탈로그-코드 대조로 3개 항목 중 1개 버그 발견 → 서버
curl 단위 테스트(지급·상한 모두 확인) → 클라이언트 반영 → 빌드 성공
— PASS.**

**다음 세션에 이어갈 것(갱신)**: S5 나머지 — 출석/미션 보상 완전 제거
(`luck-pouch-engine.ts`의 `ACTIVITY_SCORE_WEIGHTS.attendance: 1`
미조사 상태, "복주머니 보상 v5 수치 전수 재확인" 자체는 이 세션으로
완료 — PASS). S6 마무리는 완전 미착수.

---

## S5 경제 — "출석/미션 보상 완전 제거" 조사·조치 (이번 세션)

- **배경**: "진행" 지시로 위 "다음 세션에 이어갈 것"의 마지막 항목
  "출석/미션 보상 완전 제거"에 착수.

### 조사 결과 — CHECKLIST의 기존 단서는 오귀인(誤歸因)이었음
- 이 항목이 가리키던 `luck-pouch-engine.ts`의
  `ACTIVITY_SCORE_WEIGHTS.attendance: 1`을 전체 코드와 함께 조사한
  결과, 이것은 **소원방과 무관한 별도의 사이트 전역 활동점수
  시스템**(출석 외에도 `fortune_first_view`/`community_post` 등
  다양한 활동에 점수를 매겨 `maybeGrantActivityTierBonus()`로
  3/5/8/12점 구간 보너스를 주는 기능)임을 확인 — 소원방의 구
  "출석/미션" 보상과는 전혀 다른, 지금도 정상 운영 중인 기능이므로
  **손대지 않는 것이 맞다**.
- `attendance/checkin/route.ts`(사이트 전역 일일 출석 체크인,
  `attendanceRewardRule` 1~30일 테이블)도 마찬가지로 별도의 정상
  기능 — 소원방 전용 구 미션과 무관함을 확인.
- `git log -S "attend/devo10"`로 실제 이력을 추적한 결과, 소원방의
  구 EARN 카탈로그(`attend`/`devo10`/`m_visit`/`m_cheer`/`m_msg` —
  출석/정성10회/이동형 미션 3종)는 이미 이전 세션의 v5 S1 전환
  커밋(`1738749a`, "정성→기도 전환")에서 서버·데이터
  (`wishroom_data.json` EARN[])가 `pray`/`streak7`/`cheer`/`ad`/
  `welcome`/`dispatchRecv`로 완전히 교체 완료된 상태였다.
  `wishroom_data.json` 재확인 + admin_web 소스 전체 그렙 모두
  구 ID 0건.
- 실제 남아있던 것은 **flutter_app `wallet_sheet.dart`에만 있던
  죽은 코드** 4곳 — 카탈로그 어느 항목과도 매칭되지 않아 평생
  실행될 수 없는 분기였다(`_kEarnGo` 맵에 현재 카탈로그 ID가 하나도
  없어 `go`가 항상 `null`이었음).

### 조치 — `wallet_sheet.dart` 죽은 코드 제거 (커밋 `68038de5`)
- `_kEarnIcon`/`_kEarnGo` 상수 맵 삭제(구 ID만 키로 가짐).
- `_tap()`의 "이동형 미션" 분기(`go != null` 분기 전체, devo10
  삼항토스트·1.8초 지연 자동적립 포함) 삭제 — `_doEarn()` 단일
  경로로 정리.
- 카드 렌더링에서 `_kEarnIcon[id]`/`_kEarnGo[id] != null` 참조 제거,
  기본 아이콘(`•`)과 단순 `+금액` 표시로 정리.
- 더 이상 쓰이지 않는 `_kTabHome` 상수 삭제.
- **검증**: `flutter analyze` 신규 이슈 0건(기존 무관
  `WrGuardianOutfitLauncher` 에러 2건만 잔존, 이전 세션에 git
  stash로 무관함 재확인). `flutter test
  test/wallet_sheet_overflow_test.dart`는 수정 전/후 `git stash`로
  비교해 동일하게 4/5 실패(`ledger` mock 미구현 — 기존 버그, 회귀
  아님 확인). `build_local.sh --debug` 143.7초 성공. `:5060`
  HTTP 200 / `:3100` HTTP 307 확인. admin_web 수정 금지 5개 파일은
  이번 작업과 무관(이번 작업은 flutter_app 단독 수정이며, 작업 전후
  `git status --short`로 5개 파일 그대로임을 재확인).

**검증 요약 — CHECKLIST의 기존 단서(`ACTIVITY_SCORE_WEIGHTS`)는
별도 시스템으로 확인되어 제외, 실제 잔존 문제(`wallet_sheet.dart`
죽은 코드)를 찾아 제거 → 분석·테스트·빌드 전부 통과 — PASS.
이로써 "S5 나머지" 리스트(동일 결제 중복 처리 방지 ✅, 광고 보상
SSV + 1일 5회 상한 ✅-기능삭제로대체, 복주머니 보상 v5 수치 전수
재확인 ✅, 출석/미션 보상 완전 제거 ✅) 전 항목이 종료됐다.**

**다음 세션에 이어갈 것(갱신)**: S5 경제 항목은 전부 종료. 남은 것은
**S6 마무리**(21일 미리보기, 소원 수정 제한, 46개 안내 팝업, 어뷰징
체크, 9단계 플로우 테스트) — 완전 미착수. 그 외 미전달 6장 스크린샷
(`/home/user/wr_compare/DELIVERY_6SHOTS/`)도 그대로 대기 중.

## S6 마무리 — "소원 수정 제한" 완료 (대표님 S6 우선순위 1차 판정)

app3/extras.js `WishEdit3` · flow.js `editWish(t)`/`rewish(t)`/`setGoal(g)`
1:1 포팅. 서버(admin_web)·클라이언트(flutter_app) 양쪽 모두 완료.

**admin_web(서버) — 별도 커밋 `9d142403`로 이미 완료**:
- `prisma/schema.prisma`에 `WishRoom.goalDays`/`wishEditsToday`/
  `wishEditsResetDate`/`rewished` 4개 필드 추가, 마이그레이션
  `20261122010000_add_wishroom_wish_edit_limits` 작성·적용.
- 신규 라우트 `POST /wish-rooms/{id}/wish-edit`
  (`body: {mode:'edit'|'rewish'|'goal', text?, goalDays?, force?}`) —
  기존 `PATCH /wish-rooms/{id}`(DRAFT 전용 텍스트 수정)와는 서로 배타적
  상태(DRAFT vs 그 외)에서만 동작해 충돌 없음. 기존 `outcome` REWISH(타임캡슐
  "다시 소원을 빌어요")와도 전혀 다른 코드 경로 — 이름만 비슷할 뿐 무관.
  - `edit`: 문구만 다듬기, 하루 3번(`devotionsToday`와 동일한 KST 날짜별
    리셋 패턴). 날짜·기도 횟수·연속기록은 그대로.
  - `rewish`: 완전히 다른 소원으로, `dayN<=3` AND 평생(방 라이프사이클) 1회만.
  - `goal`: 21/49/100일, 횟수 제한 없음. 0 또는 null = 목표 없음.
- `wishroom-engine.ts` `roomView()`에 파생 필드 추가: `goal`
  (`goalDays ?? null`), `wishEditsRemaining`(0~3), `canRewish`
  (`dayN<=3 && !rewished`) — Flutter가 dayN을 재계산할 필요 없도록 서버가
  미리 판정해 내려줌.
- 검증: `npx tsc --noEmit` 0 에러. 금지 5개 파일(`gunghap/direct/route.ts`
  등) 그대로 미수정 확인.

**flutter_app(클라이언트) — 이번 세션 완료**:
- `lib/features/wishroom/data/models.dart` — `WishRoom`에 `goal`
  (`int?`)/`wishEditsRemaining`(`int`)/`canRewish`(`bool`) 필드 +
  `fromJson` 파싱 추가.
- `lib/features/wishroom/data/wr_api.dart` — `WrRepository.editWish()`
  추상 메서드 + `ApiRepository.editWish()` 구현
  (`POST /wish-rooms/{id}/wish-edit`) 추가. 기존 테스트 ~30개가 전부
  `WrRepository`를 `noSuchMethod` 폴백으로 구현하므로 비파괴적임을
  확인(실제로 `flutter analyze`/`flutter test`로 재확인 — 신규 에러 0건).
- `lib/features/wishroom/application/wishroom_provider.dart` —
  `WishRoomProvider.editWish()` 추가. 다른 변경 메서드들과 달리
  `ApiError`를 `lastError`에 담고 삼키는 대신 **rethrow**한다(원본
  `WishEdit3`가 `catch(e){ setErr(e.message) }` 식으로 시트 로컬
  상태에 바로 에러를 보여주는 UX를 그대로 재현하기 위함).
- `lib/features/wishroom/features/room/wish_edit_sheet.dart` **(신규)** —
  `WishEditSheet` + `openWishEditSheet(context)`. `entrust_sheet.dart`를
  구조 템플릿으로 사용(헤더/시트 데코/`Semantics(identifier:...)` 버튼
  래핑 관례 1:1 준수). 구성: ✎문구 다듬기/↺다른 소원으로 모드 토글 칩
  (`canRewish=false`면 다른 소원으로 비활성), 60자 제한 textarea(수정
  모드는 기존 소원 프리필, 다른 소원 모드는 빈칸), 인라인 에러 표시,
  21/49/100일/목표 없음 목표 칩(탭 즉시 `editWish(mode:'goal')` 호출 —
  원본처럼 별도 저장 버튼 없음), 주 저장 버튼
  (`Semantics(identifier:'wish_edit_save')`), "이 소원 마무리하기 ›"
  링크(→ `CompleteScreen`, 원본 `app.sheet('fulfill')` 1:1).
- `lib/features/wishroom/features/room/main_room_screen.dart` —
  `import 'wish_edit_sheet.dart';` 추가. `_subFor('소원 · 목표 고쳐 쓰기')`를
  하드코딩 `'목표 없음'` 대신 `room.goal` 동적 표시로 교체. `_onGoFor('소원
  · 목표 고쳐 쓰기')`의 no-op(`() {}`)을 `Navigator.pop() +
  openWishEditSheet(context)`로 교체(`'수호자에게 맡기기'` 항목과 동일한
  배선 패턴).
- `lib/features/wishroom/features/room/care_menu_info.dart` — "소원 ·
  목표 고쳐 쓰기" 항목의 `unimplemented: true` 플래그 제거(기본값
  `false`로 복귀) — 이제 서버 `unlocked[]` 날짜대로 정상 잠금/해제됨.
- **검증**: `flutter analyze` 신규 이슈 0건(기존 무관
  `WrGuardianOutfitLauncher` 에러 2건만 잔존, `git stash`로 이번 작업과
  무관함 재확인). `flutter test test/main_room_screen_overflow_test.dart
  test/main_room_sheets_overflow_test.dart` — `git stash` 전/후 비교로
  동일 실패 건수 확인(기존 버그, 회귀 아님). `build_local.sh --debug`
  171.2초 성공. `:5060` HTTP 200 / `:3100` HTTP 307 확인. admin_web
  금지 5개 파일은 이번 flutter_app 단독 작업과 무관.

### Tour21 종료 시 자동 기도 목표 설정(`setGoal(21)`) — 추가 완료

원본 `shell.jsx` `{tour && <Tour21 app={app} onEnd={(remind) => { ...
if (!v.goal) window.WRF.setGoal(21); ... }}/>}` 1:1 — 21일 미리보기
투어를 끝낼 때 아직 기도 목표가 없으면(신규 방은 항상 이 경우) 자동으로
21일로 설정한다. Flutter 포팅(`tour21_screen.dart`)에는 이 호출이
빠져 있었던 것을 발견해 `main_room_screen.dart`의 `Tour21Screen(onEnd:
...)` 콜백에 추가했다.

- `main_room_screen.dart` — `_tour21`을 끄는 `onEnd` 콜백에서
  `room.goal == null`이면 `WishRoomProvider.editWish(id, mode: 'goal',
  goalDays: 21)`을 `unawaited()`로 호출(원본도 결과를 기다리지 않고
  바로 `setToast`로 넘어감 — 실패해도 미리보기 종료 자체를 막을 이유가
  없으므로 에러는 조용히 무시, 원본에도 별도 실패 안내 없음).
- **검증**: `flutter analyze` 신규 이슈 0건(전체 파일 기준 동일, 기존
  무관 `WrGuardianOutfitLauncher` 에러 2건만 잔존). `build_local.sh
  --debug` 150.1초 성공. `:5060` HTTP 200 / `:3100` HTTP 307 확인.
  admin_web 금지 5개 파일 그대로.

### 어뷰징 미확인 4개 항목(⑥⑦⑧⑩) — 조사 완료, 구현은 대표님 판정 대기

출처: `/home/user/handoffs/extracted/소원방 최종 기획서 v5.html` §11
"어뷰징 방지"(12행 표, 1~12번). 아래는 ⑥⑦⑧⑩ 4개 항목만 admin_web 실제
코드와 대조한 결과다(코드 변경 없음 — 조사만).

**⑥ 부계정 선물 몰아주기** — 막는 법(기획): "받은 선물 재전송 불가 ·
같은 기기/결제수단 간 보상 없음 · 반복 쌍 탐지". 실제
`gifts/route.ts`에는 자기 방 차단(`SELF`)과 신규가입(7일 미만) 하루
100개 한도(`NEW_ACCOUNT_LIMIT`) 2가지만 구현. **3가지 모두 미구현**:
재전송 차단 없음, 같은 기기/결제수단 판정 로직 전무(`device`/`fingerprint`
문자열로 wishroom 라우트 전체 grep → 0건), 반복 쌍(동일 두 계정이
서로 반복 교환) 탐지 없음.

**⑦ 대신 기도 주고받기** — **[정정]** 아래 "가격 불일치" 결론은
틀렸다 — 기획서의 "500원/30원"은 원화가 아니라 🧧복주머니 개수를
원화로 환산 표기한 것(대표님 지적으로 정정, §8 환산율
`POUCH.won:10` 즉 복주머니 1개=10원 적용: 500원=🧧50개, 30원=🧧3개).
이 기준으로 다시 보면 `wishroom_data.json`의 `POUCH.dispatch."1"=50`과
`POUCH.dispatchRecv=3`이 스펙과 정확히 일치한다 — 가격 체계 자체는
문제없음.

막는 법(기획): "보내는 🧧50(500원)/받는 🧧3(30원) · 같은 방 하루 1명
· 같은 기기 간 보상 없음". 이 문구와 가장 가까운 기능은 "수호자
보내기"(Dispatch, `wish-rooms/{id}/dispatch` route) —
`validateDispatchOrThrow()`가 DAY_CAP(하루 한 곳)·ROOM_WEEK(같은 방
주 1번)·GUARDIAN_BUSY는 구현하지만, 스펙의 "같은 방 하루 1명"이
아니라 "같은 방 주 1번"으로 더 엄격하게 구현돼 있고, "같은 기기 간
보상 없음"은 전무.

**가격 불일치보다 더 중요한 새 발견**: 기획서 §6 표(라인111) "보내기
(다른 방)" 행은 가격란에 명시적으로 "하루 50 · 사흘 120 · 이레
250"(맡기기와 동일하게 유상)이라 적혀 있는데, 실제
`dispatch/route.ts`는 `price: 0`(완전 무료)으로 구현돼 있다. 이전
세션(CHECKLIST.md "보내기(visit) 범위 확정" 항목, S5 작업 시점)에
"app3 원본 `flow.js`의 `visit()`이 `price:0`이라 무료가 맞다"고
판단해 S5 결제창 통일 대상에서 뺐는데, 그건 구버전 app3 JS 기준이었고
v5 최종 기획서는 "보내기"를 유상으로 바꾼 것으로 보인다(§9 "설계
의도" 노트: "대신 기도는 보내는 쪽 500원 / 받는 쪽 30원이라 부계정
주고받기는 항상 손해" — 이 문구는 보내는 쪽이 돈을 내야 성립하는
서술인데, 현재 구현은 보내기가 무료라 이 경제적 억제장치 자체가
작동하지 않는다. 평생 수신 상한 🧧15(150원)으로 피해 규모는
제한되지만, "항상 손해"라는 설계 의도는 무료 구현에서는 성립하지
않음).

**[대표님 판정 완료]** §11/§9의 "500원/30원" 문구는 §6 "맡기기" 가격표를
잘못 재사용한 **기획서 쪽 오기**로 확정 — "보내기"는 **현행 무료
(price=0)를 그대로 유지**한다. 따라서:
- S5 "공용 결제창 통일" 대상에 "보내기"를 추가할 필요 없음(이전 S5
  판단대로 무료 기능이므로 `PayScreen` 경유 불필요 — 그대로 유지,
  Flutter `dispatchGuardian()`도 가격 파라미터 없이 이미 무료 호출
  구조로 구현돼 있어 추가 변경 불필요).
- ⑦번의 "가격" 관련 갭(500/30원 vs 실제)은 **해소됨** — 애초에 적용
  대상이 아니었음. 남은 실질 갭은 "같은 방 하루 1명"(스펙)보다 엄격한
  "주 1번"(구현) 차이, 그리고 "같은 기기 간 보상 없음"(미구현) 2가지
  뿐이며, 둘 다 사소하거나(더 엄격한 쪽은 문제라기보다 안전 방향) 2번
  결정 사항(기기 핑거프린트 범위 포함 여부)에 포함돼 별도 조치 불필요.

**⑧ 메시지 도배·괴롭힘** — 막는 법(기획): "하루 10 · 분당 3 · 금칙어 ·
신고 3번 자동 숨김+24시간 검토". 실제 `comments/route.ts`는
`enforceRateLimitAndLog(tx, userId, "comment")` → `checkRateLimit()`가
**분당 10회**(스펙은 분당 3) 제한 + 60자 제한 + `filterText(text,
true)`(금칙어만, PII는 force로 우회) 적용. **"하루 10회" 상한은 코드
어디에도 없음**(분당 제한만 있고 일일 누적 제한 없음) — 분당 수치도
스펙(3)보다 느슨함(10). 신고 쪽은 `reports/route.ts`에
`HIDE_THRESHOLD = 3`으로 "신고 3회 자동 숨김"은 정확히 구현되어 있고
응답에 `reviewWithinHours: 24`도 포함(스펙의 "24시간 검토"와 일치) —
**이 부분은 스펙과 일치**. 정리: 신고 임계값·24시간 검토는 구현됨,
분당 제한 수치는 스펙보다 느슨(3→10)하고 하루 상한 자체가 없음.

**⑩ 위기 표현** — 막는 법(기획): "막지 않음 · 109 안내 · 공개만
제한". `wishroom-engine.ts` 전체에서 "CRISIS"/"crisis"/"109" 문자열
grep 0건 — **위기 표현 감지 로직이 전혀 없음**. `filterText()`는
금칙어(PROFANITY)·개인정보(PII_PATTERNS) 2가지만 검사하며 위기 표현
관련 패턴은 존재하지 않는다. **완전 미구현으로 확인**.

**조사 과정에서 추가로 확인한 사실**: 같은 기기/결제수단 판별에 쓸 수
있는 deviceId·fingerprint·paymentMethod(공유) 개념 자체가 wishroom
도메인 코드에 전혀 없다(프로젝트 전체 grep 결과 `paymentMethod`는
사주/타로 등 "결과 접근"(result-access) 서비스의 **지불 수단
종류**(카드/포인트 등) 문자열일 뿐, 기기 식별과 무관). 즉 ⑥·⑦의
"같은 기기 간 보상 없음" 요건은 현재 아키텍처에 기기 식별 개념 자체가
없어 바로 구현할 수 없고, 선행 설계(기기 핑거프린트 수집·저장 방식)가
필요하다.

**요약표**:

| 항목 | 기획 요건 | 구현 상태 |
|---|---|---|
| ⑥ 부계정 선물 몰아주기 | 재전송 차단·동일기기 보상 없음·반복쌍 탐지 | 전부 미구현 |
| ⑦ 대신 기도 주고받기 | 🧧50/3(=500·30원)·하루1명·동일기기 보상 없음 | **[판정완료]** 가격(50/3)은 일치, "보내기" 무료(price=0)는 §11 오기로 확정돼 현행 유지 — 변경 불필요. 잔여: "하루1명"→"주1번"(더 엄격, 문제아님), 동일기기 체크 없음(⑥과 함께 범위 결정 대기) |
| ⑧ 메시지 도배·괴롭힘 | 하루10·분당3·신고3회 자동숨김 | 신고3회+24h는 구현, 분당 제한은 10(스펙3)로 느슨, 하루 상한 없음 |
| ⑩ 위기 표현 | 109 안내, 공개만 제한 | 전혀 미구현 |

**다음 결정 필요 사항(대표님 판정 대기, 코드 변경 보류)**:
1. ~~⑦ "보내기" 유상화 여부~~ — **[판정완료] 현행 무료 유지, §11/§9의
   "500/30원"은 §6 가격표 오기로 확정. 추가 조치 없음.**
2. ⑥·⑦의 "동일 기기 간 보상 없음"을 이번 범위에 포함할지(기기
   핑거프린트 설계가 선행돼야 함 — 범위가 꽤 큼).
3. ⑧의 분당 제한을 스펙대로 3으로 낮추고 "하루 10회" 상한을 추가할지.
4. ⑩ 위기 표현 감지를 신규로 구현할지(키워드 기반 1차 필터 + "공개
   시 검토" 플래그 + 109 안내 UI 정도로 제한된 1차 버전 제안 가능).

**다음 세션에 이어갈 것(갱신)**: "소원 수정 제한" + Tour21 자동
목표설정까지 전부 종료. 어뷰징 4개 항목(⑥⑦⑧⑩) 중 **⑦은 판정
완료(보내기 무료 유지, 추가 조치 없음)**. 남은 결정 대기: ⑥·⑦의
동일기기 보상 차단 범위 포함 여부, ⑧ 분당제한(10→3)·하루상한 추가
여부, ⑩ 위기표현 감지 신규 구현 여부 — 코드 변경은 아직 없음, 대표님
판정 대기(위 표/결정사항 참고). 남은 S6 항목은 46개 안내 팝업 전수
대조(아래로 완료), 9단계 플로우 수동 QA — 미착수(참고: "21일 미리보기"
자체(Tour21Screen)는 기존에 이미 구현되어 있었고, 이번에 발견돼 보강한
것은 그 "종료 시 자동 목표설정" 누락분뿐이다). 그 외 미전달 6장
스크린샷(`/home/user/wr_compare/DELIVERY_6SHOTS/`)도 그대로 대기 중.

### 46개 안내 팝업 전수 대조 — 조사 완료, 구현은 대표님 판정 대기

출처: `/home/user/handoffs/extracted/mapping/소원방 개발 매핑표.html`
§05-B "POPUPS & GUIDES"(A~G 7개 그룹, 매핑표 자체 표기로 46개 —
세부 행 전개 시 59개). 실제 카피 원문은
`/home/user/handoffs/extracted/mapping/popup_copy.json`
(GUIDE3·UNLOCK_TXT·TOUR_STEPS·MENU_INFO·TEXTS). 아래는 각 항목을
`lib/features/wishroom/` 실제 코드와 대조한 결과다(코드 변경 없음 —
조사만).

**구현 확인(문제 없음)**:
- **B1-B6**(UNLOCK_TXT, 잠금 해제 카드 6종) — `unlock_card.dart`에
  원문과 정확히 일치.
- **D1-D10**(MENU_INFO, "⋯ 소원방 돌보기" 메뉴 10종 안내) —
  `care_menu_info.dart`에 원문과 정확히 일치(과거 세션에 이미 완료).
- **A3-A10**(TOUR_STEPS, 21일 미리보기 7단계) — `tour21_screen.dart`에
  원문과 정확히 일치.
- **A1**(Intro3) — `features/intro/wish_room_intro_screen.dart`.
- **A2**(Light3) — `features/compose/wish_light_screen.dart`
  (`WishLightScreen`/`_StampSeal`/`_FlyingGlyph`).
- **A14**(DoneCard) — `main_room_screen.dart`에 테마별 말씀카드 4종 +
  🧧+5 보상까지 구현·보강됨(원안보다 풍부).
- **A15**(HOLD_SHORT) — `devotion_controller.dart`
  (`WrToast.show(context, '조금만 더 머물러 주세요')`, 정확 일치).
- **C12**(잠긴 탭 안내) — "기다릴게요" 문구로 `wr_bottom_nav.dart` 등
  4개 파일에서 확인.
- **E1·E2**(결제창·영수증) — `features/shop/pay_screen.dart`
  (`PayOrder`/`PayScreen`, S5 공용 결제창 그 자체).
- **E3**(ConfirmBuy) — `guardian_detail_sheet.dart`.
- **E4**(복주머니 시트) — `features/wallet/wallet_sheet.dart`
  (`WalletSheet`).
- **E5**(ExitAsk3) — `wr_nav_pill.dart`/`wr_bottom_nav.dart`의
  `wrExitHome`/`wrBackOrAskExit` 헬퍼로 여러 화면에 공용 적용.
- **F1**(GoalSheet3) — 독립 시트가 아니라 `wish_edit_sheet.dart`의 목표
  칩(21/49/100/0)으로 **병합 구현**(기능 자체는 존재, 화면 구성만 원안과
  다름 — 문제로 보지 않음).
- **F2**(WishEdit3) — `wish_edit_sheet.dart`(이번 세션 "소원 수정 제한"
  작업으로 완료).
- **F3**(Fulfill3, 成/放) — `main_room_screen.dart`의 `_CareSheet`
  (`Outcome.RELEASED`/`FULFILLED`, 이전 세션 4-B 작업으로 완료).
- **F4**(Celebrate3) — `features/complete/complete_screen.dart`
  (`CompleteScreen`, `_LightPillar`/`_LotusPop`/`_SealingOverlay`).
- **G1**(수호자 자세히) — `guardian_detail_sheet.dart`에 성향·성격·
  좋아하는 것·지켜주는 소원·상태별 CTA까지 원안 그대로 주석에 명시된
  구조로 구현됨.
- **G2**(맡기기 시트) — `entrust_sheet.dart`에 하루/사흘/이레 가격
  선택 그대로 구현.
- **G6**(다른 분 방 시트, Visit3) — `other_room_screen.dart`에
  메시지쓰기(60자 — 스펙 표기 80자와 숫자만 다름, 기능은 동일)·선물
  금액 칩(5/10/30/50개 — 스펙 표기 10/30/50/100과 숫자만 다름)·
  "☾ 수호자 보내기" 버튼(`dispatchGuardian()` 호출)·신고 사유 시트
  전부 구현 확인. 위기 표현 109 안내는 G6이 아니라 `compose_screen.dart`
  쪽에 구현(작성 시점 차단 — 적용 위치가 스펙과 다르지만 기능은 존재).

**확인된 공백(미구현 또는 구조적 결손) — 구현 여부 대표님 판정 필요**:

1. **C1-C11(처음 동작 안내, 11항목) — 전면 미구현**. v5 스펙은 기존
   구버전(app2 시절) 10개 주제짜리 통합 가이드북을 C(처음 동작
   안내 11개)+D(메뉴 안내 10개) 2종으로 분리하라고 요구하는데, D만
   완료되고 C는 전혀 새로 만들어지지 않았다. 현재
   `guide_data.dart`/`guide_sheet.dart`/`guide_prefs.dart` 3개 파일
   모두 여전히 구버전 10주제(촛불·정성·레벨·복주머니·캐릭터·소원·
   봉인·응원·꾸미기·보관함) 구조 그대로이고, `main_room_screen.dart`·
   `decor_screen.dart`·`vault_screen.dart`의 `_openGuide()` 호출부도
   전부 이 구버전 `GuideBook`을 그대로 띄운다. `GuidePrefs`에는 v5의
   "화면별 첫 동작 1회성 힌트"라는 개념 자체가 없다(과거 세션
   CHECKLIST에도 "구버전 가이드북을 C+D로 쪼개야 하는데 D만
   끝냈다"는 메모가 이미 있었음 — 그대로 미완 상태로 남아있었음이
   이번에 재확인됨).

2. **A11(TabGuide) — 애매함, 판정 필요**. "소원방 쓰는 법" 메뉴 항목
   (`_CareSheet` 안)이 진입점으로 존재하긴 하나, 누르면 위 1번의
   구버전 `GuideBook`이 열려 v5의 새 TabGuide 내용이 아니다.
   "진입점은 있으나 내용이 다름" — 구현/미구현 중 어느 쪽으로 볼지
   판단 필요(사실상 1번 C그룹 공백과 같은 근본 원인).

3. **A12(TomorrowCard)·A13(MorningCard3) — 확인된 공백, 과거에
   명시적으로 보류됨**. `main_room_screen.dart`에 "아침 인사
   카드(A13)·21일 미리보기(A3~A11) 신규 구현은 S3 이후 별도 작업"이라는
   코드 주석이 그대로 남아있다. 21일 미리보기(A3-A10)는 이후 실제로
   구현됐지만 A12·A13은 끝내 구현되지 않았다. 더 중요한 점은, A13이
   대체하기로 했던 구버전 "FirstVisitChip" 기능이 이미 제거된 상태라
   — 단순히 "새 기능 미구현"이 아니라 "있던 기능을 빼고 대체품을 아직
   안 넣은" 실질적 기능 공백이다.

4. **F5(공개 설정, Share3) — 부분 공백**. `_ShareSheet`
   (`main_room_screen.dart`)에 공개범위 전환(모두에게/링크로만/나만
   보기, `Visibility` enum + `updateVisibility()`)은 구현돼 있지만,
   스펙이 요구하는 "수호자 방문 받지 않기/물어보고/누구든"
   (`visitPolicy`: off/ask/open) 설정 UI는 어디에도 없다.
   `visitPolicy` 필드는 서버 응답을 그대로 읽어 **보여주기만**
   하는 2곳(`other_room_screen.dart`, `received_sheet.dart`)뿐이고,
   값을 바꾸는 UI·provider 메서드(`updateVisitPolicy` 등) 자체가
   코드에 없다 — 현재 방문객이 "☾ 방문 여쭤보기/보내기" 버튼을 볼 때
   항상 서버 기본값(`ask`)에 의존하며, 방 주인이 이를 직접 끄거나
   "누구든 OK"로 바꿀 방법이 없다.

5. **G3(EntrustBack, 맡기기 끝 카드) — 데이터/API는 있으나 UI 전혀
   없음**. 모델에 `WishRoom.entrustDone` 필드, provider에
   `ackEntrust(id)`(서버 "마음에 담기" 처리) 메서드가 다 구현돼 있지만,
   `room.entrustDone`을 읽어 "맡긴 기간 종료 · ○○이 N일 동안 대신
   빌었어요" 카드를 띄우는 화면이 **단 한 곳도 없다**. `ackEntrust()`도
   어느 UI에서도 호출되지 않는다(provider 안에서만 정의돼 있고
   호출부 0건). 즉 서버가 데이터를 내려줘도 사용자는 절대 볼 수 없고,
   종료 처리(ack) 자체도 트리거할 방법이 없다.

6. **G5(DispatchBack, 보낸 수호자 귀환 카드) — G3과 동일한 패턴의
   공백**. 모델에 `WishRoom.guardianAway`(`DispatchAway`) 필드가 있고
   `guardianAway != null` 체크는 `guardian_detail_sheet.dart`(바쁨
   상태 표시용) 등 3곳에서 하지만, 이는 전부 "지금 보낸 상태인지"
   판정용일 뿐 **귀환 완료 시 "기도 일지 보여주기" 카드**는 어디에도
   없다. provider의 `ackDispatch(dispatchId)` 메서드도 선언만 있고
   호출하는 UI가 전혀 없다(G3과 동일하게 호출부 0건).

**요약표**:

| 그룹 | 항목 수 | 상태 |
|---|---|---|
| A (처음·매일) | 15 | A1,A2,A3-A10,A14,A15 구현 / A11 애매(구내용 다름) / A12,A13 공백 |
| B (열림카드) | 6 | 전부 구현 |
| C (처음 동작 안내) | 11 | **전부 공백**(구버전 가이드북 미분리) |
| C12 (잠긴 탭) | 1 | 구현 |
| D (메뉴 안내) | 10 | 전부 구현(기완료) |
| E (확인·결제) | 5 | 전부 구현 |
| F (소원 관리) | 5 | F1,F2,F3,F4 구현 / F5 부분 공백(방문정책 편집 UI 없음) |
| G (수호자·함께) | 6 | G1,G2,G6 구현 / G3,G5 공백(데이터·API만 있고 UI 없음) / G4는 `received_sheet.dart`에 구현 확인 |

**확인된 공백 총정리(구현 필요 여부 대표님 판정 대기)**:
1. C1-C11(처음 동작 안내 11종) 신규 구현 — 가장 큰 작업.
2. A11 TabGuide를 C그룹과 함께 새로 만들지, 구버전 가이드북 연결을
   그대로 둘지.
3. A12(TomorrowCard)·A13(MorningCard3) 신규 구현 — 특히 A13은 이미
   제거된 FirstVisitChip의 대체 기능이라 우선순위 검토 필요.
4. F5 방문 정책(visitPolicy) 편집 UI 신규 구현 — 방 주인이 "수호자
   방문 받지 않기/물어보고/누구든"을 직접 설정할 방법 추가.
5. G3(EntrustBack) 카드 UI 신규 구현 — 데이터·API는 이미 있어 UI만
   추가하면 됨(상대적으로 작은 작업).
6. G5(DispatchBack) 카드 UI 신규 구현 — G3과 동일하게 UI만 추가하면 됨.

**코드 변경은 아직 없음 — 조사만 완료. 위 6개 공백에 대해 대표님 판정
후 구현 여부·우선순위 결정 예정.**

---

## 46개 안내 팝업 — 공백 구현 진행 기록 (대표님 "진행" 승인, 위 6개 공백 처리)

**F5(방문 정책 편집) — 구현 완료**:
- admin_web: `PATCH /wish-rooms/{id}` 엔드포인트에 `visitPolicy`(off/ask/open)
  파라미터 추가(기존 `visibility` 편집과 같은 엔드포인트 재사용 — 새 라우트
  만들지 않음). 커밋 `6acb2952`.
- flutter_app: `WrRepository.updateRoom()`에 `visitPolicy` 파라미터 추가,
  `WishRoomProvider.updateVisitPolicy(id, policy)` 신규 메서드,
  `main_room_screen.dart`의 `_ShareSheet`에 "수호자 방문"
  받지 않기/물어보고/누구든 탭 선택 UI 추가(기존 공개범위 탭 선택 UI와
  동일한 패턴 — `_visTab`/`_visDesc` 옆에 `_policyTab`/`_policyDesc` 추가).
  커밋 `965d3f77`.
- 검증: `flutter analyze` 통과, `tsc --noEmit` 통과.

**G3(EntrustBack, 맡기기 끝 카드) — 구현 완료**:
- 서버 변경 없음(기존 `entrustDone`/`POST .../entrust/ack` 인프라가 이미
  충분함을 재확인).
- flutter_app: `entrust_back_card.dart` 신규 — `room.entrustDone`이 있고
  다른 오버레이가 하나도 없을 때(기존 `unlock_card.dart`와 동일한 조건)
  "代願 · 기도 일지" 카드를 보여준다. [축소 반영] 원본(app3/entrust.jsx)은
  일자별 "내가 빈 날/수호자가 빈 날" 달력 칸을 그리지만, 이 서버는 그
  일자별 기도 로그(`WishRoomPrayerLog` 모델은 있으나 공개 API 미연결)를
  내려주지 않아 `Entrust` 필드(guardian/days)만으로 요약 문구로 대체했다
  — 달력 UI 자체는 구현하지 않음(아래 "남은 제약" 참고). "마음에 담기"
  버튼은 `WishRoomProvider.ackEntrust(room.id)`를 호출한다.
  `main_room_screen.dart` Stack에 `UnlockCard` 다음 우선순위로 연결.
  커밋 `1630b06f`.

**G5(DispatchBack, 보낸 수호자 귀환 카드) — 구현 완료**:
- admin_web: `wishroom-engine.ts`에 `getDispatchDone(tx, userId, nowMs)` 신규
  함수 추가(내가 보낸 dispatch 중 끝났지만 `ackedAt`이 비어 있는 가장 최근
  1건을 찾음). `MeViewOptions`/`meView()`에 `dispatchDone` 필드 추가,
  `_shared.ts`의 `buildMeView()`에 연결해 `me`를 반환하는 모든 엔드포인트
  응답에 자동 포함되도록 함(room이 아니라 me 레벨 개념이라 `roomView()`가
  아닌 `meView()`에 실음 — "어느 방으로 보냈든 내 홈 화면에 뜨는 카드"이기
  때문). 커밋 `6acb2952`.
- flutter_app: `models.dart`의 `Me` 클래스에 `dispatchDone` 필드 +
  JSON 파싱 추가. `dispatch_back_card.dart` 신규 — `me.dispatchDone`이
  있을 때 "○○이 돌아왔어요" 카드를 보여준다(G3와 동일하게 받는 방의
  소원 문구·방문자 수는 공개 API로 내려오지 않아 요약 문구로 대체).
  "마음에 담기" 버튼은 `WishRoomProvider.ackDispatch('wrd_{id}')`를
  호출한다(서버 `parseWishRoomDispatchId`가 요구하는 `wrd_` 접두어 포맷).
  **버그 수정**: `ackDispatch()` 엔드포인트는 `ackEntrust()`와 달리 응답에
  room/me를 함께 주지 않고 `{ok:true}`만 반환하므로, provider의
  `ackDispatch()`가 ack 성공 후 `loadMyRoom()`을 호출해 `me.dispatchDone`을
  직접 갱신하도록 수정(안 하면 카드가 계속 떠 있는 버그). 커밋 `1630b06f`.

**우선순위**(동시 발생 시): `pendingUnlock`(열림 카드) > `entrustDone`(G3)
> `dispatchDone`(G5) — `UnlockCard`와 동일한 "다른 오버레이 없음" 조건을
공유하되 `else if`로 상호 배타 처리.

**남은 제약(의도적 축소, 대표님 재확인 필요 시 추가 작업 대상)**:
- G3 카드의 "기도 일지 달력"(일자별 내가/수호자가 빈 날 칸)은 구현하지
  않음 — 서버에 일자별 기도 기록을 공개 API로 노출하는 엔드포인트가 없음
  (`WishRoomPrayerLog` 모델은 스키마에 있으나 연결된 라우트가 전혀 없음).
  필요하면 신규 서버 작업(API 추가)부터 시작해야 함.
- G5 카드의 "그 방 소원 문구·방문자 수" 표시도 동일한 이유로 생략 —
  발신자가 상대방 방 상세를 조회할 공개 API가 없음(현재 구조상 의도적
  — 사생활 보호 목적일 수 있어 임의로 새 엔드포인트를 만들지 않음).

**검증**: `flutter analyze`(전체 프로젝트) 통과, `tsc --noEmit` 통과,
`build_local.sh --debug` 빌드 성공(146.2s), 프리뷰 서버(:5060) 기동 확인
(HTTP 200). F5 커밋 이후 깨졌던 `test/main_room_sheets_overflow_test.dart`의
`_FakeWrRepository.updateRoom()` override 시그니처도 함께 수정.

**다음 단계(요약표 갱신)**:

| 그룹 | 항목 수 | 상태 |
|---|---|---|
| F (소원 관리) | 5 | **F1-F5 전부 구현**(F5 방문정책 편집 UI 완료) |
| G (수호자·함께) | 6 | **G1-G6 전부 구현**(G3,G5 카드 UI 완료, 일자별 달력/방 상세는 의도적 축소) |

남은 공백: A11(TabGuide)·A12(TomorrowCard)·A13(MorningCard3)·
C1-C11(처음 동작 안내 11종) — 아래 계속 진행.

---

**A12(TomorrowCard) — 구현 완료**:
- 서버 변경 없음 — `WrCatalog.I.raw['UNLOCK']`(assets/wishroom/data/
  wishroom_data.json, 클라이언트에 이미 존재)만으로 "다음에 열릴 기능"을
  계산 가능함을 확인.
- flutter_app: `tomorrow_card.dart` 신규 — app3/tour.jsx `OPEN_NEXT` 배열 +
  `TomorrowCard` 1:1 포팅. 생애 첫 기도 직후가 아닌 매일 기도 완료 직후
  (`_QuoteCard.onClose`, `_firstTimeAfterPray`가 false인 분기)에 트리거되며
  Tour21과 상호 배타(app3 `afterPray(first)` 1:1). "오늘 하루 한 번만"
  판정은 서버에 해당 로그 테이블이 없어(entrust와 동일한 공백) `GuidePrefs`에
  `roomId:dayN` 키로 로컬 저장(`tomorrowCardShown`/`markTomorrowCardShown`
  신규 메서드)하는 방식으로 대체.

**A13(MorningCard3) — 구현 완료**:
- 서버 변경 없음.
- flutter_app: `morning_card.dart` 신규 — app3/guide3.jsx `MorningCard3`
  1:1 포팅. [치환] 원본의 `v.day`(방 생성 후 누적 일련번호, 0-base)는 이
  서버 스키마에 없어 의미상 가장 가까운 `room.dayN`(1-base 경과일)으로
  대체했다 — "어젯밤 N명이 빌었어요" 숫자는 장식용 의사난수라 정확히 같은
  값일 필요는 없음. 2일째부터, 아직 오늘 기도 전이고 투어 중이 아닐 때
  화면 빌드 초입(`build()` 진입 시 postFrameCallback)에서 하루 1번 트리거.
  "오늘 하루 한 번만" 판정도 A12와 동일하게 `GuidePrefs`에 `roomId:dayN`
  키로 로컬 저장(`morningCardShown`/`markMorningCardShown` 신규 메서드).
- 커밋 `0c80728c`.

**검증(A12/A13)**: `flutter analyze`(전체 프로젝트) 통과(morning_card.dart의
`Visibility` 모호 임포트 1건 발견 → `hide Visibility`로 즉시 수정, 기존
파일들과 동일 패턴). `build_local.sh --debug` 빌드 성공(144.5s), 프리뷰
서버(:5060) 기동 확인(HTTP 200).

남은 공백: A11(TabGuide)·C1-C11(처음 동작 안내 11종, 가장 큰 남은 작업,
`GUIDE3` 딕셔너리 11건 — pray/guardians/decor/together/wardrobe/shop/pay/
entrust/theme/share/vault — 를 신규 "처음 동작 안내" 시스템으로 이식해야
함, 각 화면의 첫 동작 시점에 트리거 연결 필요) — 다음 세션에서 계속 진행.

---

### C1-C11(처음 동작 안내 11종)·A11(TabGuide) 구현 완료

- 서버 변경 없음.
- flutter_app 신규 파일 3개:
  - `guide/guide3_data.dart` — app3/guide3.jsx `GUIDE3` 딕셔너리 11키
    (pray/guardians/decor/together/wardrobe/shop/pay/entrust/theme/share/
    vault) 1:1 포팅. `wardrobe`의 img는 원본 `outfits2/O_free_01.png`가
    프로젝트에 없어 `care_menu_info.dart`에 이미 있던 선례대로
    `outfits/O_free_01.png`로 대체.
  - `guide/guide3_sheet.dart` — app3/guide3.jsx `GuideSheet3` 포팅.
    `care_menu_info_sheet.dart`의 히어로이미지+모노라벨+제목+단계카드+
    약속문구+CTA 구조를 그대로 재사용. `showGuide3Sheet(context,key,
    {lock,onClose})` + 평생 1회 노출 편의 헬퍼 `maybeShowGuide3(context,
    key)`(기존에 미사용이던 `GuidePrefs.seen/markSeen` 최초 활성화) 제공.
    `Guide3Lock` 클래스는 원본 `lock={day,left}`와의 구조적 대응을 위해
    추가했으나 이번 트리거 11건에는 실사용 안 함(향후 wishroom_shell.dart
    잠금 힌트 교체 시 재사용 후보로 보류).
  - `guide/tab_guide_sheet.dart` — app3/tour.jsx `TabGuide({app,onClose})`
    1:1 포팅(탭 6개+⋯메뉴 7행, 각 "지금 가능"/"N일째" 표시).
- flutter_app 트리거 연결(9개 파일, `want` useEffect 1:1 대응):
  - character_shop_screen.dart → 'guardians', explore_screen.dart →
    'together', shop_screen.dart → 'shop', vault_screen.dart → 'vault',
    wardrobe_screen.dart → 'wardrobe', entrust_sheet.dart → 'entrust',
    pay_screen.dart → 'pay'(항상 최우선), main_room_screen.dart
    `_ShareSheetState` → 'share', main_room_screen.dart `build()` →
    'pray'(원본 `scr==='home'&&v.wish&&!v.prayedToday&&v.prayedN===0&&
    !tour` 조건 1:1).
  - decor_screen.dart → 'decor'와 'theme' 순차 호출(이 포팅은 THEME
    전환을 DecorScreen 첫 슬롯 탭으로 통합했기 때문에 두 GUIDE3 키를
    한 화면 진입 시점에 순서대로 노출 — 대표님 재확인 필요한 판단,
    코드 주석으로 근거 명시).
  - main_room_screen.dart "소원방 쓰는 법" 행의 `onTap`을 기존
    `widget.openGuide()`(구버전 10주제 GuideBook)에서
    `showTabGuideSheet(context)`로 교체(A11). `openGuide`/`_openGuide`
    자체는 다른 용도(포커스 조회)로 다른 곳에서 계속 쓰이므로 미변경.
- Semantics identifier 추가: `guide3_close`(guide3_sheet CTA),
  `tab_guide_close`(tab_guide_sheet CTA).
- admin_web 금지 파일 5종 불변 재확인(`git status --short` 동일).

**검증**: `flutter analyze`(전체 프로젝트) 2회 통과 — 신규 오류 0건
(기존에 범위 밖으로 확인된 `guardian_outfit_launcher_test.dart` 오류
2건만 잔존). `build_local.sh --debug` 빌드 성공(137.2s). 프리뷰 서버
(:5060) 기동 확인(HTTP 200).

남은 공백: `wishroom_shell.dart`의 `_showLockHintSheet()` 플레이스홀더를
신규 `Guide3Lock` 인프라로 교체할지 여부 — 이번 범위에서는 미착수,
대표님 판단 필요. 그 외 어뷰징 ⑥⑧⑩ 잔여 결정, 9단계 플로우 수동 QA는
여전히 미착수.
