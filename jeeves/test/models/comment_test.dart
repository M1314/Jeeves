import 'package:flutter_test/flutter_test.dart';
import 'package:jeeves/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    test('parses a valid WordPress REST API comment response', () {
      final json = <String, dynamic>{
        'id': 42,
        'author_name': 'JohnGrunt',
        'content': {
          'rendered': '<p>This is a <strong>test</strong> comment.</p>\n',
        },
        'date': '2024-01-15T10:30:00',
        'post': 7,
        'parent': 0,
        'author_avatar_urls': {
          '24': 'https://example.com/avatar-24.jpg',
          '48': 'https://example.com/avatar-48.jpg',
          '96': 'https://example.com/avatar-96.jpg',
        },
      };

      final comment = Comment.fromJson(json);

      expect(comment.id, 42);
      expect(comment.author, 'JohnGrunt');
      expect(comment.content, 'This is a test comment.');
      expect(comment.date, DateTime.parse('2024-01-15T10:30:00'));
      expect(comment.postId, 7);
      expect(comment.parentCommentId, 0);
      expect(comment.authorAvatarUrl, 'https://example.com/avatar-96.jpg');
    });

    test('handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'id': 1,
        'author_name': 'Anonymous',
        'content': {'rendered': ''},
        'date': '2023-06-01T00:00:00',
        'post': 0,
        'parent': 0,
      };

      final comment = Comment.fromJson(json);

      expect(comment.id, 1);
      expect(comment.authorAvatarUrl, isNull);
      expect(comment.postTitle, isNull);
      expect(comment.postUrl, isNull);
    });

    test('strips HTML tags from content', () {
      final json = <String, dynamic>{
        'id': 2,
        'author_name': 'Tester',
        'content': {
          'rendered':
              '<p>Hello <a href="http://example.com">world</a>!</p>',
        },
        'date': '2024-03-10T08:00:00',
        'post': 3,
        'parent': 1,
      };

      final comment = Comment.fromJson(json);
      expect(comment.content, 'Hello world!');
      expect(comment.parentCommentId, 1);
    });

    test('copyWith returns updated copy', () {
      final original = Comment(
        id: 10,
        author: 'Alice',
        content: 'Original',
        date: DateTime(2024),
        postId: 5,
        parentCommentId: 0,
      );

      final copy = original.copyWith(author: 'Bob', content: 'Updated');

      expect(copy.id, 10);
      expect(copy.author, 'Bob');
      expect(copy.content, 'Updated');
      expect(copy.postId, 5);
    });
  });
}
