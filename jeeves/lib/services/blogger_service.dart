import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import '../models/comment.dart';
import '../models/blog_source.dart';

/// Wraps the Blogger API v3 to fetch posts and comments.
///
/// All public methods handle:
/// - Pagination (follows `nextPageToken` until exhausted)
/// - Exponential back-off on 429 / 5xx responses
/// - Incremental sync: only fetches items updated after [since]
class BloggerService {
  static const _baseUrl = 'https://www.googleapis.com/blogger/v3';
  static const _maxRetries = 5;
  static const _pageSize = 50;

  final http.Client _client;

  BloggerService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() => _client.close();

  // ─── Posts ───────────────────────────────────────────────────────────────

  /// Fetches all posts for [source], optionally only those updated after [since].
  Stream<Post> fetchPosts(BlogSource source, {DateTime? since}) async* {
    final blogId = source.blogId;
    final apiKey = source.apiKey;

    String? pageToken;
    do {
      final uri = _buildPostsUri(blogId, apiKey, since, pageToken);
      final body = await _getWithRetry(uri);
      if (body == null) break;

      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          yield Post.fromBloggerJson(item as Map<String, dynamic>, blogId);
        }
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
  }

  // ─── Comments ────────────────────────────────────────────────────────────

  /// Fetches all comments for a single [postId] from [source].
  Stream<Comment> fetchCommentsForPost(
    BlogSource source,
    String postId,
  ) async* {
    final blogId = source.blogId;
    final apiKey = source.apiKey;

    String? pageToken;
    do {
      final uri = _buildCommentsUri(blogId, postId, apiKey, pageToken);
      final body = await _getWithRetry(uri);
      if (body == null) break;

      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          yield Comment.fromBloggerJson(
              item as Map<String, dynamic>, postId);
        }
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
  }

  // ─── URI builders ────────────────────────────────────────────────────────

  Uri _buildPostsUri(
    String blogId,
    String? apiKey,
    DateTime? since,
    String? pageToken,
  ) {
    final params = <String, String>{
      'maxResults': '$_pageSize',
      'fetchBodies': 'true',
      'fetchImages': 'false',
      'status': 'live',
    };
    if (apiKey != null && apiKey.isNotEmpty) params['key'] = apiKey;
    if (since != null) {
      params['startDate'] = since.toUtc().toIso8601String();
    }
    if (pageToken != null) params['pageToken'] = pageToken;

    return Uri.parse('$_baseUrl/blogs/$blogId/posts')
        .replace(queryParameters: params);
  }

  Uri _buildCommentsUri(
    String blogId,
    String postId,
    String? apiKey,
    String? pageToken,
  ) {
    final params = <String, String>{
      'maxResults': '$_pageSize',
      'fetchBodies': 'true',
      'status': 'live',
    };
    if (apiKey != null && apiKey.isNotEmpty) params['key'] = apiKey;
    if (pageToken != null) params['pageToken'] = pageToken;

    return Uri.parse('$_baseUrl/blogs/$blogId/posts/$postId/comments')
        .replace(queryParameters: params);
  }

  // ─── HTTP with exponential back-off ──────────────────────────────────────

  Future<String?> _getWithRetry(Uri uri) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final response = await _client.get(uri, headers: {
          'Accept': 'application/json',
        });

        if (response.statusCode == 200) return response.body;

        // 404 → the resource simply doesn't exist; don't retry
        if (response.statusCode == 404) return null;

        // 400 → bad request (e.g. invalid blog ID); don't retry
        if (response.statusCode == 400) return null;

        // 429 or 5xx → back off and retry
        if (response.statusCode == 429 ||
            response.statusCode >= 500) {
          attempt++;
          if (attempt >= _maxRetries) return null;
          await _backOff(attempt);
          continue;
        }

        // Other 4xx → not retryable
        return null;
      } on Exception {
        attempt++;
        if (attempt >= _maxRetries) return null;
        await _backOff(attempt);
      }
    }
    return null;
  }

  Future<void> _backOff(int attempt) async {
    final delay = Duration(
      milliseconds: (pow(2, attempt) * 500 + Random().nextInt(500)).toInt(),
    );
    await Future<void>.delayed(delay);
  }
}
