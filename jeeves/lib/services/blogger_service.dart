/// HTTP client for fetching posts and comments from WordPress and Dreamwidth
/// sites.
///
/// [FeedService] supports two source types, selected automatically based on
/// [BlogSource.sourceType]:
///
/// - **WordPress** ([SourceType.wordpress]): uses the WordPress REST API v2
///   (`/wp-json/wp/v2/posts` and `/wp-json/wp/v2/comments`) to fetch posts
///   and comments with full pagination support and incremental sync via the
///   `after` (modified-date) parameter.
///
/// - **Dreamwidth** ([SourceType.dreamwidth]): parses the site's public Atom
///   feed (`/data/atom`) with page-level pagination via the `skip` query
///   parameter.  Comment sync is not available for Dreamwidth sources because
///   the platform exposes no unauthenticated per-post comments endpoint.
///
/// ## Common behaviours
/// - **Pagination**: iterates over every page of results until no more items
///   are returned.
/// - **Incremental sync**: the [since] parameter limits fetched posts to those
///   modified after the last local sync (WordPress only; Dreamwidth stops
///   paginating once it encounters an entry that pre-dates [since]).
/// - **Exponential back-off**: transient HTTP errors (429, 5xx) are retried
///   up to [_maxRetries] times with a randomised delay calculated as
///   `2^attempt × 500 ms ± jitter`.
/// - **Graceful degradation**: non-retryable errors and exhausted retries
///   return `null` rather than throwing so the caller can skip and continue.
///
/// The service owns its [http.Client] and should be [dispose]d when no longer
/// needed to release the underlying TCP connection pool.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/blog_source.dart';

/// Multi-platform feed client for fetching posts and comments.
///
/// Inject a custom [http.Client] in tests to mock HTTP responses.
class FeedService {
  /// Maximum number of HTTP attempts (1 initial + up to 4 retries) before
  /// giving up on a page request.
  static const _maxRetries = 5;

  /// Number of items to request per page from the WordPress REST API.
  ///
  /// 100 is the maximum allowed; higher values reduce round-trips for
  /// large blogs.
  static const _wpPageSize = 100;

  /// Number of entries served per Dreamwidth Atom feed page.
  ///
  /// Dreamwidth returns 25 entries per page by default; requests beyond the
  /// most recent ~1000 entries silently return an empty feed.
  static const _dwPageSize = 25;

  /// Underlying HTTP client shared across all requests from this instance so
  /// that keep-alive connections are reused.
  final http.Client _client;

  /// Creates a [FeedService].
  ///
  /// Provide a [client] to inject a mock in unit tests; omit to use the
  /// default [http.Client] backed by the platform's HTTP stack.
  FeedService({http.Client? client}) : _client = client ?? http.Client();

  /// Closes the underlying HTTP client and releases its connections.
  ///
  /// Must be called when the service is no longer needed (e.g. in
  /// [SyncService.dispose]).
  void dispose() => _client.close();

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Streams all posts for [source], optionally limited to those modified
  /// after [since].
  ///
  /// Dispatches to the appropriate platform implementation based on
  /// [BlogSource.sourceType].
  Stream<Post> fetchPosts(BlogSource source, {DateTime? since}) {
    switch (source.sourceType) {
      case SourceType.wordpress:
        return _fetchWordPressPosts(source, since: since);
      case SourceType.dreamwidth:
        return _fetchDreamwidthPosts(source, since: since);
    }
  }

  /// Streams all comments for [postId] from a [source].
  ///
  /// Only supported for [SourceType.wordpress] sources.  Dreamwidth sources
  /// always yield nothing (no unauthenticated comments endpoint).
  Stream<Comment> fetchCommentsForPost(
    BlogSource source,
    String postId,
  ) {
    switch (source.sourceType) {
      case SourceType.wordpress:
        return _fetchWordPressComments(source, postId);
      case SourceType.dreamwidth:
        // Dreamwidth has no public unauthenticated per-post comments API.
        return const Stream.empty();
    }
  }

  // ─── WordPress ────────────────────────────────────────────────────────────

  /// Fetches posts via the WordPress REST API v2 posts endpoint.
  ///
  /// Paginates through all available pages using the `X-WP-TotalPages`
  /// response header.  When [since] is provided, only posts with a
  /// `modified_gmt` value after that date are returned (using the `after`
  /// query parameter, which WordPress interprets against `modified_gmt`).
  Stream<Post> _fetchWordPressPosts(
    BlogSource source, {
    DateTime? since,
  }) async* {
    final base = _normalise(source.siteUrl);
    int page = 1;
    int totalPages = 1;

    do {
      final params = <String, String>{
        'per_page': '$_wpPageSize',
        '_embed': 'true',   // Inline author and taxonomy term objects.
        'page': '$page',
        'orderby': 'modified',
        'order': 'desc',
      };
      if (since != null) {
        // WordPress `after` filters by `modified_gmt`; only posts modified
        // after this date are returned, enabling incremental sync.
        params['after'] = since.toUtc().toIso8601String();
      }

      final uri =
          Uri.parse('$base/wp-json/wp/v2/posts').replace(queryParameters: params);
      final response = await _getWithRetry(uri);
      if (response == null) break;

      // On the first page, read the total page count from the response header
      // so that we know when to stop without fetching an empty last page.
      if (page == 1) {
        totalPages =
            int.tryParse(response.headers['x-wp-totalpages'] ?? '1') ?? 1;
      }

      final items = jsonDecode(response.body) as List<dynamic>;
      if (items.isEmpty) break;

      for (final item in items) {
        yield Post.fromWordPressJson(item as Map<String, dynamic>, source.siteUrl);
      }

      page++;
    } while (page <= totalPages);
  }

  /// Fetches comments via the WordPress REST API v2 comments endpoint.
  ///
  /// Paginates through all pages for the given [postId].
  Stream<Comment> _fetchWordPressComments(
    BlogSource source,
    String postId,
  ) async* {
    final base = _normalise(source.siteUrl);
    int page = 1;
    int totalPages = 1;

    do {
      final params = <String, String>{
        'per_page': '$_wpPageSize',
        'post': postId,
        'page': '$page',
        'orderby': 'date_gmt',
        'order': 'asc',
      };

      final uri = Uri.parse('$base/wp-json/wp/v2/comments')
          .replace(queryParameters: params);
      final response = await _getWithRetry(uri);
      if (response == null) break;

      if (page == 1) {
        totalPages =
            int.tryParse(response.headers['x-wp-totalpages'] ?? '1') ?? 1;
      }

      final items = jsonDecode(response.body) as List<dynamic>;
      if (items.isEmpty) break;

      for (final item in items) {
        yield Comment.fromWordPressJson(item as Map<String, dynamic>, postId);
      }

      page++;
    } while (page <= totalPages);
  }

  // ─── Dreamwidth ───────────────────────────────────────────────────────────

  /// Fetches posts from a Dreamwidth Atom feed, paginating via the `skip`
  /// query parameter.
  ///
  /// The Atom feed is ordered newest-first.  When [since] is provided,
  /// pagination stops as soon as an entry whose [Post.updatedAt] is not after
  /// [since] is encountered, avoiding fetching the entire archive on
  /// incremental syncs.
  Stream<Post> _fetchDreamwidthPosts(
    BlogSource source, {
    DateTime? since,
  }) async* {
    final base = _normalise(source.siteUrl);
    int skip = 0;

    while (true) {
      final uri = Uri.parse('$base/data/atom').replace(
        queryParameters: {'skip': '$skip'},
      );
      final response = await _getWithRetry(uri);
      if (response == null) break;

      final XmlDocument doc;
      try {
        doc = XmlDocument.parse(response.body);
      } catch (_) {
        // Malformed XML — stop paginating rather than crashing.
        break;
      }

      final entries = doc.findAllElements('entry').toList();
      if (entries.isEmpty) break;

      bool reachedSince = false;
      for (final entry in entries) {
        final post = Post.fromAtomEntry(entry, source.siteUrl);

        // Once we encounter an entry that pre-dates the incremental boundary,
        // all further entries (older) can be skipped.
        if (since != null && !post.updatedAt.isAfter(since)) {
          reachedSince = true;
          break;
        }
        yield post;
      }

      if (reachedSince || entries.length < _dwPageSize) break;
      skip += _dwPageSize;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Strips a single trailing slash from [url] so that path segments can be
  /// appended with a single `/` separator.
  String _normalise(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  // ─── HTTP with exponential back-off ──────────────────────────────────────

  /// Performs an HTTP GET for [uri], retrying on transient failures with
  /// exponential back-off.
  ///
  /// Returns the [http.Response] on HTTP 200.  Returns `null` when:
  /// - The status code indicates a non-retryable client error (400, 404,
  ///   other 4xx).
  /// - All [_maxRetries] attempts have been exhausted for a 429 or 5xx error.
  /// - A network-level exception occurs and all retries are exhausted.
  Future<http.Response?> _getWithRetry(Uri uri) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        final response = await _client.get(uri, headers: {
          'Accept': 'application/json, application/atom+xml, */*',
        });

        if (response.statusCode == 200) return response;

        // 404 — resource does not exist; no point retrying.
        if (response.statusCode == 404) return null;

        // 400 — bad request; retrying will not help.
        if (response.statusCode == 400) return null;

        // 429 (Too Many Requests) or 5xx (server error) — transient; back off.
        if (response.statusCode == 429 || response.statusCode >= 500) {
          attempt++;
          if (attempt >= _maxRetries) return null;
          await _backOff(attempt);
          continue;
        }

        // Any other 4xx is a configuration error and will not self-resolve.
        return null;
      } on Exception {
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
  Future<void> _backOff(int attempt) async {
    final delay = Duration(
      milliseconds: (pow(2, attempt) * 500 + Random().nextInt(500)).toInt(),
    );
    await Future<void>.delayed(delay);
  }
}
