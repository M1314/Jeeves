import 'dart:convert';

class Post {
  final String id;
  final String blogId;
  final String url;
  final String title;
  final String author;
  final DateTime publishedAt;
  final DateTime updatedAt;
  final String body;
  final List<String> labels;
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

  /// Plain-text excerpt, stripped of HTML tags, truncated to [maxLength].
  String get excerpt {
    const maxLength = 200;
    final text = body
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] as String,
      blogId: map['blog_id'] as String,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'blog_id': blogId,
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

  /// Build a Post from the Blogger API v3 JSON response item.
  factory Post.fromBloggerJson(Map<String, dynamic> json, String blogId) {
    final authorMap = json['author'] as Map<String, dynamic>? ?? {};
    final replyMap = json['replies'] as Map<String, dynamic>? ?? {};
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
      publishedAt: DateTime.tryParse(json['published'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated'] as String? ?? '') ?? DateTime.now(),
      body: json['content'] as String? ?? '',
      labels: labelsList,
      commentCount:
          int.tryParse(replyMap['totalItems'] as String? ?? '0') ?? 0,
    );
  }

  static List<String> _decodeLabels(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }
}
