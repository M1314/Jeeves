/// Immutable value-object representing a single blog post.
///
/// A [Post] is created in one of three ways:
/// 1. Deserialised from the local SQLite database via [Post.fromMap].
/// 2. Parsed from a WordPress REST API v2 JSON response via
///    [Post.fromWordPressJson].
/// 3. Parsed from a Dreamwidth Atom feed entry via [Post.fromAtomEntry].
///
/// All timestamps are stored and operated on as [DateTime] values; epoch
/// milliseconds are used only for the SQLite wire format.
///
/// Labels (tags) are stored as a JSON-encoded list in SQLite but surfaced as
/// a typed [List<String>] to the rest of the application.
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

/// Immutable data model for a blog post scraped from a WordPress or Dreamwidth
/// site.
///
/// Fields map to columns in the `posts` SQLite table and to the response
/// structures of both the WordPress REST API v2 and the Dreamwidth Atom feed.
/// The class is intentionally immutable; use [copyWith] when a derived copy is
/// needed (e.g. to update [commentCount] after fetching comments).
class Post {
  /// Unique post identifier.
  ///
  /// For WordPress sources this is the numeric post ID serialised as a string.
  /// For Dreamwidth Atom entries this is the numeric entry ID extracted from
  /// the `<id>` URL (e.g. the `"12345"` in
  /// `"https://ecosophia.dreamwidth.org/12345.html"`).
  final String id;

  /// Base URL of the [BlogSource] that owns this post (matches
  /// [BlogSource.siteUrl]).  Stored in the `blog_id` database column.
  final String siteUrl;

  /// Canonical URL of the post on the live site.
  final String url;

  /// Title of the post.
  final String title;

  /// Display name of the post author.
  final String author;

  /// UTC timestamp when the post was originally published.
  final DateTime publishedAt;

  /// UTC timestamp of the most recent edit to the post.
  ///
  /// Used for incremental sync: posts are only re-fetched if the remote
  /// modified timestamp is newer than the locally stored [updatedAt].
  final DateTime updatedAt;

  /// Full post body as raw HTML.
  ///
  /// HTML is retained verbatim so that the detail screen can strip tags on
  /// demand and to avoid data loss if a richer renderer is added later.
  final String body;

  /// Tags / labels attached to the post, e.g. `["peak oil", "climate"]`.
  ///
  /// WordPress sources populate this from the `wp:term` embedded taxonomy
  /// objects; Dreamwidth sources populate it from `<category term="...">`.
  final List<String> labels;

  /// Locally-computed count of comments stored in the `comments` table for
  /// this post.  Updated by [DatabaseHelper.updatePostCommentCount] after each
  /// comment sync.
  final int commentCount;

  const Post({
    required this.id,
    required this.siteUrl,
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
  /// Uses the [html] package's DOM parser to extract text from the raw HTML.
  /// This handles nested elements, HTML entities, and malformed markup more
  /// reliably than regex-based stripping.
  ///
  /// Used in list and search result tiles where only a short preview is
  /// appropriate.  An ellipsis character is appended when the text is
  /// truncated.
  String get excerpt {
    const maxLength = 200;
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
      siteUrl: map['blog_id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
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
      // The database column is named `blog_id`; it stores the site URL.
      'blog_id': siteUrl,
      'url': url,
      'title': title,
      'author': author,
      'published_at': publishedAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'body': body,
      'labels': jsonEncode(labels),
      'comment_count': commentCount,
    };
  }

  /// Returns a shallow copy of this [Post] with the specified fields replaced.
  Post copyWith({int? commentCount}) {
    return Post(
      id: id,
      siteUrl: siteUrl,
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

  // ─── Factory constructors for remote data ──────────────────────────────────

  /// Parses a [Post] from a single item in a WordPress REST API v2 posts list
  /// response (with `_embed=true`).
  ///
  /// [json] is the JSON object for one post in the `/wp-json/wp/v2/posts`
  /// response array.  [siteUrl] is the base URL of the [BlogSource], used as
  /// the post's owning source identifier.
  ///
  /// Author name is taken from the embedded `_embedded.author[0].name` field
  /// (available when `_embed=true` is sent with the request).
  ///
  /// Labels are derived from the embedded `wp:term` taxonomy objects, which
  /// include both categories and post tags.
  factory Post.fromWordPressJson(Map<String, dynamic> json, String siteUrl) {
    // `_embedded` is present when the request included `_embed=true`.
    final embedded = json['_embedded'] as Map<String, dynamic>?;
    final authorList = embedded?['author'] as List<dynamic>?;
    final authorName = authorList?.isNotEmpty == true
        ? (authorList!.first as Map<String, dynamic>)['name'] as String? ??
            'Unknown'
        : 'Unknown';

    // `wp:term` is a list-of-lists: one inner list per taxonomy.
    // Flatten all terms and collect their display names.
    final termGroups = embedded?['wp:term'] as List<dynamic>?;
    final labels = (termGroups ?? [])
        .expand((group) => group as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((t) => t['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    // WordPress returns `date_gmt` and `modified_gmt` as UTC ISO 8601 strings
    // without a 'Z' suffix (e.g. "2024-01-15T12:00:00").  Append 'Z' so that
    // DateTime.parse treats them as UTC rather than local time.
    DateTime parseGmt(String? raw) {
      if (raw == null || raw.isEmpty) return DateTime.now();
      final normalised = raw.endsWith('Z') ? raw : '${raw}Z';
      return DateTime.tryParse(normalised) ?? DateTime.now();
    }

    // `title.rendered` and `content.rendered` may contain HTML entities.
    // Extract plain text for the title; keep HTML for the body.
    final titleHtml =
        (json['title'] as Map<String, dynamic>?)?['rendered'] as String? ??
            '(no title)';
    final title = html_parser.parseFragment(titleHtml).text?.trim() ??
        titleHtml;

    return Post(
      id: json['id'].toString(),
      siteUrl: siteUrl,
      url: json['link'] as String? ?? '',
      title: title,
      author: authorName,
      publishedAt: parseGmt(json['date_gmt'] as String?),
      updatedAt: parseGmt(json['modified_gmt'] as String?),
      body: (json['content'] as Map<String, dynamic>?)?['rendered']
              as String? ??
          '',
      labels: labels,
      commentCount: json['comment_count'] as int? ?? 0,
    );
  }

  /// Parses a [Post] from a single `<entry>` element in a Dreamwidth Atom
  /// feed.
  ///
  /// [entry] is the parsed `<entry>` [XmlElement].  [siteUrl] is the base URL
  /// of the [BlogSource].
  ///
  /// The post ID is extracted as the trailing numeric segment of the Atom
  /// `<id>` URL (e.g. `"12345"` from
  /// `"https://ecosophia.dreamwidth.org/12345.html"`).
  factory Post.fromAtomEntry(XmlElement entry, String siteUrl) {
    String? text(String localName) =>
        entry.findElements(localName).firstOrNull?.innerText.trim();

    // Extract a stable numeric post ID from the Atom `<id>` element.
    //
    // Dreamwidth feeds may use either:
    //   • URL style:     "https://ecosophia.dreamwidth.org/12345.html"
    //   • Tag URI style: "tag:dreamwidth.org,2009:user:ecosophia:12345"
    //
    // Both patterns end with a numeric entry ID; we match the last
    // unambiguous run of digits in the string.  The fallback (when no
    // digits are found) is the raw `<id>` value itself, which is still
    // unique within the feed even if it is verbose.
    final idUrl = text('id') ?? '';
    final allDigits = RegExp(r'(\d+)').allMatches(idUrl).toList();
    final postId = allDigits.isNotEmpty
        ? allDigits.last.group(1)!
        : idUrl;

    // Author name lives inside <author><name>.
    final authorName = entry
            .findElements('author')
            .firstOrNull
            ?.findElements('name')
            .firstOrNull
            ?.innerText
            .trim() ??
        'Unknown';

    // The `rel="alternate"` link is the human-readable post URL.
    final linkEl = entry.findElements('link').firstWhere(
          (e) => e.getAttribute('rel') == 'alternate',
          orElse: () => entry.findElements('link').firstOrNull ??
              XmlElement(XmlName('link')),
        );
    final postUrl = linkEl.getAttribute('href') ?? '';

    // Categories appear as <category term="tag-name" />.
    final labels = entry
        .findElements('category')
        .map((e) => e.getAttribute('term') ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    // Prefer <content> for the full body; fall back to <summary>.
    final body = text('content') ?? text('summary') ?? '';

    return Post(
      id: postId,
      siteUrl: siteUrl,
      url: postUrl,
      title: text('title') ?? '(no title)',
      author: authorName,
      publishedAt:
          DateTime.tryParse(text('published') ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(text('updated') ?? '') ?? DateTime.now(),
      body: body,
      labels: labels,
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

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
