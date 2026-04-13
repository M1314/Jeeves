import '../models/comment.dart';
import '../services/ecosophia_api_service.dart';

class _CachedResult<T> {
  final T data;
  final DateTime fetchedAt;

  _CachedResult({required this.data, required this.fetchedAt});

  bool get isExpired =>
      DateTime.now().difference(fetchedAt) > const Duration(minutes: 5);
}

class CommentRepository {
  final EcosophiaApiService _service;

  _CachedResult<(List<Comment>, int)>? _recentCommentsCache;
  final Map<String, _CachedResult<(List<Comment>, int)>> _searchCache = {};
  final Map<int, _CachedResult<(List<Comment>, int)>> _postCommentsCache = {};

  CommentRepository({EcosophiaApiService? service})
      : _service = service ?? EcosophiaApiService();

  Future<List<Comment>> searchCommentsByAuthor(String name) async {
    return _service.searchCommentsByAuthor(name);
  }

  Future<(List<Comment>, int)> getCommentsForPost(int postId,
      {int page = 1}) async {
    final cacheKey = postId * 10000 + page;
    final cached = _postCommentsCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    final result = await _service.getCommentsForPost(postId, page: page);
    _postCommentsCache[cacheKey] =
        _CachedResult(data: result, fetchedAt: DateTime.now());
    return result;
  }

  Future<(List<Comment>, int)> getRecentComments({int page = 1}) async {
    if (page == 1) {
      final cached = _recentCommentsCache;
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }
    final result = await _service.getRecentComments(page: page);
    if (page == 1) {
      _recentCommentsCache =
          _CachedResult(data: result, fetchedAt: DateTime.now());
    }
    return result;
  }

  Future<(List<Comment>, int)> searchComments(String query,
      {int page = 1}) async {
    final key = '${query}_$page';
    final cached = _searchCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    final result = await _service.searchComments(query, page: page);
    _searchCache[key] =
        _CachedResult(data: result, fetchedAt: DateTime.now());
    return result;
  }

  void clearCache() {
    _recentCommentsCache = null;
    _searchCache.clear();
    _postCommentsCache.clear();
  }
}
