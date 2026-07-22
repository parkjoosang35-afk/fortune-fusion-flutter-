import '../../../core/api/api_result.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/ranking_model.dart';

/// 06단계 §4.13 `/v1/ranking` 대응 Mock Repository (포인트 랭킹 TOP 리스트)
class RankingRepository {
  static const _nicknames = [
    '운세마스터', '별빛여행자', '행운의사주', '타로퀸', '달빛소년', '금빛운명',
    '해피포춘', '럭키스타', '마법사쿠키', '오늘의행운', '소원지기', '초록달',
  ];

  Future<ApiResult<List<RankingEntryModel>>> getWeeklyRanking({required int myPoints}) async {
    await mockDelay(ms: 400);

    final entries = <RankingEntryModel>[];
    for (int i = 0; i < _nicknames.length; i++) {
      entries.add(RankingEntryModel(rank: i + 1, nickname: _nicknames[i], points: 9800 - i * 620));
    }

    // "나"를 임의 순위에 삽입 (Mock 시연용)
    final myRank = 7;
    entries.insert(
      myRank - 1,
      RankingEntryModel(rank: myRank, nickname: '나', points: myPoints, isMe: true),
    );

    // 순위 재정렬
    final resorted = <RankingEntryModel>[];
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      resorted.add(RankingEntryModel(rank: i + 1, nickname: e.nickname, points: e.points, isMe: e.isMe));
    }

    return ApiResult.ok(resorted);
  }
}
