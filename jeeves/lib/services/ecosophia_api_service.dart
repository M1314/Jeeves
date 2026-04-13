import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/comment.dart';

class EcosophiaApiService {
  static const String _baseUrl = 'https://ecosophia.net/wp-json/wp/v2';

  Future<List<Comment>> searchCommentsByAuthor(String name) async {
    final uri = Uri.parse(
        '$_baseUrl/comments?author_name=${Uri.encodeComponent(name)}&per_page=50');
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch comments for author "$name": HTTP ${response.statusCode}');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error searching comments by author: $e');
    }
  }

  Future<(List<Comment>, int)> getCommentsForPost(int postId,
      {int page = 1}) async {
    final uri = Uri.parse(
        '$_baseUrl/comments?post=$postId&per_page=10&page=$page');
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch comments for post $postId: HTTP ${response.statusCode}');
      }
      final totalPages =
          int.tryParse(response.headers['x-wp-totalpages'] ?? '1') ?? 1;
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final comments = data
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
      return (comments, totalPages);
    } catch (e) {
      throw Exception('Error fetching comments for post: $e');
    }
  }

  Future<(List<Comment>, int)> getRecentComments({int page = 1}) async {
    final uri = Uri.parse(
        '$_baseUrl/comments?per_page=10&page=$page&orderby=date&order=desc');
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch recent comments: HTTP ${response.statusCode}');
      }
      final totalPages =
          int.tryParse(response.headers['x-wp-totalpages'] ?? '1') ?? 1;
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final comments = data
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
      return (comments, totalPages);
    } catch (e) {
      throw Exception('Error fetching recent comments: $e');
    }
  }

  Future<(List<Comment>, int)> searchComments(String query,
      {int page = 1}) async {
    final uri = Uri.parse(
        '$_baseUrl/comments?search=${Uri.encodeComponent(query)}&per_page=10&page=$page');
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to search comments for "$query": HTTP ${response.statusCode}');
      }
      final totalPages =
          int.tryParse(response.headers['x-wp-totalpages'] ?? '1') ?? 1;
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      final comments = data
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
      return (comments, totalPages);
    } catch (e) {
      throw Exception('Error searching comments: $e');
    }
  }

  Future<Comment?> getCommentById(int id) async {
    final uri = Uri.parse('$_baseUrl/comments/$id');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch comment $id: HTTP ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Comment.fromJson(data);
    } catch (e) {
      throw Exception('Error fetching comment by id: $e');
    }
  }
}
