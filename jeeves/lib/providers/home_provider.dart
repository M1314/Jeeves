import 'package:flutter/foundation.dart';
import '../models/comment.dart';
import '../repositories/comment_repository.dart';

class HomeProvider extends ChangeNotifier {
  final CommentRepository _repository;

  List<Comment> _recentComments = [];
  bool _loading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  HomeProvider(this._repository);

  List<Comment> get recentComments => _recentComments;
  bool get loading => _loading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  Future<void> loadRecentComments({int page = 1}) async {
    _loading = true;
    _error = null;
    _currentPage = page;
    notifyListeners();

    try {
      final (comments, totalPages) =
          await _repository.getRecentComments(page: page);
      _recentComments = comments;
      _totalPages = totalPages;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
