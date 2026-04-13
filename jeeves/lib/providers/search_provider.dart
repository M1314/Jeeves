import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../repositories/comment_repository.dart';

class SearchProvider extends ChangeNotifier {
  final CommentRepository _repository;

  String _query = '';
  List<Comment> _results = [];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  SearchProvider(this._repository);

  String get query => _query;
  List<Comment> get results => _results;
  bool get loading => _loading;
  String? get error => _error;
  int get page => _page;
  int get totalPages => _totalPages;

  Future<void> search(String query) async {
    if (query.isEmpty) {
      clear();
      return;
    }
    _query = query;
    _page = 1;
    _results = [];
    await _fetch();
  }

  Future<void> loadPage(int page) async {
    _page = page;
    await _fetch();
  }

  Future<void> _fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final (comments, totalPages) =
          await _repository.searchComments(_query, page: _page);
      _results = comments;
      _totalPages = totalPages;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _query = '';
    _results = [];
    _loading = false;
    _error = null;
    _page = 1;
    _totalPages = 1;
    notifyListeners();
  }
}
