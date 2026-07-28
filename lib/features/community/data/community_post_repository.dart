import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_result.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/config/env_config.dart';
import '../domain/community_post_model.dart';
import '../domain/wish_post_model.dart' show ReportTargetType;

/// 06단계 §4.12(리워드 커뮤니티) `/v1/community/*` 대응 Repository (Mock→실API 전환)
///
/// 대응 API(admin_web):
/// - GET  /api/public/community/boards               -> getBoards()
/// - GET  /api/public/community/posts?boardId=       -> getPosts()
/// - GET  /api/public/community/posts?sortByPopular=true -> getPosts(sortByPopular: true)
/// - POST /api/public/community/posts                -> createPost()
/// - POST /api/public/community/posts/:id/like       -> toggleLike()
/// - GET  /api/public/community/posts/:id/comments    -> getComments()
/// - POST /api/public/community/posts/:id/comments    -> addComment()
/// - POST /api/public/reports (targetType=communityPost) -> report() (폴리모픽 공용신고)
///
/// [방법 A — 임시 인증 우회] 회원 로그인 시스템이 아직 없어, 서버가 시딩해둔
/// 테스트 유저(userId=1)를 고정으로 사용한다(daily_fortune_repository.dart와 동일 패턴).
class CommunityPostRepository {
  Future<ApiResult<List<CommunityBoardModel>>> getBoards() async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/community/boards',
    );
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '게시판 목록을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map(
            (e) => CommunityBoardModel(
              id: e['id'] as String,
              code: e['code'] as String,
              name: e['name'] as String,
              description: e['description'] as String?,
              sortOrder: (e['sortOrder'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[CommunityPostRepository] [getBoards] 예외 -> $e');
      return ApiResult.fail('게시판 목록을 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<List<CommunityPostModel>>> getPosts({
    String? boardId,
    bool sortByPopular = false,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final qp = <String, String>{'userId': '$userId'};
    if (boardId != null) qp['boardId'] = boardId;
    if (sortByPopular) qp['sortByPopular'] = 'true';
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/community/posts',
    ).replace(queryParameters: qp);
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(
          decoded['error'] as String? ?? '게시글 목록을 불러오지 못했습니다.',
        );
      }
      final list = (decoded['data'] as List<dynamic>)
          .map((e) => _postFromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResult.ok(list);
    } catch (e) {
      debugPrint('[CommunityPostRepository] [getPosts] 예외 -> $e');
      return ApiResult.fail('게시글 목록을 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<CommunityPostModel>> createPost({
    required String boardId,
    required String title,
    required String content,
  }) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    if (title.trim().isEmpty || content.trim().isEmpty) {
      return ApiResult.fail('제목과 내용을 모두 입력해 주세요.');
    }
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/community/posts',
    );
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': userId,
              'boardId': boardId,
              'title': title.trim(),
              'content': content.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '게시글 작성에 실패했습니다.');
      }
      return ApiResult.ok(
        _postFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[CommunityPostRepository] [createPost] 예외 -> $e');
      return ApiResult.fail('게시글 작성에 실패했습니다: $e');
    }
  }

  Future<ApiResult<CommunityPostModel>> toggleLike(String postId) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/community/posts/$postId/like',
    );
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || decoded['success'] != true) {
        return ApiResult.fail(decoded['error'] as String? ?? '좋아요 처리에 실패했습니다.');
      }
      return ApiResult.ok(
        _postFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[CommunityPostRepository] [toggleLike] 예외 -> $e');
      return ApiResult.fail('좋아요 처리에 실패했습니다: $e');
    }
  }

  Future<ApiResult<List<CommunityCommentModel>>> getComments(
    String postId,
  ) async {
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/community/posts/$postId/comments',
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
      debugPrint('[CommunityPostRepository] [getComments] 예외 -> $e');
      return ApiResult.fail('댓글을 불러오지 못했습니다: $e');
    }
  }

  Future<ApiResult<CommunityCommentModel>> addComment(
    String postId,
    String content,
  ) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    if (content.trim().isEmpty) return ApiResult.fail('댓글 내용을 입력해 주세요.');
    final uri = Uri.parse(
      '${EnvConfig.adminApiBaseUrl}/api/public/community/posts/$postId/comments',
    );
    try {
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
      return ApiResult.ok(
        _commentFromJson(decoded['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('[CommunityPostRepository] [addComment] 예외 -> $e');
      return ApiResult.fail('댓글 작성에 실패했습니다: $e');
    }
  }

  /// 06§4.12 `POST /{targetType}/:id/report` 공용 신고(L-6, 폴리모픽)
  /// targetType='communityPost'로 소원게시판과 동일한 폴리모픽 신고 인터페이스 재사용
  Future<ApiResult<void>> report(
    ReportTargetType targetType,
    String targetId,
    String reason,
  ) async {
    final userId = await AuthTokenStore.getCurrentUserId();
    if (reason.trim().isEmpty) return ApiResult.fail('신고 사유를 입력해 주세요.');
    final uri = Uri.parse('${EnvConfig.adminApiBaseUrl}/api/public/reports');
    try {
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
      debugPrint('[CommunityPostRepository] [report] 예외 -> $e');
      return ApiResult.fail('신고 접수에 실패했습니다: $e');
    }
  }

  CommunityPostModel _postFromJson(Map<String, dynamic> e) {
    return CommunityPostModel(
      id: e['id'] as String,
      boardId: e['boardId'] as String,
      boardName: e['boardName'] as String,
      authorNickname: e['authorNickname'] as String,
      title: e['title'] as String,
      content: e['content'] as String,
      createdAt: DateTime.parse(e['createdAt'] as String),
      likeCount: (e['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (e['commentCount'] as num?)?.toInt() ?? 0,
      isPinned: e['isPinned'] as bool? ?? false,
      isLikedByMe: e['isLikedByMe'] as bool? ?? false,
      isMine: e['isMine'] as bool? ?? false,
    );
  }

  CommunityCommentModel _commentFromJson(Map<String, dynamic> e) {
    return CommunityCommentModel(
      id: e['id'] as String,
      postId: e['postId'] as String,
      authorNickname: e['authorNickname'] as String,
      content: e['content'] as String,
      createdAt: DateTime.parse(e['createdAt'] as String),
    );
  }
}
