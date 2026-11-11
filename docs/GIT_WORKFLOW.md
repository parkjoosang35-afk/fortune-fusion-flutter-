# 작업 규칙서 (GIT_WORKFLOW)

> 이 문서는 **여러 작업실(샌드박스/코드방)에서 동시에 같은 저장소를 개발할 때** 지켜야 할 규칙입니다.
> AI 어시스턴트든 사람이든, 이 저장소에서 작업하기 전에 **반드시 이 문서를 먼저 읽고** 그대로 따릅니다.

---

## 0. 한눈에 보는 3원칙

1. **작업 시작 전엔 항상 `git pull origin main`** — 이걸 빼먹으면 충돌의 90%가 발생한다.
2. **`main`에 직접 push 하지 않는다** — 항상 `feature/*` 또는 `fix/*` 브랜치를 파서 작업한다.
3. **`git push --force`(강제 푸시)는 절대 금지** — 상대 작업실의 커밋이 통째로 사라진다.

---

## 1. 저장소 구조 이해

```
GitHub (parkjoosang35-afk/fortune-fusion-flutter-)  ← 진짜 원본(공통)
    ↑ pull / push
    ├── 코드방 샌드박스 (주력 개발)
    └── 이 방 샌드박스   (검토 / 버그수정 / APK 빌드)
```

- 두 작업실 사이에 **자동 동기화는 없다.** 오직 `pull` / `push` 로만 주고받는다.
- 따라서 **다른 작업실이 무엇을 했는지 알 수 없다.** 항상 `pull` 로 확인해야 한다.

---

## 2. 브랜치 이름 규칙

형식: `종류/짧은-설명` (소문자, 하이픈 사용, 한글 가능하나 영문 권장)

| 종류 | 언제 쓰나 | 예시 |
|---|---|---|
| `feature/` | 새 기능 개발 | `feature/lucky-number-video` |
| `fix/` | 버그 수정 | `fix/tarot-back-image` |
| `refactor/` | 동작 변화 없는 구조 개선 | `refactor/fortune-provider-split` |
| `chore/` | 설정·의존성·문서 | `chore/update-deps` |
| `hotfix/` | 긴급 수정 (배포 직후 치명 버그) | `hotfix/login-crash` |

**규칙**
- 브랜치는 **작업 하나당 하나**. 여러 기능을 한 브랜치에 섞지 않는다.
- 이름에 공백·대문자·언더스코어 금지. (`feature/My Fix` ❌ → `feature/my-fix` ✅)
- 이미 존재하는 이름은 재사용하지 않는다. `git branch -a` 로 먼저 확인.

---

## 3. 표준 작업 절차 (5단계)

```bash
# ── 1단계: 최신 상태 받기 (필수! 생략 금지) ──
cd /home/user/flutter_app
git pull origin main

# ── 2단계: 내 작업실(브랜치) 만들고 들어가기 ──
git checkout -b feature/작업이름

# ── 3단계: 작업 수행 ──
#   - 코드 수정, 파일 추가 등
#   - 작업 중에도 커밋은 잘게 나눠도 됨 (3단계 중간 커밋 허용)

# ── 4단계: 검증 (아래 5번 항목 참고) ──
flutter analyze
flutter build web --release     # 웹 빌드 확인

# ── 5단계: 올리기 ──
git add .
git commit -m "변경 요약 (한국어 가능, 50자 내외)"
git push -u origin feature/작업이름   # ← main이 아니라 내 브랜치!
```

이후 **GitHub 웹에서 PR(Pull Request) 생성** → 확인 → `Merge`.

---

## 4. 금지 사항 (어기면 작업 손실)

| 금지 | 이유 | 대신 이렇게 |
|---|---|---|
| `git push -f` / `--force` | 상대 작업실 커밋이 사라짐 | 일반 `git push`. 거부되면 pull 후 재시도 |
| `main` 에 직접 commit + push | 모든 작업실의 기준이 흔들림 | `feature/*` 브랜치 → PR |
| `git pull` 없이 작업 시작 | 상대 변경분을 덮어씀 | **항상** 먼저 pull |
| `git reset --hard` (공용 브랜치에서) | 상대 커밋 유실 | `git revert` 사용 |
| `.dart_tool/`, `build/`, `*.log` 커밋 | 저장소 오염 | `.gitignore` 이미 처리됨. 실수 시 커밋 취소 |
| `android/app/build.gradle*` 의 `applicationId` 변경 | Firebase/패키지 불일치 유발 | 변경 필요하면 **단독 브랜치 + 별도 PR** |
| `pubspec.lock` 임의 수정 | 의존성 불일치 → 빌드 실패 | 버전 변경 시 `flutter pub get` 결과만 커밋 |

---

## 5. 검증 기준 (push 전 필수)

```bash
flutter analyze                    # 에러 0 이어야 함 (info/warning 은 허용)
flutter build web --release        # 성공해야 함
```

- `error` 가 하나라도 있으면 **push 하지 않는다.**
- `warning`/`info` 는 허용하되, 새로 늘리지 않도록 노력한다.
- UI 변경 시 **웹 프리뷰에서 실제 확인** 후 push.
- APK/AAB 빌드는 별도 확인 후 진행.

---

## 6. 동시 작업 시 구역 나누기 (충돌 예방)

같은 파일을 양쪽에서 동시에 고치면 반드시 충돌한다. 아래처럼 **주로 건드리는 파일**을 분리한다.

| 파일/영역 | 주의도 | 권장 |
|---|---|---|
| `pubspec.yaml`, `pubspec.lock` | 🔴 매우 높음 | 동시 수정 금지. 한쪽만 |
| `lib/main.dart`, `lib/app.dart` | 🔴 매우 높음 | 동시 수정 금지 |
| `lib/core/router/app_router.dart` | 🔴 높음 | 새 화면 등록은 단독 PR로 |
| `lib/core/theme/*` | 🟡 중간 | 디자인 변경은 한쪽에서만 |
| `lib/features/각-기능/*` | 🟢 낮음 | **기능 단위로 나누면 충돌 거의 없음** |
| `assets/**` | 🟢 낮음 | 파일 추가는 안전, 같은 파일 교체는 주의 |

**원칙: 기능 폴더(`lib/features/xxx/`) 단위로 작업을 나누면 서로 부딪히지 않는다.**

---

## 7. 충돌(Conflict) 발생 시 대처

### 증상
`git push` 또는 `git pull` 시 아래 같은 메시지

```
CONFLICT (content): Merge conflict in lib/features/xxx/yyy.dart
Automatic merge failed; fix conflicts and then commit the result.
```

### 대처 순서

```bash
# 1) 현재 상태 확인
git status                      # 충돌 파일 목록(빨간색) 확인
git diff                        # 무엇이 충돌했는지 확인

# 2) 충돌 파일을 열어 아래 표시를 찾는다
<<<<<<< HEAD
  내 쪽 내용
=======
  상대 쪽 내용
>>>>>>> origin/main

# 3) 둘 다 살릴지, 한쪽만 쓸지 결정해서 표시를 지우고 최종 코드만 남긴다
#    (표시줄 <<<<<<<, =======, >>>>>>> 를 모두 제거해야 함)

# 4) 해결 후
flutter analyze                 # 문법 오류 없는지 확인
git add .
git commit -m "merge: main 병합 및 충돌 해결"
git push -u origin feature/작업이름
```

### 판단이 어려울 때 (안전 우선)

```bash
git merge --abort               # 병합 자체를 취소하고 원래대로 되돌림
```

→ 그다음 **상대 작업실 담당자(사람)에게 확인 요청.** 절대 감으로 덮어쓰지 않는다.

### 절대 하면 안 되는 것
```bash
git checkout --theirs .         # ❌ 내 작업 전부 날아감
git checkout --ours .           # ❌ 상대 작업 전부 무시
git reset --hard origin/main    # ❌ 내 커밋 전부 소실
```

---

## 8. PR(Pull Request) 절차

1. `git push -u origin feature/작업이름` 완료
2. GitHub 저장소 접속 → **"Compare & pull request"** 버튼 클릭
3. 입력:
   - **Title**: 무엇을 했는지 한 줄 (예: `타로 카드 뒷면 이미지 누락 수정`)
   - **Description**: ① 왜 ② 무엇을 ③ 어떻게 확인했는지
4. **Files changed** 탭에서 바뀐 내용을 확인 (문제 없으면)
5. **Merge pull request** → **Confirm merge**
6. 머지 후 브랜치 삭제 (GitHub가 제안하는 **Delete branch** 클릭)

> **규칙: PR은 만든 사람이 아니라 "다른 쪽"이 확인 후 머지하는 것을 권장.** (혼자 쓰면 본인이 머지해도 무방)

---

## 9. 작업 보고 형식 (다른 작업실에 알릴 때)

작업 완료 후 상대 작업실(또는 사람)에게 아래 형식으로 보고한다.

```
■ 브랜치: feature/tarot-back-image
■ 작업 내용: 타로 카드 뒷면 이미지 파일 누락 수정
■ 변경 파일:
  - assets/tarot/backs/back_default.webp (추가)
  - pubspec.yaml (주석 정리)
■ 검증: flutter analyze 에러 0 / flutter build web 성공
■ PR: #12 (머지 대기)
```

---

## 10. AI 어시스턴트에게 지시하는 방법

이 저장소에서 AI에게 작업을 시킬 때는 **아래 한 줄이면 충분하다.**

```
docs/GIT_WORKFLOW.md 규칙대로 브랜치 파서 작업하고 push해줘.
작업 내용: 【하고 싶은 일 설명】
```

AI는 이 문서를 읽고 다음을 자동으로 수행해야 한다:

1. `git pull origin main`
2. `git checkout -b {종류}/{설명}`
3. 작업 수행
4. `flutter analyze` + `flutter build web --release` 검증
5. `git add` → `git commit` → `git push -u origin {브랜치}`
6. **main에 직접 push 하지 않고** 브랜치 이름과 변경 파일 목록을 보고

---

## 11. 자주 쓰는 명령 모음

```bash
# 현재 상태 파악
git status                       # 변경/충돌 파일
git branch -a                    # 로컬+원격 브랜치 목록
git log --oneline -10            # 최근 커밋 10개
git log --oneline --graph --all  # 브랜치 그래프

# 최신 받기
git pull origin main
git fetch origin                 # 받기만 하고 병합은 안 함

# 브랜치 이동/정리
git checkout main
git checkout -b fix/새작업
git branch -D feature/버린작업   # 로컬 브랜치 삭제
git push origin --delete feature/버린작업  # 원격 브랜치 삭제

# 되돌리기 (안전한 방법)
git revert <커밋해시>            # 해당 커밋을 취소하는 새 커밋 생성 (권장)
git stash                        # 작업 임시 저장 (브랜치 전환 전)
git stash pop                    # 임시 저장 복원
```

---

## 12. 요약 카드

> **① pull → ② 브랜치 → ③ 작업 → ④ analyze/build → ⑤ push(브랜치로) → ⑥ PR → ⑦ merge**
>
> **main 직접 push 금지 / force push 금지 / pull 생략 금지**
>
> 지시는 한 줄: `docs/GIT_WORKFLOW.md 규칙대로 브랜치 파서 작업하고 push해줘. 작업 내용: ______`
