/// [신통방통 정통사주 리뉴얼 — 다크 핸드오프] 용어 사전(termKey).
/// admin_web `interpret-term-dictionary.ts`의 `TERM_DICTIONARY`를
/// 그대로 옮긴 것 — 서버(interpret 응답 본문에 박히는 `[[termKey|..]]`
/// 마크업)와 클라이언트(탭 시 보여줄 시트 제목/설명)의 termKey 목록이
/// 반드시 일치해야 한다는 설계 원칙(docs/06_카피덱.md §3)에 따라, 이
/// 파일은 서버 소스를 그대로 복제한 것이며 임의로 키를 추가/수정하지
/// 않는다.
library;

class SajuTermEntry {
  const SajuTermEntry({
    required this.termKey,
    required this.sheetTitle,
    required this.note,
  });

  final String termKey;

  /// 시트 제목 — 탭했을 때 보여줄 한자 병기 용어.
  final String sheetTitle;

  /// 보조설명 1줄.
  final String note;
}

const List<SajuTermEntry> kSajuTermDictionary = [
  SajuTermEntry(
    termKey: 'jaesung',
    sheetTitle: '재성 (財星)',
    note: '사주에서 돈의 방식을 나타내는 기운. 쌓는형(정재)과 흐르는형(편재)이 있습니다.',
  ),
  SajuTermEntry(
    termKey: 'yongshin',
    sheetTitle: '용신 (用神)',
    note: '부족해 채워야 하는 오행. 이야기의 방향을 결정합니다.',
  ),
  SajuTermEntry(
    termKey: 'ilji',
    sheetTitle: '일지 (日支)',
    note: '태어난 날의 지지. 배우자·친밀한 관계의 자리입니다.',
  ),
  SajuTermEntry(
    termKey: 'daewoon',
    sheetTitle: '대운 (大運)',
    note: '10년 단위로 흐름이 바뀌는 사주의 계절입니다.',
  ),
  SajuTermEntry(
    termKey: 'hap',
    sheetTitle: '합 (合)',
    note: '합은 결합, 충은 긴장 — 어느 쪽이 나쁜지가 아니라 어디에 에너지가 모이는지의 문제입니다.',
  ),
  SajuTermEntry(
    termKey: 'chung',
    sheetTitle: '충 (沖)',
    note: '합은 결합, 충은 긴장 — 어느 쪽이 나쁜지가 아니라 어디에 에너지가 모이는지의 문제입니다.',
  ),
  SajuTermEntry(
    termKey: 'strength',
    sheetTitle: '강약',
    note: '기운의 세기를 다섯 단계로 보여 줍니다. 강하다고 좋고 약하다고 나쁜 것이 아니라, 쓰는 방식이 달라질 뿐입니다.',
  ),
  SajuTermEntry(
    termKey: 'gwan',
    sheetTitle: '관성 (官星)',
    note: '나를 다듬고 세우는 기운. 일·책임·명예가 머무는 자리입니다.',
  ),
  SajuTermEntry(
    termKey: 'inseong',
    sheetTitle: '인성 (印星)',
    note: '나를 돕고 채워 주는 기운. 배움과 귀인이 들어오는 통로입니다.',
  ),
  SajuTermEntry(
    termKey: 'bigyeon',
    sheetTitle: '비견 (比肩)',
    note: '나와 같은 기운. 스스로 서는 힘, 자기 기준의 뿌리입니다.',
  ),
];

SajuTermEntry? sajuTermLookup(String termKey) {
  for (final e in kSajuTermDictionary) {
    if (e.termKey == termKey) return e;
  }
  return null;
}
