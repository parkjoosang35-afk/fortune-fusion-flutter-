// 신당(THE SHRINE) U5 — 부적의 수명 · 돌봄 · 소멸 · 보내기
// 원본: shrine-screens-f.jsx (유일한 소스 오브 트루스, /tmp/shrine_v3/merged/prototype/)
// ─────────────────────────────────────────────────────────────
// · 부적은 영원하지 않다 — 49일 동안 기운을 품고, 돌보지 않으면 빨리 쇠한다.
//   기운이 다하면 「소멸」 → 「보내 드리기」(태워 보내는 의식) → 재(灰)로 부적함에 남는다.
// · 기운 = 남은 날 / 49. 하루 한 번 「향 올리기」로 +3일(최대 49일). 받은 날 0일째.
// · 상태: 生(갓 쓴 7일) · 盛(기운 가득) · 衰(남은 기운 30% 미만) · 滅(소멸) · 灰(보낸 부적)
//
// ⚠ 원본 주석 그대로 유지: "서버 저장 시 부적 at·tended·lastTend·sentAt를 함께 저장.
// 날짜 계산은 서버 시간 기준 권장(기기 시간 조작 방지)." — 현재 구현은 재발급 방지(U12)처럼
// 악용 방지가 필요한 영역이 아니라고 판단해 기기 로컬 시간(DateTime.now()) + 기존
// SharedPreferences('shrine.v2') 저장 정책을 그대로 따른다. 서버 영속화가 필요해지면
// 이 파일의 nowOf()만 서버 시각 기준으로 교체하면 된다.
import '../state/shrine_session_provider.dart';

const int kLifeDays = 49;
const int kTendDays = 3;
const int _dayMs = 86400000; // 864e5

class LifeStateInfo {
  final String k;
  final String label;
  final String note;
  const LifeStateInfo(this.k, this.label, this.note);
}

/// 5단계 상태 사전 — key: born/full/wane/gone/sent
const Map<String, LifeStateInfo> kLifeState = {
  'born': LifeStateInfo('生', '갓 쓴 부적', '먹이 아직 마르지 않았습니다. 이레 동안 가장 강합니다.'),
  'full': LifeStateInfo('盛', '기운이 가득', '부적이 제 몫을 다하고 있습니다.'),
  'wane': LifeStateInfo('衰', '기운이 옅어짐', '먹빛이 바래고 있습니다. 향을 올려 주십시오.'),
  'gone': LifeStateInfo('滅', '소멸', '부적이 제 할 일을 마쳤습니다. 이제 보내 드릴 때입니다.'),
  'sent': LifeStateInfo('灰', '보낸 부적', '태워 보낸 부적은 재로 남아 이 자리를 지킵니다.'),
};

/// 현재 시각(ms). 서버 시간 기준으로 교체하고 싶다면 이 함수만 바꾸면 된다.
int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// 부적 하나의 수명 상태.
class Life {
  final String st; // born/full/wane/gone/sent
  final int left; // 남은 일수(ceil)
  final double qi; // left / kLifeDays (0~1)
  final int age; // 받은 지 며칠째(floor)
  final LifeStateInfo s;
  final bool tendedToday;
  const Life({
    required this.st,
    required this.left,
    required this.qi,
    required this.age,
    required this.s,
    required this.tendedToday,
  });
}

/// [lifeOf 포팅] 부적(BoxItem)의 현재 수명 상태를 계산한다.
/// at 필드가 없는 과거 데이터(U5 이전 발급분)는 원본과 동일하게 "3일 전에 받은 것"으로
/// 가정해 안전하게 생(生)/성(盛) 범위에서 시작하도록 한다.
Life lifeOf(BoxItem b) {
  if (b.sentAt != null) {
    return Life(
      st: 'sent',
      left: 0,
      qi: 0,
      age: 0,
      s: kLifeState['sent']!,
      tendedToday: false,
    );
  }
  final n = nowMs();
  final at = b.at ?? (n - 3 * _dayMs);
  final age = ((n - at) / _dayMs).clamp(0, double.infinity);
  final left = (kLifeDays - age + b.tended * kTendDays).clamp(
    0,
    kLifeDays.toDouble(),
  );
  final qi = left / kLifeDays;
  final st = left <= 0
      ? 'gone'
      : age < 7
      ? 'born'
      : qi < .3
      ? 'wane'
      : 'full';
  final tendedToday =
      b.lastTend != null && (b.lastTend! ~/ _dayMs) == (n ~/ _dayMs);
  return Life(
    st: st,
    left: left.ceil(),
    qi: qi,
    age: age.floor(),
    s: kLifeState[st]!,
    tendedToday: tendedToday,
  );
}

/// [tendTalis 포팅] 향 올리기 — 하루 한 번 +3일. `updateBox()`를 통해 적용한다.
/// [U9-4 포팅] 원본: `tendDays: [...(b.tendDays||[]).filter(x => x !== day), day].slice(-30)`
/// — 오늘 일자 번호(day)를 중복 없이 추가하고 최근 30개만 보관한다.
BoxItem tendTalisItem(BoxItem b) {
  final n = nowMs();
  final day = n ~/ _dayMs;
  final days = b.tendDays.where((x) => x != day).toList()..add(day);
  final kept = days.length > 30 ? days.sublist(days.length - 30) : days;
  return b.copy(tended: b.tended + 1, lastTend: n, tendDays: kept);
}

/// [sendTalis 포팅] 보내 드리기 — 태워서 재(灰)로 남긴다. 소멸(滅) 상태의 부적만 가능.
BoxItem sendTalisItem(BoxItem b) => b.copy(sentAt: nowMs());

// ═══════════ U9-4 — 誠 정성의 테두리(연속 향 일수) ═══════════
// 원본: shrine-u9.jsx devotionOf(item, now). item.tendDays(일자 번호 목록)로
// 연속 일수를 계산한다. 오늘(또는 어제까지, 아직 오늘 향을 안 올렸어도
// 어제까지 이어졌으면 유지) 기준으로 끊기지 않았는지 확인 후, 최근 날짜부터
// 거꾸로 훑어 연속된 구간의 길이를 streak로 삼는다. rank: 7일↑=1(금테),
// 21일↑=2(붉은 금테).
class Devotion {
  final int streak;
  final int rank; // 0 없음 · 1 금(7일) · 2 붉은 금(21일)
  const Devotion(this.streak, this.rank);
}

Devotion devotionOf(BoxItem item, int now) {
  final days = item.tendDays.toList()..sort((a, b) => b.compareTo(a));
  if (days.isEmpty) return const Devotion(0, 0);
  final today = now ~/ _dayMs;
  // 원본: `if (today - days[0] > 1) return { streak: 0, rank: 0 };` — 오늘도
  // 어제도 아니면(이틀 이상 공백) 연속이 끊긴 것으로 본다.
  if (today - days[0] > 1) return const Devotion(0, 0);
  var s = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1] - days[i] == 1) {
      s++;
    } else {
      break;
    }
  }
  return Devotion(s, s >= 21 ? 2 : s >= 7 ? 1 : 0);
}

/// 원본 `DEV_NAME` — rank(0~2)에 대응하는 정성 호칭.
const List<String> kDevName = ['', '誠 · 이레의 정성', '誠 · 스무하루의 정성'];
