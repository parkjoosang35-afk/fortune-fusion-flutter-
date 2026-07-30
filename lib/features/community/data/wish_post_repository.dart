import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/wish_post_model.dart';

/// 06단계 §4.12(소원게시판/커뮤니티) `/v1/wishes/*` 대응 Repository (Mock→실API 전환)
///
/// 대응 API(admin_web):
/// - GET  /api/public/wishes?tab=all|popular|mine     -> getFeed()
/// - POST /api/public/wishes                          -> createPost()
/// - POST /api/public/wishes/:id/support              -> toggleSupport() ("행운 보내기"
///                                                        임시정책: 포인트이동 없는 단순 응원카운트,
///                                                        03§10.3/§18/§570 정책 미확정 사항 유지)
/// - GET  /api/public/wishes/:id/comments             -> getComments()
/// - POST /api/public/wishes/:id/comments             -> addComment()
/// - POST /api/public/reports (targetType=wish)       -> report() (폴리모픽 공용신고,
///                                                        community_post_repository.dart와 동일 엔드포인트 재사용)
///
/// [방법 A — 임시 인증 우회] 회원 로그인 시스템이 아직 없어, 서버가 시딩해둔
/// 테스트 유저(userId=1)를 고정으로 사용한다(daily_fortune_repository.dart와 동일 패턴).
class WishPostRepository {
  Future<ApiResult<List<WishPostModel>>> getFeed({
    WishFeedTab tab = WishFeedTab.all,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final qp = <String, String>{'userId': '$userId', 'tab': tab.name};
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes',
    ).replace(queryParameters: qp);
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '소원 목록을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _wishFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[WishPostRepository] [getFeed] 예외 -> $e');
      return ApiResult.fail('소원 목록을 불러오지 못했습니다: $e');
    }
  }

  /// [3단계 - 복주머니 커뮤니티 적립 연동] admin_web `POST /api/public/wishes`가
  /// 소원 등록 시 point_policies.community 정책에 따라 지급한 rewardPoint를 함께
  /// 내려주므로, 여기서 함께 파싱해 반환한다(호출부가 "+N P 획득" 피드백을 표시할 수 있도록).
  Future<ApiResult<({WishPostModel post, int rewardPoint})>> createPost(
    String content, {
    String category = '기타',
    bool isAnonymous = false,
    String? goalTag,
  }) async {
    if (content.trim().isEmpty) return ApiResult.fail('내용을 입력해 주세요.');
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/wishes');
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'content': content.trim(),
              'category': category,
              'isAnonymous': isAnonymous,
              'goalTag': goalTag,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '소원 등록에 실패했습니다.');
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok((
        post: _wishFromJson(data),
        rewardPoint: (data['rewardPoint'] as num?)?.toInt() ?? 0,
      ));
    } catch (e) {
      debugPrint('[WishPostRepository] [createPost] 예외 -> $e');
      return ApiResult.fail('소원 등록에 실패했습니다: $e');
    }
  }

  /// "행운 보내기" - 포인트 이동 없는 단순 응원(support) 토글
  Future<ApiResult<WishPostModel>> toggleSupport(String wishId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes/$wishId/support',
    );
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '응원 처리에 실패했습니다.');
      }
      return ApiResult.ok(
        _wishFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[WishPostRepository] [toggleSupport] 예외 -> $e');
      return ApiResult.fail('응원 처리에 실패했습니다: $e');
    }
  }

  Future<ApiResult<List<WishCommentModel>>> getComments(String wishId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes/$wishId/comments',
    );
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '댓글을 불러오지 못했습니다.');
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _commentFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[WishPostRepository] [getComments] 예외 -> $e');
      return ApiResult.fail('댓글을 불러오지 못했습니다: $e');
    }
  }

  /// [3단계 - 복주머니 커뮤니티 적립 연동] 소원 댓글 작성 시 admin_web이
  /// wish_config.comment_bokju_reward 만큼 복주머니(bokjuAwarded)를 자동 지급하므로
  /// 함께 반환한다(호출부가 "+N 복주머니" 피드백/레벨업 연출을 표시할 수 있도록).
  Future<ApiResult<({WishCommentModel comment, int bokjuAwarded, bool leveledUp})>>
  addComment(String wishId, String content) async {
    if (content.trim().isEmpty) return ApiResult.fail('댓글 내용을 입력해 주세요.');
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes/$wishId/comments',
    );
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'content': content.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '댓글 작성에 실패했습니다.');
      }
      final data = decoded['data'] as Map<String, dynamic>;
      return ApiResult.ok((
        comment: _commentFromJson(data),
        bokjuAwarded: (data['bokjuAwarded'] as num?)?.toInt() ?? 0,
        leveledUp: data['leveledUp'] as bool? ?? false,
      ));
    } catch (e) {
      debugPrint('[WishPostRepository] [addComment] 예외 -> $e');
      return ApiResult.fail('댓글 작성에 실패했습니다: $e');
    }
  }

  /// 06§4.12 `POST /{targetType}/:id/report` 공용 신고(L-6, 폴리모픽)
  /// community_post_repository.dart와 동일한 /api/public/reports 엔드포인트 재사용
  Future<ApiResult<void>> report(
    ReportTargetType targetType,
    String targetId,
    String reason,
  ) async {
    if (reason.trim().isEmpty) return ApiResult.fail('신고 사유를 입력해 주세요.');
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/reports');
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'targetType': targetType.name,
              'targetId': targetId,
              'reason': reason.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '신고 접수에 실패했습니다.');
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[WishPostRepository] [report] 예외 -> $e');
      return ApiResult.fail('신고 접수에 실패했습니다: $e');
    }
  }

  /// [소원성(Wish Castle) 확장] 복주머니 보내기 - 실제 포인트/지갑 이동 없는
  /// 상징적 응원 단위. amount는 admin_web bokju_preset_amounts 화이트리스트를
  /// 그대로 따른다(서버에서도 [1,5,10,50,100] 외 값은 400 처리).
  /// 반환 data에는 leveledUp/previousLevel이 포함되어 있어, 호출부(Provider)에서
  /// 레벨업 여부에 따라 성장 연출/레벨업 연출을 분기할 수 있다.
  Future<ApiResult<Map<String, dynamic>>> sendBokju(
    String wishId,
    int amount,
  ) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes/$wishId/bokju',
    );
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'amount': amount}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '복주머니 보내기에 실패했습니다.',
        );
      }
      return ApiResult.ok(decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[WishPostRepository] [sendBokju] 예외 -> $e');
      return ApiResult.fail('복주머니 보내기에 실패했습니다: $e');
    }
  }

  /// [소원성(Wish Castle) 확장] CMS 설정(촛불 임계값/댓글보상/복주머니 단위/
  /// AI 응원문구/애니메이션 ON-OFF) 전체를 key-value로 조회.
  /// admin_web wish-config-meta.ts의 WISH_CONFIG_KEYS와 동일한 키 목록을
  /// 클라이언트에서 파싱한다(파싱은 WishCastleConfigProvider 쪽에서 수행).
  Future<ApiResult<Map<String, String>>> getWishConfig() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wish-config',
    );
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '설정을 불러오지 못했습니다.');
      }
      final map = (decoded['data'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      );
      return ApiResult.ok(map);
    } catch (e) {
      debugPrint('[WishPostRepository] [getWishConfig] 예외 -> $e');
      return ApiResult.fail('설정을 불러오지 못했습니다: $e');
    }
  }

  /// [소원성(Wish Castle) 확장] 최종 레벨(4) 도달 소원에 대한 성취 후기 등록.
  /// candleLevel<4인 소원에 호출하면 서버가 400을 반환한다(서버측 가드 재확인).
  Future<ApiResult<void>> submitReview(String wishId, String content) async {
    if (content.trim().isEmpty) return ApiResult.fail('후기 내용을 입력해 주세요.');
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes/$wishId/reviews',
    );
    try {
      final userId = await AuthTokenStore.getCurrentUserId();
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId, 'content': content.trim()}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '후기 등록에 실패했습니다.');
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[WishPostRepository] [submitReview] 예외 -> $e');
      return ApiResult.fail('후기 등록에 실패했습니다: $e');
    }
  }

  /// [소원성(Wish Castle) 확장] 명예의 전당 - 관리자가 수동 선정한 성취 후기
  /// (featuredReviews) + 응원 누적 상위 랭킹(ranking)을 함께 내려받는다.
  Future<ApiResult<Map<String, dynamic>>> getHallOfFame() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes/hall-of-fame',
    );
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '명예의 전당을 불러오지 못했습니다.',
        );
      }
      return ApiResult.ok(decoded['data'] as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[WishPostRepository] [getHallOfFame] 예외 -> $e');
      return ApiResult.fail('명예의 전당을 불러오지 못했습니다: $e');
    }
  }

  /// [소원성(Wish Castle) 확장] 최종단계(레벨4) 전체화면 특별 연출을 "이미 봤음"으로
  /// 표시(1회 제한 보장). 실패해도 UX에 큰 영향이 없으므로 호출부는 결과를 무시해도 된다.
  Future<ApiResult<void>> markMilestoneShown(String wishId) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/wishes/$wishId/milestone-shown',
    );
    try {
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '처리에 실패했습니다.');
      }
      return ApiResult.ok(null);
    } catch (e) {
      debugPrint('[WishPostRepository] [markMilestoneShown] 예외 -> $e');
      return ApiResult.fail('처리에 실패했습니다: $e');
    }
  }

  WishPostModel _wishFromJson(Map<String, dynamic> e) {
    return WishPostModel(
      id: e['id'] as String,
      authorNickname: e['authorNickname'] as String,
      content: e['content'] as String,
      category: e['category'] as String,
      isAnonymous: e['isAnonymous'] as bool? ?? false,
      supportCount: (e['supportCount'] as num?)?.toInt() ?? 0,
      commentCount: (e['commentCount'] as num?)?.toInt() ?? 0,
      isSupportedByMe: e['isSupportedByMe'] as bool? ?? false,
      isMine: e['isMine'] as bool? ?? false,
      createdAt: DateTime.parse(e['createdAt'] as String),
      goalTag: e['goalTag'] as String?,
      // [소원성(Wish Castle) 확장] 신규 필드 - 하위호환을 위해 없으면 기본값 사용
      candleLevel: (e['candleLevel'] as num?)?.toInt() ?? 0,
      bokjuCount: (e['bokjuCount'] as num?)?.toInt() ?? 0,
      achievedAt: e['achievedAt'] != null
          ? DateTime.parse(e['achievedAt'] as String)
          : null,
      isMilestoneShown: e['isMilestoneShown'] as bool? ?? false,
    );
  }

  WishCommentModel _commentFromJson(Map<String, dynamic> e) {
    return WishCommentModel(
      id: e['id'] as String,
      wishId: e['wishId'] as String,
      authorNickname: e['authorNickname'] as String,
      content: e['content'] as String,
      createdAt: DateTime.parse(e['createdAt'] as String),
    );
  }
}
