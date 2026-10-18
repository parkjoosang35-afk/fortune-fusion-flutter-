// shrine_rite_data.dart — 신당(神堂) 의식 단계 · 주제 · 결말 · 추가 이야기 = 데이터.
// 신당 디자인 핸드오프(05_design_handoff_v4/flutter/lib/core/rite.dart)를 그대로 이식했다.
// 受·用 단계 추가는 코드가 아니라 이 배열에 항목을 더하는 것으로 끝나도록 설계된
// 원본 구조를 그대로 유지한다(지시서 §11 "지금 구조에서 지켜 둘 것").
//
// [사용자 확정 결정 ②] 이 프로젝트에 이미 존재하는 정통사주 만세력 엔진을
// 재사용하기로 했으므로, 신당 스타터의 saju(DateTime, String?) 함수(날짜를
// 한자로 세로 표기만 하는 플레이스홀더)는 포팅하지 않는다. 대신
// shrine_saju_adapter.dart 가 JeontongReportBuilder를 호출해 실제 사주
// 8자(년주/월주/일주/시주 한자)를 세로쓰기 문자열로 변환한다.

enum ShrineTopic { myeong, yeon, jae, ryu }

class ShrineTopicDef {
  final ShrineTopic id;
  final String key, ro, label, name, hanja, alt, motif, useWhere;
  final ShrineUseKind use;
  final List<String> top; // ② 부호 상단 파자 3자
  final List<String> reveal; // 계시 문구 2줄 ({이름} 치환)
  const ShrineTopicDef(this.id, this.key, this.ro, this.label, this.name, this.hanja, this.alt,
      this.motif, this.use, this.useWhere, this.top, this.reveal);
}

enum ShrineUseKind { attach, carry, offer }

const shrineTopics = <ShrineTopic, ShrineTopicDef>{
  ShrineTopic.myeong: ShrineTopicDef(
      ShrineTopic.myeong,
      '命',
      'MYEONG',
      '나의 길',
      '칠성부',
      '七星符',
      '소망성취부',
      '북두칠성 7점 + 별',
      ShrineUseKind.carry,
      '머리맡 · 지갑',
      ['日', '月', '星'],
      ['북두의 일곱 별이', '{이름}님의 머리맡에 섰습니다.']),
  ShrineTopic.yeon: ShrineTopicDef(
      ShrineTopic.yeon,
      '緣',
      'YEON',
      '사람의 인연',
      '화합부',
      '和合符',
      '인연부',
      '붉은 실 · 매듭',
      ShrineUseKind.carry,
      '접어 봉투에 넣어',
      ['天', '天', '合'],
      ['끊긴 줄 알았던 실이', '아직 한 가닥 남아 있습니다.']),
  ShrineTopic.jae: ShrineTopicDef(
      ShrineTopic.jae,
      '財',
      'JAE',
      '재물의 흐름',
      '재수대길부',
      '財數大吉符',
      '초재부',
      '엽전 · 동전',
      ShrineUseKind.carry,
      '지갑 · 금고',
      ['日', '光', '財'],
      ['고여 있던 기운이', '조금씩 길을 찾고 있습니다.']),
  ShrineTopic.ryu: ShrineTopicDef(
      ShrineTopic.ryu,
      '流',
      'RYU',
      '올해의 기운',
      '삼재예방부',
      '三災豫防符',
      '벽사부',
      '삼재 표식 (들 · 눌 · 날)',
      ShrineUseKind.attach,
      '현관 위 · 문설주',
      ['神', '雷', '龍'],
      ['문 앞에 서성이던 것이', '한 걸음 물러났습니다.']),
};

/// 의식 6단계 — 상단 레일 표시용
class ShrineRiteStep {
  final String k, ko;
  final bool isNew;
  const ShrineRiteStep(this.k, this.ko, {this.isNew = false});
}

const shrineRiteSteps = [
  ShrineRiteStep('診', '진단'),
  ShrineRiteStep('寫', '쓰기'),
  ShrineRiteStep('奉', '봉헌'),
  ShrineRiteStep('示', '계시'),
  ShrineRiteStep('受', '수령', isNew: true),
  ShrineRiteStep('用', '사용', isNew: true),
];

/// 화면 라우트 — 순서·자동 진행·SKIP 대상까지 데이터로.
class ShrineRouteDef {
  final String id, k, ko, group;
  final String? next; // SKIP / 안전 타이머가 보내는 곳
  final String? video; // assets/videos/shrine/*.mp4
  final bool isNew;
  const ShrineRouteDef(this.id, this.k, this.ko, this.group, {this.next, this.video, this.isNew = false});
}

const shrineRoutes = [
  ShrineRouteDef('entry', '入', '메인 입장', 'ENTER', video: 'entry'),
  ShrineRouteDef('door', '門', '문 열림', 'ENTER', next: 'shrine', video: 'door'),
  ShrineRouteDef('shrine', '堂', '신당 내부', 'ENTER'),
  ShrineRouteDef('talk', '診', '월화와 대화', 'RITE', video: 'talk'),
  ShrineRouteDef('info', '寫', '정보 입력', 'RITE'),
  ShrineRouteDef('write', '筆', '부적 쓰기', 'RITE', next: 'paper', video: 'write'),
  ShrineRouteDef('paper', '符', '부적 완성', 'RITE'),
  ShrineRouteDef('burn', '奉', '봉헌', 'RITE', next: 'reveal', video: 'burn'),
  ShrineRouteDef('reveal', '示', '계시', 'RITE', next: 'read'),
  ShrineRouteDef('read', '讀', '재 읽기', 'RITE', next: 'receive'),
  ShrineRouteDef('receive', '受', '소지부 수령', 'RITE', video: 'give', isNew: true),
  ShrineRouteDef('use', '用', '사용법', 'RITE', isNew: true),
  ShrineRouteDef('useAttach', '貼', '붙이기', 'RITE', isNew: true),
  ShrineRouteDef('useCarry', '持', '지니기', 'RITE', isNew: true),
  ShrineRouteDef('useReturn', '奉', '봉헌하기', 'RITE', isNew: true),
  ShrineRouteDef('story', '話', '스토리', 'STORY'),
  ShrineRouteDef('memory', '憶', '회상', 'STORY'),
  ShrineRouteDef('branch', '岐', '카드 분기', 'STORY'),
  ShrineRouteDef('surprised', '驚', '놀란 월화', 'STORY'),
  ShrineRouteDef('ending', '結', '엔딩', 'END'),
  ShrineRouteDef('scroll', '卷', '결과 두루마리', 'END'),
  ShrineRouteDef('more', '續', '다음 문', 'END'),
];

/// 다음 장면 영상 미리 로드 맵 (지시서 §12.2)
const shrinePreloadNext = {
  'entry': 'door',
  'door': 'talk',
  'shrine': 'talk',
  'talk': 'write',
  'info': 'write',
  'write': 'burn',
  'paper': 'burn',
  'reveal': 'give',
  'read': 'give',
};

/// burn.mp4 실측 — 종이 착화 ≈42% · 소멸 ≈92%. 이름 마스크 = clamp((t/dur − .42) / .50)
/// [변경 금지 값 — 신당_개발지시서_v1.4.pdf §2]
const double shrineBurnStart = .42, shrineBurnSpan = .50;

/// burn.mp4(720×1294) 위 종이 위치 (%) — 컨테이너를 같은 비율로 cover 배치해야 어긋나지 않음
/// [변경 금지 값]
const shrineBurnBox = (l: 37.9, r: 37.5, t: 23.0, b: 39.5);

/// 결말 — choice → ending
enum ShrineChoice { bell, leave, name2, none }

class ShrineEndingDef {
  final String k, title, img, line, body;
  final List<String> path;
  const ShrineEndingDef(this.k, this.title, this.img, this.line, this.body, this.path);
}

const shrineEndings = <ShrineChoice, ShrineEndingDef>{
  ShrineChoice.bell: ShrineEndingDef(
      'A',
      '돌아온 방울',
      'end-a',
      '오래전 주운 방울은, 결국 제 주인에게 돌아갔습니다.',
      '{이름}님은 오래 잊고 있던 방울을 다시 쥐었습니다. 따라온 것은 해치러 온 것이 아니라, 돌려받으러 온 것이었습니다.',
      ['방울을 흔듦', '놀란 월화', '이름을 부름']),
  ShrineChoice.leave: ShrineEndingDef(
      'B',
      '닫힌 문',
      'end-b',
      '내려놓은 것은, 그 자리에서 조용히 기다리기로 했습니다.',
      '{이름}님은 방울을 내려놓고 계단을 내려왔습니다. 문은 닫혔지만, 잠기지는 않았습니다.',
      ['방울을 내려놓음', '계단을 내려옴']),
  ShrineChoice.name2: ShrineEndingDef(
      'C',
      '두 번째 이름',
      'end-c',
      '돌아온 것은 둘이었고, 이름도 둘이었습니다.',
      '연기로 된 아이는 {이름}님 곁에 무릎을 꿇었습니다. 월화는 두 번째 이름을 적고, 방울을 그 아이에게 돌려주었습니다.',
      ['방울을 흔듦', '놀란 월화', '두 번째 이름을 부름']),
  ShrineChoice.none: ShrineEndingDef(
      'D',
      '향이 다 타도록',
      'end-d',
      '고르지 않은 것도, 하나의 길이었습니다.',
      '향이 다 탈 때까지 {이름}님은 아무것도 고르지 않았습니다. 월화는 그 침묵을 답으로 적었습니다.',
      ['향이 다 탐', '침묵']),
};

/// 다음 문 — 해제 조건은 순수 함수
class ShrineStoryDef {
  final String id, k, title, img, tease, cond;
  final int fear, minutes;
  final (int, int) Function(Set<String> got, bool kept) progress;
  const ShrineStoryDef(this.id, this.k, this.title, this.img, this.fear, this.minutes, this.tease,
      this.cond, this.progress);
}

final shrineMoreStories = [
  ShrineStoryDef('souls', '魂', '잊힌 영혼의 방', 'story-1', 3, 9, '이름이 지워진 위패들 사이에서, 하나만 아직 따뜻합니다.',
      '결말 두 개를 보면 열립니다', (g, k) => (g.length.clamp(0, 2), 2)),
  ShrineStoryDef('ruin', '崩', '무너진 신당의 밤', 'story-2', 4, 12, '비가 그친 뒤에도, 무너진 처마 아래 촛불은 꺼지지 않았습니다.',
      '결말 C 「두 번째 이름」을 보면 열립니다', (g, k) => (g.contains('C') ? 1 : 0, 1)),
  ShrineStoryDef('bell', '鈴', '방울의 주인', 'story-3', 2, 7, '숲속 당집 앞, 일곱 살의 당신이 방울을 줍기 하루 전.',
      '소지부를 한 장 간직하면 열립니다', (g, k) => (k ? 1 : 0, 1)),
  ShrineStoryDef('first', '始', '월화의 첫 손님', 'story-4', 5, 15, '월화가 처음 문을 열어 주던 밤. 그 손님은 아직 돌아가지 않았습니다.',
      '네 개의 결말을 모두 보면 열립니다', (g, k) => (g.length.clamp(0, 4), 4)),
];

const shrineHours = [
  '子時', '丑時', '寅時', '卯時', '辰時', '巳時', '午時', '未時', '申時', '酉時', '戌時', '亥時'
];
const shrineHourRanges = [
  '23–1시', '1–3시', '3–5시', '5–7시', '7–9시', '9–11시', '11–13시', '13–15시', '15–17시', '17–19시', '19–21시', '21–23시'
];
