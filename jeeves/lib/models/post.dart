/// Immutable value-object representing a single Blogger/Blogspot post.
///
/// A [Post] is created in one of two ways:
/// 1. Deserialised from the local SQLite database via [Post.fromMap].
/// 2. Parsed directly from a Blogger API v3 JSON response via
///    [Post.fromBloggerJson].
///
/// All timestamps are stored and operated on as [DateTime] values; epoch
/// milliseconds are used only for the SQLite wire format.
///
/// Labels (tags) are stored as a JSON-encoded list in SQLite but surfaced as
/// a typed [List<String>] to the rest of the application.
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

/// Immutable data model for a blog post scraped from a Blogger/Blogspot site.
///
/// Fields map directly to the Blogger API v3 post resource and to columns in
/// the `posts` SQLite table.  The class is intentionally immutable; use
/// [copyWith] when a derived copy is needed (e.g. to update [commentCount]
/// after fetching comments).
class Post {
  /// Blogger-assigned post ID (numeric string, e.g. `"1234567890"`).
  final String id;

  /// Blogger blog ID that owns this post (matches [BlogSource.blogId]).
  final String blogId;

  /// Canonical URL of the post on the Blogger site.
  final String url;

  /// Title of the post as returned by the Blogger API.
  final String title;

  /// Display name of the post author as returned by the Blogger API.
  final String author;

  /// UTC timestamp when the post was originally published.
  final DateTime publishedAt;

  /// UTC timestamp of the most recent edit to the post.
  ///
  /// Used for incremental sync: posts are only re-fetched if the remote
  /// `updated` value is newer than the locally stored [updatedAt].
  final DateTime updatedAt;

  /// Full post body as raw HTML returned by the Blogger API.
  ///
  /// HTML is retained verbatim so that the detail screen can strip tags on
  /// demand and to avoid data loss if a richer renderer is added later.
  final String body;

  /// Blogger labels (tags) attached to the post, e.g. `["peak oil", "climate"]`.
  final List<String> labels;

  /// Locally-computed count of comments stored in the `comments` table for
  /// this post.  Updated by [DatabaseHelper.updatePostCommentCount] after each
  /// comment sync.
  final int commentCount;

  const Post({
    required this.id,
    required this.blogId,
    required this.url,
    required this.title,
    required this.author,
    required this.publishedAt,
    required this.updatedAt,
    required this.body,
    required this.labels,
    this.commentCount = 0,
  });

  /// Plain-text excerpt of the post body, stripped of HTML tags and
  /// normalised whitespace, truncated to 200 characters.
  ///
  /// Uses the [html] package's DOM parser to extract text from the raw HTML
  /// returned by the Blogger API for Ecosophia posts.  This handles nested
  /// elements, HTML entities (e.g. `&amp;`, `&nbsp;`), and malformed markup
  /// more reliably than regex-based stripping.
  ///
  /// Used in list and search result tiles where only a short preview is
  /// appropriate.  An ellipsis character is appended when the text is
  /// truncated.
  String get excerpt {
    const maxLength = 200;
    // Parse the Blogger-supplied HTML fragment and extract all inner text.
    // html_parser.parseFragment handles both full documents and bare HTML
    // snippets as returned by the Blogger API v3 `content` field.
    final fragment = html_parser.parseFragment(body);
    final text = (fragment.text ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';
  }

  /// Deserialises a [Post] from a SQLite column map.
  ///
  /// The [map] is expected to match the `posts` table schema:
  /// - Timestamps are stored as integer milliseconds since epoch.
  /// - Labels are stored as a JSON-encoded string (`'["tag1","tag2"]'`).
  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as String,
      blogId: map['blog_id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      // Timestamps are persisted as ms-since-epoch integers for compact
      // storage and fast range comparisons in SQL.
      publishedAt:
          DateTime.fromMillisecondsSinceEpoch(map['published_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      body: map['body'] as String,
      labels: _decodeLabels(map['labels'] as String? ?? '[]'),
      commentCount: map['comment_count'] as int? ?? 0,
    );
  }

  /// Serialises this [Post] into a SQLite column map.
  ///
  /// The map keys match the `posts` table column names exactly so that it can
  /// be passed directly to [DatabaseHelper.upsertPost] or a batch insert.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'blog_id': blogId,
      'url': url,
      'title': title,
      'author': author,
      // Store timestamps as integers to enable efficient SQL range filters
      // and avoid platform-specific date string parsing issues.
      'published_at': publishedAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'body': body,
      // SQLite has no native array type; encode labels as a JSON string so
      // they can be decoded back to a typed list without a join table.
      'labels': jsonEncode(labels),
      'comment_count': commentCount,
    };
  }

  /// Returns a shallow copy of this [Post] with the specified fields replaced.
  ///
  /// Currently only [commentCount] can be overridden because all other fields
  /// are immutable after a sync.  Extend as needed when editable fields are
  /// introduced.
  Post copyWith({int? commentCount}) {
    return Post(
      id: id,
      blogId: blogId,
      url: url,
      title: title,
      author: author,
      publishedAt: publishedAt,
      updatedAt: updatedAt,
      body: body,
      labels: labels,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  /// Parses a [Post] from a single item in a Blogger API v3 post list response.
  ///
  /// [json] should be the JSON object at `items[n]` in the API response.
  /// [blogId] is the Blogger blog ID supplied by the caller because the API
  /// does not include it in each post item.
  ///
  /// Gracefully handles missing or `null` fields by falling back to sensible
  /// defaults (empty strings, `DateTime.now()`, 0 comments).
  factory Post.fromBloggerJson(Map<String, dynamic> json, String blogId) {
    // The `author` field is a nested object: { id, displayName, url, image }.
    final authorMap = json['author'] as Map<String, dynamic>? ?? {};
    // `replies` is a nested object: { selfLink, totalItems }.
    final replyMap = json['replies'] as Map<String, dynamic>? ?? {};
    // `labels` is an optional array of plain strings.
    final labelsList = (json['labels'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Post(
      id: json['id'] as String,
      blogId: blogId,
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '(no title)',
      author: authorMap['displayName'] as String? ?? 'Unknown',
      // Blogger timestamps are RFC 3339 strings, e.g. "2024-01-15T12:00:00-05:00".
      publishedAt: DateTime.tryParse(json['published'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated'] as String? ?? '') ?? DateTime.now(),
      body: json['content'] as String? ?? '',
      labels: labelsList,
      // `totalItems` is a string in the API response, not an integer.
      commentCount:
          int.tryParse(replyMap['totalItems'] as String? ?? '0') ?? 0,
    );
  }

  /// Decodes a JSON-encoded label list (e.g. `'["tag1","tag2"]'`) back to a
  /// typed [List<String>].
  ///
  /// Returns an empty list on any decode failure to prevent crashes from
  /// malformed database rows.
  static List<String> _decodeLabels(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Silently ignore malformed JSON; an empty list is a safe fallback.
    }
    return [];
  }
}
