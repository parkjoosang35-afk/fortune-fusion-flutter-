import 'dart:async';

import '../domain/wish_counsel_models.dart';
import '../theme/wish_counsel_colors.dart' show CounselCategory;
import 'wish_counsel_character_data.dart';

/// 상담(Midnight Comfort) Mock Repository.
///
/// [무료 광고형 구조 재정비] 정책(기존 `consultation_repository.dart` 참고) —
/// 이 모듈 역시 코인/과금 로직 없이 완전 Mock으로 동작하며, 향후 실 API
/// 연동 시(handoff `02_API_SPEC.md`의 6개 엔드포인트) 이 파일만 교체하면
/// Provider/Presentation 레이어는 변경 없이 재사용 가능하도록 설계했다.
///
/// 위기 감지: `01_AI_PROMPTS.md` §안전가드레일의 정규식을 그대로 이식.
class WishCounselRepository {
  WishCounselRepository() : _characters = loadWishCounselCharacters();

  final List<CounselCharacter> _characters;

  static final RegExp crisisPattern = RegExp(
    r'(죽고\s?싶|살기\s?싫|자해|극단적\s?선택|사라지고\s?싶|끝내고\s?싶|목숨을\s?끊)',
  );

  List<CounselCharacter> allCharacters() => List.unmodifiable(_characters);

  List<CounselCharacter> byCategory(CounselCategory cat) =>
      _characters.where((c) => c.category == cat).toList();

  CounselCharacter? byId(String id) {
    for (final c in _characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool detectCrisis(String text) => crisisPattern.hasMatch(text);

  /// 감정별 첫인사 변주(01_AI_PROMPTS.md 페르소나 락 요약본). 캐릭터별로
  /// voice_greeting을 기본값으로 사용하고, 감정이 지정되면 조금 더 맥락에
  /// 맞는 문장을 덧붙인다.
  String greetingFor(CounselCharacter character, {String? emotionKey}) {
    final base = character.voiceGreeting;
    if (emotionKey == null) return base;
    switch (emotionKey) {
      case 'anxious':
        return '$base\n지금 마음이 불안하셨군요. 천천히 짚어볼게요.';
      case 'stuck':
        return '$base\n답답한 마음, 여기서는 편하게 풀어놔도 돼요.';
      case 'excited':
        return '$base\n설레는 기운이 느껴지네요. 함께 들여다볼까요.';
      case 'tired':
        return '$base\n많이 지치셨나 봐요. 잠시 쉬어가듯 이야기해요.';
      case 'sad':
        return '$base\n마음이 많이 무거우셨겠어요. 함께 있을게요.';
      case 'angry':
        return '$base\n화가 나셨던 순간, 그 마음도 먼저 들어볼게요.';
      default:
        return base;
    }
  }

  /// 결정론적 Mock 응답 후보군(캐릭터 role별) — hashCode 기반 선택 패턴은
  /// 기존 `ConsultationRepository._replyPool`과 동일한 관행을 따른다.
  static const Map<String, List<String>> _replyPool = {
    '정통 명리형': [
      '사주 원국을 짚어보면, 지금은 큰 흐름이 바뀌는 시기예요. 서두르지 않아도 괜찮아요.',
      '올해 대운의 방향은 안정 쪽으로 기울어 있어요. 무리한 결정은 미뤄도 좋겠어요.',
      '팔자에 새겨진 기운을 보면, 지금 겪는 어려움은 지나가는 계절 같은 거예요.',
    ],
    '따뜻한 해석형': [
      '사주 안에는 당신이 생각보다 훨씬 다정한 사람이라는 게 담겨 있어요.',
      '지금 느끼는 감정, 사주로 봐도 자연스러운 흐름이에요. 너무 자책하지 말아요.',
      '관계에서 마음을 많이 쓰는 편이시네요. 그만큼 소중한 사람인 거예요.',
    ],
    '현실 조언형': [
      '결과만 말씀드릴게요. 지금은 움직일 때보다 준비할 때예요.',
      '재물운은 나쁘지 않아요. 다만 성급한 투자는 피하는 게 맞아요.',
      '이직이라면 지금부터 3개월 안이 낫습니다. 판단은 그래도 당신 몫이에요.',
    ],
    '신비 감성형': [
      '카드가 조용히 달을 보여주네요. 지금은 마음속 목소리에 귀 기울일 때예요.',
      '뽑힌 카드는 관계의 흐름이 서서히 바뀌고 있다는 뜻이에요.',
      '숨겨둔 감정이 카드 위로 떠올랐어요. 외면하지 않아도 괜찮아요.',
    ],
    '쿨한 직관형': [
      '결론부터. 지금은 예스예요.',
      '카드는 망설이지 말라고 하네요. 핵심만 말하면 그거예요.',
      '이번 주 흐름, 한 장으로 말하면 "전환"이에요.',
    ],
    '위로형 리더': [
      '오늘 뽑힌 카드는 당신을 다치지 않게 감싸주고 있어요.',
      '이별 뒤에 남은 마음, 그 카드가 조용히 안아주네요.',
      '자신을 사랑하는 카드가 나왔어요. 오늘은 그 말 하나만 기억해요.',
    ],
    '친구형': [
      '아 진짜? 그건 너 잘못 아니야. 나라도 그랬을 것 같아.',
      '음 들어보니까 좀 억울했겠다. 오늘은 그냥 다 풀어놔.',
      '괜찮아 괜찮아. 천천히 말해도 돼, 나 시간 많아.',
    ],
    '공감형': [
      '지금 그 감정, 이상한 게 아니에요. 충분히 그럴 수 있어요.',
      '말이 잘 안 나올 땐 나오는 만큼만 이야기해줘도 돼요.',
      '혼자 견디셨겠어요. 지금은 여기서 잠시 내려놓아도 괜찮아요.',
    ],
    '코치형': [
      '지금 상황을 하나씩 정리해볼까요. 가장 급한 것부터 짚어봐요.',
      '막막할 땐 작은 목표부터예요. 오늘 할 수 있는 딱 하나만 정해봐요.',
      '작심삼일이어도 다시 시작하면 그게 진짜 실행이에요.',
    ],
  };

  /// 위기 상황일 때의 고정 응답(01_AI_PROMPTS.md 안전가드레일).
  static const String _crisisReply =
      '지금 많이 힘든 마음이 느껴져요. 혼자 견디지 않아도 돼요.\n'
      '언제든 자살예방상담전화 1393으로 연결해 이야기 나눌 수 있어요.';

  /// 어절 단위 스트리밍 응답(기존 ConsultationRepository.streamReply와 동일한
  /// 관행 — 90ms 지연 방출로 타이핑 효과 재현).
  Stream<String> streamReply({
    required CounselCharacter character,
    required String userMessage,
  }) async* {
    final isCrisis = detectCrisis(userMessage);
    final String full;
    if (isCrisis) {
      full = _crisisReply;
    } else {
      final pool = _replyPool[character.role] ?? _replyPool['공감형']!;
      final idx = userMessage.hashCode.abs() % pool.length;
      full = pool[idx];
    }
    final tokens = full.split(RegExp(r'(?<=\s)'));
    for (final token in tokens) {
      await Future.delayed(const Duration(milliseconds: 90));
      yield token;
    }
  }

  Future<CounselSession> createSession(CounselCharacter character) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return CounselSession(
      id: 'session-${DateTime.now().millisecondsSinceEpoch}',
      character: character,
      messages: [],
      startedAt: DateTime.now(),
    );
  }
}
