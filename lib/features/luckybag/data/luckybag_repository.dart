import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/luckybag_model.dart';
import '../domain/luckybag_open_log_model.dart';
import '../domain/luckybag_product_model.dart';
import '../domain/luckybag_reward_model.dart';

/// 06단계 §4.9 `/v1/luckybags/*` 대응 Repository — admin_web 공개 API
/// (`GET /api/public/luckybag`, `POST /api/public/luckybag/open`,
/// `GET /api/public/luckybag/history`)를 호출한다.
///
/// [핵심 원칙] 확률 추첨과 행복머니 차감/지급은 서버(admin_web `luckybag/open` API)가
/// 단일 트랜잭션으로 처리한다. 이 Repository와 화면은 결과를 받아 표시만 한다
/// (클라이언트에서 별도로 확률을 뽑거나 행복머니를 차감하지 않음).
///
/// [방법 A — 임시 인증 우회] 회원 로그인 시스템이 아직 없어, 서버가 시딩해둔
/// 테스트 유저(userId=1)를 고정으로 사용한다(WalletRepository와 동일한 임시 값).
class LuckyBagRepository {
  // ── 기존(홈 배너 요약) - Mock 유지 ──
  // [비고] 서버 측 보상은 개봉 즉시 지급되는 구조라 "받을 수 있는(미수령) 행복머니 개수"
  // 개념이 별도로 존재하지 않는다. 홈 배너용 요약이므로 우선 Mock을 유지한다.
  Future<ApiResult<LuckyBagSummary>> getPendingSummary() async {
    await mockDelay(ms: 300);
    final seed = DateTime.now().day;
    final pending = seed % 3 == 0 ? 0 : 1 + (seed % 3);
    final grade = pending == 0
        ? 'none'
        : (['common', 'rare', 'epic'][seed % 3]);
    return ApiResult.ok(LuckyBagSummary(pendingCount: pending, grade: grade));
  }

  // 마지막으로 조회한 확률표를 캐시(같은 화면 내 확률보기 반복 호출 시 재요청 방지용).
  Map<String, List<LuckyBagRewardPoolModel>>? _cachedProbabilities;

  String _iconEmojiFor(String name) {
    if (name.contains('황금') || name.contains('한정')) return '🧧';
    if (name.contains('고급') || name.contains('프리미엄')) return '🎊';
    return '🧿';
  }

  /// GET /api/public/luckybag - 상품 목록 + 확률표를 한 번에 받아 각각 캐시한다.
  Future<Map<String, dynamic>?> _fetchLuckyBagData() async {
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/luckybag');
    debugPrint('[LuckyBagRepository] [1] 상품/확률표 요청 -> $uri');

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    debugPrint(
      '[LuckyBagRepository] [2] 응답 수신 -> statusCode=${response.statusCode}',
    );

    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) return null;
    return decoded['data'] as Map<String, dynamic>;
  }

  /// GET /v1/luckybags
  Future<ApiResult<List<LuckyBagProductModel>>> getProducts() async {
    try {
      final data = await _fetchLuckyBagData();
      if (data == null) {
        return ApiResult.fail('행복머니 목록을 불러오지 못했습니다.');
      }

      final productsRaw = data['products'] as List<dynamic>;
      final products = productsRaw.map((e) {
        final map = e as Map<String, dynamic>;
        final name = map['name'] as String;
        return LuckyBagProductModel(
          id: (map['id'] as int).toString(),
          name: name,
          pricePoint: map['pricePoint'] as int,
          iconEmoji: _iconEmojiFor(name),
          seasonName: map['seasonName'] as String?,
        );
      }).toList();

      final probabilitiesRaw = data['probabilities'] as Map<String, dynamic>;
      final probabilities = <String, List<LuckyBagRewardPoolModel>>{};
      for (final entry in probabilitiesRaw.entries) {
        probabilities[entry.key] = (entry.value as List<dynamic>).map((e) {
          final map = e as Map<String, dynamic>;
          return LuckyBagRewardPoolModel(
            id: (map['id'] as int).toString(),
            grade: LuckyBagGrade.byCode(map['gradeCode'] as String),
            rewardType: map['rewardType'] as String,
            rewardLabel: map['rewardLabel'] as String,
            rewardAmount: map['rewardAmount'] as int?,
            probability: (map['probability'] as num).toDouble(),
          );
        }).toList();
      }

      _cachedProbabilities = probabilities;

      return ApiResult.ok(List.unmodifiable(products));
    } catch (e, st) {
      debugPrint('[LuckyBagRepository] [X] getProducts 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('행복머니 목록을 불러오지 못했습니다: $e');
    }
  }

  /// GET /v1/luckybags/:id/probabilities - 확률 공개(투명성, 법적 요건)
  Future<ApiResult<List<LuckyBagRewardPoolModel>>> getProbabilities(
    String productId,
  ) async {
    try {
      // 캐시가 없으면(예: 상점 목록을 거치지 않고 직접 진입) 먼저 목록을 받아온다.
      if (_cachedProbabilities == null) {
        final productsResult = await getProducts();
        if (!productsResult.success) {
          return ApiResult.fail(
            productsResult.errorMessage ?? '확률 정보를 불러오지 못했습니다.',
          );
        }
      }
      final pools = _cachedProbabilities?[productId];
      if (pools == null) return ApiResult.fail('존재하지 않는 상품입니다.');
      return ApiResult.ok(List.unmodifiable(pools));
    } catch (e) {
      debugPrint('[LuckyBagRepository] [X] getProbabilities 예외 -> $e');
      return ApiResult.fail('확률 정보를 불러오지 못했습니다: $e');
    }
  }

  /// POST /v1/luckybags/:id/open - 개봉(구매+추첨). 서버(admin_web)가 행복머니 차감,
  /// 확률 추첨, 보상 지급, 개봉 로그 기록을 하나의 트랜잭션으로 처리하고 그 결과를
  /// 그대로 반환한다. [remainingBalance] 파라미터는 기존 시그니처 호환용으로 남겨두되
  /// 실제로는 사용하지 않는다(서버가 계산한 값을 신뢰).
  Future<ApiResult<LuckyBagOpenResult>> open(
    String productId,
    int remainingBalance,
  ) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/luckybag/open',
    );
    debugPrint('[LuckyBagRepository] [open] 요청 시작 -> productId=$productId');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'productId': int.parse(productId),
            }),
          )
          .timeout(const Duration(seconds: 10));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(
        '[LuckyBagRepository] [open] 응답 수신 -> statusCode=${response.statusCode}',
      );

      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '개봉 처리 중 오류가 발생했습니다.',
        );
      }

      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok(
        LuckyBagOpenResult(
          openLogId: (data['openLogId'] as int).toString(),
          grade: LuckyBagGrade.byCode(data['gradeCode'] as String),
          rewardType: data['rewardType'] as String,
          rewardLabel: data['rewardLabel'] as String,
          rewardAmount: data['rewardAmount'] as int?,
          remainingBalance: data['remainingBalance'] as int,
        ),
      );
    } catch (e, st) {
      debugPrint('[LuckyBagRepository] [X] open 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('개봉 처리 중 오류가 발생했습니다: $e');
    }
  }

  /// GET /v1/luckybags/history
  Future<ApiResult<List<LuckyBagOpenLogModel>>> getHistory() async {
    try {
      final result = await _fetchHistory();
      if (result == null) return ApiResult.fail('개봉 이력을 불러오지 못했습니다.');
      return ApiResult.ok(List.unmodifiable(result.$1));
    } catch (e, st) {
      debugPrint('[LuckyBagRepository] [X] getHistory 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('개봉 이력을 불러오지 못했습니다: $e');
    }
  }

  /// GET /v1/luckybags/rewards/my - 등급/보상타입별 집계(서버가 미리 합산해 제공)
  Future<ApiResult<List<LuckyBagRewardSummaryEntry>>> getRewardSummary() async {
    try {
      final result = await _fetchHistory();
      if (result == null) return ApiResult.fail('보상 요약을 불러오지 못했습니다.');
      return ApiResult.ok(List.unmodifiable(result.$2));
    } catch (e, st) {
      debugPrint('[LuckyBagRepository] [X] getRewardSummary 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('보상 요약을 불러오지 못했습니다: $e');
    }
  }

  Future<(List<LuckyBagOpenLogModel>, List<LuckyBagRewardSummaryEntry>)?>
  _fetchHistory() async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/luckybag/history?userId=$userId',
    );
    debugPrint('[LuckyBagRepository] [history] 요청 시작 -> $uri');

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    debugPrint(
      '[LuckyBagRepository] [history] 응답 수신 -> statusCode=${response.statusCode}',
    );

    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) return null;

    final data = decoded['data'] as Map<String, dynamic>;
    final itemsRaw = data['items'] as List<dynamic>;
    final items = itemsRaw.map((e) {
      final map = e as Map<String, dynamic>;
      final productMap = map['product'] as Map<String, dynamic>;
      final productName = productMap['name'] as String;
      return LuckyBagOpenLogModel(
        id: (map['id'] as int).toString(),
        product: LuckyBagProductModel(
          id: (productMap['id'] as int).toString(),
          name: productName,
          pricePoint: productMap['pricePoint'] as int,
          iconEmoji: _iconEmojiFor(productName),
        ),
        grade: LuckyBagGrade.byCode(map['gradeCode'] as String),
        rewardType: map['rewardType'] as String,
        rewardLabel: map['rewardLabel'] as String,
        rewardAmount: map['rewardAmount'] as int?,
        openedAt: DateTime.parse(map['openedAt'] as String),
      );
    }).toList();

    final summaryRaw = data['summary'] as List<dynamic>;
    final summary = summaryRaw.map((e) {
      final map = e as Map<String, dynamic>;
      return LuckyBagRewardSummaryEntry(
        grade: LuckyBagGrade.byCode(map['gradeCode'] as String),
        count: map['count'] as int,
        totalPointReward: map['totalPointReward'] as int,
      );
    }).toList()..sort((a, b) => b.grade.sortOrder.compareTo(a.grade.sortOrder));

    return (items, summary);
  }
}
