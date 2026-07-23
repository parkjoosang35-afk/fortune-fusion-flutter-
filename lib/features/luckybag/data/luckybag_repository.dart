import 'dart:math';
import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/luckybag_model.dart';
import '../domain/luckybag_open_log_model.dart';
import '../domain/luckybag_product_model.dart';
import '../domain/luckybag_reward_model.dart';

/// 06단계 §4.9 `/v1/luckybags/*` 대응 Mock Repository
/// 10단계(Mock): 상품/확률테이블/개봉이력을 메모리에 고정 데이터로 유지.
/// 향후 실제 API 연동 시 이 클래스 내부 구현만 http 호출로 교체.
class LuckyBagRepository {
  // ── 기존(홈 배너 요약) - 변경 없음 ──
  Future<ApiResult<LuckyBagSummary>> getPendingSummary() async {
    await mockDelay(ms: 300);
    final seed = DateTime.now().day;
    final pending = seed % 3 == 0 ? 0 : 1 + (seed % 3);
    final grade = pending == 0
        ? 'none'
        : (['common', 'rare', 'epic'][seed % 3]);
    return ApiResult.ok(LuckyBagSummary(pendingCount: pending, grade: grade));
  }

  // ── Phase10: 상점/개봉/이력/보상요약 ──
  static const List<LuckyBagProductModel> _products = [
    LuckyBagProductModel(
      id: 'lb_001',
      name: '오늘의 복주머니',
      pricePoint: 300,
      iconEmoji: '🧿',
    ),
    LuckyBagProductModel(
      id: 'lb_002',
      name: '황금 복주머니',
      pricePoint: 800,
      iconEmoji: '🎊',
    ),
    LuckyBagProductModel(
      id: 'lb_003',
      name: '신년 특별 복주머니',
      pricePoint: 1500,
      iconEmoji: '🧧',
      seasonName: '신년 이벤트',
    ),
  ];

  /// 04A `luckybag_reward_pools`(I-3) 대응 Mock 확률 테이블(상품별 공통 적용, Mock 단순화)
  static final Map<String, List<LuckyBagRewardPoolModel>> _rewardPools = {
    'lb_001': [
      LuckyBagRewardPoolModel(
        id: 'rp_001_1',
        grade: LuckyBagGrade.byCode('none'),
        rewardType: 'none',
        rewardLabel: '다음 기회에',
        probability: 40,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_001_2',
        grade: LuckyBagGrade.byCode('common'),
        rewardType: 'point',
        rewardLabel: '100P',
        rewardAmount: 100,
        probability: 40,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_001_3',
        grade: LuckyBagGrade.byCode('rare'),
        rewardType: 'point',
        rewardLabel: '500P',
        rewardAmount: 500,
        probability: 15,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_001_4',
        grade: LuckyBagGrade.byCode('best'),
        rewardType: 'amulet',
        rewardLabel: '전설 부적',
        probability: 5,
      ),
    ],
    'lb_002': [
      LuckyBagRewardPoolModel(
        id: 'rp_002_1',
        grade: LuckyBagGrade.byCode('none'),
        rewardType: 'none',
        rewardLabel: '다음 기회에',
        probability: 25,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_002_2',
        grade: LuckyBagGrade.byCode('common'),
        rewardType: 'point',
        rewardLabel: '300P',
        rewardAmount: 300,
        probability: 45,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_002_3',
        grade: LuckyBagGrade.byCode('rare'),
        rewardType: 'point',
        rewardLabel: '1,000P',
        rewardAmount: 1000,
        probability: 22,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_002_4',
        grade: LuckyBagGrade.byCode('best'),
        rewardType: 'giftcard_fragment',
        rewardLabel: '상품권 조각',
        probability: 8,
      ),
    ],
    'lb_003': [
      LuckyBagRewardPoolModel(
        id: 'rp_003_1',
        grade: LuckyBagGrade.byCode('common'),
        rewardType: 'point',
        rewardLabel: '500P',
        rewardAmount: 500,
        probability: 55,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_003_2',
        grade: LuckyBagGrade.byCode('rare'),
        rewardType: 'point',
        rewardLabel: '2,000P',
        rewardAmount: 2000,
        probability: 30,
      ),
      LuckyBagRewardPoolModel(
        id: 'rp_003_3',
        grade: LuckyBagGrade.byCode('best'),
        rewardType: 'amulet',
        rewardLabel: '한정판 황금부적',
        probability: 15,
      ),
    ],
  };

  final List<LuckyBagOpenLogModel> _openLogs = [];
  final _random = Random();

  /// GET /v1/luckybags
  Future<ApiResult<List<LuckyBagProductModel>>> getProducts() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_products));
  }

  /// GET /v1/luckybags/:id/probabilities
  Future<ApiResult<List<LuckyBagRewardPoolModel>>> getProbabilities(
    String productId,
  ) async {
    await mockDelay(ms: 300);
    final pools = _rewardPools[productId];
    if (pools == null) return ApiResult.fail('존재하지 않는 상품입니다.');
    return ApiResult.ok(List.unmodifiable(pools));
  }

  /// POST /v1/luckybags/:id/open - 개봉(구매+추첨 동시 처리)
  /// 내부적으로 단일 트랜잭션 흉내: 확률 추첨 → open_logs 기록.
  /// 실제 포인트 spend/earn은 Provider단(WalletProvider)에서 orchestrate.
  Future<ApiResult<LuckyBagOpenResult>> open(
    String productId,
    int remainingBalance,
  ) async {
    await mockDelay(ms: 500);
    final product = _products.where((p) => p.id == productId).firstOrNull;
    final pools = _rewardPools[productId];
    if (product == null || pools == null || pools.isEmpty) {
      return ApiResult.fail('존재하지 않는 상품입니다.');
    }

    // 확률 가중 추첨(그룹 합=100 가정)
    final roll = _random.nextDouble() * 100;
    double acc = 0;
    var picked = pools.last;
    for (final pool in pools) {
      acc += pool.probability;
      if (roll <= acc) {
        picked = pool;
        break;
      }
    }

    final logId = 'lbol_${_openLogs.length + 1}';
    _openLogs.insert(
      0,
      LuckyBagOpenLogModel(
        id: logId,
        product: product,
        grade: picked.grade,
        rewardType: picked.rewardType,
        rewardLabel: picked.rewardLabel,
        rewardAmount: picked.rewardAmount,
        openedAt: DateTime.now(),
      ),
    );

    return ApiResult.ok(
      LuckyBagOpenResult(
        openLogId: logId,
        grade: picked.grade,
        rewardType: picked.rewardType,
        rewardLabel: picked.rewardLabel,
        rewardAmount: picked.rewardAmount,
        remainingBalance: remainingBalance,
      ),
    );
  }

  /// GET /v1/luckybags/history
  Future<ApiResult<List<LuckyBagOpenLogModel>>> getHistory() async {
    await mockDelay(ms: 300);
    return ApiResult.ok(List.unmodifiable(_openLogs));
  }

  /// GET /v1/luckybags/rewards/my - 등급/보상타입별 집계
  Future<ApiResult<List<LuckyBagRewardSummaryEntry>>> getRewardSummary() async {
    await mockDelay(ms: 300);
    final byGrade = <String, List<LuckyBagOpenLogModel>>{};
    for (final log in _openLogs) {
      byGrade.putIfAbsent(log.grade.code, () => []).add(log);
    }
    final entries = byGrade.entries.map((e) {
      final grade = LuckyBagGrade.byCode(e.key);
      final totalPoint = e.value
          .where((l) => l.rewardType == 'point')
          .fold<int>(0, (sum, l) => sum + (l.rewardAmount ?? 0));
      return LuckyBagRewardSummaryEntry(
        grade: grade,
        count: e.value.length,
        totalPointReward: totalPoint,
      );
    }).toList();
    entries.sort((a, b) => b.grade.sortOrder.compareTo(a.grade.sortOrder));
    return ApiResult.ok(entries);
  }
}
