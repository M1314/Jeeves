/// Immutable value-object representing a single comment on a blog post.
///
/// Comments are associated with their parent post via [postId] and may be
/// threaded via the optional [parentId] field.  The [CommentThread] widget
/// reconstructs the tree structure at render time from a flat list of
/// [Comment]s by matching [parentId] values to sibling [id]s.
///
/// HTML in [body] is preserved verbatim (matching the Blogger API response)
/// and stripped only when rendering via [plainBody].
class Comment {
  /// Blogger-assigned comment ID (numeric string).
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

  /// Raw HTML body of the comment as returned by the Blogger API.
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

  /// Parses a [Comment] from a single item in a Blogger API v3 comment list
  /// response.
  ///
  /// [json] should be the JSON object at `items[n]` in the comment list.
  /// [postId] is supplied by the caller because the Blogger API does not
  /// embed the parent post ID inside each comment item.
  ///
  /// The `inReplyTo` field — when present — provides the [parentId] needed
  /// to reconstruct threaded conversations.
  factory Comment.fromBloggerJson(Map<String, dynamic> json, String postId) {
    // `author` is a nested object: { id, displayName, url, image }.
    final authorMap = json['author'] as Map<String, dynamic>? ?? {};
    // `inReplyTo` is only present when the comment is a direct reply to
    // another comment (as opposed to a top-level comment on the post).
    final inReplyTo = json['inReplyTo'] as Map<String, dynamic>?;

    return Comment(
      id: json['id'] as String,
      postId: postId,
      parentId: inReplyTo?['id'] as String?,
      author: authorMap['displayName'] as String? ?? 'Unknown',
      // Blogger timestamps are RFC 3339 strings.
      publishedAt: DateTime.tryParse(json['published'] as String? ?? '') ??
          DateTime.now(),
      body: json['content'] as String? ?? '',
    );
  }
}
