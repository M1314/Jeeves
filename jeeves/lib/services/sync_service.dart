import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/blog_source.dart';
import 'blogger_service.dart';

enum SyncStatus { idle, syncing, done, error }

class SyncService extends ChangeNotifier {
  final DatabaseHelper _db;
  final BloggerService _blogger;

  SyncStatus _status = SyncStatus.idle;
  String _statusMessage = '';
  double _progress = 0;
  String? _lastError;

  SyncService({
    DatabaseHelper? db,
    BloggerService? blogger,
  })  : _db = db ?? DatabaseHelper.instance,
        _blogger = blogger ?? BloggerService();

  SyncStatus get status => _status;
  String get statusMessage => _statusMessage;
  double get progress => _progress;
  String? get lastError => _lastError;
  bool get isSyncing => _status == SyncStatus.syncing;

  /// Sync all enabled blog sources.
  Future<void> syncAll() async {
    if (_status == SyncStatus.syncing) return;
    final sources = await _db.getBlogSources();
    final enabled = sources.where((s) => s.enabled).toList();
    if (enabled.isEmpty) {
      _setStatus(SyncStatus.done, 'No blog sources configured.');
      return;
    }
    await _syncSources(enabled);
  }

  /// Sync a single blog source by ID.
  Future<void> syncSource(String sourceId) async {
    if (_status == SyncStatus.syncing) return;
    final sources = await _db.getBlogSources();
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) return;
    await _syncSources([source]);
  }

  Future<void> _syncSources(List<BlogSource> sources) async {
    _setStatus(SyncStatus.syncing, 'Starting sync…');
    _lastError = null;
    _progress = 0;

    try {
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        _setStatus(
            SyncStatus.syncing, 'Syncing "${source.name}" — fetching posts…');

        final since = await _db.getLatestPostUpdatedAt(source.blogId);

        // Collect all posts first so we can track progress
        final posts = await _blogger.fetchPosts(source, since: since).toList();
        await _db.upsertPosts(posts);

        // Fetch comments for each post
        for (var j = 0; j < posts.length; j++) {
          final post = posts[j];
          _progress = (i / sources.length) +
              (j / posts.length) * (1 / sources.length);
          _setStatus(
            SyncStatus.syncing,
            'Syncing "${source.name}" — '
            'comments for "${post.title}" (${j + 1}/${posts.length})…',
          );

          final comments = await _blogger
              .fetchCommentsForPost(source, post.id)
              .toList();
          await _db.upsertComments(comments);
          await _db.updatePostCommentCount(post.id);
        }

        await _db.updateLastSyncAt(source.id);
      }

      _progress = 1;
      _setStatus(SyncStatus.done, 'Sync complete.');
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error, 'Sync failed: $_lastError');
    }
  }

  void _setStatus(SyncStatus status, String message) {
    _status = status;
    _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _blogger.dispose();
    super.dispose();
  }
}
