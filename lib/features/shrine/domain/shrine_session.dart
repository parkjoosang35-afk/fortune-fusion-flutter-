// shrine_session.dart — 신당(神堂) 세션 상태. 기기 내 저장만, 서버 전송 없음
// (신당_개발지시서_v1.4.pdf §1.2). 신당 디자인 핸드오프의 session.dart(Session)를
// 순수 불변 데이터 클래스 그대로 이식했다(상태관리 래핑은
// shrine_session_provider.dart 가 ChangeNotifier로 담당 — 프로젝트 컨벤션).
import 'shrine_rite_data.dart';

enum ShrineTextSize { small, normal, large }

extension ShrineTextSizeX on ShrineTextSize {
  double get scale => const [.92, 1.0, 1.12][index];
  String get ko => const ['작게', '보통', '크게'][index];
}

class ShrineSession {
  final String name; // 최대 4자
  final DateTime birth;
  final String? hour; // '申時' | null(모름)
  final ShrineTopic topic;
  final ShrineChoice? choice;
  final Set<String> got; // 획득 결말 'A'..'D'
  final bool kept; // 소지부 간직 여부
  // 설정
  final bool sound; // 기본 OFF · 입장 제스처 이후만
  final bool reduceMotion; // 앱 설정 || MediaQuery.disableAnimations
  final bool climaxTimer; // 향 타이머 9s
  final ShrineTextSize textSize;
  // info 화면 진행 단계(이름→생일→시) — 신당 스타터에는 없던 필드이나
  // 화면 재진입 시 입력 단계를 복원하기 위해 추가.
  final int infoStep;

  ShrineSession({
    this.name = '',
    DateTime? birth,
    this.hour = '申時',
    this.topic = ShrineTopic.myeong,
    this.choice,
    this.got = const {},
    this.kept = false,
    this.sound = false,
    this.reduceMotion = false,
    this.climaxTimer = true,
    this.textSize = ShrineTextSize.normal,
    this.infoStep = 0,
  }) : birth = birth ?? DateTime(1995, 8, 14);

  ShrineSession copyWith({
    String? name,
    DateTime? birth,
    String? hour,
    bool clearHour = false,
    ShrineTopic? topic,
    ShrineChoice? choice,
    Set<String>? got,
    bool? kept,
    bool? sound,
    bool? reduceMotion,
    bool? climaxTimer,
    ShrineTextSize? textSize,
    int? infoStep,
  }) =>
      ShrineSession(
        name: name ?? this.name,
        birth: birth ?? this.birth,
        hour: clearHour ? null : (hour ?? this.hour),
        topic: topic ?? this.topic,
        choice: choice ?? this.choice,
        got: got ?? this.got,
        kept: kept ?? this.kept,
        sound: sound ?? this.sound,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        climaxTimer: climaxTimer ?? this.climaxTimer,
        textSize: textSize ?? this.textSize,
        infoStep: infoStep ?? this.infoStep,
      );

  String get displayName => name.isEmpty ? '이서윤' : name;
  ShrineEndingDef get ending => shrineEndings[choice ?? ShrineChoice.bell]!;

  Map<String, dynamic> toJson() => {
        'name': name,
        'birth': birth.toIso8601String(),
        'hour': hour,
        'topic': topic.index,
        'choice': choice?.index,
        'got': got.toList(),
        'kept': kept,
        'sound': sound,
        'rm': reduceMotion,
        'climax': climaxTimer,
        'ts': textSize.index,
        'infoStep': infoStep,
      };

  static ShrineSession fromJson(Map<String, dynamic> j) => ShrineSession(
        name: j['name'] ?? '',
        birth: DateTime.tryParse(j['birth'] ?? ''),
        hour: j['hour'],
        topic: ShrineTopic.values[j['topic'] ?? 0],
        choice: j['choice'] == null ? null : ShrineChoice.values[j['choice']],
        got: {...(j['got'] as List? ?? []).cast<String>()},
        kept: j['kept'] ?? false,
        sound: j['sound'] ?? false,
        reduceMotion: j['rm'] ?? false,
        climaxTimer: j['climax'] ?? true,
        textSize: ShrineTextSize.values[j['ts'] ?? 1],
        infoStep: j['infoStep'] ?? 0,
      );
}
