/// Immutable value-object representing a single comment on a blog post.
///
/// Comments are associated with their parent post via [postId] and may be
/// threaded via the optional [parentId] field.  The [CommentThread] widget
/// reconstructs the tree structure at render time from a flat list of
/// [Comment]s by matching [parentId] values to sibling [id]s.
///
/// HTML in [body] is preserved verbatim and stripped only when rendering via
/// [plainBody].
///
/// WordPress comments are fetched via the `/wp-json/wp/v2/comments` endpoint.
/// Dreamwidth comment sync is not supported (no public unauthenticated API).
class Comment {
  /// Unique comment identifier (numeric string).
  final String id;

  /// The [Post.id] of the post this comment belongs to.
  final String postId;

  /// The [id] of the parent comment if this is a reply, or `null` for
  /// top-level comments.
  ///
  /// Used by [CommentThread._buildTree] to reconstruct the nested thread
  /// structure from the flat list returned by the database.
  final String? parentId;

  /// Display name of the comment author.
  final String author;

  /// UTC timestamp when the comment was originally published.
  final DateTime publishedAt;

  /// Raw HTML body of the comment.
  final String body;

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.author,
    required this.publishedAt,
    required this.body,
  });

  /// Plain-text version of [body] with all HTML tags stripped and whitespace
  /// normalised to single spaces.
  ///
  /// Used by [CommentThread] for rendering and by [SearchScreen] for
  /// displaying match excerpts.
  String get plainBody =>
      body.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Deserialises a [Comment] from a SQLite column map.
  ///
  /// The [map] is expected to match the `comments` table schema:
  /// - [parentId] maps to `parent_id`, which may be `NULL` in SQLite.
  /// - [publishedAt] is stored as integer milliseconds since epoch.
  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      // parent_id is nullable in the database; a null value means this is a
      // top-level (root) comment in the thread.
      parentId: map['parent_id'] as String?,
      author: map['author'] as String,
      publishedAt:
          DateTime.fromMillisecondsSinceEpoch(map['published_at'] as int),
      body: map['body'] as String,
    );
  }

  /// Serialises this [Comment] into a SQLite column map.
  ///
  /// The map keys match the `comments` table column names exactly.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      // A null parent_id is stored as SQL NULL, which allows the database
      // to efficiently distinguish root comments from replies.
      'parent_id': parentId,
      'author': author,
      'published_at': publishedAt.millisecondsSinceEpoch,
      'body': body,
    };
  }

  /// Parses a [Comment] from a single item in a WordPress REST API v2 comment
  /// list response.
  ///
  /// [json] is the JSON object for one comment from
  /// `/wp-json/wp/v2/comments?post=<id>`.  [postId] is the owning post ID
  /// supplied by the caller because it matches the [Post.id] already stored
  /// locally.
  ///
  /// A `parent` value of `0` means the comment is top-level; any other value
  /// is the numeric ID of the parent comment.
  ///
  /// WordPress returns `date_gmt` as a UTC ISO 8601 string without a 'Z'
  /// suffix; this constructor appends 'Z' before parsing.
  factory Comment.fromWordPressJson(Map<String, dynamic> json, String postId) {
    final rawDate = json['date_gmt'] as String? ?? '';
    final normalised = rawDate.endsWith('Z') ? rawDate : '${rawDate}Z';
    final parentId = (json['parent'] as int? ?? 0) == 0
        ? null
        : json['parent'].toString();

    return Comment(
      id: json['id'].toString(),
      postId: postId,
      parentId: parentId,
      author: json['author_name'] as String? ?? 'Unknown',
      publishedAt: DateTime.tryParse(normalised) ?? DateTime.now(),
      body: (json['content'] as Map<String, dynamic>?)?['rendered']
              as String? ??
          '',
    );
  }
}
