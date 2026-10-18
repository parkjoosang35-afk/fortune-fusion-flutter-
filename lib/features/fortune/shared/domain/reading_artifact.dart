// [관상·손금 결과화면 + 소원방 봉인 통합 리디자인 v7] ReadingArtifact 패턴.
//
// 디자인 핸드오프(design_handoff_gwansang_songeum_v7) `ReadingArtifact.jsx`
// `buildArtifact()`/`sealReading()`의 Flutter 포팅. 관상/손금 "읽기" 결과를
// 엔진(실측·판정) + LLM(해석) 묶음으로 "확정"해 사진/랜드마크 좌표 없이
// 소원방으로 넘길 수 있는 경계 객체로 만든다.
//
// [v7.2 원칙] 실측(엔진)과 전통 상법(문헌) 근거를 분리 표기한다.
//   - MeasureRow: 엔진이 실제로 관찰한 값만 담는다. min/max/lo/hi 같은
//     "분포 구간"은 절대 두지 않는다 — 전통 상법에는 그런 통계가 없으므로
//     없는 숫자를 지어내지 않는다(표준 불변 제약: Mock 데이터로 실패 가리지 않기).
//   - CiteRef: 출전(出典) 요지 — "원문 인용이 아닙니다" 고지와 함께 쓰인다.
//
// [v7.1 원칙] 풀이는 "동봉물"이며 새 소원을 만들지 않는다. 이 파일은 순수
// 데이터 모델만 다루고, 소원에 "얹는" 로직은 features/fortune/shared/data의
// 저장소와 wishroom 쪽 통합 지점에서 처리한다.
//
// [절대 금지] 사진 바이트·랜드마크 좌표는 이 객체에 포함하지 않는다
// (`photo` 필드는 항상 'ephemeral' 문자열 마커일 뿐이다).
library;

/// 관상(face) 또는 손금(palm) 구분.
enum ReadingKind {
  face,
  palm;

  String get apiValue => name;

  static ReadingKind fromString(String s) =>
      s == 'palm' ? ReadingKind.palm : ReadingKind.face;

  String get label => this == ReadingKind.face ? '관상' : '손금';
  String get hanja => this == ReadingKind.face ? '觀相' : '手相';
}

/// 엔진이 사진에서 실측/판정한 값 1행.
/// v7.2: 분포 막대·표준 구간(min/max/lo/hi) 없음 — 측정값만.
class MeasureRow {
  const MeasureRow({required this.label, required this.value, this.unit});

  /// 예: '상정 비율', '눈 크기', '생명선 길이'
  final String label;

  /// 예: '보통', '넓음', '큼' — 기존 백엔드(face-judgment.ts 등)가 실제로
  /// 산출하는 범주형 판정값을 그대로 담는다. 존재하지 않는 수치(㎜, %)를
  /// 새로 지어내지 않는다.
  final String value;
  final String? unit;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    if (unit != null) 'unit': unit,
  };

  factory MeasureRow.fromJson(Map<String, dynamic> j) => MeasureRow(
    label: j['label'] as String,
    value: j['value'] as String,
    unit: j['unit'] as String?,
  );
}

/// 전통 상법(문헌) 출전 요지. v7.2: "(요지)" 배지 + "원문 인용이 아닙니다" 고지.
class CiteRef {
  const CiteRef({required this.src, this.srcKo, required this.text});

  /// 한자 서명. 예: '麻衣相法', '神相全編'. 손금은 '西洋手相傳統'(v7.2 교정—
  /// 동양 손금은 십간 명명 체계이므로 '手相學'을 그대로 쓰지 않는다).
  final String src;
  final String? srcKo;

  /// 요지 본문(원문 인용 아님).
  final String text;

  Map<String, dynamic> toJson() => {
    'src': src,
    if (srcKo != null) 'srcKo': srcKo,
    'text': text,
  };

  factory CiteRef.fromJson(Map<String, dynamic> j) => CiteRef(
    src: j['src'] as String,
    srcKo: j['srcKo'] as String?,
    text: j['text'] as String,
  );
}

/// 부위 하나의 "풀이 1건" — 엔진 실측(measures) + LLM 해석(title/body) +
/// 출전(cite)을 함께 담는다. v7.2: '일치도' 대신 '부위 검출'(검출 신뢰도)
/// 라벨을 쓴다 — 가장 보수적인 의미(랜드마크 검출 신뢰도)로 교정.
class ReadingStep {
  const ReadingStep({
    required this.key,
    required this.chip,
    required this.title,
    required this.body,
    this.detectionConfidence,
    this.measures = const [],
    this.cite,
    this.status = 'ok',
  });

  /// 부위 식별자. 관상: 얼굴형/이마/눈썹/눈/코/입/턱/총평.
  /// 손금: 생명선/두뇌선/감정선/운명선/총평.
  final String key;

  /// 인장 한자 1~2자(디자인 핸드오프의 'chip'). 예: '輪','額','眉'...
  final String chip;

  final String title;
  final String body;

  /// 0.0~1.0. null이면 화면에 표시하지 않는다(v7.2: 없는 통계 창작 금지).
  final double? detectionConfidence;

  final List<MeasureRow> measures;
  final CiteRef? cite;

  /// LLM 해석 부분 실패 허용(v7.4 §9) — 'ok' | 'partial'.
  final String status;

  Map<String, dynamic> toJson() => {
    'key': key,
    'chip': chip,
    'title': title,
    'body': body,
    if (detectionConfidence != null)
      'detectionConfidence': detectionConfidence,
    'measures': measures.map((m) => m.toJson()).toList(),
    if (cite != null) 'cite': cite!.toJson(),
    'status': status,
  };

  factory ReadingStep.fromJson(Map<String, dynamic> j) => ReadingStep(
    key: j['key'] as String,
    chip: j['chip'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    detectionConfidence: (j['detectionConfidence'] as num?)?.toDouble(),
    measures: (j['measures'] as List? ?? const [])
        .map((e) => MeasureRow.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    cite: j['cite'] == null
        ? null
        : CiteRef.fromJson(Map<String, dynamic>.from(j['cite'])),
    status: j['status'] as String? ?? 'ok',
  );
}

/// 총결과(요약) — 디자인 핸드오프 TotalScreens.jsx의 TOTALS 구조.
class ReadingTotal {
  const ReadingTotal({
    required this.key,
    required this.keyKo,
    required this.title,
    required this.body,
    this.cite,
  });

  /// 총평 인장 한자 1자. 예: 관상 '晩', 손금 '自'.
  final String key;
  final String keyKo;
  final String title;
  final String body;
  final CiteRef? cite;

  Map<String, dynamic> toJson() => {
    'key': key,
    'keyKo': keyKo,
    'title': title,
    'body': body,
    if (cite != null) 'cite': cite!.toJson(),
  };

  factory ReadingTotal.fromJson(Map<String, dynamic> j) => ReadingTotal(
    key: j['key'] as String,
    keyKo: j['keyKo'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    cite: j['cite'] == null
        ? null
        : CiteRef.fromJson(Map<String, dynamic>.from(j['cite'])),
  );
}

/// 엔진 메타 — 버전만 기록. 실측 포인트는 각 step.measures에 분산 보관한다
/// (design_handoff의 engine.points/metrics를 그대로 복제하지 않고, 이미
/// 존재하는 "부위별 판정" 구조를 그대로 재사용하기 위함 — 기존 엔진 재구현 금지).
class ReadingEngineMeta {
  const ReadingEngineMeta({this.version = 1});
  final int version;
  Map<String, dynamic> toJson() => {'version': version};
  factory ReadingEngineMeta.fromJson(Map<String, dynamic> j) =>
      ReadingEngineMeta(version: (j['version'] as num?)?.toInt() ?? 1);
}

/// [핵심 모델] 관상/손금 "풀이 확정" 결과 — 사진·좌표 없이 소원방으로
/// 이동 가능한 경계 객체. `sealReading()`으로 생성된다.
///
/// [절대 금지] photo 필드는 항상 'ephemeral' 상수뿐이며, 실제 이미지
/// 바이트나 랜드마크 좌표를 담지 않는다.
class ReadingArtifact {
  const ReadingArtifact({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.engine,
    required this.steps,
    required this.total,
    required this.sourceResultId,
    this.photo = 'ephemeral',
  });

  final String id;
  final ReadingKind kind;
  final DateTime createdAt;
  final ReadingEngineMeta engine;
  final List<ReadingStep> steps;
  final ReadingTotal total;

  /// 원본 FaceResultModel.id / PalmResultModel.id — 서버 히스토리와의
  /// 연결점(기존 /api/public/fortune/face|palm 엔드포인트 재사용 원칙).
  final String sourceResultId;

  /// 항상 'ephemeral'. 사진이 전혀 보관되지 않음을 명시하는 마커.
  final String photo;

  int get measuredCount =>
      steps.fold(0, (sum, s) => sum + s.measures.length);
  int get interpretedCount => steps.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.apiValue,
    'createdAt': createdAt.toIso8601String(),
    'engine': engine.toJson(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'total': total.toJson(),
    'sourceResultId': sourceResultId,
    'photo': photo,
  };

  factory ReadingArtifact.fromJson(Map<String, dynamic> j) => ReadingArtifact(
    id: j['id'] as String,
    kind: ReadingKind.fromString(j['kind'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    engine: ReadingEngineMeta.fromJson(
      Map<String, dynamic>.from(j['engine'] ?? const {}),
    ),
    steps: (j['steps'] as List? ?? const [])
        .map((e) => ReadingStep.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    total: ReadingTotal.fromJson(Map<String, dynamic>.from(j['total'])),
    sourceResultId: j['sourceResultId'] as String? ?? '',
    photo: 'ephemeral',
  );

  static String newId(ReadingKind kind) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'ra_${kind.apiValue}_$now';
  }
}
