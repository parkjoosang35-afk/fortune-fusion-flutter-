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
BoxItem tendTalisItem(BoxItem b) {
  final n = nowMs();
  return b.copy(tended: b.tended + 1, lastTend: n);
}

/// [sendTalis 포팅] 보내 드리기 — 태워서 재(灰)로 남긴다. 소멸(滅) 상태의 부적만 가능.
BoxItem sendTalisItem(BoxItem b) => b.copy(sentAt: nowMs());
