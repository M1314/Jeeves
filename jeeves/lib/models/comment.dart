class Comment {
  final int id;
  final String author;
  final String content;
  final DateTime date;
  final int postId;
  final int parentCommentId;
  final String? authorAvatarUrl;
  final String? postTitle;
  final String? postUrl;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.date,
    required this.postId,
    required this.parentCommentId,
    this.authorAvatarUrl,
    this.postTitle,
    this.postUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final rawContent =
        (json['content'] as Map<String, dynamic>?)?['rendered'] as String? ?? '';
    final strippedContent =
        rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    final avatarUrls =
        json['author_avatar_urls'] as Map<String, dynamic>?;
    final avatarUrl = avatarUrls?['96'] as String?;

    return Comment(
      id: json['id'] as int,
      author: json['author_name'] as String? ?? 'Anonymous',
      content: strippedContent,
      date: DateTime.parse(json['date'] as String),
      postId: json['post'] as int? ?? 0,
      parentCommentId: json['parent'] as int? ?? 0,
      authorAvatarUrl: avatarUrl,
      postTitle: json['post_title'] as String?,
      postUrl: json['post_url'] as String?,
    );
  }

  Comment copyWith({
    int? id,
    String? author,
    String? content,
    DateTime? date,
    int? postId,
    int? parentCommentId,
    String? authorAvatarUrl,
    String? postTitle,
    String? postUrl,
  }) {
    return Comment(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      date: date ?? this.date,
      postId: postId ?? this.postId,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      postTitle: postTitle ?? this.postTitle,
      postUrl: postUrl ?? this.postUrl,
    );
  }
}
