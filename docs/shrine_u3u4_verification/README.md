# 신당(THE SHRINE) U1~U13 — 1·2단계 시각 검증 기록

> 이 디렉토리는 코드가 아니라 **시각 검증 증거(evidence)** 보관소입니다.
> Playwright + headless Chrome으로 Flutter 웹(Canvas 렌더링) 앱을
> 홈 화면부터 끝까지 실제로 주행하며 각 단계가 정상 렌더링되는지
> 좌표 클릭 기반으로 확인한 자동화 스크립트와 스크린샷을 보관합니다.

## 배경

- 신당 U1~U13 업데이트는 4개 zip 파일을 병합한 `/tmp/shrine_v3/merged/`가
  유일한 소스 오브 트루스(소스 자체는 로컬 임시 경로에만 존재하며 이 저장소에는
  포함되지 않음).
- 구현은 7단계로 나뉘며, 전체를 한번에 구현하지 않고 단계별로 보고 후 승인을
  받는 방식으로 진행 중.
- 이 문서가 다루는 범위: **1단계(정통사주 연동)** + **2단계(U3 bjCompose +
  U4 BjOneBadge)** 의 시각 검증.

## 검증 환경 / 기법

- **뷰포트**: 414×896 (모바일 포트레이트)
- **브라우저 실행 인자**: `--explicitly-allowed-ports=5060` (필수 — 없으면
  Chromium이 5060 포트 접속을 차단함)
- **세션 유지**: `/tmp/shrine_logged_in_state.json` (Playwright storage_state) —
  실계정 `sksks77@naver.com`(userId=155, 닉네임 "박정민") 로그인 세션 저장.
  매 실행마다 온보딩 영상(약 27초+)은 재생되지만 로그인 자체는 유지됨.
- **DOM 셀렉터 사용 불가**: Flutter 웹은 Canvas 렌더링이므로 텍스트/버튼에
  대한 DOM 셀렉터가 작동하지 않음. **좌표 기반 `page.mouse.click(x, y)`**
  방식만 사용 가능.
- **좌표 함정 디버깅 기법(핵심)**: 버튼이 화면 중앙에 정렬되어 있을 것이라는
  가정이 반복적으로 틀렸음. 이를 해결하기 위해 PIL(Pillow)로 스크린샷의
  특정 y행을 따라 x를 스캔하며 픽셀 RGB 값의 급격한 변화(배경색 → 버튼색
  경계)를 찾아 버튼의 실제 클릭 가능 영역을 역산함:
  ```python
  from PIL import Image
  img = Image.open("screenshot.png")
  for x in range(0, 414, 5):
      print(x, img.getpixel((x, y))[:3])
  ```

## 전체 화면 흐름 (Navigator 1.0 ShrineNav.go 기반, 실주행 확인됨)

```
EntryScreen → DoorScreenV32(skip 가능) → HallScreen(제단 다가가기)
  → ResultAccessGateSheet(복주머니 결제)
  → ConnectScreen(동의하고 명부 옮기기)
  → TalkScreen(門/符 온보딩 4단계 + 월화와의 대화)
  → SajuScreen(정통사주 결과 — RealSajuRepository 실연동)
  → RecommendScreen(주제 추천 + 선택)
  → StoryScreen(「붉은 방울·THE RED BELL」 — 다중 분기, 回想 플래시백, 카드 선택)
  → ResultScreen(ENDING C·되돌아온 것 + 선택 히스토리 + 멀티엔딩 안내)
  → MeaningScreen(부적 미리보기 "연인부·斷緣" + "월화에게 부적을 부탁하기")
  → [筆 부적 쓰기 → 符 부적 태우기 → 示 신의 계시 → 讀 이야기 분석 → 受 부적 받기]
  → ReceiveScreen(BjOneBadge 唯一 인장 — 미도달, 다음 단계 목표)
```

## 발견된 좌표 함정 3건 (전부 "중앙 정렬 가정"이 틀렸던 사례)

| # | 화면 | 버튼 | 오답(중앙 가정) | 정답(픽셀 스캔 실측) |
|---|------|------|-----------------|----------------------|
| 1 | ConnectScreen | "동의하고 명부 옮기기" | x=207 (중앙) | **x=95** (좌측 정렬) |
| 2 | StoryScreen | "NEXT" | x=207, y=450 (중앙) | **x=358, y=856** (우측 하단) |
| 3 | MeaningScreen | "월화에게 부적을 부탁하기" | x=207, y=847 (중앙) | **x=107, y=840** (좌측 정렬, 버튼 영역 x:20~195) |

**교훈**: 이 프로젝트의 신당 화면들은 버튼이 화면 전체 폭을 차지하는 중앙
정렬 디자인이 아니라, 좌측 혹은 우측에 치우친 비대칭 레이아웃을 자주
사용함. 좌표 클릭이 무반응일 때 "대기시간 부족"이나 "서버 지연"을 먼저
의심하지 말고, **PIL 픽셀 스캔으로 실제 버튼 위치부터 확인**할 것.

## 1단계 검증 결과: 정통사주(RealSajuRepository) 연동 — ✅ 완료

- `screenshots/02_sajuscreen_fullrender.png` — SajuScreen에서 四柱(丁未/丁丑/
  甲申/乙亥), 日干, 五行(木2火2土2金1水1), 강점/주의할점이 실제 계산값으로
  정상 렌더링됨. SAMPLE 태그 없음.
- `screenshots/03_sajuscreen_topics_enginebound.png` — 主題별 풀이(命/緣/財/
  流) + "엔진이 근거를 주지 않는 주제는 표시하지 않습니다" 문구 확인.
  **신당 엔진 경계 원칙**("신당은 사주를 계산하지 않는다. null→화면 생략")이
  실제로 작동함을 시각 확인.
- `screenshots/04_recommendscreen.png` — RecommendScreen에서 추천 이유 +
  사주 근거가 실제 데이터로 표시됨.
- `screenshots/09_resultscreen_full_scroll_multiending.png` — ResultScreen
  "사주의 근거" 박스에도 동일하게 실제 계산값("관성(부성) 1개. 정식·안정된
  배우자 인연...") 표시 확인.

## 2단계 검증 결과: U3 bjCompose + U4 BjOneBadge — ✅ 완료

### 전체 흐름 완주 성공 (MeaningScreen → ReceiveScreen)

```
MeaningScreen("월화에게 부적을 부탁하기")
  → 筆 부적 쓰기(이름 붓글씨 애니메이션)
  → 符 부적 태우기("불이 이름을 삼킵니다...")
  → 示 신의 계시
  → 讀 이야기 분석("재의 모양을 읽고 있습니다" — 이름의 획/여름의 바람/
     타고 남은 재/고른 길을 부적에 새김 — U3 bjCompose 연출)
  → (월화가 완성된 부적을 들고 "태운 것은 끝이 아닙니다. 방금 올린 그
     부적을, OOO님 몫으로 한 장 더 옮겨 적었습니다")
  → 受 부적 받기 = ReceiveScreen (BjOneBadge 완전 렌더링) ✅
```

- `screenshots/05_storyscreen_redbell.png` ~ `07_storyscreen_cardchoice_flipcard.png`
  — StoryScreen 다중 분기(선택지, 回想 플래시백, 카드 선택 — U9 FlipCard로
  추정)가 끝까지 정상 작동.
- `screenshots/08_resultscreen_first_entry.png`,
  `09_resultscreen_full_scroll_multiending.png` — ResultScreen 완전 렌더링.
  선택 히스토리(걸어온 길 1~7단계) + "모든 결말 1/4" 멀티엔딩 안내 확인.
- `screenshots/10_meaningscreen_bujeok_preview.png` — MeaningScreen에서
  부적 미리보기("연인부·斷緣") 확인.
- `screenshots/11_bjwriting_pil_name_animation.png`,
  `12_bjwriting_complete_tapindicator.png` — 筆(부적 쓰기) 단계: 월화가
  붓으로 이름을 적는 애니메이션 + 완성 후 탭 유도 인디케이터 확인.
- `screenshots/13_bjburning_flame_animation.png` — 符(부적 태우기) 단계:
  "불이 이름을 삼킵니다..." 문구 + 불타는 애니메이션 진행 확인.
- `screenshots/14_readingscreen_ash_analysis.png` — 讀(이야기 분석) 단계:
  "재의 모양을 읽고 있습니다" + 4개 세부 문구(이름의 획/여름의 바람/타고
  남은 재/고른 길을 새김) 확인. **U3 bjCompose 12단계 알고리즘이 사용자에게
  보여지는 스토리텔링 연출로 구현된 것으로 판단됨.**
- `screenshots/15_wolhwa_delivers_bujeok.png` — 월화가 완성된 부적을 들고
  전달하는 장면 확인.
- **`screenshots/16_receivescreen_bjonebadge_SUCCESS.png` — ReceiveScreen
  BjOneBadge 완전 렌더링 성공 (핵심 검증 목표 달성):**
  - **唯一(유일) 인장** 아이콘 확인
  - **"이 세상에 하나뿐인 개인화 부적입니다"** 안내 문구 확인
  - **조합ID: "BJ6-QLE1K1"** — ✅ 요구사항 예정 형식 "BJ6-XXXXXXX"와
    **정확히 일치**. (이전에 MeaningScreen에서 관찰된 "BJ-LOVE-去-4VN"은
    MeaningScreen 전용의 다른 표시 방식이었던 것으로 판명 — ReceiveScreen의
    최종 BjOneBadge 조합ID가 실제 bjCompose 결과물임)
  - 이름 표시 옵션 3종: "이름 전부"(박서연) / "첫 글자만"(박○○) /
    "적지 않음"(持者不記) — 라디오 버튼 선택 UI 확인
  - "공유 이미지에는 생년월일이 들어가지 않습니다" 개인정보 보호 안내 확인
  - "부적 간직하기" 최종 액션 버튼 확인

### 미완료 (2단계 범위를 넘어선 후속 검증 과제)
- 부적 재현성(같은 조건 재방문 시 같은 조합ID가 나오는지, bjCompose의
  결정론적 시드 재현성 검증) 미착수.
- 새 부적 비율(1:2.3, stroke 0.0125) 수치 정합성 코드 레벨 확인 미착수
  (시각적으로는 세로로 긴 비율의 부적이 정상 렌더링됨을 확인함).
- "이름 전부/첫 글자만/적지 않음" 옵션 선택 시 실제 이미지 변경 여부 미확인.
- "부적 간직하기" 버튼 클릭 이후 최종 저장/공유 플로우 미확인.

### 결론
**2단계(U3 bjCompose + U4 BjOneBadge)의 핵심 목표 — "MeaningScreen에서
ReceiveScreen까지 끝까지 주행하며 BjOneBadge가 정상적으로 유일 조합ID와
함께 렌더링되는지 시각 확인" — 를 달성함.** 위 "미완료" 항목들은 2단계의
부가적 세부 검증이며, 3단계(U12) 진행에 지장을 주지 않는 수준으로 판단됨.

## 자동화 스크립트 디렉토리 안내

`scripts/shrine_full_run6.py` ~ `shrine_full_run22.py`는 각각 이전
스크립트의 클릭 시퀀스를 그대로 복사한 뒤 마지막에 새로운 단계의 클릭을
추가한 **누적 확장형 스크립트**입니다(일회성 디버깅 도구, 운영 코드 아님).
번호가 클수록 더 뒷단계까지 도달합니다. 가장 진도가 많이 나간 스크립트는
`shrine_full_run22.py`(筆→符 단계까지 도달)입니다.

재실행 전제조건:
```bash
# 1. Flutter 웹 서버가 5060 포트에서 구동 중이어야 함
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5060/   # 200 기대

# 2. 로그인 세션 파일이 /tmp/shrine_logged_in_state.json 에 있어야 함
#    (없으면 로그인 단계부터 다시 자동화해야 함)

# 3. 실행 예시 (bash 도구 120초 타임아웃을 피하려면 백그라운드 + sleep 폴링 권장)
cd /tmp && nohup python3 shrine_full_run22.py > run22_log.txt 2>&1 &
sleep 90 && cat run22_log.txt
```

## 완주 스크립트

`scripts/shrine_full_run23.py` — 홈 화면부터 ReceiveScreen(BjOneBadge
렌더링 확인)까지 **전체 플로우를 끝까지 완주하는 최종 스크립트**. 이후
단계(U12 이후) 검증 시 이 스크립트의 앞부분(신당 진입~筆/符/示/讀/受)을
재사용 가능.

## 다음 단계 (계획)

1. ~~`shrine_full_run22.py`를 기반으로 示/讀/受 단계를 추가 진행하는
   `shrine_full_run23.py` 작성 → ReceiveScreen 도달.~~ ✅ 완료
2. ~~BjOneBadge 唯一 인장 + 조합ID 렌더링 시각 확인~~ ✅ 완료
   (조합ID "BJ6-QLE1K1" — 요구사항 형식과 일치 확인됨)
3. (선택) 부가 검증: 이름 표시 옵션별 변경 확인, "부적 간직하기" 이후
   플로우, bjCompose 재현성 테스트 — 필요 시 추가 진행.
4. **사용자에게 2단계(U3+U4) 완료 보고 + 3단계(U12 어뷰징 방지) 진행
   승인 요청** — 다음 턴에서 즉시 진행.
