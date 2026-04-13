/// HTTP client for the Blogger API v3.
///
/// [BloggerService] fetches posts and comments for a given [BlogSource] using
/// the Blogger REST API v3 (https://developers.google.com/blogger/docs/3.0/reference).
///
/// ## Key behaviours
/// - **Pagination**: iterates over every page of results by following
///   `nextPageToken` until the API returns no further token.
/// - **Incremental sync**: the [since] parameter sets the API's `startDate`
///   filter so that only posts updated after the last local sync are fetched.
/// - **Exponential back-off**: transient HTTP errors (429, 5xx) are retried
///   up to [_maxRetries] times with a randomised delay calculated as
///   `2^attempt × 500 ms ± jitter`.
/// - **Graceful degradation**: non-retryable errors (400, 404, other 4xx) and
///   exhausted retries return `null` rather than throwing so the caller can
///   skip the failed page and continue.
///
/// The service owns its [http.Client] and should be [dispose]d when no longer
/// needed to release the underlying TCP connection pool.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/post.dart';
import '../models/comment.dart';
import '../models/blog_source.dart';

/// Blogger API v3 client for fetching posts and comments.
///
/// Inject a custom [http.Client] in tests to mock HTTP responses.
class BloggerService {
  /// Base URL for all Blogger API v3 endpoints.
  static const _baseUrl = 'https://www.googleapis.com/blogger/v3';

  /// Maximum number of HTTP attempts (1 initial + up to 4 retries) before
  /// giving up on a page request.
  static const _maxRetries = 5;

  /// Number of items to request per page from the Blogger API.
  ///
  /// 50 is the maximum allowed by the API; higher values reduce the number
  /// of round-trips for large blogs.
  static const _pageSize = 50;

  /// Underlying HTTP client.  Shared across all requests from this instance
  /// so that keep-alive connections are reused.
  final http.Client _client;

  /// Creates a [BloggerService].
  ///
  /// Provide a [client] to inject a mock in unit tests; omit to use the
  /// default [http.Client] backed by the platform's HTTP stack.
  BloggerService({http.Client? client}) : _client = client ?? http.Client();

  /// Closes the underlying HTTP client and releases its connections.
  ///
  /// Must be called when the service is no longer needed (e.g. in
  /// [SyncService.dispose]).
  void dispose() => _client.close();

  // ─── Posts ───────────────────────────────────────────────────────────────

  /// Streams all posts for [source], optionally limited to those updated
  /// after [since].
  ///
  /// Follows `nextPageToken` through all pages of the Blogger API response,
  /// yielding each [Post] as it is parsed.  The caller can collect results
  /// with `.toList()` or process them lazily.
  ///
  /// If [since] is provided, only posts with an `updated` timestamp after
  /// that date are returned (sets the API's `startDate` parameter).  This
  /// enables efficient incremental sync — only new or changed posts are
  /// fetched on subsequent syncs.
  ///
  /// Yields nothing and exits cleanly if the API returns an error or if
  /// [_getWithRetry] gives up after exhausting retries.
  Stream<Post> fetchPosts(BlogSource source, {DateTime? since}) async* {
    final blogId = source.blogId;
    final apiKey = source.apiKey;

    String? pageToken;
    do {
      final uri = _buildPostsUri(blogId, apiKey, since, pageToken);
      final body = await _getWithRetry(uri);
      // A null body means the request failed or returned no content; stop
      // paginating rather than entering an infinite loop.
      if (body == null) break;

      final data = jsonDecode(body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          yield Post.fromBloggerJson(item as Map<String, dynamic>, blogId);
        }
      }
      // `nextPageToken` is absent (null) on the last page, terminating the loop.
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);
  }

  // ─── Comments ────────────────────────────────────────────────────────────

  /// Streams all comments for [postId] from [source], following pagination.
  ///
  /// Mirrors the pagination logic of [fetchPosts].  Because comments are
  /// fetched per-post, [SyncService] calls this method once per post
  /// returned by [fetchPosts].
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

  /// Constructs the URI for the Blogger API v3 posts list endpoint.
  ///
  /// Always requests live (published) posts with full bodies and without
  /// image objects to reduce payload size.  Optional parameters are only
  /// added when non-null.
  Uri _buildPostsUri(
    String blogId,
    String? apiKey,
    DateTime? since,
    String? pageToken,
  ) {
    final params = <String, String>{
      'maxResults': '$_pageSize',
      'fetchBodies': 'true',   // Include full post HTML content.
      'fetchImages': 'false',  // Omit image metadata to reduce payload.
      'status': 'live',        // Exclude draft and scheduled posts.
    };
    if (apiKey != null && apiKey.isNotEmpty) params['key'] = apiKey;
    if (since != null) {
      // The API accepts RFC 3339 UTC strings for startDate.
      params['startDate'] = since.toUtc().toIso8601String();
    }
    if (pageToken != null) params['pageToken'] = pageToken;

    return Uri.parse('$_baseUrl/blogs/$blogId/posts')
        .replace(queryParameters: params);
  }

  /// Constructs the URI for the Blogger API v3 comments list endpoint
  /// for a specific post.
  Uri _buildCommentsUri(
    String blogId,
    String postId,
    String? apiKey,
    String? pageToken,
  ) {
    final params = <String, String>{
      'maxResults': '$_pageSize',
      'fetchBodies': 'true',  // Include full comment HTML content.
      'status': 'live',       // Exclude pending-moderation comments.
    };
    if (apiKey != null && apiKey.isNotEmpty) params['key'] = apiKey;
    if (pageToken != null) params['pageToken'] = pageToken;

    return Uri.parse('$_baseUrl/blogs/$blogId/posts/$postId/comments')
        .replace(queryParameters: params);
  }

  // ─── HTTP with exponential back-off ──────────────────────────────────────

  /// Performs an HTTP GET for [uri], retrying on transient failures with
  /// exponential back-off.
  ///
  /// Returns the response body string on HTTP 200.  Returns `null` when:
  /// - The status code indicates a non-retryable client error (400, 404,
  ///   other 4xx).
  /// - All [_maxRetries] attempts have been exhausted for a 429 or 5xx error.
  /// - A network-level exception occurs and all retries are exhausted.
  Future<String?> _getWithRetry(Uri uri) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final response = await _client.get(uri, headers: {
          'Accept': 'application/json',
        });

        if (response.statusCode == 200) return response.body;

        // 404 — the blog, post, or comments resource does not exist.
        // No point retrying; return null immediately.
        if (response.statusCode == 404) return null;

        // 400 — bad request, e.g. malformed blog ID or invalid parameter.
        // Retrying will not help; return null immediately.
        if (response.statusCode == 400) return null;

        // 429 (Too Many Requests) or 5xx (server error) — transient;
        // increment the attempt counter and back off before the next try.
        if (response.statusCode == 429 ||
            response.statusCode >= 500) {
          attempt++;
          if (attempt >= _maxRetries) return null;
          await _backOff(attempt);
          continue;
        }

        // Any other 4xx (e.g. 401 Unauthorized, 403 Forbidden) is a
        // configuration error and will not self-resolve; return null.
        return null;
      } on Exception {
        // Network-level exception (SocketException, TimeoutException, etc.).
        // Back off and retry up to the maximum attempt count.
        attempt++;
        if (attempt >= _maxRetries) return null;
        await _backOff(attempt);
      }
    }
    return null;
  }

  /// Waits for an exponentially-growing delay before the next retry attempt.
  ///
  /// The delay is `2^attempt × 500 ms` plus up to 500 ms of random jitter
  /// to prevent a *thundering herd* when multiple sources are synced
  /// simultaneously and all hit a rate-limit at the same time.
  ///
  /// Example delays (without jitter):
  /// - attempt 1: ~1 s
  /// - attempt 2: ~2 s
  /// - attempt 3: ~4 s
  /// - attempt 4: ~8 s
  Future<void> _backOff(int attempt) async {
    final delay = Duration(
      milliseconds: (pow(2, attempt) * 500 + Random().nextInt(500)).toInt(),
    );
    await Future<void>.delayed(delay);
  }
}
