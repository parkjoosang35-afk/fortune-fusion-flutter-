import '../theme/wish_counsel_colors.dart';

/// 상담(Midnight Comfort) · 도메인 모델
///
/// 출처: `handoff/data/characters.json` 구조를 그대로 이식. 프로젝트는
/// json_annotation을 사용하지 않으므로(pubspec.yaml 미설치) 모든 모델은
/// 수동 fromJson 팩토리를 갖는다.

/// 감정 6종 (홈/채팅 감정 칩에서 공용으로 사용)
class CounselEmotion {
  const CounselEmotion({
    required this.key,
    required this.label,
    required this.glyph,
  });

  final String key;
  final String label;
  final String glyph;

  static const List<CounselEmotion> all = [
    CounselEmotion(key: 'anxious', label: '불안해요', glyph: '◐'),
    CounselEmotion(key: 'stuck', label: '답답해요', glyph: '◑'),
    CounselEmotion(key: 'excited', label: '설레요', glyph: '◒'),
    CounselEmotion(key: 'tired', label: '지쳤어요', glyph: '◓'),
    CounselEmotion(key: 'sad', label: '슬퍼요', glyph: '◔'),
    CounselEmotion(key: 'angry', label: '화나요', glyph: '◕'),
  ];

  static CounselEmotion byKey(String key) =>
      all.firstWhere((e) => e.key == key, orElse: () => all.first);
}

/// 상담 모드 3종(일반/깊은/빠른)
///
/// [코인/포인트 잔재 제거] 과거 "코인/분" 과금 개념(coinPerMin)이 남아있었으나,
/// 이 앱의 유일한 재화는 복주머니뿐이며 AI 상담은 완전 무료 정책이므로 제거함.
class CounselMode {
  const CounselMode({
    required this.key,
    required this.label,
    required this.glyph,
    required this.maxTokens,
    this.pro = false,
  });

  final String key;
  final String label;
  final String glyph;
  final int maxTokens;
  final bool pro;

  static const List<CounselMode> all = [
    CounselMode(key: 'normal', label: '일반 상담', glyph: '○', maxTokens: 500),
    CounselMode(
      key: 'deep',
      label: '깊은 상담',
      glyph: '◐',
      maxTokens: 1200,
      pro: true,
    ),
    CounselMode(key: 'quick', label: '빠른 한마디', glyph: '◦', maxTokens: 200),
  ];
}

/// 상담사(캐릭터) 모델 — 9명
class CounselCharacter {
  const CounselCharacter({
    required this.id,
    required this.category,
    required this.name,
    required this.nameSub,
    required this.avatarAsset,
    required this.role,
    required this.tags,
    required this.styleTags,
    required this.specialties,
    required this.sampleQuestions,
    required this.voiceGreeting,
    required this.intro,
    required this.rating,
    required this.sessions,
  });

  final String id;
  final CounselCategory category;
  final String name;
  final String nameSub;
  final String avatarAsset;
  final String role;
  final List<String> tags;
  final List<String> styleTags;
  final List<String> specialties;
  final List<String> sampleQuestions;
  final String voiceGreeting;
  final String intro;
  final double rating;
  final int sessions;

  CounselCategoryTokens get theme => WishCounselColors.of(category);

  static CounselCategory _catOf(String key) {
    switch (key) {
      case 'saju':
        return CounselCategory.saju;
      case 'tarot':
        return CounselCategory.tarot;
      case 'counsel':
        return CounselCategory.counsel;
      default:
        return CounselCategory.counsel;
    }
  }

  factory CounselCharacter.fromJson(Map<String, dynamic> json) {
    return CounselCharacter(
      id: json['id'] as String,
      category: _catOf(json['cat'] as String),
      name: json['name'] as String,
      nameSub: json['name_sub'] as String? ?? '',
      avatarAsset: json['avatar'] as String,
      role: json['role'] as String? ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      styleTags:
          (json['style_tags'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      specialties:
          (json['specialties'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      sampleQuestions:
          (json['sample_questions'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      voiceGreeting: json['voice_greeting'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 채팅 발화자
enum CounselRole { user, ai }

/// 채팅 메시지(간단 버전 — 음성미리보기/트리거는 Phase 1 범위에서는 텍스트만)
class CounselMessage {
  CounselMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.crisis = false,
  });

  final String id;
  final CounselRole role;
  final String text;
  final DateTime createdAt;
  final bool crisis;

  CounselMessage copyWith({String? text, bool? crisis}) => CounselMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        crisis: crisis ?? this.crisis,
      );
}

/// 세션 요약(SUMMARY 화면용)
class CounselSession {
  CounselSession({
    required this.id,
    required this.character,
    required this.messages,
    required this.startedAt,
    this.startEmotion,
    this.endEmotion,
  });

  final String id;
  final CounselCharacter character;
  final List<CounselMessage> messages;
  final DateTime startedAt;
  String? startEmotion;
  String? endEmotion;

  Duration get elapsed => DateTime.now().difference(startedAt);
}
