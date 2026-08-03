import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api/api_result.dart';
import '../../../../core/auth/auth_token_store.dart';
import '../../../../core/config/env_config.dart';
import '../domain/tarot_model.dart';

/// 06단계 §4.3 `POST /v1/fortune/tarot/request` 대응 Repository
/// 09단계 §3.2-③ 타로 프롬프트 출력 스키마(cards/positions/interpretation) 반영
///
/// [Phase6 - AI운세 실LLM 연동] admin_web 공개 API(`POST /api/public/fortune/tarot`)를
/// 호출해 실제 LLM(ai_prompt_templates 기반)이 생성한 총평(summary) 텍스트를
/// 받아온다(Mock→실API 전환). 카드 뽑기 자체(어떤 카드가 정/역방향으로 나오는지)는
/// 서버에서도 여전히 결정론적 규칙(질문 해시 시드)으로 처리되며, 이번 연동
/// 범위는 "총평 텍스트"만 실LLM으로 교체하는 것이다.
///
/// [범위 밖] 78장 풀덱 로컬 메타데이터([TarotDeckData]/[buildFullTarotDeckMeta])와
/// [TarotTextEngine] 조합형 텍스트 생성 로직은 이번 연동에서 더 이상 사용하지
/// 않지만(서버가 총평을 대신 생성), 카드 아이콘 조회 등 화면 표시용 헬퍼로는
/// 계속 참조될 수 있어 파일 자체는 삭제하지 않는다.
///
/// [로드맵④] 실 로그인 사용자 ID를 [AuthTokenStore]에서 조회한다.
/// 비로그인 상태에서는 폴백 테스트 유저(userId=1)를 그대로 사용한다.
class TarotRepository {
  final List<TarotResultModel> _history = [];

  Future<ApiResult<TarotResultModel>> drawOneCard({required String question}) =>
      _draw(question: question, spreadType: 'one_card', topic: 'general');

  Future<ApiResult<TarotResultModel>> drawThreeCard({
    required String question,
  }) => _draw(question: question, spreadType: 'three_card', topic: 'general');

  Future<ApiResult<TarotResultModel>> drawThreeCards({
    required String question,
    String topic = 'general',
  }) => _draw(question: question, spreadType: 'three_card', topic: topic);

  /// [운세 카테고리 확장] 타로 YES/NO 스프레드(1장 뽑아 방향으로 답변).
  /// 기존 [drawOneCard]/[drawThreeCards]와 동일한 `_draw` 경로를 공유하며,
  /// `spreadType: 'yes_no'`만 서버에 추가로 전달한다(하위 호환, 추가 방식).
  Future<ApiResult<TarotResultModel>> drawYesNo({
    required String question,
    String topic = 'general',
  }) => _draw(question: question, spreadType: 'yes_no', topic: topic);

  Future<ApiResult<TarotResultModel>> _draw({
    required String question,
    required String spreadType,
    required String topic,
  }) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/fortune/tarot',
    );
    debugPrint(
      '[TarotRepository] [_draw] 요청 시작 -> $uri (spreadType=$spreadType, topic=$topic)',
    );

    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'question': question,
              'spreadType': spreadType,
              'topic': topic,
            }),
          )
          .timeout(const Duration(seconds: 45));

      debugPrint(
        '[TarotRepository] [_draw] 응답 수신 -> statusCode=${response.statusCode}',
      );

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        final error = decoded['error'] as String? ?? '타로 리딩에 실패했습니다.';
        debugPrint('[TarotRepository] [_draw] 실패 -> $error');
        return ApiResult.fail(error);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final positionsRaw = data['positions'] as List<dynamic>;
      final positions = positionsRaw.map((p) {
        final pos = p as Map<String, dynamic>;
        final cardRaw = pos['card'] as Map<String, dynamic>;
        final card = TarotCard(
          id: cardRaw['id'] as String,
          name: cardRaw['name'] as String,
          nameKr: cardRaw['nameKr'] as String,
          isReversed: cardRaw['isReversed'] as bool,
        );
        return TarotSpreadPosition(
          label: pos['label'] as String,
          card: card,
          interpretation: pos['interpretation'] as String,
        );
      }).toList();

      final result = TarotResultModel(
        id: data['id'] as String,
        question: data['question'] as String,
        spreadType: data['spreadType'] as String,
        positions: positions,
        summary: data['summary'] as String,
        createdAt: DateTime.parse(data['createdAt'] as String),
        topic: data['topic'] as String? ?? 'general',
        answer: data['answer'] as String?,
      );

      _history.insert(0, result);
      return ApiResult.ok(result);
    } catch (e, st) {
      debugPrint('[TarotRepository] [_draw] 예외 -> $e');
      if (kDebugMode) debugPrint('$st');
      return ApiResult.fail('타로 리딩에 실패했습니다: $e');
    }
  }

  /// [남은 미세조정] `GET /api/public/fortune/tarot/history`가 신설되어,
  /// 궁합(CompatibilityRepository.getHistory())과 동일한 패턴으로 서버
  /// 영속 이력을 조회한다. 서버 조회에 실패해도(오프라인 등) 이번 세션에서
  /// 누적된 로컬 결과는 그대로 보여줄 수 있도록 폴백을 유지한다.
  Future<ApiResult<List<TarotResultModel>>> getHistory() async {
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final uri = Uri.parse(
        '${EnvConfig.adminApiBaseUrl}/api/public/fortune/tarot/history?userId=$userId',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        debugPrint('[TarotRepository] [getHistory] 서버 조회 실패, 로컬로 폴백');
        return ApiResult.ok(List.unmodifiable(_history));
      }

      final list = (decoded['data'] as List<dynamic>).map((e) {
        final item = e as Map<String, dynamic>;
        final positionsRaw = item['positions'] as List<dynamic>;
        final positions = positionsRaw.map((p) {
          final pos = p as Map<String, dynamic>;
          final cardRaw = pos['card'] as Map<String, dynamic>;
          final card = TarotCard(
            id: cardRaw['id'] as String,
            name: cardRaw['name'] as String,
            nameKr: cardRaw['nameKr'] as String,
            isReversed: cardRaw['isReversed'] as bool,
          );
          return TarotSpreadPosition(
            label: pos['label'] as String,
            card: card,
            interpretation: pos['interpretation'] as String,
          );
        }).toList();

        return TarotResultModel(
          id: item['id'] as String,
          question: item['question'] as String,
          spreadType: item['spreadType'] as String,
          positions: positions,
          summary: item['summary'] as String,
          createdAt: DateTime.parse(item['createdAt'] as String),
          topic: item['topic'] as String? ?? 'general',
          answer: item['answer'] as String?,
        );
      }).toList();

      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[TarotRepository] [getHistory] 예외 -> $e, 로컬로 폴백');
      return ApiResult.ok(List.unmodifiable(_history));
    }
  }

  /// 07단계(추가) §3.6 - 78장 풀덱 메타데이터(화면 표시/카드 아이콘 조회용).
  /// 실제 카드 뽑기는 서버가 담당하므로, 이 메서드는 UI 참조용으로만 남아있다.
  List<TarotCardMeta> buildFullDeck() => TarotDeckData.fullDeck;
}
