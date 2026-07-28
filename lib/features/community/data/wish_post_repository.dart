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
        return ApiResult.fail(decoded['error'] as String? ?? '소원 목록을 불러오지 못했습니다.');
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

  Future<ApiResult<WishPostModel>> createPost(
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
      return ApiResult.ok(_wishFromJson(decoded['data'] as Map<String, dynamic>));
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
      return ApiResult.ok(_wishFromJson(decoded['data'] as Map<String, dynamic>));
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

  Future<ApiResult<WishCommentModel>> addComment(
    String wishId,
    String content,
  ) async {
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
      return ApiResult.ok(_commentFromJson(decoded['data'] as Map<String, dynamic>));
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
