class Post {
  final int id;
  final String title;
  final String url;
  final DateTime date;

  Post({
    required this.id,
    required this.title,
    required this.url,
    required this.date,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final rawTitle =
        (json['title'] as Map<String, dynamic>?)?['rendered'] as String? ?? '';
    final strippedTitle =
        rawTitle.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Post(
      id: json['id'] as int,
      title: strippedTitle,
      url: json['link'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
    );
  }
}
