import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/wish_post_repository.dart';

/// [소원성(Wish Castle) 확장] admin_web CMS 설정(wish_config) 전역 Provider.
///
/// admin_web `src/lib/wish-config-meta.ts`의 WISH_CONFIG_KEYS와 동일한 키 목록을
/// 파싱해 앱 전역(커뮤니티 탭 진입 시 1회)에서 참조한다. 네트워크 실패 시에도 화면이
/// 깨지지 않도록 admin_web과 동일한 기본값(defaultValue)을 그대로 fallback으로 둔다.
///
/// [설계] 신규 API 클라이언트 클래스 없이 기존 WishPostRepository.getWishConfig()를
/// 재사용한다(03§9.2 과설계 방지 - Repository 중복 신설 금지).
class WishCastleConfigProvider extends ChangeNotifier {
  final WishPostRepository _repository;
  WishCastleConfigProvider(this._repository);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // 기본값 - admin_web wish-config-meta.ts WISH_CONFIG_KEYS defaultValue와 1:1 동일.
  List<int> _candleLevelThresholds = const [10, 30, 70, 150];
  int _commentBokjuReward = 1;
  List<int> _bokjuPresetAmounts = const [1, 5, 10, 50, 100];
  bool _animationEnabled = true;
  List<String> _aiCheerMessages = const [
    '당신의 마음이 따뜻한 응원으로 가득 채워지고 있어요',
    '작은 불빛이 모여 큰 빛이 되고 있어요',
    '누군가 당신의 소원을 함께 바라보고 있어요',
    '오늘도 한 걸음, 소원성이 더 밝아졌어요',
    '희망은 계속 자라나고 있어요',
  ];

  List<int> get candleLevelThresholds => _candleLevelThresholds;
  int get commentBokjuReward => _commentBokjuReward;
  List<int> get bokjuPresetAmounts => _bokjuPresetAmounts;
  bool get animationEnabled => _animationEnabled;
  List<String> get aiCheerMessages => _aiCheerMessages;

  /// 누적 행복머니 개수로 촛불 레벨(0~4)을 계산 - admin_web computeCandleLevel()과
  /// 완전히 동일한 로직. 서버가 이미 candleLevel을 계산해 내려주므로 평소에는 서버값을
  /// 그대로 신뢰하면 되지만, 애니메이션 중간 단계(예: 진행바가 목표 레벨을 향해 차오르는
  /// 연출)를 매끄럽게 그리기 위해 클라이언트에서도 동일하게 계산할 수 있게 공개한다.
  int computeCandleLevel(int bokjuCount) {
    var level = 0;
    for (var i = 0; i < _candleLevelThresholds.length; i++) {
      if (bokjuCount >= _candleLevelThresholds[i]) level = i + 1;
    }
    return level > 4 ? 4 : level;
  }

  /// 현재 레벨 안에서의 진행률(0.0~1.0) - 촛불 카드 진행바 표시용.
  /// 레벨0은 [0, threshold[0]] 구간, 레벨n(1~3)은 [threshold[n-1], threshold[n]] 구간,
  /// 최종 레벨(4)은 항상 1.0(가득 찬 상태)로 표시한다.
  double progressWithinLevel(int bokjuCount, int candleLevel) {
    if (candleLevel >= 4) return 1.0;
    final upper = _candleLevelThresholds[candleLevel];
    final lower = candleLevel == 0
        ? 0
        : _candleLevelThresholds[candleLevel - 1];
    if (upper <= lower) return 1.0;
    final ratio = (bokjuCount - lower) / (upper - lower);
    return ratio.clamp(0.0, 1.0);
  }

  /// AI 응원 메시지 목록 중 하나를 랜덤 노출 - "이루어진다"는 확정적 표현은 사용하지 않는다
  /// (마스터 기획 원칙 준수, admin_web ai_cheer_messages 문구도 동일 원칙으로 작성됨).
  String randomCheerMessage() {
    if (_aiCheerMessages.isEmpty) return '작은 불빛이 모여 큰 빛이 되고 있어요';
    final idx = DateTime.now().millisecondsSinceEpoch % _aiCheerMessages.length;
    return _aiCheerMessages[idx];
  }

  Future<void> loadConfig() async {
    final result = await _repository.getWishConfig();
    if (!result.success || result.data == null) {
      // 실패해도 기본값으로 정상 동작하도록 로드 완료 처리(사용자에게 별도 에러 노출 안 함)
      _isLoaded = true;
      notifyListeners();
      return;
    }
    final data = result.data!;
    _candleLevelThresholds = [
      _parseInt(data['candle_level_1_threshold'], 10),
      _parseInt(data['candle_level_2_threshold'], 30),
      _parseInt(data['candle_level_3_threshold'], 70),
      _parseInt(data['candle_level_4_threshold'], 150),
    ];
    _commentBokjuReward = _parseInt(data['comment_bokju_reward'], 1);
    _bokjuPresetAmounts = _parseIntList(
      data['bokju_preset_amounts'],
      _bokjuPresetAmounts,
    );
    _animationEnabled = (data['animation_enabled'] ?? 'true') == 'true';
    _aiCheerMessages = _parseStringList(
      data['ai_cheer_messages'],
      _aiCheerMessages,
    );
    _isLoaded = true;
    notifyListeners();
  }

  int _parseInt(String? raw, int fallback) {
    if (raw == null) return fallback;
    return int.tryParse(raw) ?? fallback;
  }

  List<int> _parseIntList(String? raw, List<int> fallback) {
    if (raw == null) return fallback;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => (e as num).toInt()).toList();
    } catch (e) {
      debugPrint('[WishCastleConfigProvider] bokju_preset_amounts 파싱 실패 -> $e');
      return fallback;
    }
  }

  List<String> _parseStringList(String? raw, List<String> fallback) {
    if (raw == null) return fallback;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[WishCastleConfigProvider] ai_cheer_messages 파싱 실패 -> $e');
      return fallback;
    }
  }
}
