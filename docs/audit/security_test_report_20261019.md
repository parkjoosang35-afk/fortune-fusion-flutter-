# 보안 테스트 종합 보고서 (2026-10-19, 세션 재검증)

## 0. 테스트 환경 확인 (필수 선행 절차)

| 항목 | 값 |
|---|---|
| 테스트 대상 서버 | admin_web dev server, port 3010 |
| 서버 프로세스 PID | 705136 |
| 서버 시작 시각 | 2026-10-19 09:05:26 |
| 적용된 보안수정 커밋 | 4802512 (2026-10-19 08:34:48) |
| 커밋 대비 서버시작 | 서버 시작이 커밋 이후 → 수정코드 반영 확인 |
| 테스트 대상 파일 git status | 로컬 수정 없음(커밋 상태 그대로, `git status --short` 결과 없음) |
| saju_engine(FastAPI) 상태 | PID 704451, HTTP 200 (port 8000) |
| 테스트 DB | /home/user/admin_web/prisma/dev.db (로컬 dev DB, 운영 DB 아님) |
| 테스트 계정 | userId=322(보안테스트A), userId=323(보안테스트B) — 격리된 테스트 전용 계정 |

**⚠️ 중요 경과사항**: 직전 턴에서 테스트했던 포트 3000/3001 서버는 보안수정 커밋(08:34:48) 이전(각각 04:45, 02:31)부터 기동된 구버전 프로세스였음이 발견되어, 해당 서버로 실행한 모든 이전 테스트 결과(턴3의 테스트1/2, 턴4 초반 테스트3)를 전량 폐기하고 본 보고서로 교체함. 구버전 프로세스는 kill -9로 종료 후, 현재 커밋을 반영한 신규 서버(포트 3010)를 기동하여 전체 재검증함.

## 1. 보안 테스트 결과 (7건 전수, 전부 독립적 재검증 완료)

### [1] 정상 사용자의 정당한 콘텐츠 접근
- **대상 API**: POST /api/public/result-access/begin → POST /api/public/saju-renewal/interpret
- **시나리오**: 계정A(userId=322), topic_id=LIFE_000, 완전 신규 거래(indep-t1-1792400931-7466)
- **결과**: **통과**
  - begin: HTTP 200, status=pending, 잔액 1000→900
  - interpret: HTTP 200, success=true, cached=false(신규생성)
  - DB: 거래 status=success, amount=100
  - 잔액: 900 유지(정확히 1회 차감, 추가 차감 없음)
  - topic_interpret_results 레코드 생성 확인(userId=322, topic_id=LIFE_000, mode=detail)

### [2] 타인의 콘텐츠 또는 권한 없는 콘텐츠 접근 차단
- **대상 API**: POST /api/public/saju-renewal/interpret
- **시나리오**: 계정A 소유 거래(TXN_1)를 계정B(userId=323) 토큰으로 사용 시도
- **결과**: **통과**
  - HTTP 400, reason=TRANSACTION_OWNER_MISMATCH
  - 응답: {"success":false,"error":"잘못된 요청입니다.","reason":"TRANSACTION_OWNER_MISMATCH"}

### [3] 다른 토픽의 거래 재사용 차단 (교차토픽 콘텐츠바인딩, 핵심 보안검증)
- **대상 API**: POST /api/public/saju-renewal/interpret
- **시나리오**: 계정A가 topic LIFE_000용으로 begin한 pending 거래(TXN_3)를, 다른 topic MONEY_005의 interpret 요청에 그대로 사용
- **결과**: **통과**
  - HTTP 400, reason=TRANSACTION_CONTENT_MISMATCH
  - 응답: {"success":false,"error":"이 거래로는 해당 결과를 열람할 수 없습니다.","reason":"TRANSACTION_CONTENT_MISMATCH"}
  - DB 검증: 거래(TXN_3) 상태 여전히 pending(변조 없음), 잔액 800 유지(변동없음)
  - MONEY_005에 대한 topic_interpret_results 캐시 레코드 미생성 확인(실제 해석 생성이 전혀 일어나지 않음)

### [4] 동일 요청(거래) 반복 시 중복 차감 방지 (캐시경로 priorSuccess 로직)
- **대상 API**: POST /api/public/result-access/begin → POST /api/public/saju-renewal/interpret (캐시 히트 경로)
- **시나리오**: 계정A가 이미 LIFE_000 success 거래(TXN_1) 보유 상태에서, 동일 topic에 대해 새 거래(TXN_4)를 begin한 뒤 interpret 재호출
- **결과**: **통과**
  - begin: HTTP 200, 잔액 800→700 (정상 선차감)
  - interpret: HTTP 200, cached=true
  - DB: TXN_4 상태 자동 refunded 처리(이중결제 방지 로직 작동), amount=100
  - 잔액: 700→800으로 자동 환불 복구 확인
  - 전체 거래 내역 조회: success 거래는 TXN_1 단 1건만 존재(이중 과금 없음 확인)

### [5] 소원방 중복 신고 제한
- **대상 API**: POST /api/public/wishroom/reports
- **시나리오**: 계정A가 동일 소원방(wr_1)에 2회 연속 신고 시도
- **결과**: **통과**
  - 1차: HTTP 201, {"hidden":true,"reviewWithinHours":24}
  - 2차(중복): HTTP 201, 동일 응답(사용자에게는 "접수"로 보이나 내부적으로 재집계 안됨)
  - DB 검증: wish_rooms.report_count = 1 (2가 아님, 중복 집계 방지 확인)
  - reports 테이블: reporter_id=322, target_id=1 레코드 1건만 존재

### [6] 소유하지 않은 캐릭터로 방 생성 시 차단
- **대상 API**: POST /api/public/wishroom/wish-rooms
- **시나리오**: 계정A(미보유 캐릭터만 있는 상태)가 유료 캐릭터 F01(가격 500)로 방 생성 시도
- **결과**: **통과**
  - HTTP 403, code=NOT_OWNED, {"success":false,"error":"아직 함께하지 않는 캐릭터예요","code":"NOT_OWNED"}
  - DB 검증: 방 생성 안 됨(레코드 없음)
  - **대조군**: 동일 계정이 기본제공 캐릭터(F00, 가격 0)로는 정상 생성됨(HTTP 201, wr_4) — 정당한 사용은 차단하지 않음을 확인

### [7] 후기 삭제 후 재작성으로 보상 중복 지급 방지
- **대상 API**: POST /api/public/wishroom/wish-rooms/{id}/review → DELETE /api/public/wishroom/reviews/{id} → POST (재작성)
- **시나리오**: 계정B가 ACHIEVED 상태 소원방(wr_5)에 1차 후기 작성(리워드 수령) → 후기 삭제(soft delete) → 동일 방에 2차 후기 재작성 시도
- **결과**: **통과**
  - 1차 작성: HTTP 201, reward={base:30, photo:0}, 잔액 1000→1030
  - 삭제: HTTP 200, deletedAt 설정(soft delete), 잔액 변동없음(1030 유지, 설계상 삭제 시 환수 안 함)
  - 2차 작성(재작성): HTTP 201, **reward=null**(리워드 미지급)
  - DB 검증: 잔액 1030 유지(1060으로 증가하지 않음 = 중복지급 없음)
  - wish_rooms.review_reward_granted 플래그가 방 단위로 유지되어 재작성을 차단
  - point_histories의 wishroom_review 소스 레코드는 최초 1건(id=1281)만 존재

## 2. 테스트 중 발견된 참고사항 (버그 아님, 설계 확인)

- 테스트1을 계정A에서 처음 시도했을 때, 이전 테스트로 이미 LIFE_000 캐시/거래가 존재하는 오염된 DB 상태에서 실행하여 "정상사용" 대신 "캐시+자동환불" 경로로 빠진 적이 있었음. 이는 버그가 아니라 테스트4가 검증하려는 priorSuccess 방어 로직이 의도대로 작동한 결과였으나, 테스트1 자체는 깨끗한 상태에서 재실행하여 별도로 확정함(본 보고서의 결과가 최종).
- 테스트7 최초 시도 시 계정A의 일일 복주머니 적립 상한(80/일)이 이전 테스트(환불 300 복구)로 소진되어 리워드가 0으로 처리됨 — 보안 로직 결함이 아니라 테스트 환경 상태(point_histories가 append-only라 삭제 불가) 문제로 확인, 계정B로 전환하여 깨끗한 상태에서 재검증 완료.

## 3. 결론

7개 필수 보안 시나리오 **전부 독립적으로 재현·검증 완료**(응답 코드, DB 거래상태, 잔액 변동까지 확인). 직전 턴의 구버전 서버 기반 결과는 전량 폐기되었으며, 본 보고서가 유일한 유효 결과임.
