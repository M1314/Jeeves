class Comment {
  final String id;
  final String postId;
  final String? parentId;
  final String author;
  final DateTime publishedAt;
  final String body;

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.author,
    required this.publishedAt,
    required this.body,
  });

  /// Plain-text body, stripped of HTML tags.
  String get plainBody =>
      body.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] as String,
      postId: map['post_id'] as String,
      parentId: map['parent_id'] as String?,
      author: map['author'] as String,
      publishedAt:
          DateTime.fromMillisecondsSinceEpoch(map['published_at'] as int),
      body: map['body'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'post_id': postId,
      'parent_id': parentId,
      'author': author,
      'published_at': publishedAt.millisecondsSinceEpoch,
      'body': body,
    };
  }

  /// Build a Comment from the Blogger API v3 JSON response item.
  factory Comment.fromBloggerJson(Map<String, dynamic> json, String postId) {
    final authorMap = json['author'] as Map<String, dynamic>? ?? {};
    final inReplyTo = json['inReplyTo'] as Map<String, dynamic>?;

    return Comment(
      id: json['id'] as String,
      postId: postId,
      parentId: inReplyTo?['id'] as String?,
      author: authorMap['displayName'] as String? ?? 'Unknown',
      publishedAt: DateTime.tryParse(json['published'] as String? ?? '') ??
          DateTime.now(),
      body: json['content'] as String? ?? '',
    );
  }
}
