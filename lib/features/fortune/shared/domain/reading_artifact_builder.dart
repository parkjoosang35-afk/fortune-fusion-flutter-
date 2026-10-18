// [v7 통합] FaceResultModel / PalmResultModel → ReadingArtifact 변환기.
//
// [v7.2 원칙 엄수] 기존 엔진(백엔드 face-judgment.ts/손금 판정)이 실제로
// 반환하는 값은 features/lines(부위→해석 텍스트)와 topicResults(주제→해석
// 텍스트)뿐이며, 픽셀 단위 실측치나 신뢰도(%) 숫자는 제공하지 않는다.
// 따라서 이 빌더는:
//   - 없는 통계(표본 수, 분포 막대, 검출 % 등)를 절대 새로 만들어내지 않는다.
//   - "엔진 실측" 자리에는 features/lines의 텍스트를 그대로 담아 "엔진이
//     관찰해 적어 준 내용"으로 정직하게 표기한다(수치가 없으면 수치 섹션을
//     아예 비워 둔다 — Mock 데이터로 채우지 않는다, 표준 불변 제약).
//   - 전통 상법 출전(cite)은 디자인 핸드오프 reading-data-v2.js에 이미
//     작성된 13건의 실제 출전 텍스트를 활용하고, 나머지는 CSV 콘텐츠
//     적재가 완료되기 전까지 일반 출전 고지만 노출한다(콘텐츠 200건 확장은
//     v7.5 명시대로 후순위 보류 — 이 빌더는 "틀"만 만든다).
library;

import '../../face/domain/face_model.dart';
import '../../palm/domain/palm_model.dart';
import 'reading_artifact.dart';

/// 부위별 인장 한자 1~2자 — 디자인 핸드오프 content_inventory.csv '인장' 열,
/// reading-data-v2.js의 chip 값과 1:1 대응.
const Map<String, String> _faceChip = {
  '얼굴형': '輪',
  '이마': '額',
  '눈썹': '眉',
  '눈': '目',
  '코': '鼻',
  '입': '口',
  '턱': '頤',
};

const Map<String, String> _palmChip = {
  '생명선': '生',
  '두뇌선': '頭',
  '감정선': '感',
  '운명선': '運',
};

/// content_inventory.csv '한자' 열 — 궁 이름(서술형 출전 라벨용).
const Map<String, String> _faceGung = {
  '얼굴형': '輪廓',
  '이마': '官祿宮',
  '눈썹': '保壽官',
  '눈': '監察官',
  '코': '財帛宮',
  '입': '出納官',
  '턱': '地閣',
};

const Map<String, String> _palmGung = {
  '생명선': '生命線',
  '두뇌선': '頭腦線',
  '감정선': '感情線',
  '운명선': '運命線',
};

/// v7.2 교정: 손금은 '西洋手相傳統'(서양 수상 전통) — 동양은 십간 명명
/// 체계라 '手相學'을 그대로 쓰지 않는다. 관상은 '麻衣相法'/'神相全編'을 쓴다.
CiteRef _defaultCite(ReadingKind kind) => kind == ReadingKind.face
    ? const CiteRef(
        src: '麻衣相法',
        srcKo: '마의상법',
        text: '부위의 생김과 기세를 종합해 그 사람의 성정과 흐름을 가늠한다는 전통 관상학의 일반론(요지).',
      )
    : const CiteRef(
        src: '西洋手相傳統',
        srcKo: '서양 수상 전통',
        text: '손바닥의 선을 생명·이성·감정·운의 흐름으로 나누어 읽는 서양 수상 전통의 일반론(요지).',
      );

class ReadingArtifactBuilder {
  ReadingArtifactBuilder._();

  /// 관상 결과를 ReadingArtifact로 변환한다(사진/좌표는 절대 포함하지 않음).
  static ReadingArtifact fromFace(FaceResultModel result) {
    final steps = <ReadingStep>[
      ...result.features.entries.map(
        (e) => ReadingStep(
          key: e.key,
          chip: _faceChip[e.key] ?? '觀',
          title: e.key,
          body: e.value,
          // [v7.2] 픽셀 실측치가 없으므로 수치 행은 비워 둔다. 엔진이
          // 실제로 관찰해 적어준 텍스트 자체가 "엔진 실측" 섹션의 내용이다.
          measures: const [],
          cite: CiteRef(
            src: _defaultCite(ReadingKind.face).src,
            srcKo: _defaultCite(ReadingKind.face).srcKo,
            text:
                '${_faceGung[e.key] ?? e.key}의 생김에 관한 전통 관상학의 일반론(요지).',
          ),
        ),
      ),
      ...result.topicResults.entries
          .where((e) => e.key != '종합')
          .map(
            (e) => ReadingStep(
              key: e.key,
              chip: '總',
              title: e.key,
              body: e.value,
              measures: const [],
              cite: _defaultCite(ReadingKind.face),
            ),
          ),
    ];
    final total = ReadingTotal(
      key: '總',
      keyKo: '종합·總評',
      title: '관상 종합 풀이',
      body: result.summary,
      cite: _defaultCite(ReadingKind.face),
    );
    return ReadingArtifact(
      id: ReadingArtifact.newId(ReadingKind.face),
      kind: ReadingKind.face,
      createdAt: DateTime.now(),
      engine: const ReadingEngineMeta(version: 1),
      steps: steps,
      total: total,
      sourceResultId: result.id,
    );
  }

  /// 손금 결과를 ReadingArtifact로 변환한다.
  static ReadingArtifact fromPalm(PalmResultModel result) {
    final steps = <ReadingStep>[
      ...result.lines.entries.map(
        (e) => ReadingStep(
          key: e.key,
          chip: _palmChip[e.key] ?? '手',
          title: e.key,
          body: e.value,
          measures: const [],
          cite: CiteRef(
            src: _defaultCite(ReadingKind.palm).src,
            srcKo: _defaultCite(ReadingKind.palm).srcKo,
            text: '${_palmGung[e.key] ?? e.key}의 모양에 관한 서양 수상 전통의 일반론(요지).',
          ),
        ),
      ),
      ...result.topicResults.entries
          .where((e) => e.key != '종합')
          .map(
            (e) => ReadingStep(
              key: e.key,
              chip: '總',
              title: e.key,
              body: e.value,
              measures: const [],
              cite: _defaultCite(ReadingKind.palm),
            ),
          ),
    ];
    final total = ReadingTotal(
      key: '自',
      keyKo: '종합·總評',
      title: '손금 종합 풀이',
      body: result.summary,
      cite: _defaultCite(ReadingKind.palm),
    );
    return ReadingArtifact(
      id: ReadingArtifact.newId(ReadingKind.palm),
      kind: ReadingKind.palm,
      createdAt: DateTime.now(),
      engine: const ReadingEngineMeta(version: 1),
      steps: steps,
      total: total,
      sourceResultId: result.id,
    );
  }
}
