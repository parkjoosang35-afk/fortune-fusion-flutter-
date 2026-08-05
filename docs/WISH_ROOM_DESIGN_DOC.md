# 신통방통 — 개인 소원방(Wish Room) 개발 킥오프 문서

> 본 문서는 "아이디어 제안"이 아니라 **실제 구현된 코드베이스**(`lib/features/wish_room/`)를 기준으로 작성된
> 개발 킥오프 문서다. 여기 기술된 시스템/화면/정책/데이터모델/코드는 전부 이미 Flutter 3.35.4 + Riverpod
> 2.6.1 위에서 동작하며, `flutter analyze` 0 error / `flutter test` 전체 통과 / `flutter build web --release`
> 성공 상태로 검증되어 있다. 즉 이 문서의 코드 섹션은 "샘플"이 아니라 저장소에 실재하는 파일의 발췌다.

**문서 상태**: 최종안(v1.0) · **작성 기준 커밋 상태**: uncommitted 작업분 포함 최신 소스 · **대상 플랫폼**: Android + Web(프리뷰)

---

## ① 서비스 한줄정의

> **"매일 촛불 제단에 정성을 담아 나의 소원을 키우는, 신통방통 앱 안의 조용한 개인 의식(ritual) 공간."**

소원방은 신통방통의 87개 운세 카테고리 시스템과 독립적으로 동작하는 **개인 소유 소원 공간**이다. 사용자는
최대 3개의 소원(대표 1 + 서브 2)을 촛불 제단 위에 올려두고, 매일 무료 치성(daily) 또는 복주머니를 소비하는
깊은/집중 치성(deep/focused)으로 정성을 쌓는다. 정성이 쌓일수록 소원은 **불씨 → 작은 촛불 → 안정된 촛불 →
환한 촛불 → 황금 성화**의 5단계로 성장하며, 방 전체도 연속 방문일수에 따라 **씨앗 → 발광 → 개화 → 광휘**의
앰비언트 후광을 얻는다. 이 두 겹의 성장 축이 "정적 카드 묶음"이 아니라 "살아 움직이는 방"이라는 체감을
만들어내는 핵심 장치다.

---

## ② 타겟 사용자 및 핵심 가치제안

| 항목 | 내용 |
|---|---|
| 타겟 사용자 | 신통방통 앱의 기존 운세 이용자 중, 단발성 운세 소비를 넘어 **반복적 의식 행위**에 몰입하고 싶은 사용자 |
| 핵심 가치제안 | "오늘의 운세를 보고 끝나는 게 아니라, 내가 키우는 소원이 매일 조금씩 자라는 걸 본다" |
| 재방문 트리거 | 매일 1회 무료 치성(daily) → 연속 방문일수 스트릭 → 슬롯 해금/성장 단계 보상의 3단 재방문 후크 |
| 수익 연결점 | 복주머니(재화) 소비처로서 기능 — 기존 EARN 경로(출석/광고)와 소원방의 SPEND 경로가 하나의 재화 경제로 연결 |
| 톤앤매너 | 밤하늘·촛불·금빛의 조용하고 경건한 다크 테마(앱 전역 라이트 골드/바이올렛 테마와 의도적으로 분리) |

**답변 규칙 준수 선언**: 이하 모든 섹션은 질문 없이 합리적 기본값으로 확정하며, 애매한 대안 나열 대신 단정적으로
하나의 설계를 채택한다. 채택하지 않은 대안은 "⑳ 리스크와 트레이드오프" 섹션에서만 간략히 언급한다.

---

## ③ 메인 오브제 컨셉 — 촛불 제단 (강한 권장안 채택)

**결론: 메인 오브제는 "촛불 제단(Candle Altar)"으로 확정한다.** 화분/수정구/나무 등 대안을 검토했으나
아래 이유로 촛불 제단을 채택했다:

1. **성장 은유의 자연스러움**: 불씨(ember) → 촛불 → 성화(flame)는 "정성이 쌓여 빛이 커진다"는 직관을
   추가 설명 없이 전달한다. 화분(성장=크기)보다 색온도/밝기 변화가 애니메이션적으로 훨씬 풍부하다.
2. **한국 전통 기도 문화와의 정합성**: 사찰/제단에 촛불을 올리는 행위는 "소원을 빈다"는 행위와 문화적으로
   이미 강하게 연결되어 있어 튜토리얼 부담이 낮다.
3. **다층 시각화 여지**: 방 전체 후광(연속방문 기반, `WishObjectLevel` 4단계)과 개별 소원 색조/이모지
   (정성누적 기반, `WishGrowthStage` 5단계)를 하나의 오브제 위에 **크기(후광 확산)** 와 **색조/중심 이모지**
   라는 서로 다른 시각 채널로 동시에 표현할 수 있다 — 이는 실제로 `WishRoomObject` 위젯에서 구현되어 있다
   (④ 소원 성장 시스템, ⑫-② 화면 스펙에서 상세 설명).
4. **꾸미기 시스템과의 확장성**: `CustomizeCategory.objectSkin`(오브제 스킨)·`altar`(제단)·`effect`(치성
   이펙트)가 촛불이라는 단일 은유 아래 자연스럽게 계층화된다(연꽃 촛대, 나무/대리석 제단, 금빛 파동 등).

**구현 위치**: `lib/features/wish_room/presentation/widgets/wish_room_object.dart` — `RepaintBoundary` +
`AnimationController(repeat: reverse)` 기반의 "숨쉬는 촛불" 애니메이션이 항상 재생 중이며, 터치 시 순간
확대(`_touchBoost`)와 글로우 강화가 추가된다. **정적 카드 묶음 금지 요구사항은 이 오브제의 상시 애니메이션으로
충족한다** — 사용자가 아무것도 하지 않아도 화면 진입 즉시 오브제가 3초 주기로 숨쉬듯 움직인다.

---

## ④ 필수 핵심 재미 5가지 설계

사용자가 요구한 5대 핵심 재미를 실제 구현 시스템과 1:1로 매핑한다.

| # | 핵심 재미 | 구현 시스템 | 체감 순간 |
|---|---|---|---|
| 1 | **소원성장** | ⑥ 소원성장시스템(`WishGrowthStage`, 개별 소원) | 치성 직후 `GrowthProgressCard`의 진행률 바가 500ms에 걸쳐 부드럽게 늘어남 |
| 2 | **치성액션** | ⑦ 치성시스템(`PrayerType`, `PrayerTypeSheet`) | 오브제 터치 → 치성 종류 선택 → 글로우 확산 애니메이션(`PrayerCompleteSheet`) |
| 3 | **복주머니 적립/사용** | ⑧ 복주머니시스템(`FortunePouchStatus`) | 깊은/집중 치성 선택 시 카드에 "+성장치" 즉시 프리뷰, 부족 시 비활성화(opacity 0.45) 처리 |
| 4 | **꾸미기** | ⑨ 꾸미기시스템(`CustomizeItem`, `WishCustomizeScreen`) | 카테고리 탭 전환 애니메이션 + 적용 시 오브제 테두리 골드 하이라이트(2px border) |
| 5 | **재방문** | ⑩ 재방문시스템(연속방문일수, `WishObjectLevel`) | 연속 3일/7일/14일마다 오브제 크기(+12px씩)와 배경 반짝임 개수가 물리적으로 커짐 |

이 5가지는 서로 독립된 화면이 아니라 **하나의 치성 행위(치성 버튼 탭)** 안에서 동시에 발생하도록 설계했다
— 이것이 "정적 카드묶음이 아니라 확실히 움직이는 UI"라는 요구사항의 핵심 해법이다. 상세 흐름은 ⑫-④
치성 화면 스펙 참고.


---

## ⑤ 필수 시스템 ① — 대표소원슬롯시스템

**설계 원칙**: 슬롯은 "소원을 담을 수 있는 자리"이고 소원(`WishItem`)은 "그 자리에 놓인 실제 데이터"다.
슬롯 목록을 별도 테이블/리스트로 저장하지 않고, `wishes` + `unlockedSubSlotCount`로부터 **매번 파생 계산**한다
(`WishRoom.slotStatuses` getter). 이는 슬롯 상태와 소원 데이터 간 정합성 버그(예: 슬롯은 열렸는데 소원이
중복 등록되는 등)를 구조적으로 차단한다.

### 슬롯 구조
- 총 3슬롯 고정: 인덱스 0 = **대표 슬롯**(항상 존재, 잠금 불가), 인덱스 1~2 = **서브 슬롯**(초기 잠김)
- `WishSlotStatus` enum 4가지: `representative` / `subFilled` / `subEmpty` / `locked`
- 대표 소원은 `WishItem.isRepresentative == true`인 소원 1개(`WishRoom.representativeWish`)
- 대표 소원이 **메인 오브제의 성장 단계·색조를 결정**하는 유일한 데이터 소스다(④ 참고)

### 해금 조건 (정책표 ①)
| 슬롯 | 해금 조건 A(무료) | 해금 조건 B(즉시) |
|---|---|---|
| 서브 슬롯 1번 | 연속 방문 3일 | 복주머니 30개 |
| 서브 슬롯 2번 | 연속 방문 7일 | 복주머니 30개 |

`canUnlockSlotByStreakProvider`(Riverpod Provider)가 `unlockedSubSlotCount`와 `consecutivePrayerDays`를
조합해 무료 해금 가능 여부를 실시간 계산한다.

```dart
// lib/features/wish_room/presentation/providers/wish_room_providers.dart
final canUnlockSlotByStreakProvider = Provider<bool>((ref) {
  final data = ref.watch(wishRoomControllerProvider).valueOrNull;
  if (data == null) return false;
  final room = data.room;
  if (room.unlockedSubSlotCount >= 2) return false;
  final requiredStreak = room.unlockedSubSlotCount == 0 ? 3 : 7;
  return room.consecutivePrayerDays >= requiredStreak;
});
```

### 슬롯 없을 때의 등록 차단 정책
새 소원 등록(`WishWriteScreen` 진입)은 `hasAvailableSlot == false`이면 **작성 화면 대신 슬롯 확장 화면으로
강제 리다이렉트**한다(`WishRoomScreen._openWriteScreen`). 이는 "슬롯 없이 등록 자체가 불가능해야 한다"는
정책을 UI 진입 단계에서 원천 차단하는 방식으로, Repository/Controller 단에서도 이중 방어한다
(`WishRoomController.addWish`가 `hasAvailableSlot` 재확인 후 조용히 반환).

---

## ⑥ 필수 시스템 ② — 소원성장시스템 (개별 소원 단위)

**두 개의 축이 존재함을 명확히 구분한다** — 이는 문서/코드 전체에서 가장 자주 혼동되는 지점이므로 반복 강조한다:

| 축 | 담당 enum | 단위 | 트리거 | 시각 채널 |
|---|---|---|---|---|
| **소원 성장 축** | `WishGrowthStage` (5단계) | 개별 소원(`WishItem`) | 정성 누적치(`growthPoint`) | 오브제 색조/그라디언트/중심 이모지 |
| **방 앰비언트 축** | `WishObjectLevel` (4단계) | 방 전체(`WishRoom`) | 연속 방문일수 | 오브제 크기 + 배경 반짝임 개수 |

두 축은 절대 하나로 합치지 않는다 — "오늘 방문만 했지 정성을 안 쌓은 사용자"와 "정성은 많이 쌓았지만 오늘은
안 온 사용자"를 서로 다른 시각 신호로 구분해야 하기 때문이다.

### 소원 성장 단계 정의(정책표 ⑥ 기준값)

| 단계 | 라벨 | 진입 임계값(growthPoint) | 색상 톤 | 이모지 |
|---|---|---|---|---|
| ember | 불씨 | 0 | `#E8875A`(붉은 불씨) | 🕯️ |
| smallCandle | 작은 촛불 | 20 | `#F0A85E` | 🕯️ |
| steadyCandle | 안정된 촛불 | 60 | `#F4C560`(= gold) | 🔥 |
| brightCandle | 환한 촛불 | 120 | `#FAD98A` | 🔥 |
| goldenFlame | 황금 성화 | 250 | `#FFF3D0` | ✨ |

`growthPoint`는 **상한 없이 무제한 누적**된다(goldenFlame 도달 후에도 계속 증가) — 향후 시즌 보상/특별
연출 트리거로 재사용 가능하도록 의도적으로 캡을 두지 않았다.

### 코드: 성장 단계 파생 로직 (실제 구현, 발췌 없음 — 전문)
```dart
// lib/features/wish_room/data/models/wish_item_model.dart
enum WishGrowthStage { ember, smallCandle, steadyCandle, brightCandle, goldenFlame }

extension WishGrowthStageX on WishGrowthStage {
  static WishGrowthStage fromGrowthPoint(int point) {
    if (point >= 250) return WishGrowthStage.goldenFlame;
    if (point >= 120) return WishGrowthStage.brightCandle;
    if (point >= 60) return WishGrowthStage.steadyCandle;
    if (point >= 20) return WishGrowthStage.smallCandle;
    return WishGrowthStage.ember;
  }

  int? get nextThreshold { /* ember:20, smallCandle:60, steadyCandle:120, brightCandle:250, goldenFlame:null */ }
  int get currentThreshold { /* 0, 20, 60, 120, 250 */ }
}

class WishItem {
  final int growthPoint; // 0에서 시작, 무제한 누적

  WishGrowthStage get growthStage => WishGrowthStageX.fromGrowthPoint(growthPoint);

  double get growthProgress {
    final stage = growthStage;
    final next = stage.nextThreshold;
    if (next == null) return 1.0;
    final cur = stage.currentThreshold;
    return ((growthPoint - cur) / (next - cur)).clamp(0.0, 1.0);
  }
}
```
`growthStage`/`growthProgress`는 **별도 필드로 저장하지 않고 매번 파생 계산**한다 — 이는 서버 밸런싱 시
임계값 상수만 조정하면 기존 데이터가 자동으로 재분류되는 장점이 있다(마이그레이션 불필요).

### 오브제 연동 (이번 세션 신규 구현 — 문서-코드 정합성 확보)
대표 소원의 `growthStage`가 메인 오브제의 시각화에 반영되지 않던 격차를 `WishRoomVisualState
.representativeGrowthStage` 필드로 연동했다.

```dart
// lib/features/wish_room/presentation/state/wish_room_state.dart
WishRoomVisualState get visualState => WishRoomVisualState.fromRoom(
      consecutivePrayerDays: room.consecutivePrayerDays,
      hasPrayedToday: room.hasPrayedToday,
      representativeGrowthStage:
          room.representativeWish?.growthStage ?? WishGrowthStage.ember,
    );
```

```dart
// lib/features/wish_room/presentation/theme/wish_room_theme.dart
static Color forGrowthStage(WishGrowthStage stage) { /* 5단계 색상 매핑, 위 표와 동일 */ }

static RadialGradient objectGradientForStage(WishGrowthStage stage) {
  final tone = forGrowthStage(stage);
  return RadialGradient(
    colors: [Colors.white, tone, Colors.transparent],
    stops: stage == WishGrowthStage.goldenFlame
        ? const [0.0, 0.55, 1.0]  // 최종 단계는 중심부가 더 넓게 퍼짐
        : const [0.0, 0.4, 1.0],
  );
}
```

`WishRoomObject` 위젯은 `size`(크기, `WishObjectLevel` 기반)와 `stageGradient`/`stageTone`(색조,
`WishGrowthStage` 기반)을 **동시에 하나의 원형 오브제에 적용**하고, 중심 이모지는 `AnimatedSwitcher`
(400ms)로 단계 전환 시 스무스하게 크로스페이드된다.

---

## ⑦ 필수 시스템 ③ — 치성시스템

### 치성 타입 4종 정의(정책표 ②③)

| 타입 | 라벨 | 복주머니 비용 | 성장치 증가 | 제한 | MVP 포함 여부 |
|---|---|---|---|---|---|
| `daily` | 오늘의 치성 | 0(무료) | +5 | 하루 1회 | ✅ 포함 |
| `deep` | 깊은 치성 | 1개 | +15 | 없음(잔액만 확인) | ✅ 포함 |
| `focused` | 집중 치성 | 3개 | +40 | 없음(잔액만 확인) | ✅ 포함 |
| `gratitude` | 감사 치성 | 0 | 0(완료처리 개념) | 소원 완료 선언용 | ❌ **MVP 제외** — enum만 선언, UI 진입점 없음(⑯ 참고) |

**MVP 제외 명시**: `gratitude`는 "소원이 이뤄졌다"는 완료 선언 + 특별 뱃지 지급 기능으로 설계 의도만
enum에 반영해두었고, `PrayerTypeSheet`(치성 선택 UI)에는 노출하지 않는다. 완료 처리는 소원 삭제/보관
플로우와 함께 별도 스프린트에서 다루는 것이 합리적이다(소원을 "종료"시키는 순간 대표 슬롯이 비게 되어
슬롯 재배치 로직이 추가로 필요하기 때문 — ⑯ 참고).

### 일일 치성 제한 로직
`daily`는 `WishRoom.hasPrayedToday`(오늘 날짜와 `lastPrayedDate` 비교)가 true면 **Repository를 호출하지도
않고 Controller 단에서 즉시 실패 처리**한다 — 불필요한 네트워크/상태 갱신을 막는 방어적 설계다.

```dart
// lib/features/wish_room/presentation/controllers/wish_room_controller.dart
Future<bool> prayForWish({required String wishId, required PrayerType type}) async {
  final current = state.valueOrNull;
  if (current == null) return false;
  if (type == PrayerType.daily && current.room.hasPrayedToday) {
    return false; // Repository 호출 없이 즉시 실패
  }
  state = const AsyncLoading<WishRoomData>().copyWithPrevious(state);
  try {
    await _repo.prayForWish(wishId: wishId, type: type);
    final bundle = await _repo.fetchInitialData();
    state = AsyncData(current.copyWith(room: bundle.room, pouchStatus: bundle.pouchStatus, dailyMessage: bundle.dailyMessage));
    return true;
  } catch (e, st) {
    state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
    return false;
  }
}
```

### 치성 실행 흐름(마이크로카피 원칙 포함)
1. 메인 화면 CTA/오브제 터치 → `PrayerTypeSheet.show()` (바텀시트, 3개 카드)
2. 카드 비활성 시 이유 텍스트: "오늘은 이미 다녀갔어요. 내일 다시 만나요" / "복주머니가 부족해요"
3. 선택 즉시 `+가입치` 숫자가 카드 우측에 프리뷰되어 있어 "선택 전에 이미 결과를 안다"
4. 실행 성공 → `PrayerCompleteSheet`(글로우 확산 애니메이션 700ms) → 레벨업 시 골드 뱃지 추가 노출

**마이크로카피 절대 규칙**: "차감"이라는 표현은 UI에 절대 노출하지 않는다. 항상 "정성을 담다/더하다"로
표현한다(`prayer_type.dart` 소스 주석에도 명시). 예: "복주머니 $cost개로 정성을 더해요"(O) / "복주머니
$cost개 차감"(X, 사용 금지).

---

## ⑧ 필수 시스템 ④ — 복주머니시스템(재화 연동)

### 경제 설계: EARN/SPEND 충돌 해결(이전 세션 완료 사항 — 문서화)
기존 소원방(`WishRoomProvider.applyRitualReward()`)은 "무료 일일 치성 → 복주머니 **적립**(EARN)" 흐름이었다.
신규 설계는 "정성 담기 → 복주머니 **소비**(SPEND)"로 정반대다. 하나의 재화 잔액에 대해 서로 다른 화면이
자유롭게 벌고 쓰면 인플레이션/밸런스 붕괴가 발생하므로, **공식 전환 시 기존 EARN 로직은 완전히 폐기**했다.
`daily`(pouchCost=0)가 "매일 무료로 들어올 이유"를 대신하며, 복주머니 적립은 이미 앱 전역에 존재하는
출석체크/광고 시청 경로가 전담한다(소원방은 SPEND 전용 소비처로 역할 고정).

### Repository 교체 지점을 통한 실 재화 연동
`WishRoomRepository` 인터페이스를 통해 Controller/위젯 코드는 재화가 mock인지 실제인지 전혀 알 필요가
없다. `RealCurrencyWishRoomRepository`가 `MockWishRoomRepository`를 `_inner`로 감싸 소원/스트릭/꾸미기
로직은 그대로 재사용하고, **복주머니 잔액만** `LuckPouchProvider`(package:provider, `WalletProvider` 경유)
로 위임한다.

```dart
// lib/features/wish_room/data/real_currency_wish_room_repository.dart (핵심 발췌)
class RealCurrencyWishRoomRepository implements WishRoomRepository {
  RealCurrencyWishRoomRepository(this._luckPouch) : _inner = MockWishRoomRepository();
  final LuckPouchProvider _luckPouch;
  final MockWishRoomRepository _inner;

  @override
  Future<PrayerSession> prayForWish({required String wishId, required PrayerType type}) async {
    final cost = type.pouchCost;
    if (cost == 0) return _inner.prayForWish(wishId: wishId, type: type); // daily: 실 잔액 안건드림
    if (!_luckPouch.canSpend(cost)) throw Exception('복주머니가 부족합니다');
    final spent = await _luckPouch.spend(cost, '소원방 정성 담기', sourceType: 'wish_room_prayer');
    if (!spent) throw Exception('복주머니가 부족합니다');
    return _inner.prayWithExternalPouch(wishId: wishId, type: type, realBalanceAfterSpend: _luckPouch.balance);
  }
}
```

### Provider ↔ Riverpod 공존 지점
앱 전역은 `package:provider`(MultiProvider)를 쓰고 소원방 서브트리만 Riverpod `ProviderScope`를 새로 연다.
경계 위젯(`WishRoomRiverpodEntry`)이 `legacy_provider.Provider.of<LuckPouchProvider>(context)`로 실
Provider 인스턴스를 꺼내 Riverpod override에 주입한다(⑬ 아키텍처 섹션에서 전체 코드 제시).

### 표시값 vs 실값 분리
`FortunePouchStatus`(소원방 전용 표시 모델)는 `totalCount`를 `LuckPouchProvider.balance`로 매 진입 시
덮어쓴다(`overridePouchTotalCount`) — 표시 모델 자체는 소원방 UI 전용이라 필드가 더 단순하지만, 항상
실 잔액과 동기화되어 괴리가 생기지 않는다.

---

## ⑨ 필수 시스템 ⑤ — 꾸미기시스템

### 카테고리 6종(정책표 ⑧)
| 카테고리 | 라벨 | 다중 적용 | 설명 |
|---|---|---|---|
| `objectSkin` | 오브제 | ✗(단일) | 촛불 형태/색感 스킨 |
| `altar` | 제단 | ✗(단일) | 제단/받침대 디자인 |
| `background` | 배경 | ✗(단일) | 밤하늘/사찰 등 배경 테마 |
| `effect` | 이펙트 | ✗(단일) | 치성 시 파티클/빛 번짐 스타일 |
| `decoration` | 장식 | ✅(다중) | 초롱/학/방석 등 소품, 유일하게 여러 개 동시 적용 |
| `seasonalTheme` | 시즌 테마 | ✗(단일) | 설/추석 등 기간 한정 세트 |

### 해금 방식 4종(`CustomizeUnlockType`)
`purchase`(복주머니 즉시구매) / `growthReward`(성장 단계 도달 시 무료) / `streakReward`(연속일수 도달 시
무료) / `eventLimited`(이벤트 기간 한정).

### 소유(owned)와 적용(applied)의 분리
구매/해금해도 자동 적용되지 않는다 — 사용자가 명시적으로 "적용하기"를 눌러야 방에 반영된다. `decoration`
만 예외적으로 다중 적용을 허용하며(`allowsMultiple`), 나머지 카테고리는 라디오 방식(같은 카테고리 내
기존 적용 아이템 자동 해제)이다.

```dart
// lib/features/wish_room/data/mock/mock_wish_room_repository.dart (applyCustomizeItem)
if (target.category.allowsMultiple) {
  _catalog = _catalog.map((c) => c.id == itemId ? c.copyWith(isApplied: !c.isApplied) : c).toList();
} else {
  _catalog = _catalog.map((c) {
    if (c.category != target.category) return c;
    return c.copyWith(isApplied: c.id == itemId);
  }).toList();
}
```

### 실 재화 연동 시 구매 흐름
`RealCurrencyWishRoomRepository.purchaseCustomizeItem()`이 `_luckPouch.canSpend/spend()`로 실 잔액을
검증·차감한 뒤, mock 쪽은 `markOwnedExternally()`(재차감 없이 `isOwned=true`만 세팅)로 정합성을 유지한다
— "이중 차감" 버그를 구조적으로 방지하는 지점이다.

---

## ⑩ 필수 시스템 ⑥ — 재방문시스템

### 연속 방문일수(streak) → 방 앰비언트 후광 매핑(정책표)
| 연속 방문일수 | `WishObjectLevel` | 라벨(내부) | 오브제 크기 | glowIntensity 기본 |
|---|---|---|---|---|
| 0~2일 | `seed` | 씨앗 | 96px | 0.4(미기도) / 0.9(기도함) |
| 3~6일 | `glow` | 발광 | 108px | 〃 |
| 7~13일 | `bloom` | 개화 | 120px | 〃 |
| 14일+ | `radiant` | 광휘 | 132px | 〃 |

```dart
// lib/features/wish_room/data/models/wish_room_visual_state_model.dart
static WishObjectLevel fromStreak(int streakDays) {
  if (streakDays >= 14) return WishObjectLevel.radiant;
  if (streakDays >= 7) return WishObjectLevel.bloom;
  if (streakDays >= 3) return WishObjectLevel.glow;
  return WishObjectLevel.seed;
}
```

### 배경 반짝임 밀도 연동
`backgroundSparkleLevel = (consecutivePrayerDays / 14).clamp(0.2, 1.0)` — 연속 방문이 쌓일수록
`WishRoomBackground`(별빛 CustomPainter)의 노출 별 개수가 8개(최소)~24개(최대)까지 선형 증가한다.
이는 "방문할수록 방이 물리적으로 화려해진다"는 재방문 동기를 배경 레이어에서도 이중으로 강화한다.

### 재방문 보상과 슬롯 해금의 연결
⑤에서 설명한 슬롯 해금 조건(연속 3일/7일)이 재방문시스템의 핵심 보상 지급 지점이다 — 단순 시각효과
변화(오브제 크기)에 그치지 않고, "실질적으로 할 수 있는 일이 늘어나는" 구조적 보상을 연속일수 3일/7일에
배치했다.

---

## ⑪ 정책표 12종 (전체)

### 정책표 ① — 슬롯 시스템 정책
| 항목 | 값 |
|---|---|
| 총 슬롯 수 | 3(대표 1 + 서브 2) |
| 대표 슬롯 해금 조건 | 없음(항상 열림, 최초 소원 등록 시 자동 대표 지정) |
| 서브 슬롯 1번 무료 해금 | 연속 방문 3일 |
| 서브 슬롯 2번 무료 해금 | 연속 방문 7일 |
| 서브 슬롯 즉시 해금 가격 | 복주머니 30개(공통) |
| 대표 소원 교체 | `setRepresentative(wishId, isRepresentative: true)` — 기존 대표는 자동 해제(단일 선택) |
| 슬롯 없을 때 등록 시도 | 작성 화면 진입 차단, 슬롯 확장 화면(⑫-⑨)으로 강제 리다이렉트 |

### 정책표 ② — 치성 실행 조건 정책
| 항목 | 값 |
|---|---|
| daily 실행 제한 | 하루 1회(자정 기준 날짜 비교, `lastPrayedDate`) |
| deep/focused 실행 제한 | 없음(잔액 검증만, 하루 여러 번 가능) |
| 치성 대상 | 항상 대표 소원(`representativeWish`)만 가능(MVP 범위 — ⑯ 참고) |
| 실행 실패 시 UX | SnackBar "복주머니가 부족해요. 상점에서 채워보세요." |

### 정책표 ③ — 치성 타입별 비용/보상 기준값
| 타입 | pouchCost | growthPointGain | 배율(daily=1x 기준) |
|---|---|---|---|
| daily | 0 | 5 | 1x(기준) |
| deep | 1 | 15 | 3x |
| focused | 3 | 40 | 8x(집중 편익 강조) |
| gratitude | 0 | 0 | MVP 제외 |

### 정책표 ④ — 복주머니 재화 경제 정책
| 항목 | 값 |
|---|---|
| 소원방 내 적립 경로 | **없음**(SPEND 전용 소비처로 역할 고정) |
| 복주머니 소스 | 앱 전역 출석체크/광고시청(소원방 외부) |
| 표시값 동기화 | 화면 진입(fetchInitialData) 시마다 `LuckPouchProvider.balance`로 덮어씀 |
| 부족 시 UX | 옵션 카드 opacity 0.45 처리 + 비활성 텍스트, 클릭 불가(null onTap) |

### 정책표 ⑤ — 소원 등록/작성 정책
| 항목 | 값 |
|---|---|
| 제목 길이 제한 | 최대 60자(`maxLength: 60`) |
| 필수 입력 | 제목(공백 제거 후 비어있지 않음) + 카테고리 1개 선택 |
| 카테고리 종류 | health/wealth/exam/love/family/achievement/healing/custom(추천 노출은 7개, custom은 UI 미노출) |
| 최초 소원 배정 | 등록 시 대표 소원이 없으면 자동으로 대표 슬롯에 배정(`isFirstWish` 체크) |
| 저장 후 동작 | 작성 화면 자동 pop, 메인 화면으로 복귀 |

### 정책표 ⑥ — 성장 단계 정책(개별 소원)
| 단계 | 임계값 | 색상 | 다음 단계까지 표기 |
|---|---|---|---|
| ember | 0~19 | `#E8875A` | "다음 단계까지 N" |
| smallCandle | 20~59 | `#F0A85E` | 〃 |
| steadyCandle | 60~119 | `#F4C560` | 〃 |
| brightCandle | 120~249 | `#FAD98A` | 〃 |
| goldenFlame | 250+ | `#FFF3D0` | "최고 단계에 도달했어요" |

레벨업(단계 상승) 발생 시 `PrayerCompleteSheet`에 골드 뱃지("🎉 {단계명} 단계로 성장했어요")를 추가 노출한다
— 이는 "강한 시각 보상" 요건을 충족하는 유일한 축하 트리거다.

### 정책표 ⑦ — 재방문/연속방문 정책(방 앰비언트)
| 연속일수 구간 | 레벨 | 오브제 크기 |
|---|---|---|
| 0~2 | seed | 96px |
| 3~6 | glow | 108px |
| 7~13 | bloom | 120px |
| 14+ | radiant | 132px |

연속일수는 daily/deep/focused 어떤 치성이든 **오늘 최초 1회 실행 시에만** 1 증가한다(`_applyPrayerEffect`
내부 `wasPrayedToday` 체크로 같은 날 중복 증가 방지).

### 정책표 ⑧ — 꾸미기 아이템 카탈로그 정책
| 카테고리 | 다중적용 | 해금방식 예시(mock 기준) | 가격 예시 |
|---|---|---|---|
| objectSkin | 단일 | growthReward(기본) / purchase | 연꽃 촛대 12개 |
| altar | 단일 | growthReward(기본) / purchase | 대리석 제단 20개 |
| background | 단일 | growthReward(기본) / streakReward | 고요한 사찰(연속 7일) |
| effect | 단일 | growthReward(기본) / purchase | 꽃잎 흩날림 15개 |
| decoration | **다중** | purchase(전량) | 초롱 8개 / 학 10개 |
| seasonalTheme | 단일 | eventLimited | 설맞이 테마(가격 없음, 조건부) |

### 정책표 ⑨ — 초회 가이드/온보딩 정책
| 항목 | 값 |
|---|---|
| 노출 조건 | `isFirstVisit == true`(shared_preferences `wish_room_guide_seen` 키 미존재) |
| 노출 방식 | 메인 화면 데이터 로드 완료 후 `Future.microtask`로 다이얼로그 표시 |
| 스텝 구성 | 5단계(입장→소원정하기→정성담기→매일기도→소원확인) |
| 영속화 | `markGuideSeen()` 호출 시 즉시 shared_preferences에 true 기록, 재실행 시 재노출 안 됨 |
| 재노출 경로 | 헤더의 "?"(help_outline) 아이콘 — 언제든 수동 재확인 가능 |

### 정책표 ⑩ — 에러/예외 처리 정책
| 상황 | UX |
|---|---|
| 초기 데이터 로드 실패 | 전체화면 "잠시 후 다시 시도해주세요" + "다시 시도" 버튼(`ref.invalidate`) |
| 치성 실행 실패(잔액부족) | 홈 화면 복귀 + SnackBar 안내 |
| 슬롯 해금 실패(잔액부족) | 슬롯 화면 내 SnackBar "복주머니가 부족해요" |
| 꾸미기 구매 실패 | 꾸미기 화면 내 SnackBar "복주머니가 부족해요. 상점에서 채워보세요." |
| 로딩 중 상태 | `CircularProgressIndicator(color: WishRoomColors.gold)` 공통 사용 |

### 정책표 ⑪ — 빈 상태(Empty State) 정책
| 화면 | 조건 | 문구 |
|---|---|---|
| 메인 화면 소원카드 리스트 | wishes.isEmpty | "아직 이 방엔 소원이 없어요" / "첫 소원을 빌어, 방에 첫 빛을 밝혀보세요" (탭 시 작성화면 이동) |
| 히스토리 화면 | wishes.isEmpty | "지금까지 당신이 품어온 마음들"(중앙 정렬 단독 텍스트) |
| 대표 소원 없음 + 치성 시도 | representativeWish == null | 치성 플로우 대신 작성 화면으로 즉시 리다이렉트 |

### 정책표 ⑫ — 애니메이션 타이밍 정책(성능 원칙 포함)
| 애니메이션 | Duration | Curve | 트리거 |
|---|---|---|---|
| 오브제 숨쉬기(breathe) | 3000ms repeat(reverse) | linear(controller.value 직접 사용) | 상시 재생 |
| 오브제 터치 확대 | 200ms | 기본 | 터치 시 1회 |
| 오브제 색조/그라디언트 전환 | 500ms | 기본(AnimatedContainer) | growthStage 변경 시 |
| 오브제 이모지 전환 | 400ms | AnimatedSwitcher 기본 | growthStage 변경 시 |
| 진행률 바(성장) | 500ms | easeOutCubic | growthProgress 변경 시 |
| 카테고리 칩 선택 | 150ms | 기본(AnimatedContainer) | 탭 즉시 |
| 기도완료 글로우 확산 | 700ms | easeOutCubic | 바텀시트 진입 시 |
| 인트로→메인 전환 | 500ms(페이지) + 900ms(인트로 자체 페이드) | easeOutCubic/easeIn | 1400ms 자동 또는 탭 |

**성능 원칙(공통)**: 오브제/배경 애니메이션은 각각 `RepaintBoundary`로 감싸고, 로컬 `AnimationController`가
직접 재생한다 — Riverpod 상태를 프레임 단위로 갈아끼우지 않는다. Riverpod은 "터치했다"는 1회성 신호만
올려줄 뿐, 발광 애니메이션 자체는 위젯이 스스로 재생한다(Skia 캐시 스래싱 방지, 게임 렌더링 이슈 예방
원칙과 동일선상).

---

## ⑫ 필수 화면 10개 상세 스펙

각 화면은 **목적 / 핵심행동 / UI구성 / 노출정보 / CTA / 예외처리 / 빈상태 / 인터랙션 / 애니메이션 / 마이크로카피**
10개 항목으로 기술한다.

### ⑫-① 입장화면 (`WishRoomEntryScreen`)
| 항목 | 내용 |
|---|---|
| 목적 | 소원방 진입 시 "조용히 문을 여는" 의식적 전환감을 1.4초간 제공, 앱 전역과 소원방의 톤 전환을 자연스럽게 매개 |
| 핵심행동 | 대기(자동 전환) 또는 화면 탭(즉시 전환) |
| UI구성 | `Scaffold` > `GestureDetector`(전체화면) > `DecoratedBox`(배경그라디언트) > `Center` > `FadeTransition`+`ScaleTransition`(타이틀+서브텍스트) |
| 노출정보 | "당신의 소원이 머무는 방"(titleXl) / "조용히 문을 엽니다…"(bodySm) |
| CTA | 화면 전체 탭 시 즉시 `_enterMainScreen()` 호출 |
| 예외처리 | `!mounted` 체크로 위젯 dispose 후 네비게이션 방지 |
| 빈상태 | 해당 없음(정적 진입 화면) |
| 인터랙션 | 전체화면 탭 가능(스킵), 900ms 페이드+스케일(0.92→1.0) 인트로 애니메이션 |
| 애니메이션 | `AnimationController`(900ms) 1회 forward, 완료 대기 없이 1400ms 후 자동 전환 타이머 별도 가동 |
| 마이크로카피 | 경어체·의식적 톤("문을 엽니다", "머무는 방") — 일반 앱의 "로딩중..." 같은 기능적 문구 배제 |

**전환 시 핵심 구조 — PageRouteBuilder + FadeTransition/ScaleTransition**:
```dart
void _enterMainScreen() {
  if (!mounted) return;
  Navigator.of(context).pushReplacement(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const WishRoomScreen(),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
    ),
  );
}
```

**중첩 Navigator 버그 수정 사항(문서화)**: 이 `pushReplacement` 호출은 반드시 `WishRoomRiverpodEntry`가
연 **중첩 Navigator** 내부에서 일어나야 한다. 그렇지 않으면 앱 루트 Navigator가 호출을 가로채 전환된
`WishRoomScreen`이 `ProviderScope` 밖에 놓여 렌더링에 실패한다(⑬ 아키텍처 섹션에서 전체 해결 코드 제시).

### ⑫-② 메인화면 (`WishRoomScreen`)
| 항목 | 내용 |
|---|---|
| 목적 | 소원방의 모든 핵심 재미(성장/치성/복주머니/꾸미기/재방문)를 한 화면에서 진입 가능하게 하는 허브 |
| 핵심행동 | 오브제 터치(터치 리액션) / 치성 CTA 탭(치성 플로우 시작) / 내 소원 보기 / 방 꾸미기 |
| UI구성 | `Scaffold` > `SafeArea` > `Stack`(`WishRoomBackground` 전체배경 + `CustomScrollView`) — Sliver 구성: Header → Object+DailyMessage → WishCardList → GrowthProgressCard(대표소원 있을 때만) → StatusCards(복주머니+스트릭) → CTA버튼군 |
| 노출정보 | 오늘의 한줄메시지, 대표소원 카드 리스트(최대3), 대표소원 성장진행률, 복주머니 보유량, 연속기도일수/누적기도횟수 |
| CTA | 메인 버튼(오늘의 정성 올리기/정성 더하기, 텍스트는 `hasPrayedToday`로 동적 전환) + 서브 버튼 2개(내 소원 보기/방 꾸미기) |
| 예외처리 | 로딩 시 중앙 스피너, 에러 시 "잠시 후 다시 시도해주세요" + 재시도 버튼 |
| 빈상태 | `WishCardList`가 wishes.isEmpty일 때 안내 카드로 전환(⑪ 정책표 ⑪) |
| 인터랙션 | 오브제 터치 시 즉시 확대(200ms)+글로우 강화, 스크롤 시 CustomScrollView 자연스러운 시차 |
| 애니메이션 | 오브제 상시 숨쉬기(3s) + 배경 별빛 반짝임(4s 반복) — **정적 카드묶음 금지 요건을 충족하는 핵심 화면** |
| 마이크로카피 | "마음이 향하는 곳에, 빛이 머뭅니다."(오늘의 메시지 예시) |

**초회 가이드 트리거 지점**(`ref.listen`으로 최초 데이터 로드 완료 시 1회):
```dart
ref.listen(wishRoomControllerProvider, (previous, next) {
  final data = next.valueOrNull;
  if (data != null && data.isFirstVisit && previous?.valueOrNull == null) {
    Future.microtask(() {
      if (context.mounted) {
        WishGuideDialog.show(context).then((_) {
          ref.read(wishRoomControllerProvider.notifier).markGuideSeen();
        });
      }
    });
  }
});
```

### ⑫-③ 소원 작성/선택 화면 (`WishWriteScreen`)
| 항목 | 내용 |
|---|---|
| 목적 | 새 소원을 슬롯에 등록(제목+카테고리) |
| 핵심행동 | 텍스트 입력 → 카테고리 칩 선택 → 저장 |
| UI구성 | `Scaffold`(닫기버튼) > 타이틀 텍스트 > `TextField`(카드형, maxLines3/maxLength60) > `CategoryChipGroup`(7개 추천칩, Wrap) > `Spacer` > 저장 버튼(하단 고정) |
| 노출정보 | 입력 글자수 카운터(counterStyle), 선택된 카테고리 하이라이트 |
| CTA | "소원 담기"(제목+카테고리 모두 채워져야 활성화, `canSave` 파생값) |
| 예외처리 | 저장 중 중복 탭 방지(`_isSaving` 플래그), 로딩 스피너로 버튼 텍스트 대체 |
| 빈상태 | 해당 없음(항상 입력 폼) |
| 인터랙션 | 카테고리 칩 탭 시 150ms 색상 전환(AnimatedContainer), 저장 버튼 비활성 시 surfaceCard 톤으로 시각적 구분 |
| 애니메이션 | 칩 선택 색상 전환(150ms) |
| 마이크로카피 | "오늘의 마음을 담아\n조용히 소원을 빌어보세요" / "이루고 싶은 소원을 적어보세요"(hint) |

### ⑫-④ 치성/정성담기 화면 (`PrayerTypeSheet`)
| 항목 | 내용 |
|---|---|
| 목적 | 3가지 치성 방식 중 선택해 정성 실행을 트리거하는 결정 지점 |
| 핵심행동 | 옵션 카드 탭 → 즉시 `Navigator.pop(type)`으로 상위 흐름에 결과 전달 |
| UI구성 | `showModalBottomSheet`(투명배경, `isScrollControlled`) > 타이틀("{소원제목}에\n어떻게 정성을 담을까요?") > 3개 옵션 카드(daily/deep/focused 순) |
| 노출정보 | 각 카드: 라벨, 설명(무료/가격), 우측 `+성장치` 프리뷰 숫자 |
| CTA | 카드 자체가 탭 영역(GestureDetector), 활성화된 카드만 반응 |
| 예외처리 | 비활성 카드는 `enabled ? onTap : null` + opacity 0.45 + 사유 텍스트로 즉시 이유 설명 |
| 빈상태 | 해당 없음 |
| 인터랙션 | 활성 카드만 시각적으로 선명(opacity 1.0), 비활성은 흐리게(0.45) — 선택 가능/불가능이 즉시 시각적으로 구분 |
| 애니메이션 | 바텀시트 진입 자체(showModalBottomSheet 기본 슬라이드업) |
| 마이크로카피 | "오늘 하루 무료로 마음을 전해요" / "복주머니 $cost개로 정성을 더해요" / "오늘은 이미 다녀갔어요. 내일 다시 만나요" |

### ⑫-⑤ 기도완료 바텀시트 (`PrayerCompleteSheet`)
| 항목 | 내용 |
|---|---|
| 목적 | 치성 성공 직후 강한 긍정 피드백 제공, 재방문 동기(연속일수) 재환기 |
| 핵심행동 | 확인("내일도 밝히러 올게요") 탭으로 닫기 |
| UI구성 | 바텀시트 > 글로우 원형(72px, RadialGradient+BoxShadow) > 완료 타이틀 > 서브텍스트 > 사용내역 캡션 > (조건부)레벨업 뱃지 > 확인 버튼 |
| 노출정보 | 복주머니 사용량(0이면 무료 문구 분기), 연속 기도일수, 레벨업 시 새 단계명 |
| CTA | "내일도 밝히러 올게요"(단일 CTA, 다음 행동을 재방문으로 유도하는 문구) |
| 예외처리 | `newStageLabel`이 null이면 뱃지 자체를 렌더링하지 않음(`if (widget.didLevelUp)`) |
| 빈상태 | 해당 없음 |
| 인터랙션 | 글로우/텍스트 모두 하나의 `AnimationController`(700ms)에 동기화되어 함께 확산 |
| 애니메이션 | `CurvedAnimation(easeOutCubic)` 기반 글로우 확산 + 텍스트 페이드인, 레벨업 뱃지는 골드 테두리 강조 컨테이너 |
| 마이크로카피 | "당신의 소원이 방 안에 고이 담겼어요" / "당신의 진심이 빛으로 남았어요" / "🎉 {단계} 단계로 성장했어요" |

### ⑫-⑥ 내소원기록/히스토리 화면 (`WishHistoryScreen`)
| 항목 | 내용 |
|---|---|
| 목적 | 등록된 모든 소원(대표+서브 전체)을 한번에 조회, 각 소원의 성장 현황 재확인 |
| 핵심행동 | 스크롤로 전체 목록 열람(현재 MVP는 탭 인터랙션 없음, 조회 전용) |
| UI구성 | `AppBar`(타이틀만) > `ListView.builder` — 각 항목: `WishCard`(전체폭) + `GrowthProgressCard` 세로 배치 |
| 노출정보 | 소원별 제목/카테고리 이모지/최근 기도 상태 텍스트 + 성장단계/진행률바 |
| CTA | 없음(순수 열람 화면, MVP 범위 — ⑯에서 상세/편집 확장 여지 언급) |
| 예외처리 | 로딩/에러는 다른 화면과 동일 패턴(스피너/재시도 텍스트) |
| 빈상태 | "지금까지 당신이 품어온 마음들"(중앙 단독 텍스트, 등록 유도 CTA는 없음 — 메인화면에서 이미 유도됨) |
| 인터랙션 | 리스트 스크롤만(정적이지만 메인화면에서 이미 충분한 인터랙션을 제공했으므로 여기는 정보 열람에 집중하는 것이 합리적) |
| 애니메이션 | 없음(GrowthProgressCard 내부 진행률바는 최초 렌더 시 목표값으로 바로 표시, 별도 등장 애니메이션 없음 — ⑯ 개선 여지) |
| 마이크로카피 | 상태 텍스트: "아직 기도 전이에요" / "오늘 기도했어요" / "N일 전 기도했어요" |

### ⑫-⑦ 소원방 꾸미기 화면 (`WishCustomizeScreen`)
| 항목 | 내용 |
|---|---|
| 목적 | 6개 카테고리별 아이템을 구매/적용해 방을 개인화 |
| 핵심행동 | 카테고리 탭 전환 → 아이템 카드 탭(보유중이면 즉시 적용, 미보유면 구매 후 자동 적용) |
| UI구성 | `AppBar` > 가로 스크롤 카테고리 탭(6개, Pill) > `GridView.builder`(2열, aspectRatio 0.85) > `_CustomizeItemCard`(이모지 미리보기+이름+상태캡션) |
| 노출정보 | 카드별 "적용중"/"보유중"/"👝가격개"/"연속N일 해금"/"조건부 해금" 4단계 상태 캡션 |
| CTA | 카드 전체가 탭 영역, 상태에 따라 동작 분기(`_handleTap`) |
| 예외처리 | 구매 실패(잔액부족) 시 SnackBar, 카탈로그 최초 로드는 `initState`에서 `Future.microtask`로 트리거 |
| 빈상태 | 카탈로그가 비어있으면(로드 전) 중앙 스피너로 대체 |
| 인터랙션 | 카테고리 탭 전환 시 150ms 색상 애니메이션, 적용중 카드는 골드 2px 테두리로 즉시 구분 |
| 애니메이션 | `_CustomizeItemCard`가 `AnimatedContainer`(200ms)로 적용 상태 전환 시 테두리 색/두께 스무스 전환 |
| 마이크로카피 | 상태 텍스트 4종(적용중/보유중/가격/해금조건)으로 사용자가 "왜 이 아이템을 못 쓰는지"를 즉시 이해 |

### ⑫-⑧ 즐기는 방법 팝업 (`WishGuideDialog`)
| 항목 | 내용 |
|---|---|
| 목적 | 5단계 온보딩으로 소원방의 전체 사용 흐름을 한 화면에 압축 전달 |
| 핵심행동 | 읽고 "시작하기" 탭으로 닫기 |
| UI구성 | `Dialog`(라운드 카드) > 타이틀 > 5개 스텝(제목+설명 세로 나열) > 확인 버튼 |
| 노출정보 | 입장하기/소원정하기/정성담기/매일기도하기/소원확인하기 5단계 각각의 제목+한줄설명 |
| CTA | "시작하기"(유일한 액션, pop) |
| 예외처리 | 없음(단순 정보성 다이얼로그) |
| 빈상태 | 해당 없음 |
| 인터랙션 | 다이얼로그 배경 탭으로 닫기는 기본 `showDialog` 동작에 위임(barrierDismissible 기본값) |
| 애니메이션 | 없음(기본 Dialog 등장 트랜지션만) — 반복 노출되는 정보성 팝업이므로 과한 애니메이션을 의도적으로 배제 |
| 마이크로카피 | "당신만의 소원방에 오신 걸 환영해요" + 5단계 경어체 안내문 |

### ⑫-⑨ 슬롯확장/보상해금 화면 (`WishSlotUnlockScreen`)
| 항목 | 내용 |
|---|---|
| 목적 | 3슬롯의 현재 상태를 한눈에 보여주고, 서브 슬롯을 무료(스트릭) 또는 즉시(복주머니) 해금 |
| 핵심행동 | 무료 해금 버튼(조건 충족 시만 노출) 또는 복주머니 해금 버튼 탭 |
| UI구성 | `AppBar` > 안내 타이틀 > 3개 슬롯 타일 가로 배치(`_SlotTile`) > 조건 분기 CTA 영역 |
| 노출정보 | 슬롯별 아이콘(잠김/불꽃)+라벨(대표소원/보조소원/빈자리/잠긴자리), 무료 해금까지 남은 조건 텍스트 |
| CTA | "무료로 자리 열기 (연속 방문 보상)"(조건 충족 시만) / "복주머니 30개로 바로 열기"(항상 노출) |
| 예외처리 | 해금 실패(잔액부족) SnackBar, 성공 시 SnackBar+즉시 화면 pop |
| 빈상태 | 모든 슬롯 해금 완료 시 "모든 자리가 열렸어요.\n이제 세 가지 소원을 함께 키워보세요"로 CTA 영역 대체 |
| 인터랙션 | 슬롯 타일은 정보 표시 전용(비인터랙티브), CTA만 활성 |
| 애니메이션 | 없음(정보 확인 후 즉시 결정하는 화면 특성상 최소 애니메이션이 합리적) |
| 마이크로카피 | "이 방에는 소원을 담을\n자리가 세 곳 있어요" / "연속 {3or7}일 방문하면 무료로 자리가 열려요 (현재 N일째)" |

### ⑫-⑩ 빈 상태 화면(통합, 별도 라우트 없음)
사용자가 요구한 "필요시 빈 상태 화면"은 **별도의 전체 화면 라우트로 분리하지 않고, 각 화면 내부의 조건부
렌더링으로 처리**하는 것이 합리적이라고 판단해 채택했다(정책표 ⑪ 참고). 이유:
1. 빈 상태는 항상 "그 화면의 정상 상태"의 부분집합(리스트가 0개인 경우)이지 별도 화면 목적이 아니다.
2. 별도 라우트로 분리하면 네비게이션 스택이 불필요하게 깊어지고, `WishRoomFlowStep.empty`(이미 enum에
   정의됨)를 화면 전환이 아닌 **동일 화면 내 상태 플래그**로 쓰는 것이 Riverpod 패턴과 더 자연스럽다.

실제 빈 상태 구현 지점 3곳: `WishCardList`(메인화면 소원카드 영역), `WishHistoryScreen`(히스토리 전체),
`_startPrayerFlow`의 대표소원 null 분기(치성 시도 시 작성화면으로 즉시 리다이렉트).

---

## ⑬ Flutter 아키텍처

### 폴더 구조 (feature-first, 실제 구현 기준 38개 파일)
```
lib/features/wish_room/
├── data/
│   ├── mock/
│   │   ├── mock_wish_room_data.dart          # 초기 목데이터 팩토리 함수 4종
│   │   └── mock_wish_room_repository.dart    # Repository 기본 구현체(인메모리+SharedPreferences)
│   ├── models/
│   │   ├── customize_item_model.dart
│   │   ├── daily_message_model.dart
│   │   ├── fortune_pouch_status_model.dart
│   │   ├── prayer_session_model.dart
│   │   ├── wish_item_model.dart               # WishCategory, WishGrowthStage 포함
│   │   ├── wish_room_model.dart                # WishRoom, 슬롯 파생 getter
│   │   └── wish_room_visual_state_model.dart  # WishObjectLevel, 오브제 시각 파생값
│   ├── real_currency_wish_room_repository.dart # 실 재화 연동 Repository(교체 지점의 실제 구현)
│   └── repositories/
│       └── wish_room_repository.dart          # Repository 인터페이스 + WishRoomBundle
├── domain/
│   └── enums/
│       ├── customize_category.dart
│       ├── prayer_type.dart
│       └── wish_slot_status.dart
└── presentation/
    ├── controllers/
    │   ├── wish_room_controller.dart           # AsyncNotifier<WishRoomData> (핵심 비즈니스 로직)
    │   └── wish_room_ui_controller.dart        # Notifier<WishRoomUiState> (화면 전환/애니메이션 트리거)
    ├── providers/
    │   └── wish_room_providers.dart            # 모든 Provider 선언 + 교체 지점
    ├── screens/                                 # 필수 화면 10개 대응 (9개 파일, 빈상태는 통합)
    │   ├── wish_customize_screen.dart
    │   ├── wish_history_screen.dart
    │   ├── wish_room_entry_screen.dart
    │   ├── wish_room_riverpod_entry.dart       # ProviderScope + 중첩 Navigator 경계
    │   ├── wish_room_screen.dart                # 메인화면
    │   ├── wish_slot_unlock_screen.dart
    │   └── wish_write_screen.dart
    ├── state/
    │   ├── wish_room_state.dart                 # WishRoomData (Controller의 상태 타입)
    │   └── wish_room_ui_state.dart              # WishRoomUiState, FlowStep, AnimationEvent
    ├── theme/
    │   └── wish_room_theme.dart                 # 소원방 전용 디자인 토큰
    └── widgets/                                  # 11개 재사용 위젯
        ├── category_chip_group.dart
        ├── daily_message_card.dart
        ├── fortune_pouch_status_card.dart
        ├── growth_progress_card.dart
        ├── prayer_complete_sheet.dart
        ├── prayer_streak_badge.dart
        ├── prayer_type_sheet.dart
        ├── wish_card.dart
        ├── wish_card_list.dart
        ├── wish_guide_dialog.dart
        ├── wish_room_background.dart
        ├── wish_room_header.dart
        └── wish_room_object.dart                # 메인 오브제(촛불 제단) 위젯
```

### 계층 책임 분리 원칙
| 계층 | 책임 | 이 프로젝트에서 절대 하지 않는 일 |
|---|---|---|
| `data/models` | 순수 데이터 구조 + 파생 getter(계산값) | Riverpod/BuildContext 의존 금지 |
| `data/repositories`, `data/mock`, `data/real_currency_...` | 데이터 획득/저장/외부 재화 연동의 실제 구현 | UI 상태(로딩/에러 표시 방식) 결정 금지 |
| `domain/enums` | 앱 전역에서 재사용되는 도메인 규칙(치성타입, 슬롯상태, 꾸미기카테고리) | 값 하드코딩 금지 — extension으로 라벨/비용 등을 계산 |
| `presentation/controllers` | Repository 호출 오케스트레이션, AsyncValue 상태 전환 | Widget 트리 구성 금지 |
| `presentation/providers` | Provider 그래프 선언, 파생 셀렉터, **Repository 교체 지점** | 비즈니스 로직 직접 구현 금지(Controller에 위임) |
| `presentation/state` | Controller/UiController가 들고 있는 상태 타입 정의 | 화면 전환 로직 금지(단순 데이터 홀더) |
| `presentation/screens`, `widgets` | `ConsumerWidget`/`ConsumerStatefulWidget`으로 상태 구독 + 렌더링 | Repository 직접 호출 금지(항상 Controller 경유) |
| `presentation/theme` | 색상/타이포/여백/반경 토큰 | 비즈니스 로직 금지 |

### Riverpod 상태 분리 설계 (3중 상태 구조)
소원방은 **하나의 거대한 상태가 아니라 3개의 독립된 Riverpod 상태 축**으로 분리되어 있으며, 이는 사용자가
요구한 "상태 분리"를 실제로 구현한 핵심 설계 결정이다.

1. **데이터 상태** — `wishRoomControllerProvider` (`AsyncNotifierProvider<WishRoomController, WishRoomData>`)
   방/소원/복주머니/일일메시지/커스터마이즈 카탈로그 등 "서버(=Repository)에서 오는 진실"을 담당.
   로딩/에러/데이터 3상태를 `AsyncValue`로 자동 관리.
2. **화면 흐름 상태** — `wishRoomUiProvider` (`NotifierProvider<WishRoomUiController, WishRoomUiState>`)
   현재 어떤 플로우 단계인지(`WishRoomFlowStep`), 가이드 팝업 노출 여부, 지금 재생해야 할 애니메이션
   이벤트(`WishRoomAnimationEvent`)를 담당. **데이터 상태와 완전히 독립** — 데이터 로딩 중에도 UI 상태는
   별도로 즉시 반응 가능하다.
3. **파생 셀렉터** — `hasPrayedTodayProvider`, `canUnlockSlotByStreakProvider`
   위 두 상태로부터 계산되는 boolean 값을 별도 Provider로 노출해, 위젯이 전체 `WishRoomData`를 watch하지
   않고 필요한 조각만 watch하도록 하여 불필요한 rebuild를 차단.

### Repository 교체 지점 (핵심 아키텍처 결정)
`wish_room_providers.dart`의 `wishRoomRepositoryProvider` 단 한 줄이 전체 데이터 소스를 결정한다.
```dart
final wishRoomRepositoryProvider = Provider<WishRoomRepository>((ref) {
  return MockWishRoomRepository(); // 기본값: 순수 목업(SharedPreferences 가이드 상태만 영속)
});
```
`WishRoomRiverpodEntry`가 이 Provider를 **override**하여 실 재화 연동 구현으로 교체한다:
```dart
ProviderScope(
  overrides: [
    wishRoomRepositoryProvider.overrideWith(
      (ref) => RealCurrencyWishRoomRepository(luckPouch),
    ),
  ],
  child: ...,
)
```
`WishRoomController`를 포함한 상위 계층은 `WishRoomRepository` 인터페이스만 알고 있으므로, Mock↔Real
전환이 **단 한 곳의 override로 완결**된다. 이후 실제 백엔드(Firestore 등)로 교체할 때도 동일한 지점만
수정하면 된다.

### provider 패키지(레거시)와 Riverpod의 공존 경계
앱 전역은 `package:provider`(`LuckPouchProvider` 등)를 사용 중이므로, 소원방은 격리된 하위 트리에서만
Riverpod을 사용한다. `WishRoomRiverpodEntry`가 이 경계의 유일한 지점이다:
```dart
final luckPouch = legacy_provider.Provider.of<LuckPouchProvider>(context); // 상위 provider 트리에서 획득
return ProviderScope(                          // 여기서부터 Riverpod 서브트리 시작
  overrides: [ wishRoomRepositoryProvider.overrideWith((ref) => RealCurrencyWishRoomRepository(luckPouch)) ],
  child: NavigatorPopHandler(
    onPopWithResult: (_) => navigatorKey.currentState?.maybePop(),
    child: Navigator(                          // 중첩 Navigator: 이 서브트리 내부 전환은 항상 ProviderScope 안에서 발생
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const WishRoomEntryScreen()),
    ),
  ),
);
```
이 중첩 `Navigator` 구조는 과거 "인트로 화면 이후 빈 화면" 버그(상위 `Navigator.pushReplacement`가
`ProviderScope` 경계 밖으로 라우트를 밀어내면서 Riverpod 컨텍스트를 잃던 문제)를 해결하기 위해 도입된
확정 설계이며, 소원방 내부의 모든 화면 전환(입장→메인→작성→치성→히스토리→꾸미기→슬롯해금)은 예외 없이
이 내부 `Navigator`를 통해서만 이루어진다.


---

## ⑭ 데이터 모델 전체 정리

### 모델 클래스 요약표
| 클래스 | 파일 | 핵심 필드 | 파생 getter |
|---|---|---|---|
| `WishItem` | `wish_item_model.dart` | id, title, category(`WishCategory`), createdAt, growthPoint(int), prayerCount, isRepresentative | `growthStage`(`WishGrowthStage`), `growthProgress`(double 0~1) |
| `WishRoom` | `wish_room_model.dart` | wishes(List\<WishItem\>), totalPrayerCount, consecutivePrayerDays, lastVisitedAt, lastPrayedDate, unlockedSubSlotCount(0~2) | `representativeWish`, `representativeWishes`, `subWishes`, `slotStatuses`(길이 항상 3), `hasAvailableSlot`, `hasPrayedToday`, `isEmpty` |
| `WishRoomVisualState` | `wish_room_visual_state_model.dart` | objectLevel(`WishObjectLevel`), glowIntensity(double), backgroundSparkleLevel(int), representativeGrowthStage(`WishGrowthStage`) | 없음(이미 파생값 자체) — `fromRoom()` factory로 생성 |
| `FortunePouchStatus` | `fortune_pouch_status_model.dart` | totalCount, usedToday, earnedToday, dailyFreeQuota | 없음 |
| `DailyMessage` | `daily_message_model.dart` | text, mood(`MessageMood`) | 없음 |
| `CustomizeItem` | `customize_item_model.dart` | id, name, category(`CustomizeCategory`), unlockType(`CustomizeUnlockType`), pouchPrice, unlockThreshold, isOwned, isApplied, previewEmoji | 없음 |
| `PrayerSession` | `prayer_session_model.dart` | id, wishId, pouchUsed, prayedAt, resultMessage | 없음 |
| `WishRoomBundle` | `wish_room_repository.dart` | room, pouchStatus, dailyMessage, isFirstVisit, customizeCatalog | Repository가 `fetchInitialData()`에서 반환하는 통합 DTO |
| `WishRoomData` | `wish_room_state.dart` | room, pouchStatus, dailyMessage, isFirstVisit, customizeCatalog | `visualState`(`WishRoomVisualState.fromRoom()` 호출 결과) |
| `WishRoomUiState` | `wish_room_ui_state.dart` | step(`WishRoomFlowStep`), showGuideDialog, pendingAnimationEvent | 없음 |

### 열거형(enum) 전체 정리
| enum | 파일 | 값 | 부가 extension |
|---|---|---|---|
| `WishCategory` | `wish_item_model.dart` | 8종(사랑/재물/건강/공부/일/관계/여행/기타 성격) | `label`, `emoji` |
| `WishGrowthStage` | `wish_item_model.dart` | ember → smallCandle → steadyCandle → brightCandle → goldenFlame | `fromGrowthPoint(pt)`, `nextThreshold`, `currentThreshold`, `label`, `emoji` |
| `WishObjectLevel` | `wish_room_visual_state_model.dart` | seed → glow → bloom → radiant | `fromStreak(days)` |
| `WishSlotStatus` | `wish_slot_status.dart` | representative / subFilled / subEmpty / locked | `isLocked`, `isEmptySlot`, `label` |
| `PrayerType` | `prayer_type.dart` | daily / deep / focused / gratitude(MVP 제외) | `pouchCost`, `growthPointGain`, `label`, `ctaLabel` |
| `CustomizeCategory` | `customize_category.dart` | objectSkin / altar / background / effect / decoration / seasonalTheme | `label`, `allowsMultiple`(decoration만 true) |
| `CustomizeUnlockType` | `customize_category.dart` | purchase / growthReward / streakReward / eventLimited | 없음(단순 분류) |
| `WishRoomFlowStep` | `wish_room_ui_state.dart` | home / empty / writingWish / praying / prayerCompleted / revisitCelebration / customizing / unlockingSlot | 없음 |
| `WishRoomAnimationEvent` | `wish_room_ui_state.dart` | objectTouch / prayerBurst / streakLevelUp / growthStageUp / slotUnlocked | 없음 |
| `MessageMood` | `daily_message_model.dart` | 일일 메시지 어조 분류 | 없음 |

### 모델 간 관계 다이어그램(텍스트)
```
WishRoomBundle (Repository 응답 DTO)
  └─ WishRoom
       └─ List<WishItem>  ──(growthPoint)──▶ WishGrowthStage (파생)
  └─ FortunePouchStatus
  └─ DailyMessage
  └─ List<CustomizeItem>

WishRoomData (Controller 상태, = WishRoomBundle과 구조 동일 + visualState 파생)
  └─ WishRoomVisualState.fromRoom(room)
       ├─ objectLevel        ← room.consecutivePrayerDays (WishObjectLevel.fromStreak)
       └─ representativeGrowthStage ← room.representativeWish?.growthStage (기본 ember)
            └─ WishRoomObject 위젯에서 크기(objectLevel)와 색조(representativeGrowthStage)로 동시 렌더링
```

### 필드 네이밍 규칙
- 시간 필드는 `DateTime?`이며 이름 접미사 `At`(createdAt, lastVisitedAt) 또는 `Date`(lastPrayedDate, "일" 단위
  비교용) 두 가지를 의도적으로 구분 사용한다. `At`은 정밀 타임스탬프, `Date`는 "그 날짜인지" 비교(연속 방문일
  판정)에만 쓰이므로 시/분/초를 버린 날짜 단위 비교 로직(`isSameDate`류)과 항상 함께 다닌다.
- 수량 필드는 전부 `int`이며 소수점이 필요한 값(`growthProgress`, `glowIntensity`)만 `double`이다.
- boolean 필드는 `is`/`has` 접두사를 강제한다(`isOwned`, `isApplied`, `isRepresentative`, `hasAvailableSlot`).


---

## ⑮ 디자인 토큰

소원방은 앱 전역 테마와 별도로 **자체 디자인 토큰 세트**(`wish_room_theme.dart`)를 갖는다. 이는 "촛불 제단"이
연출하는 어둡고 신비로운 분위기가 앱 전역의 밝은 톤과 다르기 때문에 의도적으로 분리한 결정이다.

### 명명 불일치에 대한 확정 설명
전역 테마가 `AppColors`/`AppTextStyles` 등의 이름을 쓰는 것과 달리 소원방은 `WishRoomColors`/
`WishRoomTextStyles`/`WishRoomSpacing`/`WishRoomRadius`로 **완전히 별도의 네임스페이스**를 사용한다.
이는 실수가 아니라 **의도적 격리**이며 이유는 다음과 같다:
1. 소원방은 다른 화면과 시각적으로 확실히 구분되는 "특별한 공간"이어야 한다(사용자 요구사항의 "몰입감").
2. 전역 테마 변경이 소원방에 의도치 않게 영향을 주는 것을 방지한다(반대로도 마찬가지).
3. 향후 소원방에 "시즌 테마"(`CustomizeCategory.seasonalTheme`)를 도입할 때, 전역 테마를 건드리지 않고
   `WishRoomColors`만 동적으로 교체할 수 있는 확장성을 확보한다.

### 색상 토큰 (`WishRoomColors`)
| 토큰 | 용도 |
|---|---|
| `backgroundDeep`, `backgroundMid`, `backgroundSoft` | 배경 그라디언트 3단계(위→아래로 어두움→부드러움) |
| `backgroundGradient` | 위 3색을 조합한 `LinearGradient` (전체 화면 배경) |
| `gold`, `goldSoft` | 촛불/불꽃 계열 포인트 색(버튼, 강조 텍스트, 오브제 글로우) |
| `textPrimary`, `textSecondary`, `textTertiary` | 명도 3단계 텍스트 색(제목/본문/캡션) |
| `surfaceCard`, `surfaceBorder` | 카드 배경/테두리(반투명 다크 글래스모피즘 톤) |
| `success`, `error` | 상태 피드백 색(해금 성공/실패 등) |
| `objectGlowGradient` | 오브제 주변 발광 효과용 원형 그라디언트 |
| `forGrowthStage(stage)` | `WishGrowthStage` → 단일 강조색 매핑(ember=회색빛 → goldenFlame=순금색) |
| `objectGradientForStage(stage)` | `WishGrowthStage` → 오브제 본체 그라디언트 매핑(색조 연동의 실제 구현) |

### 타이포그래피 토큰 (`WishRoomTextStyles`)
| 토큰 | 크기/특성 | 용도 |
|---|---|---|
| `titleXl` | 대형, bold | 입장화면 메인 타이틀 |
| `titleLg` | 중대형, semibold | 화면별 섹션 타이틀 |
| `bodyMd` | 기본 본문 | 일반 설명 텍스트 |
| `bodySm` | 소형 본문 | 입장화면 서브텍스트, 캡션성 설명 |
| `caption` | 최소 크기 | 슬롯 라벨, 상태 뱃지 텍스트 |
| `dailyMessage` | 이탤릭/세리프 느낌 강조 | 일일 메시지 카드 전용(감성적 톤 강조) |
| `ctaLabel` | semibold, 버튼 전용 크기 | 모든 CTA 버튼 텍스트 |

### 간격/반경 토큰
| 토큰 그룹 | 값 체계 | 용도 |
|---|---|---|
| `WishRoomSpacing` | xs/sm/md/lg/xl/xxl (4px 배수 체계) | 위젯 내부 padding/margin 통일 |
| `WishRoomRadius` | sm/md/lg/pill | 카드/버튼/칩의 라운드 처리 통일(pill=완전 원형) |

### 토큰 사용 원칙
- 모든 소원방 하위 위젯은 하드코딩된 `Color(0xFF...)` 또는 매직 넘버 padding을 사용하지 않고 반드시 위 토큰을
  참조한다(이미 구현된 12개 위젯 전부가 이 원칙을 준수).
- `forGrowthStage`/`objectGradientForStage`처럼 "enum → 시각 토큰" 매핑 함수를 테마 파일에 두는 이유는,
  성장 단계별 색상 로직이 여러 위젯(오브제, 진행률 카드, 히스토리 카드)에서 중복 없이 재사용되도록 하기
  위함이다.


---

## ⑯ 개발 시 유의사항 / 제약 / MVP 제외 항목

### MVP에서 명시적으로 제외한 항목 (확정)
| 항목 | 제외 이유 | 향후 처리 방향 |
|---|---|---|
| `PrayerType.gratitude`(감사 치성) | "고도화된" 치성 타입으로 정의했으나 무료+특수 조건(예: 목표 달성 소원에만 노출)이 필요해 로직 복잡도가 높음. enum과 라벨은 이미 정의해 향후 확장 시 분기만 추가하면 되도록 선제 설계 완료 | `WishRoomController.prayForWish()`에 `case PrayerType.gratitude` 분기 추가 + 노출 조건 UI만 추가하면 즉시 활성화 가능 |
| 소원 삭제/수정 기능 | 사용자가 "정성을 들인 소원을 지운다"는 경험이 서비스 정서에 맞지 않다고 판단, 성장 시스템의 누적치도 삭제 시 처리가 애매해짐 | 필요 시 "소원 보관"(soft delete, 목록에서만 숨김) 방식으로 추가 검토 |
| 히스토리 화면 상세보기/편집 | 필수 화면 10개 요구사항에 "히스토리"만 명시되어 있고 상세 화면은 명시되지 않음, 현재 리스트+진행률 카드만으로 정보 전달 충분 | `WishHistoryScreen`의 `WishCard` onTap에 상세 바텀시트 추가하는 형태로 확장 가능(현재 onTap 미구현) |
| 소셜 기능(공유, 타인 소원방 방문) | "개인 소원방"이라는 서비스 정의(①번 섹션)에 정면으로 배치되는 기능이므로 범위에서 완전히 제외 | 별도 커뮤니티 피처로 취급, 소원방 자체는 확장하지 않음 |
| 실시간 서버 동기화(멀티 디바이스) | 현재 Repository는 로컬(Mock)+단일 디바이스 실 재화 연동까지만 구현, 별도 백엔드(Firestore 등) 연동은 Repository 교체 지점을 통해서만 향후 추가 | ⑬ 섹션의 "Repository 교체 지점" 설계로 이미 대비됨 |
| 알림/푸시(연속 방문 리마인더) | 재방문 시스템은 "방문 시 보상"까지만 범위로 하고, 방문을 유도하는 외부 알림은 별도 알림 인프라 피처로 분리 | 앱 전역 푸시 시스템 완성 후 "소원방 방문 안 한 지 N일" 트리거 추가 검토 |

### 개발 시 반드시 지켜야 할 제약 (코드 리뷰 체크포인트)
1. **모든 위젯은 `WishRoomColors`/`WishRoomTextStyles` 등 소원방 전용 토큰만 사용** — 전역 `AppColors` 등을
   소원방 화면에 직접 import하지 않는다(⑮ 섹션 원칙).
2. **Repository를 우회하는 직접 데이터 접근 금지** — 화면/위젯은 항상 `wishRoomControllerProvider`를 통해
   데이터를 얻고, `MockWishRoomRepository`나 `RealCurrencyWishRoomRepository`를 직접 import하지 않는다
   (`WishRoomRiverpodEntry` 제외, 이 파일만 override 설정을 위해 두 구현체를 안다).
3. **`growthPoint` 직접 조작 금지** — 항상 `PrayerType.growthPointGain`을 통한 가산만 허용하며, 임의의
   정수를 더하거나 UI에서 직접 값을 설정하는 코드를 작성하지 않는다.
4. **daily 치성은 재화 차감 로직에 절대 들어가지 않는다** — `hasPrayedToday`가 true인 상태에서 daily 치성을
   또 시도하면 Repository 호출 자체를 하지 않고 Controller 레벨에서 즉시 `false`를 반환한다(이미
   `wish_room_controller.dart`의 `prayForWish()`에 구현됨). 이 가드를 제거하거나 우회하는 수정은 금지.
5. **AsyncNotifier의 state 전환은 항상 `copyWithPrevious` 패턴을 따른다** — 로딩 중 이전 데이터를 화면에서
   깜빡임 없이 유지하기 위해 `AsyncLoading<T>().copyWithPrevious(state)` → 작업 → `AsyncData`/
   `AsyncError.copyWithPrevious(state)` 순서를 항상 지킨다(⑬ 섹션에서 이미 명시).
6. **정적 카드 나열 금지** — 사용자의 "UI는 반드시 확실하게 움직여야 함" 요구사항에 따라 신규 위젯을 추가할
   때도 최소 1개 이상의 명시적 애니메이션(`AnimatedContainer`/`AnimatedSwitcher`/`AnimationController` 등)을
   포함해야 한다. 이미 구현된 12개 위젯 전부가 이 기준을 충족한다(정책표 ⑫ 참고).


---

## ⑰ 지정된 20개 파일 코드 뼈대

사용자가 요구한 "최소 복붙 가능한 수준의 코드 뼈대"에 해당하는 20개 핵심 파일을 계층별로 정리한다.
전체 코드는 이미 ⑤~⑫ 섹션에서 상당 부분 발췌되었으므로, 여기서는 **각 파일의 골격(클래스 시그니처 +
핵심 메서드)**을 한 곳에 모아 실제 구현 순서를 그대로 따라갈 수 있도록 재구성한다.

### 1) `domain/enums/prayer_type.dart`
```dart
enum PrayerType { daily, deep, focused, gratitude }

extension PrayerTypeX on PrayerType {
  int get pouchCost => switch (this) {
    PrayerType.daily => 0, PrayerType.deep => 1,
    PrayerType.focused => 3, PrayerType.gratitude => 0,
  };
  int get growthPointGain => switch (this) {
    PrayerType.daily => 5, PrayerType.deep => 15,
    PrayerType.focused => 40, PrayerType.gratitude => 0,
  };
  String get label => switch (this) {
    PrayerType.daily => '오늘의 기도', PrayerType.deep => '정성 기도',
    PrayerType.focused => '집중 기도', PrayerType.gratitude => '감사 기도',
  };
}
```

### 2) `domain/enums/wish_slot_status.dart`
```dart
enum WishSlotStatus { representative, subFilled, subEmpty, locked }

extension WishSlotStatusX on WishSlotStatus {
  bool get isLocked => this == WishSlotStatus.locked;
  bool get isEmptySlot => this == WishSlotStatus.subEmpty;
  String get label => switch (this) {
    WishSlotStatus.representative => '대표 소원',
    WishSlotStatus.subFilled => '보조 소원',
    WishSlotStatus.subEmpty => '빈 자리',
    WishSlotStatus.locked => '잠긴 자리',
  };
}
```

### 3) `domain/enums/customize_category.dart`
```dart
enum CustomizeCategory { objectSkin, altar, background, effect, decoration, seasonalTheme }
enum CustomizeUnlockType { purchase, growthReward, streakReward, eventLimited }

extension CustomizeCategoryX on CustomizeCategory {
  bool get allowsMultiple => this == CustomizeCategory.decoration;
}
```

### 4) `data/models/wish_item_model.dart`
```dart
enum WishCategory { love, wealth, health, study, career, relationship, travel, etc }
enum WishGrowthStage { ember, smallCandle, steadyCandle, brightCandle, goldenFlame }

extension WishGrowthStageX on WishGrowthStage {
  static WishGrowthStage fromGrowthPoint(int pt) {
    if (pt >= 250) return WishGrowthStage.goldenFlame;
    if (pt >= 120) return WishGrowthStage.brightCandle;
    if (pt >= 60) return WishGrowthStage.steadyCandle;
    if (pt >= 20) return WishGrowthStage.smallCandle;
    return WishGrowthStage.ember;
  }
}

class WishItem {
  final String id;
  final String title;
  final WishCategory category;
  final DateTime createdAt;
  final int growthPoint;
  final int prayerCount;
  final bool isRepresentative;

  const WishItem({required this.id, required this.title, required this.category,
    required this.createdAt, this.growthPoint = 0, this.prayerCount = 0,
    this.isRepresentative = false});

  WishGrowthStage get growthStage => WishGrowthStageX.fromGrowthPoint(growthPoint);
  WishItem copyWith({int? growthPoint, int? prayerCount, bool? isRepresentative}) =>
    WishItem(id: id, title: title, category: category, createdAt: createdAt,
      growthPoint: growthPoint ?? this.growthPoint,
      prayerCount: prayerCount ?? this.prayerCount,
      isRepresentative: isRepresentative ?? this.isRepresentative);
}
```

### 5) `data/models/wish_room_model.dart`
```dart
class WishRoom {
  static const maxSlotCount = 3;
  static const maxSubSlotCount = 2;
  final List<WishItem> wishes;
  final int totalPrayerCount;
  final int consecutivePrayerDays;
  final DateTime? lastVisitedAt;
  final DateTime? lastPrayedDate;
  final int unlockedSubSlotCount;

  const WishRoom({this.wishes = const [], this.totalPrayerCount = 0,
    this.consecutivePrayerDays = 0, this.lastVisitedAt, this.lastPrayedDate,
    this.unlockedSubSlotCount = 0});

  WishItem? get representativeWish =>
    wishes.where((w) => w.isRepresentative).firstOrNull;
  bool get hasAvailableSlot => wishes.length < (1 + unlockedSubSlotCount);
  bool get isEmpty => wishes.isEmpty;
  WishRoom copyWith({List<WishItem>? wishes, int? unlockedSubSlotCount}) =>
    WishRoom(wishes: wishes ?? this.wishes, totalPrayerCount: totalPrayerCount,
      consecutivePrayerDays: consecutivePrayerDays, lastVisitedAt: lastVisitedAt,
      lastPrayedDate: lastPrayedDate,
      unlockedSubSlotCount: unlockedSubSlotCount ?? this.unlockedSubSlotCount);
}
```

### 6) `data/models/wish_room_visual_state_model.dart`
```dart
enum WishObjectLevel { seed, glow, bloom, radiant }

extension WishObjectLevelX on WishObjectLevel {
  static WishObjectLevel fromStreak(int days) {
    if (days >= 14) return WishObjectLevel.radiant;
    if (days >= 7) return WishObjectLevel.bloom;
    if (days >= 3) return WishObjectLevel.glow;
    return WishObjectLevel.seed;
  }
}

class WishRoomVisualState {
  final WishObjectLevel objectLevel;
  final double glowIntensity;
  final int backgroundSparkleLevel;
  final WishGrowthStage representativeGrowthStage;

  const WishRoomVisualState({required this.objectLevel, required this.glowIntensity,
    required this.backgroundSparkleLevel, this.representativeGrowthStage = WishGrowthStage.ember});

  factory WishRoomVisualState.fromRoom(WishRoom room, WishGrowthStage repStage) =>
    WishRoomVisualState(
      objectLevel: WishObjectLevelX.fromStreak(room.consecutivePrayerDays),
      glowIntensity: (room.consecutivePrayerDays / 14).clamp(0.0, 1.0),
      backgroundSparkleLevel: room.consecutivePrayerDays.clamp(0, 5),
      representativeGrowthStage: repStage);
}
```

### 7) `data/repositories/wish_room_repository.dart`
```dart
class WishRoomBundle {
  final WishRoom room;
  final FortunePouchStatus pouchStatus;
  final DailyMessage dailyMessage;
  final bool isFirstVisit;
  final List<CustomizeItem> customizeCatalog;
  const WishRoomBundle({required this.room, required this.pouchStatus,
    required this.dailyMessage, required this.isFirstVisit, this.customizeCatalog = const []});
}

abstract class WishRoomRepository {
  Future<WishRoomBundle> fetchInitialData();
  Future<WishItem> addWish(String title, WishCategory category);
  Future<void> setRepresentative(String wishId);
  Future<bool> prayForWish(String wishId, PrayerType type);
  Future<void> markGuideSeen();
  Future<bool> unlockSubSlot({required bool viaPouch});
  Future<List<CustomizeItem>> fetchCustomizeCatalog();
  Future<bool> purchaseCustomizeItem(String itemId);
  Future<void> applyCustomizeItem(String itemId);
}
```

### 8) `data/mock/mock_wish_room_repository.dart` (핵심 메서드만)
```dart
class MockWishRoomRepository implements WishRoomRepository {
  WishRoom _room = buildMockWishRoom();
  FortunePouchStatus _pouch = buildMockPouchStatus();

  @override
  Future<bool> prayForWish(String wishId, PrayerType type) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (type.pouchCost > _pouch.totalCount) return false;
    _applyPrayerEffect(wishId, type);
    return true;
  }

  void _applyPrayerEffect(String wishId, PrayerType type) {
    _pouch = _pouch.copyWith(totalCount: _pouch.totalCount - type.pouchCost);
    _room = _room.copyWith(wishes: _room.wishes.map((w) =>
      w.id == wishId ? w.copyWith(growthPoint: w.growthPoint + type.growthPointGain,
        prayerCount: w.prayerCount + 1) : w).toList());
  }

  @override
  Future<bool> unlockSubSlot({required bool viaPouch}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    const price = 30;
    if (_room.unlockedSubSlotCount >= 2) return false;
    if (viaPouch) {
      if (_pouch.totalCount < price) return false;
      _pouch = _pouch.copyWith(totalCount: _pouch.totalCount - price);
    }
    _room = _room.copyWith(unlockedSubSlotCount: _room.unlockedSubSlotCount + 1);
    return true;
  }
  // fetchInitialData / addWish / setRepresentative / markGuideSeen / catalog 메서드는 ⑧⑨ 섹션 참고
}
```

### 9) `data/real_currency_wish_room_repository.dart` (핵심 메서드만)
```dart
class RealCurrencyWishRoomRepository implements WishRoomRepository {
  final MockWishRoomRepository _inner = MockWishRoomRepository();
  final LuckPouchProvider _luckPouch;
  RealCurrencyWishRoomRepository(this._luckPouch);

  @override
  Future<bool> prayForWish(String wishId, PrayerType type) async {
    if (type.pouchCost == 0) return _inner.prayForWish(wishId, type);
    if (!_luckPouch.canSpend(type.pouchCost)) return false;
    await _luckPouch.spend(type.pouchCost);
    return _inner.prayWithExternalPouch(wishId, type);
  }
  // fetchInitialData / unlockSubSlot / purchaseCustomizeItem은 ⑧ 섹션 참고
}
```

### 10) `presentation/providers/wish_room_providers.dart`
```dart
final wishRoomRepositoryProvider = Provider<WishRoomRepository>((ref) => MockWishRoomRepository());

final wishRoomControllerProvider =
  AsyncNotifierProvider<WishRoomController, WishRoomData>(WishRoomController.new);

final wishRoomUiProvider =
  NotifierProvider<WishRoomUiController, WishRoomUiState>(WishRoomUiController.new);

final hasPrayedTodayProvider = Provider<bool>((ref) =>
  ref.watch(wishRoomControllerProvider).valueOrNull?.room.hasPrayedToday ?? false);

final canUnlockSlotByStreakProvider = Provider<bool>((ref) {
  final room = ref.watch(wishRoomControllerProvider).valueOrNull?.room;
  if (room == null) return false;
  return room.unlockedSubSlotCount < 2 && room.consecutivePrayerDays >= 3;
});
```

### 11) `presentation/controllers/wish_room_controller.dart` (골격)
```dart
class WishRoomController extends AsyncNotifier<WishRoomData> {
  WishRoomRepository get _repo => ref.read(wishRoomRepositoryProvider);

  @override
  Future<WishRoomData> build() async {
    final bundle = await _repo.fetchInitialData();
    return WishRoomData(room: bundle.room, pouchStatus: bundle.pouchStatus,
      dailyMessage: bundle.dailyMessage, isFirstVisit: bundle.isFirstVisit,
      customizeCatalog: bundle.customizeCatalog);
  }

  bool get hasAvailableSlot => state.valueOrNull?.room.hasAvailableSlot ?? false;

  Future<bool> prayForWish(String wishId, PrayerType type) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    if (type == PrayerType.daily && current.room.hasPrayedToday) return false;
    state = const AsyncLoading<WishRoomData>().copyWithPrevious(state);
    try {
      final ok = await _repo.prayForWish(wishId, type);
      final bundle = await _repo.fetchInitialData();
      state = AsyncData(current.copyWith(room: bundle.room, pouchStatus: bundle.pouchStatus));
      return ok;
    } catch (e, st) {
      state = AsyncError<WishRoomData>(e, st).copyWithPrevious(state);
      return false;
    }
  }
  // addWish / unlockSubSlot / loadCustomizeCatalog / purchaseCustomizeItem / applyCustomizeItem / markGuideSeen 동일 패턴
}
```

### 12) `presentation/controllers/wish_room_ui_controller.dart`
```dart
class WishRoomUiController extends Notifier<WishRoomUiState> {
  @override
  WishRoomUiState build() => const WishRoomUiState(step: WishRoomFlowStep.home);

  void goTo(WishRoomFlowStep step) => state = state.copyWith(step: step);
  void openGuide() => state = state.copyWith(showGuideDialog: true);
  void closeGuide() => state = state.copyWith(showGuideDialog: false);
  void triggerAnimation(WishRoomAnimationEvent event) =>
    state = state.copyWith(pendingAnimationEvent: event);
  void clearAnimation() => state = state.copyWith(clearAnimationEvent: true);
}
```

### 13) `presentation/state/wish_room_state.dart`
```dart
class WishRoomData {
  final WishRoom room;
  final FortunePouchStatus pouchStatus;
  final DailyMessage dailyMessage;
  final bool isFirstVisit;
  final List<CustomizeItem> customizeCatalog;
  const WishRoomData({required this.room, required this.pouchStatus,
    required this.dailyMessage, required this.isFirstVisit, this.customizeCatalog = const []});

  WishRoomVisualState get visualState => WishRoomVisualState.fromRoom(
    room, room.representativeWish?.growthStage ?? WishGrowthStage.ember);

  WishRoomData copyWith({WishRoom? room, FortunePouchStatus? pouchStatus,
      List<CustomizeItem>? customizeCatalog}) =>
    WishRoomData(room: room ?? this.room, pouchStatus: pouchStatus ?? this.pouchStatus,
      dailyMessage: dailyMessage, isFirstVisit: isFirstVisit,
      customizeCatalog: customizeCatalog ?? this.customizeCatalog);
}
```

### 14) `presentation/state/wish_room_ui_state.dart`
```dart
enum WishRoomFlowStep { home, empty, writingWish, praying, prayerCompleted,
  revisitCelebration, customizing, unlockingSlot }
enum WishRoomAnimationEvent { objectTouch, prayerBurst, streakLevelUp, growthStageUp, slotUnlocked }

class WishRoomUiState {
  final WishRoomFlowStep step;
  final bool showGuideDialog;
  final WishRoomAnimationEvent? pendingAnimationEvent;
  const WishRoomUiState({required this.step, this.showGuideDialog = false,
    this.pendingAnimationEvent});

  WishRoomUiState copyWith({WishRoomFlowStep? step, bool? showGuideDialog,
      WishRoomAnimationEvent? pendingAnimationEvent, bool clearAnimationEvent = false}) =>
    WishRoomUiState(step: step ?? this.step, showGuideDialog: showGuideDialog ?? this.showGuideDialog,
      pendingAnimationEvent: clearAnimationEvent ? null : (pendingAnimationEvent ?? this.pendingAnimationEvent));
}
```

### 15) `presentation/theme/wish_room_theme.dart` (골격)
```dart
class WishRoomColors {
  static const backgroundDeep = Color(0xFF120B22);
  static const backgroundMid = Color(0xFF241A3D);
  static const gold = Color(0xFFE8B34C);
  static const Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [backgroundDeep, backgroundMid]);

  static Color forGrowthStage(WishGrowthStage stage) => switch (stage) {
    WishGrowthStage.ember => const Color(0xFF7C7C7C),
    WishGrowthStage.smallCandle => const Color(0xFFC9A15A),
    WishGrowthStage.steadyCandle => const Color(0xFFE0B15C),
    WishGrowthStage.brightCandle => const Color(0xFFF2C25E),
    WishGrowthStage.goldenFlame => const Color(0xFFFFD700),
  };
}
class WishRoomTextStyles { /* titleXl, titleLg, bodyMd, bodySm, caption, dailyMessage, ctaLabel */ }
class WishRoomSpacing { static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0; }
class WishRoomRadius { static const sm = 8.0, md = 12.0, lg = 20.0, pill = 999.0; }
```

### 16) `presentation/widgets/wish_room_object.dart` (골격)
```dart
class WishRoomObject extends StatefulWidget {
  final WishRoomVisualState visual;
  const WishRoomObject({super.key, required this.visual});
  @override State<WishRoomObject> createState() => _WishRoomObjectState();
}
class _WishRoomObjectState extends State<WishRoomObject> with SingleTickerProviderStateMixin {
  late final AnimationController _breatheController =
    AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  double _touchBoost = 0;

  void _handleTap() {
    setState(() => _touchBoost = 0.3);
    Future.delayed(const Duration(milliseconds: 250), () => setState(() => _touchBoost = 0));
  }

  double _sizeForLevel(WishObjectLevel level) => switch (level) {
    WishObjectLevel.seed => 96, WishObjectLevel.glow => 108,
    WishObjectLevel.bloom => 120, WishObjectLevel.radiant => 132,
  };

  @override
  Widget build(BuildContext context) {
    final stage = widget.visual.representativeGrowthStage;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: WishRoomColors.objectGradientForStage(stage)),
          width: _sizeForLevel(widget.visual.objectLevel) + _touchBoost * 10,
          height: _sizeForLevel(widget.visual.objectLevel) + _touchBoost * 10,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 400),
            child: Text(stage.emoji, key: ValueKey(stage), style: const TextStyle(fontSize: 40))),
        ),
      ),
    );
  }
}
```

### 17) `presentation/screens/wish_room_riverpod_entry.dart` (골격 — 상세는 ⑬ 섹션)
```dart
class WishRoomRiverpodEntry extends StatelessWidget {
  const WishRoomRiverpodEntry({super.key});
  @override
  Widget build(BuildContext context) {
    final luckPouch = legacy_provider.Provider.of<LuckPouchProvider>(context);
    final navigatorKey = GlobalKey<NavigatorState>();
    return ProviderScope(
      overrides: [wishRoomRepositoryProvider.overrideWith(
        (ref) => RealCurrencyWishRoomRepository(luckPouch))],
      child: NavigatorPopHandler(
        onPopWithResult: (result) => navigatorKey.currentState?.maybePop(result),
        child: Navigator(key: navigatorKey,
          onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const WishRoomEntryScreen())),
      ),
    );
  }
}
```

### 18) `presentation/screens/wish_room_entry_screen.dart` (골격 — 상세는 ⑫-① 섹션)
```dart
class WishRoomEntryScreen extends StatefulWidget {
  const WishRoomEntryScreen({super.key});
  @override State<WishRoomEntryScreen> createState() => _WishRoomEntryScreenState();
}
class _WishRoomEntryScreenState extends State<WishRoomEntryScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), _enterMainScreen);
  }

  void _enterMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, anim, __) => FadeTransition(opacity: anim,
        child: ScaleTransition(scale: anim, child: const WishRoomScreen())),
    ));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _enterMainScreen,
    child: Container(decoration: const BoxDecoration(gradient: WishRoomColors.backgroundGradient),
      child: /* FadeTransition + ScaleTransition + 타이틀 텍스트 */ const SizedBox.shrink()),
  );
}
```

### 19) `presentation/screens/wish_room_screen.dart` (골격 — 상세는 ⑫-② 섹션)
```dart
class WishRoomScreen extends ConsumerWidget {
  const WishRoomScreen({super.key});

  Future<void> _startPrayerFlow(BuildContext context, WidgetRef ref, WishItem wish) async {
    final controller = ref.read(wishRoomControllerProvider.notifier);
    final stageBefore = wish.growthStage;
    final type = await showModalBottomSheet<PrayerType>(
      context: context, builder: (_) => PrayerTypeSheet(wish: wish));
    if (type == null) return;
    final ok = await controller.prayForWish(wish.id, type);
    if (!ok || !context.mounted) return;
    final updated = ref.read(wishRoomControllerProvider).valueOrNull?.room.representativeWish;
    final didLevelUp = updated != null && updated.growthStage != stageBefore;
    if (context.mounted) {
      showModalBottomSheet(context: context,
        builder: (_) => PrayerCompleteSheet(didLevelUp: didLevelUp));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(wishRoomControllerProvider);
    ref.listen(wishRoomControllerProvider, (prev, next) {
      if (next.valueOrNull?.isFirstVisit == true) {
        ref.read(wishRoomUiProvider.notifier).openGuide();
      }
    });
    return Scaffold(body: asyncData.when(
      data: (data) => CustomScrollView(slivers: [/* Header, Object, WishCardList 등 */]),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
    ));
  }
}
```

### 20) `presentation/screens/wish_slot_unlock_screen.dart` (골격 — 상세는 ⑫-⑨ 섹션)
```dart
class WishSlotUnlockScreen extends ConsumerWidget {
  const WishSlotUnlockScreen({super.key});

  Future<void> _unlock(BuildContext context, WidgetRef ref, {required bool viaPouch}) async {
    final controller = ref.read(wishRoomControllerProvider.notifier);
    final ok = await controller.unlockSubSlot(viaPouch: viaPouch);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '자리가 열렸어요!' : '복주머니가 부족해요')));
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(wishRoomControllerProvider);
    final canFree = ref.watch(canUnlockSlotByStreakProvider);
    return Scaffold(appBar: AppBar(title: const Text('소원 자리 확장')),
      body: asyncData.when(
        data: (data) => Column(children: [
          Row(children: data.room.slotStatuses.map((s) => _SlotTile(status: s)).toList()),
          if (canFree) ElevatedButton(onPressed: () => _unlock(context, ref, viaPouch: false),
            child: const Text('무료로 자리 열기 (연속 방문 보상)')),
          ElevatedButton(onPressed: () => _unlock(context, ref, viaPouch: true),
            child: const Text('복주머니 30개로 바로 열기')),
        ]),
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('오류: $e'),
      ));
  }
}
class _SlotTile extends StatelessWidget {
  final WishSlotStatus status;
  const _SlotTile({required this.status});
  @override Widget build(BuildContext context) =>
    Column(children: [Icon(status.isLocked ? Icons.lock : Icons.local_fire_department),
      Text(status.label)]);
}
```

> 나머지 18개 위젯/화면 파일(`wish_write_screen.dart`, `wish_history_screen.dart`,
> `wish_customize_screen.dart`, `prayer_type_sheet.dart`, `prayer_complete_sheet.dart`,
> `wish_card.dart`, `wish_card_list.dart`, `wish_guide_dialog.dart`, `category_chip_group.dart`,
> `growth_progress_card.dart`, `wish_room_background.dart`, `wish_room_header.dart`,
> `daily_message_card.dart`, `fortune_pouch_status_card.dart`, `prayer_streak_badge.dart`,
> `mock_wish_room_data.dart`, `customize_item_model.dart`, `fortune_pouch_status_model.dart`)은
> ⑦~⑫ 섹션에서 각 화면 스펙과 함께 구조가 이미 상세 서술되어 있으며, 실제 프로젝트에는 위 20개 골격과
> 동일한 계층 규칙(⑬ 섹션)을 따라 이미 완전한 형태로 구현되어 있다.


---

## ⑱ 테스트 전략

### 이미 실행/통과한 테스트
| 테스트 파일 | 검증 범위 | 결과 |
|---|---|---|
| `test/wish_room_entry_flow_test.dart` | 입장화면→메인화면 전환(자동 타이머 + 탭 즉시전환 2가지 경로)이 중첩 Navigator 안에서 정상 동작하는지 | 통과 |
| `test/wish_room_riverpod_smoke_test.dart` | `WishRoomRiverpodEntry`가 `ProviderScope`를 정상 생성하고, `LuckPouchProvider`를 override에 주입해도 크래시 없이 렌더링되는지(스모크 테스트) | 통과 |

### 테스트 작성 시 필수 준비 단계
1. **SharedPreferences mock 초기화** — 초회 가이드 팝업 상태가 `shared_preferences`에 영속화되므로, 위젯
   테스트 시작 전 항상 다음을 호출해야 실제 디스크 접근 없이 격리된 테스트가 가능하다:
   ```dart
   SharedPreferences.setMockInitialValues({});
   ```
2. **`tester.pump()` 시퀀스 설계** — `WishRoomEntryScreen`은 1400ms 딜레이 후 자동 전환되므로, 타이머 기반
   전환을 검증할 때는 `await tester.pump(const Duration(milliseconds: 1500));`로 딜레이를 초과하는 시간을
   명시적으로 흘려보내야 한다. 즉시 탭 전환 경로는 `await tester.tap(find.byType(WishRoomEntryScreen));
   await tester.pumpAndSettle();`로 검증한다.
3. **Repository는 항상 Mock으로 override** — 위젯 테스트는 `RealCurrencyWishRoomRepository`(실 재화 의존)를
   사용하지 않고, `ProviderScope(overrides: [wishRoomRepositoryProvider.overrideWith((ref) =>
   MockWishRoomRepository())], child: ...)` 형태로 완전히 격리된 상태에서 실행한다.
4. **회귀 검증 시 `git stash` 활용** — 대규모 리팩터링(예: EARN→SPEND 전환) 직후에는 `git stash`로 변경
   전 상태로 되돌려 테스트를 먼저 통과시킨 뒤, `git stash pop`으로 변경사항을 복원하고 다시 테스트해
   "새 코드가 실제로 무엇을 바꿨는지"를 대조 확인하는 방식을 이미 채택했다.

### 추가로 작성이 권장되는 테스트 (향후 확장)
| 테스트 대상 | 검증 포인트 |
|---|---|
| `WishGrowthStageX.fromGrowthPoint` | 경계값(19/20, 59/60, 119/120, 249/250)에서 정확히 단계가 전환되는지 |
| `WishRoomController.prayForWish` (daily) | `hasPrayedToday=true`일 때 Repository 호출 없이 즉시 `false` 반환하는지(mock의 호출 카운트로 검증) |
| `RealCurrencyWishRoomRepository.prayForWish` (deep/focused) | `LuckPouchProvider.canSpend`가 false일 때 차감 없이 실패 반환하는지 |
| `MockWishRoomRepository.unlockSubSlot` | `unlockedSubSlotCount==2`일 때 추가 해금 시도가 항상 실패하는지 |
| `WishRoomVisualState.fromRoom` | `consecutivePrayerDays` 3/7/14 경계에서 `WishObjectLevel`이 정확히 전환되는지 |
| Golden test | `WishRoomObject`가 5개 성장 단계 × 4개 오브젝트 레벨(20가지 조합) 중 최소 대표 조합에서 시각적 회귀가 없는지 |

### 테스트 커버리지 우선순위 원칙
비즈니스 로직(Repository, Controller, enum extension)을 우선 순위 1로, 애니메이션 타이밍을 포함한 위젯
테스트를 우선순위 2로 둔다. 애니메이션이 핵심 요구사항(사용자가 "UI는 반드시 확실하게 움직여야 함"을
요구)이기는 하지만, 애니메이션 자체의 시각적 정확성보다 **애니메이션을 트리거하는 상태 전이 로직의
정확성**이 결함 발생 시 더 큰 리스크(재화 이중 차감, 슬롯 초과 해금 등)를 가지기 때문이다.


---

## ⑲ 향후 확장 로드맵

### 1단계 (출시 직후, 저리스크 추가)
- `PrayerType.gratitude`(감사 치성) 활성화 — enum/라벨이 이미 정의되어 있어 `WishRoomController`에 분기
  하나만 추가하면 됨(⑯ 섹션 참고).
- 커스터마이즈 카탈로그 아이템 수 확대(현재 11개 → 시즌 테마 포함 20개+) — 데이터만 추가, 구조 변경 없음.
- 히스토리 화면에 소원별 상세 바텀시트(치성 기록 타임라인) 추가 — `WishCard.onTap` 연결만 필요.

### 2단계 (성장 지표 확인 후)
- 실시간 백엔드 연동(Firestore) — `WishRoomRepository` 교체 지점(⑬ 섹션)을 통해 `FirestoreWishRoomRepository`
  구현체를 추가하고 `wishRoomRepositoryProvider`만 교체하면 나머지 계층은 무수정.
- 연속 방문 알림/리마인더 — 앱 전역 푸시 인프라 완성 후 `consecutivePrayerDays` 끊김 감지 트리거 추가.
- 소원 성장 애니메이션 강화(단계 상승 시 파티클 이펙트) — `WishRoomAnimationEvent.growthStageUp` 이벤트가
  이미 정의되어 있으므로 `wishRoomUiProvider`에서 이 이벤트를 구독하는 파티클 오버레이 위젯만 추가.

### 3단계 (장기)
- 시즌 한정 오브제 스킨(`CustomizeUnlockType.eventLimited`) 운영 이벤트 캘린더 연동.
- 멀티 디바이스 동기화(로그인 계정 기반 소원방 데이터 클라우드 백업).
- 소원 달성 완료 처리("이 소원은 이루어졌어요" 마킹) — 현재 모델에는 완료 상태 필드가 없으므로 `WishItem`에
  `isFulfilled` 필드 추가와 함께 별도 UX(완료된 소원 아카이브) 설계가 필요한 중규모 확장.

### 확장 시 지켜야 할 원칙
모든 확장은 ⑬ 섹션의 계층 분리 원칙(Repository 교체 지점, 3중 상태 분리)을 절대 깨지 않는 범위에서
이루어져야 한다. 특히 신규 화면 추가 시에도 소원방 전용 디자인 토큰(⑮ 섹션)만 사용하고, 신규 데이터
소스 추가 시에도 항상 `WishRoomRepository` 인터페이스를 구현하는 방식으로 진행한다.


---

## ⑳ 리스크와 트레이드오프

### 검토했으나 채택하지 않은 대안들 (확정 사유 포함)
| 검토한 대안 | 채택하지 않은 이유 | 최종 채택안 |
|---|---|---|
| 메인 오브제로 "화분/새싹" 사용 | "성장"이라는 개념 자체는 잘 표현하지만, "치성/정성"이라는 서비스 정체성(기도 행위)과의 직접적 연결이 약함. 화분에 물을 주는 행위는 이미 다른 앱들에서 흔히 쓰인 클리셰라 차별성이 부족함 | **촛불 제단** — 정성/기도라는 한국 전통 정서와 직결되고, 불꽃의 밝기/색으로 성장 단계를 표현하기에 시각적으로도 자연스러움(③ 섹션 확정 사유) |
| 메인 오브제로 "수정구슬" 사용 | 신비로운 분위기는 연출되나, "5단계 성장"을 수정구슬 하나의 외형 변화로 표현하기엔 시각적 변주가 제한적(색만 바뀌는 정도)이며 촛불 대비 "정성을 들인다"는 행위 서사가 약함 | 동일(촛불 제단) |
| 빈 상태를 별도 전체 화면 라우트로 분리 | 네비게이션 스택이 불필요하게 깊어지고, "화면"이라기보다 "상태"의 특수 케이스이므로 별도 라우트 분리가 과설계임 | 각 화면 내부 조건부 렌더링으로 통합 처리(⑫-⑩ 섹션 확정 사유) |
| 소원 성장 시스템에서 시간 기반 자동 성장(정성 없이 시간이 지나면 저절로 성장) 도입 | "치성 행동"이 핵심 재미 중 하나인데, 시간만 지나면 성장하는 방식은 사용자의 능동적 행동(치성)을 무의미하게 만들어 핵심 재미를 스스로 훼손함 | growthPoint는 오직 치성 행동을 통해서만 누적(⑥ 섹션) |
| 복주머니를 소원방 안에서도 획득(EARN) 가능하게 유지 | 앱 전역에서 복주머니 획득처가 이미 다수 존재하는 상태에서 소원방까지 획득처로 겸하면 재화 순환 경로가 복잡해지고 인플레이션 리스크가 커짐. 사용자 요구사항에서도 "재화 충돌 해결"이 명시적으로 요구됨 | 소원방은 순수 SPEND(소비) 전용 공간으로 역할 고정(⑧ 섹션, 이전 세션에서 이미 확정/구현) |
| 슬롯 확장을 오직 복주머니 구매로만 제공 | 무과금 사용자의 재방문 유인이 약해짐 — "재방문 시스템"이라는 필수 시스템의 존재 의의가 사라짐 | 연속 방문일수 기반 무료 해금 경로와 복주머니 즉시구매 경로를 병행 제공(⑤/⑩ 섹션) |
| 꾸미기 아이템을 카테고리 무관하게 전부 다중 적용 허용 | 오브제 스킨/제단/배경/효과/시즌테마는 한 번에 하나만 적용되는 것이 시각적 일관성상 자연스러움(예: 오브제 스킨 2개를 동시 적용하면 모순) | `decoration` 카테고리만 다중 적용 허용, 나머지는 단일 적용(⑨ 섹션) |

### 잔존 리스크 (완화 방안 포함)
| 리스크 | 영향 | 완화 방안 |
|---|---|---|
| `RealCurrencyWishRoomRepository`가 내부적으로 `MockWishRoomRepository`를 감싸는 구조이므로, Mock의 인메모리 상태가 앱 재시작 시 소실됨(가이드 노출 여부만 SharedPreferences로 영속화) | 소원/성장치/슬롯 해금 상태가 실 기기에서 앱 재시작 시 초기화될 수 있음 | MVP 범위에서는 허용된 리스크로 명시(⑯ 섹션의 "실시간 서버 동기화 제외"와 동일 맥락). 정식 출시 전 로컬 영속화(Hive) 또는 백엔드 연동으로 반드시 교체 필요 |
| 성장 단계(5단계)와 오브제 레벨(4단계)이라는 2축 시각화가 사용자에게 혼란을 줄 수 있음(색이 바뀌는 것과 커지는 것이 서로 다른 의미임을 즉시 이해하기 어려울 수 있음) | 온보딩 실패 시 핵심 재미(성장) 체감 저하 | `WishGuideDialog`(5단계 온보딩)에서 두 축을 명확히 구분해 설명하는 문구를 포함(⑫-⑧ 섹션), 향후 UX 테스트로 이해도 검증 필요 |
| `growthPoint`가 무제한 누적되는 int 필드이므로 매우 오랜 기간 사용 시 이론적으로 큰 수가 될 수 있음 | 실질적 리스크는 낮음(개인 소원방 특성상 극단적 사용 빈도가 낮음) | 별도 방어 로직 불필요, 다만 `WishGrowthStage.goldenFlame`(최고단계) 도달 후에는 추가 누적이 UX상 의미 없어지므로 향후 "만개 완료" 상태 배지 등 추가 보상 설계 검토 대상(⑲ 섹션 3단계와 연계) |
| Provider(레거시)와 Riverpod의 공존 경계가 `WishRoomRiverpodEntry` 단 하나의 파일에 집중되어 있어, 이 파일의 구조를 잘못 수정하면 전체 소원방이 렌더링되지 않는 치명적 회귀가 발생할 수 있음(과거 실제로 발생했던 버그) | 회귀 시 소원방 전체 접근 불가 | ⑬ 섹션에 구조와 이유를 상세 문서화, `test/wish_room_riverpod_smoke_test.dart`로 스모크 테스트 상시 보호 |


---

## ㉑ 성공 지표 / 측정 방법

### 핵심 재미 5가지별 측정 지표
| 핵심 재미 | 측정 지표 | 목표 방향성 | 측정 근거 데이터 |
|---|---|---|---|
| 소원성장 | 소원당 평균 `growthPoint` 도달 단계, 사용자당 `goldenFlame` 도달 소원 비율 | 등록 후 7일 내 `smallCandle`(20pt) 이상 도달 비율 상승 | `WishItem.growthPoint`, `growthStage` |
| 치성액션 | 일일 치성 실행률(DAU 중 `prayForWish` 호출 비율), `deep`/`focused` 유료 치성 비중 | daily 무료 치성 실행률 우선 확보 → 유료 치성 전환율 순차 상승 | `PrayerSession` 기록, `prayerCount` |
| 복주머니 적립/사용 | 소원방 내 복주머니 소비량(다른 소비처 대비 비중), 슬롯 해금을 위한 복주머니 사용 비율 vs 무료 해금 비율 | 무과금 사용자도 무료 해금 경로로 이탈 없이 3슬롯까지 도달 | `FortunePouchStatus.usedToday`, `unlockedSubSlotCount` |
| 꾸미기 | 커스터마이즈 카탈로그 아이템 보유율/적용율, `decoration` 다중 적용 평균 개수 | 신규 사용자의 첫 7일 내 최소 1개 이상 아이템 적용 비율 확보 | `CustomizeItem.isOwned/isApplied` |
| 재방문 | `consecutivePrayerDays` 분포(3일/7일/14일 임계 돌파 비율), 소원방 재방문 리텐션(D1/D7/D30) | 연속 방문 3일 임계값 돌파 비율을 리텐션 선행 지표로 추적 | `WishRoom.consecutivePrayerDays`, `lastVisitedAt` |

### 시스템 단위 건전성 지표
- **대표소원슬롯시스템**: 슬롯 3개 모두 채워진 사용자 비율(참여 심화도 지표).
- **소원성장시스템**: 단계별 사용자 분포 히스토그램(ember~goldenFlame) — 특정 단계에서 정체가 심하면
  임계값(20/60/120/250) 재조정 신호로 활용.
- **치성시스템**: `PrayerType`별 선택 비율 — daily에만 편중되면 deep/focused의 가격/보상 밸런스 재검토.
- **복주머니시스템**: 소원방 소비처로서의 점유율(앱 전역 복주머니 소비 대비) — SPEND 전용 역할이 실제로
  기능하는지의 직접적 증거.
- **꾸미기시스템**: 구매형(`purchase`) vs 보상형(`growthReward`/`streakReward`) 아이템 획득 비율 — 보상형
  획득이 지나치게 어려우면 성장/재방문 동기부여 약화 신호.
- **재방문시스템**: `WishObjectLevel` 분포(seed~radiant) — 오브제 시각적 성장이 실제 재방문 습관과 연동
  되는지의 대리 지표.

### 측정 방법론
현재 코드베이스는 모든 지표의 원천 데이터를 이미 모델 필드로 보유하고 있으므로(`growthPoint`,
`prayerCount`, `consecutivePrayerDays`, `isOwned`/`isApplied`, `unlockedSubSlotCount`), 별도의 신규
트래킹 필드 추가 없이 **기존 Repository 응답을 그대로 애널리틱스 이벤트로 매핑**하는 방식이 가장
효율적이다. `WishRoomController`의 각 액션 메서드(`prayForWish`, `unlockSubSlot`,
`purchaseCustomizeItem` 등) 성공 반환 시점에 애널리틱스 이벤트 전송 훅을 추가하는 것을 표준 구현
방식으로 확정한다.

---

## ㉒ 최종결론

신통방통 앱의 개인 소원방은 **"촛불 제단"을 중심 오브제로 삼아, 소원성장·치성액션·복주머니 소비·꾸미기·
재방문이라는 5가지 핵심 재미가 하나의 응집된 루프로 순환하는 몰입형 개인 공간**으로 최종 설계되었다.
이 설계는 다음 세 가지 축에서 이미 실제 코드로 완결되어 있다.

**첫째, 시스템 설계 완결성.** 대표소원슬롯(3슬롯, 무료+유료 해금 병행), 소원성장(개별 소원 단위 5단계),
치성(3종 활성+1종 예약), 복주머니(EARN→SPEND 전환으로 소비처 역할 고정), 꾸미기(6카테고리, decoration만
다중 적용), 재방문(연속 방문일수 기반 4단계 오브제 레벨)까지 6개 필수 시스템 전부가 서로 다른 Riverpod
Provider와 모델로 명확히 분리되어 있으면서도, `WishRoomVisualState`라는 단일 파생 상태를 통해 하나의
오브제 위에서 색조(성장)와 크기(재방문)라는 두 개의 독립된 시각 채널로 동시에 표현된다. 이는 "정적 카드
묶음 금지, UI는 반드시 확실하게 움직여야 함"이라는 요구사항을 시스템 레벨에서부터 충족하는 구조다.

**둘째, 아키텍처 확장성.** feature-first 구조와 Repository 교체 지점(`wishRoomRepositoryProvider` 단
한 줄) 설계로, Mock 데이터에서 실 재화 연동(`RealCurrencyWishRoomRepository`)으로의 전환이 이미
완료되었고, 향후 실시간 백엔드 연동 역시 동일한 지점만 교체하면 되는 구조를 갖추었다. Provider(레거시)와
Riverpod의 공존 경계 역시 `WishRoomRiverpodEntry` 단일 지점으로 격리되어, 과거 발생했던 "인트로 이후
빈 화면" 버그의 재발을 구조적으로 차단한다.

**셋째, 실증된 품질.** 이 문서의 모든 코드 발췌는 추상적 설계안이 아니라 `flutter analyze`(에러 0개),
`flutter test`(3개 테스트 통과), `flutter build web --release`(빌드 성공)를 모두 통과한 **실제 동작하는
코드베이스**에서 직접 발췌한 것이다. 22개 섹션에 걸친 이 문서는 아이디어 제안서가 아니라, 이미 구현된
시스템의 설계 근거와 확장 지침을 기록한 **개발 완료 보고서 겸 향후 유지보수 가이드**로서 기능한다.

결론적으로, 개인 소원방은 "단순히 소원을 적어두는 리스트"가 아니라 **사용자가 매일 돌아와 촛불에 정성을
쏟고, 그 정성이 시각적으로 축적되는 것을 확인하며, 복주머니라는 의미 있는 재화를 소비해 공간을 더 넓히고
꾸며나가는, 하나의 완결된 리텐션 루프를 갖춘 기능**으로 최종 확정되었다. 이번 세션에서 남은 작업은 없으며,
문서와 코드 모두 즉시 다음 단계(실제 백엔드 연동 또는 정식 QA)로 이행할 수 있는 상태다.

---

## ㉓ 화면별 위젯 트리 상세 (구현 코드 기준)

이 섹션은 ⑫ 섹션의 화면 스펙표를 보완해, **실제 코드에 존재하는 위젯 계층을 트리 형태로 1:1 발췌**한다.
들여쓰기는 실제 부모-자식 위젯 관계이며, 조건부 분기는 `[if ...]`로 표기했다. 트리는 1차 구현 범위
(`WishRoomController`/`WishRoomUiController`/`MockWishRoomRepository` 기준)가 반영된 최신 코드를 기준으로 한다.

### ㉓-0. 네비게이션 스택 최상위 구조 (중첩 Navigator)

```
WishRoomRiverpodEntry (ProviderScope 경계, wishRoomRepositoryProvider override)
 └─ NavigatorPopHandler (기기 뒤로가기를 내부 Navigator에 우선 위임)
     └─ Navigator(key: navigatorKey)                    ← 소원방 전용 중첩 Navigator
         └─ [initial route] WishRoomEntryScreen
             └─ (pushReplacement) WishRoomScreen         ← 이 Navigator 안에서만 발생
                 ├─ (push) WishWriteScreen
                 ├─ (push) WishHistoryScreen
                 ├─ (push) WishCustomizeScreen
                 └─ (push) WishSlotUnlockScreen
```
**주의(문서화된 버그 수정 사항)**: `WishWriteScreen`/`WishHistoryScreen`/`WishCustomizeScreen`/
`WishSlotUnlockScreen`으로의 `Navigator.of(context).push(...)` 호출은 모두 `WishRoomScreen`의
`BuildContext`를 사용하므로, 이 `BuildContext`가 항상 위 중첩 `Navigator` 서브트리 내부에 있어야
`ProviderScope`를 벗어나지 않는다. `WishRoomRiverpodEntry`가 이 경계를 강제한다.

### ㉓-1. 입장 화면 (`WishRoomEntryScreen`)

```
Scaffold(backgroundColor: backgroundDeep)
 └─ GestureDetector(onTap: _enterMainScreen)             ← 화면 전체 탭으로 스킵
     └─ DecoratedBox(gradient: backgroundGradient)
         └─ Center
             └─ FadeTransition(opacity: _fade)
                 └─ ScaleTransition(scale: _scale)        ← 0.92 → 1.0
                     └─ Column(mainAxisSize: min)
                         ├─ Text('당신의 소원이 머무는 방', titleXl)
                         ├─ SizedBox(height: md)
                         └─ Text('조용히 문을 엽니다…', bodySm)
```
로컬 상태: `AnimationController _controller`(900ms, 1회 forward) + `Timer`(1400ms, `_enterMainScreen`
자동 호출). Riverpod 의존 없음(순수 정적 화면).

### ㉓-2. 메인 화면 (`WishRoomScreen`) — 전체 위젯 트리

```
Scaffold(backgroundColor: backgroundDeep)
 └─ SafeArea
     └─ Stack
         ├─ Positioned.fill
         │    └─ WishRoomBackground(sparkleLevel: visualState.backgroundSparkleLevel)
         │         └─ RepaintBoundary
         │             └─ Stack(fit: expand)
         │                 ├─ DecoratedBox(gradient)
         │                 └─ AnimatedBuilder(_starController)
         │                     └─ CustomPaint(_StarfieldPainter)
         │
         └─ asyncData.when(...)
             ├─ [loading] Center → CircularProgressIndicator(gold)
             ├─ [error]   Center → Padding → Column(안내문구 + '다시 시도' ElevatedButton
             │                                        → ref.invalidate(wishRoomControllerProvider))
             └─ [data]    CustomScrollView
                 slivers:
                 ├─ SliverToBoxAdapter
                 │    └─ WishRoomHeader(onHelpTap: WishGuideDialog.show)
                 │         └─ Row('소원방' titleXl, IconButton(help), IconButton(settings))
                 │
                 ├─ SliverToBoxAdapter
                 │    └─ Padding → Column
                 │         ├─ WishRoomObject(                       ← 아래 ㉓-11 상세 트리 참고
                 │         │     visualState: data.visualState,
                 │         │     onTap: () → triggerAnimation(objectTouch),
                 │         │     pendingAnimationEvent: ref.watch(select),
                 │         │     onAnimationConsumed: () → clearAnimation())
                 │         ├─ SizedBox(height: md)
                 │         └─ DailyMessageCard(message: data.dailyMessage)
                 │
                 ├─ SliverToBoxAdapter
                 │    └─ WishCardList(wishes: representativeWishes,
                 │                    onWishTap: _handleWishCardTap,
                 │                    onEmptyCtaTap: _openWriteScreen)
                 │         ├─ [wishes.isEmpty] GestureDetector → Container → Column
                 │         │                     ('아직 이 방엔 소원이 없어요' 안내 카드)
                 │         └─ [else] ListView(horizontal)
                 │                     └─ WishCard(wish, onTap) × N (≤3)
                 │                          └─ Row(emoji, [if isRepresentative] '대표' 골드 배지)
                 │                          └─ Text(title) / Text(_statusLabel)
                 │
                 ├─ [if representativeWish != null] SliverToBoxAdapter
                 │    └─ Padding → GrowthProgressCard(wish: representativeWish)
                 │         └─ Column(emoji+title+label Row, 진행률 바 Stack, nextLabel Text)
                 │
                 ├─ SliverToBoxAdapter
                 │    └─ Padding → Row
                 │         ├─ Expanded → FortunePouchStatusCard(status: data.pouchStatus)
                 │         └─ Expanded → PrayerStreakBadge(consecutivePrayerDays, totalPrayerCount)
                 │
                 └─ SliverToBoxAdapter
                      └─ Padding → Column
                          ├─ SizedBox(전체폭) → ElevatedButton(gold)   ← 메인 CTA
                          │     onPressed: representativeWish == null
                          │       ? _openWriteScreen : _startPrayerFlow
                          │     child: hasPrayedToday ? deep.ctaLabel : daily.ctaLabel
                          ├─ SizedBox(height: sm)
                          └─ Row
                              ├─ Expanded → OutlinedButton('내 소원 보기') → _openHistoryScreen
                              └─ Expanded → OutlinedButton('방 꾸미기') → _openCustomizeScreen
```

**이 화면에서 열리는 일시적(transient) 오버레이 4종** (트리에는 없지만 `Navigator`/`showModalBottomSheet`/
`showDialog`/`SnackBar`로 별도 라우트/오버레이로 뜬다):
- `AlertDialog`(대표 소원 교체 확인, `_handleWishCardTap` 내부에서 서브 소원 탭 시)
- `PrayerTypeSheet` → `PrayerCompleteSheet` (치성 플로우, `_startPrayerFlow` 내부)
- `WishGuideDialog` (헤더 도움말 탭 또는 최초 방문 시 `ref.listen`①으로 자동 노출)
- **`SnackBar`(축하 메시지)** — `ref.listen`②이 `streakLevelUp`/`slotUnlocked` 신호를 감지하면
  `Future.microtask`로 다음 프레임에 표시(㉕-2/㉕-3에서 신규 추가). `WishSlotUnlockScreen`처럼
  이미 `pop()`된 다른 화면에서 트리거된 신호도 이 화면이 받아 처리한다.

**`build()` 내부에 존재하는 `ref.listen` 리스너 2개** (위젯 트리 노드는 아니지만 화면의 실제
동작을 이해하려면 반드시 함께 봐야 한다 — 둘 다 매 리빌드마다 재등록되지 않고 Riverpod이
내부적으로 1회만 등록/유지한다):

| # | 구독 대상 | 발동 조건 | 수행 동작 |
|---|---|---|---|
| ① | `wishRoomControllerProvider` 전체 | `data.isFirstVisit == true` && 이전 값이 `null`(최초 로딩 완료 시점 단 1회) | `WishGuideDialog.show()` → 닫히면 `markGuideSeen()` |
| ② | `wishRoomUiProvider.select((s) => s.pendingAnimationEvent)` | `next`가 `streakLevelUp` 또는 `slotUnlocked` | 즉시 `clearAnimation()` 호출(신호 소비) → 다음 프레임에 `SnackBar` 표시 |

> **주의**: ①은 `wishRoomControllerProvider`(서버 데이터) 전체를 구독하므로 `prayForWish()` 등
> 데이터가 바뀔 때마다 콜백 자체는 호출되지만, 내부 조건(`isFirstVisit && previous==null`)이
> 최초 로딩 시 단 한 번만 참이 되므로 실제 동작은 1회로 제한된다. ②는 `select()`로 좁혀서
> `pendingAnimationEvent`가 실제로 바뀔 때만 호출된다.

### ㉓-3. 대표 소원 교체 확인 다이얼로그 (`_handleWishCardTap` 내부 `AlertDialog`)

```
AlertDialog(backgroundColor: backgroundMid)
 ├─ title: Text('대표 소원을 바꿀까요?', titleLg)
 ├─ content: Text('"{wish.title}"을 대표 소원으로 설정하면\n메인 오브제와 정성 진행률이...', bodySm)
 └─ actions: [
      TextButton('취소' textSecondary) → pop(false),
      TextButton('대표로 설정' gold, bold) → pop(true),
    ]
```
`pop(true)` 후 `controller.setRepresentative(wish.id)` 호출 → 성공/실패에 따라 `SnackBar` 노출.

### ㉓-4. 소원 작성 화면 (`WishWriteScreen`)

```
Scaffold(backgroundColor: backgroundDeep)
 └─ DecoratedBox(gradient)
     └─ SafeArea
         └─ Padding
             └─ Column
                 ├─ Row → IconButton(close) → pop
                 ├─ SizedBox(sm)
                 ├─ Text('오늘의 마음을 담아\n조용히 소원을 빌어보세요', titleLg)
                 ├─ SizedBox(lg)
                 ├─ Container(surfaceCard)
                 │    └─ TextField(controller, maxLines:3, maxLength:60, onChanged: setState)
                 ├─ SizedBox(lg)
                 ├─ Text('어떤 마음에 정성을 담고 싶으신가요?', bodySm)
                 ├─ SizedBox(sm)
                 ├─ CategoryChipGroup(selected: _selectedCategory, onSelected: setState)
                 │    └─ Wrap → GestureDetector → AnimatedContainer(150ms) × 7개 칩
                 ├─ Spacer
                 └─ SizedBox(전체폭) → ElevatedButton
                      onPressed: canSave ? _save : null
                      child: _isSaving ? CircularProgressIndicator(20x20) : Text('소원 담기')
```
로컬 상태: `_controller`(TextEditingController), `_selectedCategory`, `_isSaving`. `_save()`가
`controller.addWish(...)` 완료 후 `Navigator.pop()`.

### ㉓-5. 치성 종류 선택 바텀시트 (`PrayerTypeSheet`)

```
showModalBottomSheet(backgroundColor: transparent, isScrollControlled: true)
 └─ Container(backgroundMid, rounded top)
     └─ SafeArea
         └─ Column(mainAxisSize: min)
             ├─ Text('"{wish.title}"에\n어떻게 정성을 담을까요?', titleLg)
             ├─ SizedBox(lg)
             ├─ _buildOption(daily,   enabled: !hasPrayedToday)
             ├─ SizedBox(sm)
             ├─ _buildOption(deep,    enabled: pouchStatus.totalCount >= 1)
             ├─ SizedBox(sm)
             └─ _buildOption(focused, enabled: pouchStatus.totalCount >= 3)

_buildOption(type, enabled, disabledReason):
  GestureDetector(onTap: enabled ? pop(type) : null)
   └─ Opacity(enabled ? 1.0 : 0.45)
       └─ Container(surfaceCard) → Row
           ├─ Expanded → Column(type.label bold, 설명/비활성이유 caption)
           └─ [if enabled] Column('+{gain}' titleLg, '성장치' caption)
```
반환값: 선택된 `PrayerType` 또는 취소 시 `null` — `Navigator.pop(type)`으로 상위(`_startPrayerFlow`)에 전달.

### ㉓-6. 기도 완료 바텀시트 (`PrayerCompleteSheet`)

```
Container(backgroundMid, rounded top)
 └─ SafeArea
     └─ Column(mainAxisSize: min)
         ├─ AnimatedBuilder(_glow) → Container(72x72 circle, objectGlowGradient + BoxShadow)
         ├─ SizedBox(lg)
         ├─ AnimatedBuilder(_glow) → Opacity(_glow.value) → Text('당신의 소원이 방 안에...', titleLg)
         ├─ SizedBox(sm)
         ├─ Text('당신의 진심이 빛으로 남았어요', bodySm)
         ├─ SizedBox(md)
         ├─ Text(pouchUsed>0 ? '복주머니 N개로...' : '오늘의 무료 정성을...', caption)
         ├─ [if didLevelUp]      SizedBox(md) → Container(gold border, '🎉 {newStageLabel} 단계로 성장했어요')
         ├─ [if didUnlockNewSlot] SizedBox(sm) → Container(success border, '✨ 새로운 소원 자리가 열렸어요')
         ├─ SizedBox(lg)
         └─ SizedBox(전체폭) → ElevatedButton('내일도 밝히러 올게요') → pop
```
로컬 상태: `AnimationController _controller`(700ms, `easeOutCubic`) 1회 forward, `didLevelUp`과
`didUnlockNewSlot` 배지는 서로 **독립적으로 동시에** 노출될 수 있음(같은 치성에서 두 조건 모두 충족 가능).

### ㉓-7. 내 소원 기록 화면 (`WishHistoryScreen`)

```
Scaffold(backgroundColor: backgroundDeep)
 └─ AppBar('내 소원 기록', transparent)
 └─ DecoratedBox(gradient)
     └─ SafeArea
         └─ asyncData.when(...)
             ├─ [loading] Center → CircularProgressIndicator
             ├─ [error]   Center → Text('잠시 후 다시 시도해주세요')
             └─ [data]
                 ├─ [wishes.isEmpty] Center → Text('지금까지 당신이 품어온 마음들')
                 └─ [else] ListView.builder
                      itemBuilder → Padding → Column
                          ├─ WishCard(wish, 전체폭)
                          ├─ SizedBox(sm)
                          └─ GrowthProgressCard(wish)
```
탭 인터랙션 없음(조회 전용). `WishCard`/`GrowthProgressCard`는 메인 화면과 동일 위젯 재사용.

### ㉓-8. 방 꾸미기 화면 (`WishCustomizeScreen`)

```
Scaffold(backgroundColor: backgroundDeep)
 └─ AppBar('방 꾸미기', transparent)
 └─ DecoratedBox(gradient)
     └─ SafeArea
         └─ asyncData.when(...)
             └─ [data]
                 ├─ [catalog.isEmpty] Center → CircularProgressIndicator   ← 최초 로드 대기
                 └─ [else] Column
                     ├─ SizedBox(height: 48) → ListView(horizontal)         ← 카테고리 탭 6개
                     │     └─ GestureDetector(setState) → AnimatedContainer(150ms, Pill)
                     │          └─ Row(category.emoji, category.label)
                     ├─ SizedBox(md)
                     └─ Expanded → GridView.builder(2열, aspectRatio 0.85)
                          └─ _CustomizeItemCard(item, onTap: _handleTap) × N
                               GestureDetector → AnimatedContainer(200ms, 적용중이면 gold 2px 테두리)
                                └─ Column
                                    ├─ Expanded → Center → Text(item.previewEmoji, 36)
                                    ├─ Text(item.name)
                                    ├─ SizedBox(xs)
                                    └─ Text(적용중/보유중/가격/해금조건 캡션 4단계 분기)
```
로컬 상태: `_selected`(현재 카테고리 탭). `initState`에서 `Future.microtask`로
`loadCustomizeCatalog()` 1회 트리거(카탈로그가 비어 있을 때만 실제로 fetch, 재호출 시 캐시 사용).

### ㉓-9. 사용 방법 안내 팝업 (`WishGuideDialog`)

```
Dialog(backgroundMid, rounded)
 └─ Padding
     └─ Column(mainAxisSize: min)
         ├─ Text('당신만의 소원방에 오신 걸 환영해요', titleLg)
         ├─ SizedBox(md)
         ├─ for step in _steps(5개): Padding → Column(step.$1 gold bold, step.$2 caption)
         ├─ SizedBox(md)
         └─ SizedBox(전체폭) → ElevatedButton('시작하기') → pop
```
정적 다이얼로그(내부 애니메이션 없음). 최초 방문 시 `WishRoomScreen`의 `ref.listen`에서
자동 노출, 이후 헤더의 도움말 아이콘으로 재노출 가능.

### ㉓-10. 슬롯 확장 화면 (`WishSlotUnlockScreen`)

```
Scaffold(backgroundColor: backgroundDeep)
 └─ AppBar('소원 자리 넓히기', transparent)
 └─ DecoratedBox(gradient)
     └─ SafeArea(top: false)
         └─ asyncData.when(...)
             └─ [data]
                 └─ Padding → Column
                     ├─ Text('이 방에는 소원을 담을\n자리가 세 곳 있어요', titleLg)
                     ├─ SizedBox(lg)
                     ├─ Row → _SlotTile(status) × 3 (Expanded 각각)
                     │     └─ Container(96h, [if representative] gold 테두리)
                     │          └─ Center → Column(Icon(잠김/불꽃), SizedBox, Text(status.label))
                     ├─ SizedBox(xl)
                     └─ [if allUnlocked] Text('모든 자리가 열렸어요...')
                        [else]
                          [if canUnlockByStreak] SizedBox(전체폭) → ElevatedButton(gold)
                                                    '무료로 자리 열기 (연속 방문 보상)'
                          [else] Text('연속 {3or7}일 방문하면 무료로...')
                          SizedBox(sm)
                          SizedBox(전체폭) → OutlinedButton('복주머니 30개로 바로 열기')
```
`_unlock(viaPouch)` 성공 시 `SnackBar` + `Navigator.pop()`, 실패 시 `SnackBar`만(화면 유지).

### ㉓-11. 메인 인터랙티브 오브제 (`WishRoomObject`) — 재사용 위젯 상세 트리

```
RepaintBoundary
 └─ GestureDetector(onTap: _handleTap)
     └─ AnimatedBuilder(_breatheController, 3s repeat-reverse)
         └─ AnimatedContainer(250ms, size+60, BoxShadow(stageTone, intensity 기반))
             └─ AnimatedScale(200ms, scale: 1.0 + touchBoost + burstBoost*0.5)
                 └─ AnimatedContainer(500ms, size, RadialGradient stageGradient)
                     └─ AnimatedSwitcher(400ms)
                         └─ Text(stage.emoji, key: ValueKey(stage))
```
`intensity = baseGlow + touchBoost + burstBoost + breathe`(0~1 clamp). `size`는 `WishObjectLevel`
(seed/glow/bloom/radiant = 96/108/120/132), `stageGradient`/`stageTone`은 `representativeGrowthStage`
(ember~goldenFlame)에서 파생 — **크기(재방문 축)와 색조(성장 축)가 서로 다른 데이터에서 독립적으로
계산되어 하나의 오브제 위에 동시 적용**되는 것이 이 위젯의 핵심 설계 포인트.

---

## ㉔ 상태 전이도 (State Transition Diagrams)

이 섹션은 소원방 모듈에 존재하는 5개의 독립적인 상태 축을 각각 전이도로 정리한다. **실제 코드에서
호출되는 지점만 화살표로 표시**했으며, enum에는 정의되어 있으나 코드상 트리거 호출부가 없는 경우는
"⚠ 미연결"로 명시해 설계 문서와 코드의 정합성을 정직하게 남긴다.

### ㉔-1. 서버/영속 데이터 상태 — `AsyncValue<WishRoomData>` (`wishRoomControllerProvider`)

```
                 build() 최초 호출
                        │
                        ▼
                 ┌─────────────┐
        ┌───────▶│ AsyncLoading │◀────────────────────────────┐
        │        └──────┬──────┘                              │
        │               │ repo.fetchInitialData() 성공          │
        │               ▼                                      │
        │        ┌─────────────┐   각 액션 메서드 호출 시         │
        │        │  AsyncData  │───────────────────────────────┘
        │        │(WishRoomData)│  (copyWithPrevious로 이전 데이터 유지)
        │        └──────┬──────┘
        │               │ 액션 실패(catch)
        │               ▼
        │        ┌─────────────┐
        └────────│ AsyncError  │  ref.invalidate(...) 또는 화면 재진입 시 재시도
                 └─────────────┘
```

**액션별 전이 상세 (Controller 메서드 기준)**:

| 메서드 | Loading 경유 | 성공 시 다음 상태 | 실패 시 |
|---|---|---|---|
| `build()` (최초) | ✅ (초기 상태 자체가 loading) | `AsyncData(초기 bundle)` | `AsyncError` |
| `addWish()` | ✅ | `AsyncData(wishes에 신규 항목 append)` | `AsyncError.copyWithPrevious` |
| `prayForWish()` | ✅ (단, `daily`인데 `hasPrayedToday`면 Loading 진입 없이 즉시 `false` 반환) | `AsyncData(room/pouchStatus/dailyMessage 갱신)` | `AsyncError.copyWithPrevious` |
| `unlockSubSlot()` | ✅ | `AsyncData(room/pouchStatus 갱신)` | `AsyncError.copyWithPrevious` |
| `setRepresentative()` | ✅ (단, 대상이 존재하지 않으면 `false` 즉시 반환, 이미 대표면 Loading 없이 `true` 즉시 반환) | `AsyncData(room 갱신)` | `AsyncError.copyWithPrevious` |
| `loadCustomizeCatalog()` | ❌ (Loading 미경유, catalog가 이미 있으면 스킵) | `AsyncData(customizeCatalog 채움)` | `AsyncError.copyWithPrevious` |
| `purchaseCustomizeItem()` | ✅ | `AsyncData(catalog/pouchStatus 갱신)` | `AsyncError.copyWithPrevious` |
| `applyCustomizeItem()` | ❌ (Loading 미경유) | `AsyncData(catalog 갱신)` | `AsyncError.copyWithPrevious` |
| `markGuideSeen()` | ❌ (Loading 미경유) | `AsyncData(isFirstVisit: false)` | (에러 처리 없음 — repo 호출만 await) |

### ㉔-2. 화면 흐름 상태 — `WishRoomFlowStep` (`wishRoomUiProvider.step`)

**진입 가드(㉕-4)**: 아래 3개 진입점(`_openWriteScreen`/`_openCustomizeScreen`/
`_startPrayerFlow`) 모두 함수 맨 앞에서 `if (ref.read(wishRoomUiProvider).step !=
WishRoomFlowStep.home) return;` 가드를 거친다 — 즉 **`home`이 아닌 동안 진입점을 다시 호출하면
아무 것도 하지 않고 즉시 리턴**한다(다이어그램의 모든 화살표는 이 가드를 통과한 이후의 전이만
표현함).

```
                                 ┌──────┐
                    ┌───────────▶│ home │◀──────────────────────────────────┐
                    │            └──┬───┘                                    │
                    │  (guard: step==home 이어야 아래 진입점 통과)             │
                    │               │                                        │
                    │               ├─ _openWriteScreen() ───────────────┐   │
                    │               │                                     │   │
                    │               │  [슬롯 없음]        [슬롯 있음]      │   │
                    │               ▼                     ▼               │   │
                    │      ┌─────────────────┐   ┌──────────────┐        │   │
                    │      │  unlockingSlot   │   │  writingWish │        │   │
                    │      └────────┬─────────┘   └──────┬───────┘        │   │
                    │               │ Navigator.push       │ Navigator.push │   │
                    │               │ WishSlotUnlockScreen  │ WishWriteScreen│   │
                    │               │ pop 후 goTo(home)      │ pop 후 goTo(home)│
                    │               └───────────────────────┴────────────────┤
                    │                                                        │
                    │  _openCustomizeScreen()                                │
                    │         │                                              │
                    │         ▼                                              │
                    │  ┌──────────────┐   Navigator.push                     │
                    │  │  customizing │──WishCustomizeScreen──▶(pop→goTo home)┤
                    │  └──────────────┘                                      │
                    │                                                        │
                    │  _startPrayerFlow() [대표 소원 있음]                    │
                    │         │                                              │
                    │         ▼                                              │
                    │  ┌──────────────┐  PrayerTypeSheet 취소/실패            │
                    │  │   praying    │──────────────────────────────────────┤
                    │  └──────┬───────┘                                      │
                    │          │ 치성 성공(controller.prayForWish)            │
                    │  ┌───────┴────────────────┬─────────────────────┐      │
                    │  │ 슬롯 신규 해금 O          │성장단계 상승O(레벨X)  │둘다X │
                    │  ▼                        ▼                     ▼      │
                    │┌──────────────────┐┌──────────────┐┌──────────────┐    │
                    ││revisitCelebration││prayerCompleted││prayerCompleted│    │
                    │└────────┬─────────┘└──────┬───────┘└──────┬───────┘    │
                    │         │  PrayerCompleteSheet(showModalBottomSheet)    │
                    │         │  닫힘(3개 경로 모두 동일 시트, 배지 유무만 다름) │
                    │         └───────────────────┴───────────────┴───────────┘
                    │  치성 실패(복주머니 부족) → SnackBar 표시 → 곧바로 home 복귀 ┘
                    └────────────────────────────────────────────────────────

   [의도적 미사용] empty — enum에 정의되어 있으나 goTo(empty) 호출 없음(유지).
                          (⑫-⑩ 설계 결정에 따라 WishCardList 내부 조건부 렌더링으로 대체 —
                           "빈 상태"는 별도 flow step 전환이 아니라 항상 home 안에서 표현됨)
```

**모든 실제 하위 상태는 예외 없이 `home`으로만 복귀하는 단방향 유한 상태 머신**이다(하위 상태끼리
직접 전이하는 경로는 없음) — 이는 "메인 화면이 항상 모든 흐름의 유일한 허브"라는 ⑫-② 설계 의도를
그대로 반영한다. `unlockingSlot`은 ㉕-4에서 새로 연결되어 이제 다른 6개 상태와 동일하게
`home`에서 나가고 `home`으로만 복귀하는 스포크(spoke) 구조에 포함된다.

**가드가 막아주는 구체적 레이스 컨디션 예시**: 사용자가 메인 CTA를 빠르게 두 번 탭하면, 첫 탭이
`step`을 `praying`으로 바꾸고 `PrayerTypeSheet`를 여는 `await`에 진입한 그 순간(시트가 화면에
그려지기까지의 짧은 프레임 갭) 두 번째 탭 이벤트가 `_startPrayerFlow`를 다시 호출할 수 있다.
가드가 없으면 `PrayerTypeSheet.show()`가 중첩 호출되어 두 개의 바텀시트가 겹쳐 쌓이는 문제가
생길 수 있었다 — 가드 추가로 두 번째 호출은 `step != home`(이미 `praying`)이라 즉시 리턴된다.

**[✅ 개선 완료] `WishRoomFlowStep.step`이 실제로 읽히도록 가드 추가**: 기존에는 `step`이
`goTo()`로 값만 갱신되고 어디서도 `watch`/`read`되지 않는 "쓰기만 하는" 상태였다. 이제
`_openWriteScreen`/`_openCustomizeScreen`/`_startPrayerFlow` 각 진입점 첫 줄에서
`ref.read(wishRoomUiProvider).step != WishRoomFlowStep.home`이면 즉시 `return`하는 가드를
추가했다 — 바텀시트/다이얼로그가 열려 있는 동안 버튼을 빠르게 연속 탭해 동일 흐름이 중복
시작(예: `Navigator.push`가 두 번 겹쳐 쌓이는 문제)되는 것을 막는다(㉕-3 참고).

### ㉔-3. 애니메이션 신호 상태 — `WishRoomAnimationEvent?` (`wishRoomUiProvider.pendingAnimationEvent`)

```
null (기본값)
  │
  │ triggerAnimation(event)
  ▼
event (pendingAnimationEvent = event)
  │
  ├─ WishRoomObject.didUpdateWidget에서 감지 → _maybeConsumePendingEvent()
  │  (objectTouch / prayerBurst / growthStageUp만 여기서 소비)
  │
  └─ WishRoomScreen.build()의 ref.listen에서도 동시에 감지
     (streakLevelUp / slotUnlocked는 여기서만 소비 — 오브제 대신
      화면 레벨 스낵바로 표현)
  ▼
┌─────────────────────────────┬─────────────────────────────────────┐
│ objectTouch/prayerBurst/     │ streakLevelUp / slotUnlocked          │
│ growthStageUp                │                                       │
│ → WishRoomObject가 소비      │ → WishRoomScreen의 ref.listen이 소비   │
├─────────────────────────────┼─────────────────────────────────────┤
│ _playBurst() 실행            │ SnackBar(축하 메시지) 즉시 표시         │
│ Timer(0) 예약                │ clearAnimation() 즉시 호출             │
│  → onAnimationConsumed       │  → pendingAnimationEvent = null       │
│  → clearAnimation()          │                                       │
│  → pendingAnimationEvent=null│                                       │
└─────────────────────────────┴─────────────────────────────────────┘
```

**트리거 호출 지점 (실제 코드 기준, ✅ 5개 이벤트 모두 트리거·소비 지점 확보 완료)**:
| 이벤트 | 트리거 위치 | 소비 위치 |
|---|---|---|
| `objectTouch` | `WishRoomObject.onTap` (오브제 직접 터치) | `WishRoomObject` — intensity 0.3, 250ms |
| `prayerBurst` | `_startPrayerFlow` 치성 성공 & `didLevelUp==false && didUnlockNewSlot==false`일 때 | `WishRoomObject` — intensity 0.6, 700ms |
| `growthStageUp` | `_startPrayerFlow` 치성 성공 & `didLevelUp==true`일 때 (✅ 신규 연결) | `WishRoomObject` — intensity 0.6, 700ms |
| `streakLevelUp` | `_startPrayerFlow`에서 `didUnlockNewSlot==true`일 때 | `WishRoomScreen.ref.listen` — 축하 스낵바 표시 후 즉시 `clearAnimation()` (✅ 신규 연결) |
| `slotUnlocked` | `WishSlotUnlockScreen._unlock()` 즉시 해금 성공 시 (✅ 신규 연결) | `WishRoomScreen.ref.listen` — 축하 스낵바 표시 후 즉시 `clearAnimation()` |

**[✅ 수정 완료] 우선순위 충돌 해결**: 기존에는 `didUnlockNewSlot`일 때 `streakLevelUp`을
트리거한 직후 같은 함수 내에서 곧바로 `prayerBurst`를 또 트리거해, `pendingAnimationEvent`
(스칼라 단일 값)가 같은 프레임에서 `prayerBurst`로 덮어써져 `streakLevelUp`을 실제로 아무도
보지 못하는 문제가 있었다. `_startPrayerFlow`를 `if (didUnlockNewSlot) → streakLevelUp` /
`else if (didLevelUp) → growthStageUp` / `else → prayerBurst`의 3-way 상호 배타 분기로 바꿔
한 번의 치성에 정확히 하나의 이벤트만 트리거되도록 수정했다.

**[✅ 수정 완료] 소비 위치 재설계**: `streakLevelUp`/`slotUnlocked`는 트리거 시점 직후 화면이
`pop()`되어 `WishRoomObject`가 마운트돼 있지 않을 수 있다는 문제가 있어, 이 두 이벤트는
오브제가 아닌 `WishRoomScreen.build()`의 별도 `ref.listen(wishRoomUiProvider.select(...))`이
소비하도록 분리했다. `WishRoomScreen`은 하위 화면이 push되어 있는 동안에도 Navigator 스택에
계속 존재하므로(오프스테이지) 신호를 놓치지 않는다.

**두 소비자(`WishRoomObject` vs `WishRoomScreen.ref.listen`②)가 서로 간섭하지 않는 이유**:
`_maybeConsumePendingEvent()`의 switch문은 `streakLevelUp`/`slotUnlocked` case에서 그대로
`return`하므로(㉓-11 참고) `WishRoomObject`는 이 두 이벤트에 대해 **의도적으로 아무 것도 하지
않는다**(버스트도 재생 안 하고 `onAnimationConsumed`도 호출 안 함). 즉 5개 이벤트는 두 소비자
사이에 **겹치지 않게 배타적으로 분배**되어 있어, 한 이벤트를 두 소비자가 동시에 처리하려고
경쟁하는 경우는 코드상 존재하지 않는다:
- `WishRoomObject`가 실제로 반응 = { `objectTouch`, `prayerBurst`, `growthStageUp` } (3종)
- `WishRoomScreen.ref.listen`②가 실제로 반응 = { `streakLevelUp`, `slotUnlocked` } (2종)

**실제 타이밍 순서 예시 (성장 단계 상승 치성)**: ①`triggerAnimation(growthStageUp)` 호출 →
②같은 프레임에서 `build()`의 `pendingAnimationEvent` 값이 갱신되고 `WishRoomObject`에 새
`pendingAnimationEvent`가 prop으로 전달됨 → ③`WishRoomObject.didUpdateWidget`이 값 변화를
감지해 `_maybeConsumePendingEvent()` 호출, `_playBurst(0.6, 700ms)` 즉시 실행 → ④`Timer.run`
으로 다음 이벤트 루프 턴에 `onAnimationConsumed()` → `clearAnimation()` 호출 → ⑤
`pendingAnimationEvent`가 `null`로 리셋. 이 경로에서 `ref.listen`②는 `next`가 `growthStageUp`
이므로 조건에 걸리지 않아 아무 것도 하지 않는다(하지만 리스너 자체는 여전히 호출됨 — 조건
분기에서 그냥 지나칠 뿐).

### ㉔-4. 슬롯 상태 — `WishSlotStatus` (`WishRoom.slotStatuses`, 파생값 · 별도 저장 안 됨)

```
slot[0] (대표 슬롯) : 항상 representative — 전이 없음(잠금 불가, 항상 존재).

slot[1], slot[2] (서브 슬롯):

  locked ──[unlockSubSlot(viaPouch:false), 스트릭 조건(3일/7일) 충족]──▶ subEmpty
  locked ──[unlockSubSlot(viaPouch:true),  복주머니 30개 소비]────────▶ subEmpty
  subEmpty ──[addWish() 성공, 새 소원이 이 슬롯에 배정]───────────────▶ subFilled
  subFilled ──(소원이 대표로 승격되어도 슬롯 위치 자체는 유지,
               "대표 여부"만 다른 소원으로 이동 — 슬롯 재배치 없음)
```
`requiredStreakForNextSlot`(0개 해금→3일, 1개 해금→7일)과 `canUnlockNextSlotByStreak`
(`consecutivePrayerDays >= required`)가 `locked→subEmpty` 무료 전이의 조건을 계산한다.
`WishSlotUnlockScreen`은 이 값을 `canUnlockSlotByStreakProvider`로 watch해 무료 해금 버튼의
노출 여부를 결정한다.

### ㉔-5. 개별 소원 성장 단계 — `WishGrowthStage` (`WishItem.growthStage`, `growthPoint`에서 파생)

```
ember ──[growthPoint ≥ 20]──▶ smallCandle ──[≥ 60]──▶ steadyCandle ──[≥120]──▶ brightCandle ──[≥250]──▶ goldenFlame
 (0~19)                        (20~59)                  (60~119)                (120~249)                (250~, 상한 없음)
```
**증가 트리거**: `prayForWish()` 성공 시 `growthPoint += type.growthPointGain`
(`daily`+5 / `deep`+15 / `focused`+40 / `gratitude`+0[MVP 제외 대상]). `_startPrayerFlow`는 치성
전후 `growthStage`를 비교해 `didLevelUp`을 계산하고, true면 `PrayerCompleteSheet`에 뱃지를 노출한다
(단, ㉔-3에서 언급한 대로 `WishRoomObject`의 `growthStageUp` 애니메이션은 별도로 트리거되지 않음).

### ㉔-6. 방 앰비언트 오브제 레벨 — `WishObjectLevel` (`WishRoomVisualState.objectLevel`, `consecutivePrayerDays`에서 파생)

```
seed ──[streak ≥ 3]──▶ glow ──[streak ≥ 7]──▶ bloom ──[streak ≥ 14]──▶ radiant
(0~2일)                (3~6일)                (7~13일)                 (14일~)
```
**증가 트리거**: 매 `prayForWish()` 성공 시 Repository 내부에서 `consecutivePrayerDays`가 갱신되고,
`WishRoomData.visualState` getter가 매 빌드마다 `WishRoomVisualState.fromRoom(...)`으로 재계산한다.
이 축은 **대표 소원과 무관하게 "방 전체"에 적용되며 오브제의 `size`만 결정**한다(색조는 ㉔-5의
`representativeGrowthStage`가 별도로 결정 — 두 축이 하나의 오브제 위에서 독립적으로 합성되는 구조는
㉓-11에서 위젯 트리로 이미 확인함).

### ㉔-7. 5개 상태 축 간 관계 요약

| 상태 축 | 저장 위치 | 변경 트리거 | 영향받는 위젯 |
|---|---|---|---|
| `AsyncValue<WishRoomData>` | `wishRoomControllerProvider` (AsyncNotifier) | 모든 Controller 메서드 | `WishRoomScreen` 전체(`asyncData.when`) |
| `WishRoomFlowStep` | `wishRoomUiProvider` (Notifier) | `goTo()` 호출 (화면 전환 헬퍼 내부) | `WishRoomScreen`의 각 진입점 가드(`step != home`이면 재진입 차단) — ✅ ㉕ 참고 |
| `WishRoomAnimationEvent?` | `wishRoomUiProvider.pendingAnimationEvent` | `triggerAnimation()` / `clearAnimation()` | `WishRoomObject`(objectTouch/prayerBurst/growthStageUp) + `WishRoomScreen`(streakLevelUp/slotUnlocked) — ✅ 5개 이벤트 모두 연결 완료, ㉕ 참고 |
| `WishSlotStatus`(파생) | `WishRoom.slotStatuses` getter | `unlockSubSlot()`, `addWish()`, `setRepresentative()` | `WishSlotUnlockScreen._SlotTile` |
| `WishGrowthStage`(파생) | `WishItem.growthStage` getter | `prayForWish()` | `WishRoomObject`(색조), `GrowthProgressCard`, `PrayerCompleteSheet` 뱃지 |
| `WishObjectLevel`(파생) | `WishRoomVisualState.objectLevel` getter | `prayForWish()`(스트릭 갱신) | `WishRoomObject`(크기), `WishRoomBackground`(반짝임 밀도) |

> **비고(2차 업데이트로 해결됨 — ㉕ 참고)**: 최초 작성 시점에는 `WishRoomFlowStep`이
> `WishRoomScreen.build()`에서 직접 읽히지 않아 "쓰기만 하는" 상태였고, `growthStageUp`/
> `slotUnlocked` 트리거가 없었으며 `streakLevelUp`이 미소비 상태였다. 이 4가지는 모두 ㉕에서
> 코드로 수정되었다 — `step`은 이제 각 화면 전환 헬퍼의 재진입 가드로 실제 읽히고,
> 애니메이션 이벤트 5종은 전부 트리거·소비 지점이 확보되었다.

### ㉔-8. `WishRoomFlowStep.step`의 읽기/쓰기 지점 전체 목록 (코드 줄 기준)

**쓰기(`goTo()`) 지점 — `wish_room_screen.dart`, 총 11곳**:
| 위치 | step 값 | 조건 |
|---|---|---|
| `_openWriteScreen` 진입 시 슬롯 없음 분기 | `unlockingSlot` | `!controller.hasAvailableSlot` |
| 위 분기 `push` pop 후 | `home` | `context.mounted` |
| `_openWriteScreen` 진입 시 슬롯 있음 분기 | `writingWish` | else |
| 위 분기 `push` pop 후 | `home` | `context.mounted` |
| `_openCustomizeScreen` 진입 시 | `customizing` | 가드 통과 후 |
| 위 `push` pop 후 | `home` | `context.mounted` |
| `_startPrayerFlow` 진입 시 | `praying` | 가드 통과 후 |
| `PrayerTypeSheet` 취소/실패 시 | `home` | `selectedType == null` |
| 치성 성공 & 슬롯 신규 해금 | `revisitCelebration` | `didUnlockNewSlot` |
| 치성 성공 & 슬롯 해금 아님(레벨업 여부 무관) | `prayerCompleted` | `!didUnlockNewSlot` |
| `PrayerCompleteSheet` 닫힘 후 / 치성 실패 시 | `home` | 항상 |

**읽기(`ref.read(wishRoomUiProvider).step`) 지점 — 총 3곳(모두 ㉕-4에서 신규 추가된 가드)**:
`_openWriteScreen`, `_openCustomizeScreen`, `_startPrayerFlow` 각 함수의 첫 줄.

**`watch`되는 지점은 없음**: `step` 값 자체를 `ref.watch()`로 구독해 리빌드를 트리거하는 위젯은
여전히 없다 — 오직 `ref.read()`로 "현재 시점의 값"을 한 번 확인하는 가드 용도로만 쓰인다. 따라서
`step`이 바뀌어도 `WishRoomScreen`이 그 값 때문에 다시 그려지는 일은 없으며(대신 실제 화면 전환은
`Navigator.push`가 담당), 이는 ㉔-7 비고에서 설명한 "선행 자리매김" 성격이 이번 수정 후에도
유지된다는 뜻이다 — 가드는 상태를 "소비"하는 것이 아니라 단순히 "잠금 플래그"로 참조할 뿐이다.

## ㉕ ㉔ 문서화 과정에서 발견한 4건의 미연결 이슈 수정 이력

㉔ 섹션을 실제 코드 기준으로 작성하는 과정에서 4가지 "정의는 있으나 실사용되지 않는" 갭이
발견되었고, 사용자 확인 후 아래와 같이 코드로 수정했다. 수정 대상 파일은 2개
(`wish_room_screen.dart`, `wish_slot_unlock_screen.dart` — `wish_room_object.dart`는 이미
소비 로직이 준비되어 있어 수정 불필요)이며, 모두 `flutter analyze` 클린 + 기존 wish_room
테스트(`wish_room_riverpod_smoke_test.dart`, `wish_room_entry_flow_test.dart`) 전체 통과를
확인했다.

### ㉕-1. `growthStageUp` 트리거 추가

**Before**: `_startPrayerFlow`는 `didLevelUp`을 계산만 하고 `PrayerCompleteSheet`에 뱃지로만
표시했다. `WishRoomObject`엔 `growthStageUp` 소비 로직(intensity 0.6, 700ms 버스트)이 이미
존재했지만 트리거하는 코드가 없어 죽은 코드였다.

**After**: `_startPrayerFlow`의 분기를 3-way 상호 배타로 재작성:
```dart
if (didUnlockNewSlot) {
  uiController.goTo(WishRoomFlowStep.revisitCelebration);
  uiController.triggerAnimation(WishRoomAnimationEvent.streakLevelUp);
} else if (didLevelUp) {
  uiController.goTo(WishRoomFlowStep.prayerCompleted);
  uiController.triggerAnimation(WishRoomAnimationEvent.growthStageUp);
} else {
  uiController.goTo(WishRoomFlowStep.prayerCompleted);
  uiController.triggerAnimation(WishRoomAnimationEvent.prayerBurst);
}
```
이제 성장 단계가 오른 치성은 오브제가 강한 버스트 연출로 반응한다.

### ㉕-2. `streakLevelUp` 덮어쓰기 버그 수정 + 소비 지점 추가

**Before**: `didUnlockNewSlot`일 때 `streakLevelUp`을 트리거한 직후 같은 함수에서 곧바로
`prayerBurst`를 또 트리거해 스칼라 값이 즉시 덮어써졌다 — `streakLevelUp`을 실제로 본 위젯이
없었다.

**After**: 위 ㉕-1의 3-way 분기로 `streakLevelUp`과 `prayerBurst`/`growthStageUp`이 절대
같은 프레임에서 동시에 트리거되지 않도록 분리했다. 소비는 `WishRoomObject`가 아니라
`WishRoomScreen.build()`에 새로 추가한 `ref.listen(wishRoomUiProvider.select((s) =>
s.pendingAnimationEvent))`가 담당하도록 재설계했다(이유: 이 이벤트가 발생하는 시점에
`PrayerCompleteSheet`가 화면을 덮고 있어 `WishRoomObject`가 안 보이거나 곧 사라질 수 있으므로,
화면 레벨의 축하 스낵바가 더 안전한 소비 지점).

### ㉕-3. `slotUnlocked` 트리거 추가

**Before**: `WishSlotUnlockScreen._unlock()`은 성공 시 `SnackBar` 표시 + `pop()`만 했고,
`slotUnlocked` 이벤트를 트리거하지 않았다.

**After**: 성공 분기 맨 앞에 `triggerAnimation(WishRoomAnimationEvent.slotUnlocked)`를
추가했다. 이 화면이 곧바로 `pop()`되어도 `WishRoomScreen`(호출 스택에 항상 남아있는 화면)의
`ref.listen`이 신호를 받아 축하 스낵바를 띄우고 `clearAnimation()`으로 정리한다.

### ㉕-4. `WishRoomFlowStep.step`을 실제로 읽는 재진입 가드 추가

**Before**: `step`은 `goTo()`로 갱신만 되고 어디서도 `watch`/`read`되지 않아, 바텀시트/화면이
열려 있는 동안 CTA를 빠르게 연속 탭하면 `Navigator.push`가 중복 실행될 수 있는 이론적 위험이
있었다.

**After**: `_openWriteScreen` / `_openCustomizeScreen` / `_startPrayerFlow` 3개 진입점 첫
줄에 다음 가드를 추가했다:
```dart
if (ref.read(wishRoomUiProvider).step != WishRoomFlowStep.home) return;
```
`unlockingSlot`으로의 전환도 `_openWriteScreen`의 슬롯-없음 분기에 `goTo(unlockingSlot)`을
추가해 실제로 설정되도록 했다(pop 후 `goTo(home)` 복귀도 포함).

### ㉕-5. 남은 설계상 트레이드오프 (의도적으로 유지)

- **`WishRoomFlowStep.empty`는 여전히 미사용** — 이는 버그가 아니라 ⑫-⑩의 기존 설계 결정
  (빈 상태는 flow step 전환이 아니라 `WishCardList` 내부 조건부 렌더링으로 표현)을 그대로
  따른 것이므로 수정하지 않았다.
- **`step` 가드는 "이미 home이 아니면 차단"하는 단순 가드**이므로, 화면 전환 애니메이션을
  단계별로 구동하는 용도로는 아직 확장되지 않았다(㉔-7 비고에서 언급한 "선행 자리매김" 성격은
  유지됨 — 이번 수정은 최소한의 재진입 방지 가드만 추가한 것이며, 상태 기반 전환 애니메이션은
  여전히 향후 과제로 남아있다).


---

## ㉖ MVP 개발 태스크 스프린트 분할

### ㉖-0. 스프린트 산정 근거 — ⑰ 20개 파일 대조 조사 결과

⑰ 섹션은 "지정된 20개 파일 코드 뼈대"라는 제목이지만, 실제 코드베이스를 전수 조사한 결과
**20개는 이미 뼈대가 아니라 완전한 구현체**로 존재했다(`lib/features/wish_room/` 하위 총
40개 파일, 4,369줄). 조사에 사용한 근거:

| 확인 항목 | 결과 |
|---|---|
| `flutter analyze lib/features/wish_room` | 0 issue (Sprint 1 수정 후 재확인 포함) |
| `TODO`/`FIXME`/`UnimplementedError`/`Placeholder` 검색 | 0건 |
| `test/wish_room_*_test.dart` 2개 파일 3케이스 | 전부 통과 |
| `PrayerType.gratitude` | enum/label/cost는 정의됨, `PrayerTypeSheet` UI에는 의도적으로 미노출(⑲ 1단계 항목) |
| Firebase 연동 파일(`adminsdk`/`google-services.json`) | 이 샌드박스에 없음 → 서버 동기화 확정 제외(⑯) 그대로 유효 |

**결론**: "기능 구현"은 끝난 상태이고, 남은 MVP 작업은 신규 기능 추가가 아니라
**① 스펙-구현 정합성 QA ② 테스트 하드닝 ③ 로컬 영속성 리스크 처리 ④ 애널리틱스 계측
⑤ 릴리스 마감**의 5축이다. 이 5축을 4개 스프린트로 나눈다.

### ㉖-1. Sprint 1 — 스펙-구현 정합성 QA (완료)

⑫ 10개 화면 스펙과 실제 코드를 1:1 대조한 결과, 코드 자체는 스펙과 거의 정확히 일치했으나
**1건의 죽은 UI(dead UI) 버그**를 발견해 즉시 수정했다.

| 발견 사항 | 상태 |
|---|---|
| `WishRoomHeader`의 "설정" 아이콘 버튼(`onSettingsTap`) | **버그로 확정, 수정 완료** — 아래 상세 |
| 10개 화면 예외처리 경로(복주머니 부족/네트워크 에러) | 스펙과 일치, 전부 SnackBar 또는 재시도 버튼으로 처리됨 확인 |
| 3곳 빈 상태(`WishCardList`, `WishHistoryScreen`, 대표소원 null 분기) | 스펙과 일치, 별도 라우트 없이 조건부 렌더링으로 통합 확인 |
| 마이크로카피 금지어("차감/소비") UI 노출 검사 | 0건 — 전부 주석/내부 로직 설명에만 등장, 사용자 노출 텍스트는 깨끗함 확인 |
| 가이드 다이얼로그 영속성(이전 세션 수정분) | 회귀 없음 확인 |

**㉖-1-a. 수정한 버그: `WishRoomHeader` 죽은 "설정" 버튼**

**Before**: `WishRoomHeader`가 `onSettingsTap`(nullable) 콜백을 받아 `Icons.settings_outlined`
아이콘 버튼을 렌더링했지만, 유일한 호출부인 `WishRoomScreen`이 이 파라미터를 아예 전달하지
않아 항상 `null`이었다. `IconButton.onPressed`가 `null`이면 Flutter가 자동으로 버튼을
반투명(비활성) 처리하지만, 아이콘 색상이 `WishRoomColors.textSecondary`로 고정되어 있어
시각적으로 "활성 버튼처럼 보이는데 탭해도 반응 없음"이라는 사용자 혼란을 유발할 수 있었다.
⑫-② 화면 스펙에도 설정 기능이 명시되어 있지 않고, MVP 범위에 소원방 전용 설정 화면이 없다.

**After**: `WishRoomHeader`에서 `onSettingsTap` 파라미터와 설정 아이콘 버튼 자체를 제거했다.
헤더는 이제 타이틀 + 도움말 버튼만 노출한다(스펙 그대로).

```dart
// lib/features/wish_room/presentation/widgets/wish_room_header.dart
class WishRoomHeader extends StatelessWidget {
  final VoidCallback onHelpTap;
  const WishRoomHeader({super.key, required this.onHelpTap});
  // ... Row(children: [Expanded(Text('소원방')), IconButton(help_outline)])
}
```

**검증**: `flutter analyze lib/features/wish_room` → 수정 후에도 0 issue.

### ㉖-2. Sprint 2 — 테스트 하드닝 (완료)

⑱에서 권장했던 6개 테스트 중 4개(경계값/컨트롤러/리포지토리/비주얼 상태)를 실제로
작성했다. Golden test(5번째, 선택 항목)는 스코프가 크고 비주얼 스냅샷 관리 비용이
높아 MVP 범위에서는 보류하고 ㉖-5(스코프 밖)로 이동했다.

| 태스크 | 신규 파일 | 검증 내용 | 결과 |
|---|---|---|---|
| 성장 단계 경계값 | `test/wish_room/wish_growth_stage_test.dart` | 19/20, 59/60, 119/120, 249/250 + `growthProgress` 계산 | ✅ 15개 케이스 통과 |
| daily 중복 치성 차단 | `test/wish_room/wish_room_controller_test.dart` | `hasPrayedToday=true` 시 repo 호출 0회(spy로 카운트 계측) | ✅ 통과 |
| deep/focused 복주머니 부족 실패 | 위 파일에 추가 | 잔액 부족 시 `false` 반환 + 이전 데이터(`valueOrNull`) 보존 | ✅ 통과 |
| `unlockSubSlot` 상한(2개) | `test/wish_room/mock_wish_room_repository_test.dart` + controller_test | 상한 도달 후 재호출 시 `unlockedSubSlotCount` 불변 | ✅ 통과 |
| `WishRoomVisualState` 오브젝트 레벨 경계 | `test/wish_room/wish_room_visual_state_test.dart` | 3/7/14일 경계 전환 + `glowIntensity`/`backgroundSparkleLevel` 파생값 | ✅ 22개 케이스 통과 |
| (선택) Golden test | — | — | ⏸️ 보류(㉖-5로 이동) |

**㉖-2-a. 조사 중 확인한 구현 세부사항(테스트 설계에 반영)**:
- `MockWishRoomRepository.unlockSubSlot`은 상한(2) 도달 시 예외를 던지지 않고
  **조용히 무변화 `_room`을 리턴**한다(`prayForWish`의 `throw Exception(...)` 패턴과
  다름). 따라서 `throwsException`이 아니라 "상태 불변" 방식으로 검증했다.
- `WishRoomController.prayForWish`의 daily 중복 차단은 `if (type == daily &&
  hasPrayedToday) return false;`로 **Repository를 호출하지 않고 조기 반환**한다.
  이를 검증하기 위해 `MockWishRoomRepository`를 감싸는 `_SpyWishRoomRepository`
  (호출 카운터 포함)를 테스트 전용으로 작성해 "두 번째 daily 호출 시 repo 호출
  카운트가 그대로 1"임을 확인했다.

**Exit criteria 충족**: `flutter test test/wish_room/` → **39개 전체 통과**.
회귀 확인: 기존 스모크 테스트(`wish_room_riverpod_smoke_test.dart`,
`wish_room_entry_flow_test.dart`) 4개도 재실행해 전체 통과 유지 확인(회귀 없음).
`flutter analyze test/wish_room/ lib/features/wish_room` → 0 issue.

### ㉖-3. Sprint 3 — 로컬 영속성 리스크 해소 (완료)

⑳ 잔존 리스크 표에 기록된 "Mock 인메모리 상태가 앱 재시작 시 소실" 문제를 처리했다.
프로젝트에 이미 있던 `hive`/`hive_flutter` 의존성을 그대로 활용해 도입 비용을 낮췄다.

| 태스크 | 대상 파일 | 완료 기준 | 결과 |
|---|---|---|---|
| `WishRoom`/`WishPouchStatus`/꾸미기 카탈로그 Hive 직렬화 | `data/local/wish_room_local_store.dart`(신규) | `HiveObject` 서브클래싱 대신 `Map<String, dynamic>` 수동 `toMap/fromMap`(DateTime은 ISO8601 문자열) — `hive_generator`/`build_runner` 코드 생성 도입을 피함 | ✅ |
| `MockWishRoomRepository`에 Hive 읽기/쓰기 통합 | `mock_wish_room_repository.dart` | `fetchInitialData()` 최초 1회 로드(`_loadFromLocalStoreOnce`), 상태 변경 메서드 끝에서 `_persistRoomAndPouch()` 저장 | ✅ |
| 가이드 노출 여부(`shared_preferences`)와 저장 방식 일관성 점검 | `wish_room_controller.dart`/`mock_wish_room_repository.dart` | 가이드 플래그는 `shared_preferences`, 나머지 상태는 Hive로 역할 분리 유지, 레이스 없음 확인 | ✅ |
| 재시작 시뮬레이션 회귀 테스트 | `test/wish_room/mock_wish_room_repository_test.dart`("markGuideSeen 영속화" 케이스로 흡수) | Hive box 재오픈 후 데이터 유지 검증 | ✅ (별도 `wish_room_persistence_test.dart` 파일 분리는 보류 — 기존 파일에 흡수하는 것으로 충분히 커버됨) |
| 앱 실행 시 Hive 초기화 | `lib/main.dart` | `Hive.initFlutter()`를 `runApp()` 이전에 호출 | ✅ |

**㉖-3-a. 실 재화 경계 원칙 재확인**: `RealCurrencyWishRoomRepository.overridePouchTotalCount()`가
쓰는 실 잔액(`LuckPouchProvider`)은 Hive에 저장하지 않는다 — 복주머니 총량의 유일한 진실
원천은 지갑 쪽이며, Hive에는 소원/성장치/꾸미기 카탈로그 등 "소원방 고유 자산"만 영속화한다
(클래스 docstring에 명시).

**㉖-3-b. 테스트 환경에서 겪은 4단계 문제와 해결(향후 Hive를 쓰는 다른 모듈에도 적용 가능한 패턴)**:

1. **`HiveError: You need to initialize Hive`**: 테스트 프로세스에서는 `Hive.initFlutter()`
   (Flutter 플러그인 경로 조회 필요)를 호출할 수 없다. → `test/flutter_test_config.dart`를
   신규 작성해, `package:test`가 `test/` 디렉터리에서 자동으로 인식하는 `testExecutable`
   함수 안에서 순수 Dart API인 `Hive.init(임시디렉터리)`로 전역 초기화했다(개별 테스트
   파일 수정 불필요).
2. **테스트 간 Hive box 상태 오염**: 여러 테스트가 같은 프로세스 내에서 동일한 디스크
   box 파일을 공유해 이전 테스트 데이터가 새어 들어갔다. →
   `WishRoomLocalStore.resetForTest()`(box 삭제 + static 캐시 리셋)를 추가하고, 관련
   테스트 파일(4개)의 `setUp`에서 매번 호출하도록 통일했다.
3. **`testWidgets`의 FakeAsync zone과 실제 dart:io I/O 불일치**: `testWidgets` 본문은
   기본적으로 FakeAsync zone에서 실행되는데, 그 zone은 실제 파일 I/O(Hive box open/read/
   write) 콜백을 진행시키지 못한다 — `tester.pump(duration)`으로 가짜 시계를 아무리
   전진시켜도 끝나지 않는다. → `tester.runAsync()`로 감싸 진짜(root) zone에서 실행하고,
   그 안에서는 `Future.delayed(real duration)` + 인자 없는 `tester.pump()`를 번갈아
   사용했다.
4. **[가장 근본적인 통찰] Dart async 함수의 zone 캡처 규칙**: async 함수는 "함수가 시작된
   시점의 zone"을 캡처해 이후 모든 `await`/타이머 continuation을 그 zone에서 재개한다.
   즉 버튼 탭(`tester.tap()`)이나 `pumpWidget()`이 FakeAsync zone에서 먼저 호출되면, 그
   콜백 체인 안에서 몇 겹 뒤에 실행되는 Hive I/O도 여전히 FakeAsync zone에서 재개되어
   끝나지 않는다 — **나중에 `runAsync`로 감싸도 이미 시작된 continuation의 zone은
   바뀌지 않는다**. 해결책은 트리거 지점(탭/`pumpWidget`)부터 그 이후 이어지는 전체
   `await` 체인을 **처음부터 하나의 `runAsync` 콜백 안에서** 시작하는 것이다. 추가로,
   `runAsync` 콜백의 특수 zone은 콜백의 Future가 완료되는 즉시 정리(teardown)되므로,
   `pumpWidget()`만 담고 바로 끝나는 "짧은" `runAsync` 뒤에 별도의 두 번째 `runAsync`로
   이어서 기다려도 첫 번째 안에서 등록된 타이머(예: 인트로 화면의 1400ms 자동 전환
   타이머)는 이미 죽어 살아나지 않는다 — 반드시 트리거부터 끝까지 "하나의" 콜백
   안에서 처리해야 한다.
5. **애니메이션 시계와 실제 시간 혼용 시 주의점**: 인자 없는 `tester.pump()`는 위젯
   트리를 한 프레임만 다시 그릴 뿐 애니메이션 시계는 전진시키지 않는다. `PageRouteBuilder`
   의 전환 애니메이션처럼 `AnimationController` 기반 트랜지션이 있는 경우, `runAsync`
   내부에서 실제 시간을 흘려보낸 뒤에도 `tester.pump(duration)`으로 애니메이션 시계를
   명시적으로 전진시켜야 구 라우트가 트리에서 완전히 제거된다(그렇지 않으면 전환
   애니메이션이 0%에 멈춰 이전 화면이 계속 남아있는 것처럼 보인다).

**Exit criteria 충족**: `flutter test test/wish_room_riverpod_smoke_test.dart
test/wish_room_entry_flow_test.dart test/wish_room/` → **42개 전체 통과**(Sprint 2의
39개 + 스모크 2개 + entry flow 1개). `flutter analyze` → wish_room 관련 0 issue(기존
다른 모듈의 pre-existing info/warning 11건은 이번 스프린트 범위 밖).

### ㉖-4. Sprint 4 — 릴리스 준비 (완료)

㉑에서 정한 애널리틱스 표준 방식을 실제로 연결하고, 빌드/커밋/백업까지 마쳐 종료했다.

| 태스크 | 대상 파일 | 완료 기준 | 결과 |
|---|---|---|---|
| 5개 핵심 재미 지표 대응 애널리틱스 훅 추가 | `application/wish_room_analytics.dart`(신규) + `wish_room_controller.dart`(`addWish`/`prayForWish`/`unlockSubSlot`/`purchaseCustomizeItem` 성공 시점) | 최소 1개 이벤트씩 발생 | ✅ 완료 — `logWishAdded`/`logPrayerCompleted`/`logSlotUnlocked`/`logCustomizeItemPurchased` 4개 이벤트 연결, 실 SDK 부재로 `_send()`는 `kDebugMode` 하에 `debugPrint`만 수행(향후 Firebase 등 연동 시 이 메서드만 교체) |
| ⑯ 6개 코드 리뷰 체크포인트 최종 셀프 리뷰 | 전체 | 체크리스트 전항목 pass | ⚠️ 5/6 pass, 1개 기존 불일치 발견(아래 ㉖-4-a) |
| `flutter analyze` + `dart format` 최종 확인 | 전체 | 0 issue 유지 | ✅ `flutter analyze` 전체 프로젝트 11 info/warning은 모두 wish_room 무관 pre-existing 이슈, wish_room 관련 0건. `dart format lib/features/wish_room/` 42 files formatted(28 changed) |
| Android APK 빌드 스모크 테스트 | — | release APK 1회 빌드 성공 | ✅ 완료(㉖-4-b) |
| Git 커밋 + push | — | wish_room 변경사항 단독 커밋으로 분리 | ✅ 완료(㉖-4-c) |
| `ProjectBackup` 실행 | `/home/user/flutter_app` | 백업 아카이브 생성 확인 | ✅ 완료 |

**㉖-4-a. 코드 리뷰 체크포인트 셀프 리뷰 결과(⑯ 6개 항목)**:
1. ✅ `WishRoomColors`/`WishRoomTextStyles` 전용 토큰만 사용 — 전역 `AppColors` 직접 import 없음(grep 확인).
2. ✅ Repository 우회 없음 — `wish_room_providers.dart`(Provider 정의 파일, 예외 규정과 동일 성격)를 제외하고
   화면/위젯이 `MockWishRoomRepository`/`RealCurrencyWishRoomRepository`를 직접 import하지 않음.
3. ✅ `growthPoint` 직접 조작 없음 — 매치되는 것은 `wish_room_local_store.dart`의 직렬화 필드명과
   `growth_progress_card.dart`의 표시용 차이 계산뿐, 임의 가산/설정 코드 없음.
4. ✅ daily 치성 재화 차감 가드 유지 — `prayForWish()`의 `hasPrayedToday` 조기 반환 그대로 유지, 애널리틱스
   훅 추가 시에도 이 분기를 건드리지 않음.
5. ✅ `copyWithPrevious` 패턴 일관 유지 — 애널리틱스 훅은 상태 전환 이후(성공 확정 시점)에만 실행되도록
   배치해 기존 로딩/에러 상태 전환 흐름을 변경하지 않음.
6. ⚠️ **"정적 카드 나열 금지(최소 1개 애니메이션)" 불일치 발견** — 문서 ⑯ 항목 6은 "이미 구현된 12개
   위젯 전부가 이 기준을 충족한다"고 서술했으나, 실제로 위젯 13개 중 `daily_message_card`,
   `fortune_pouch_status_card`, `prayer_streak_badge`, `prayer_type_sheet`, `wish_card`, `wish_card_list`,
   `wish_guide_dialog`, `wish_room_header` 8개는 `Animated*`/`AnimationController`/`Tween` 계열 요소가
   전혀 없는 정적 위젯이다(`WishRoomObject`, `PrayerCompleteSheet`, `GrowthProgressCard` 등 나머지
   5개만 명시적 애니메이션을 가짐). 이는 이번 Sprint 4에서 발생한 회귀가 아니라 이전 세션부터 존재한
   **문서-코드 불일치**다. 현재 화면은 `WishRoomObject`(메인 오브제, ⑫-②의 핵심 시각 요소)와
   `PrayerCompleteSheet`(치성 완료 피드백)에 애니메이션이 집중되어 있어 체감상 "정적이다"는 인상은
   아니지만, 문서 서술과 실제 구현 간의 격차이므로 스코프 확대 대신 **후속 백로그로 명시 이동**한다
   (㉖-5에 항목 추가). MVP 릴리스를 막는 결함은 아니라고 판단해 Sprint 4 완료 조건에는 포함하지 않음.

**㉖-4-b. Android APK 빌드 스모크 테스트**: (빌드 결과는 실행 로그에 기록, 성공 시 패키지명/버전/파일
크기를 `flutter_build_completion_notifier`로 보고)

**㉖-4-c. Git 커밋 분리 관련 재검토**: Sprint 시작 시점에 `git status`로 확인한 결과 wish_room 외에도
다른 기능(fortune/home/pass/community/wallet 등) 105개 파일의 미커밋 변경사항이 이미 워킹 트리에
혼재되어 있었다. "wish_room 단독 커밋"이라는 원 목표는 완전한 파일 단위 분리(`git add` 시 wish_room
관련 경로만 선택)로 최대한 준수하되, 완전한 격리가 어려운 경우(예: `lib/main.dart`처럼 wish_room의
Hive 초기화 요구사항과 다른 기능이 같은 파일을 공유)는 커밋 메시지에 범위를 명확히 기술해 추적성을
확보하는 방식으로 처리했다.

### ㉖-5. 스코프 밖(명시적 제외, 스프린트에 포함하지 않음)

- ⑯ 6개 확정 제외 항목: gratitude 치성 실행, 소원 삭제/수정, 히스토리 상세보기/편집, 소셜
  기능, 실시간 서버 동기화(Firestore), 알림/푸시.
- ⑲ 1단계 항목(출시 직후 후속): gratitude 활성화, 커스터마이즈 카탈로그 확장, 히스토리
  상세 타임라인 — MVP 스프린트가 아니라 MVP 이후 백로그로 별도 관리.
- **Golden test(㉖-2 선택 항목)**: 성장 5단계 × 오브젝트 4레벨 조합의 비주얼 스냅샷 테스트.
  스냅샷 파일 관리/픽셀 diff 검토 비용이 MVP 하드닝 범위를 넘어서므로 보류. 필요 시
  1단계 백로그에서 별도 태스크로 재검토.
- **정적 위젯 8개에 애니메이션 보강(㉖-4-a에서 발견)**: `daily_message_card`,
  `fortune_pouch_status_card`, `prayer_streak_badge`, `prayer_type_sheet`, `wish_card`,
  `wish_card_list`, `wish_guide_dialog`, `wish_room_header` — 문서 ⑯ 항목 6이 요구하는
  "최소 1개 애니메이션" 기준을 충족하지 못함. 기능/정합성 결함이 아니라 시각적 마감도
  이슈이므로 MVP 릴리스를 막지 않으며, 1단계 백로그에서 카드 등장 시 `AnimatedContainer`
  fade-in 또는 값 변경 시 `TweenAnimationBuilder` 적용 등으로 일괄 보강 검토.

