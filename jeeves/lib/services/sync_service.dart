/// Orchestrates the full sync pipeline for all configured blog sources.
///
/// [SyncService] is a [ChangeNotifier] that:
/// 1. Reads the list of enabled [BlogSource]s from [DatabaseHelper].
/// 2. For each source, calls [FeedService.fetchPosts] (with an incremental
///    `since` timestamp derived from the locally stored data).
/// 3. Saves fetched posts to the database via [DatabaseHelper.upsertPosts].
/// 4. For each fetched post, calls [FeedService.fetchCommentsForPost],
///    saves the comments, and updates [Post.commentCount].
/// 5. Records the sync completion time via [DatabaseHelper.updateLastSyncAt].
///
/// Progress is surfaced to the UI through [status], [statusMessage], and
/// [progress] properties.  Widgets subscribe to changes via
/// `context.watch<SyncService>()` (provided at the root by `main.dart`).
///
/// Only one sync may run at a time; concurrent calls to [syncAll] or
/// [syncSource] while a sync is in progress are silently ignored.
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/blog_source.dart';
import 'blogger_service.dart';

/// Lifecycle enum for the sync operation.
///
/// - [idle]    — no sync has been requested since the last app launch.
/// - [syncing] — a sync is currently in progress.
/// - [done]    — the most recent sync completed successfully.
/// - [error]   — the most recent sync failed; see [SyncService.lastError].
enum SyncStatus { idle, syncing, done, error }

/// Application-level service that coordinates blog scraping and local storage.
///
/// Provided at the root of the widget tree so that any screen can observe or
/// trigger a sync without manual prop-drilling.  Dispose is handled
/// automatically when the provider is removed from the tree.
class SyncService extends ChangeNotifier {
  /// Data-access layer; defaults to the application singleton.
  final DatabaseHelper _db;

  /// HTTP client for WordPress and Dreamwidth feeds; defaults to a new instance.
  final FeedService _feed;

  /// Current lifecycle state of the sync operation.
  SyncStatus _status = SyncStatus.idle;

  /// Human-readable description of the current sync step, suitable for
  /// display in the [_SyncBanner] widget on the Settings screen.
  String _statusMessage = '';

  /// Fractional progress in the range `[0, 1]` representing how many
  /// posts across all sources have had their comments fetched.
  ///
  /// Displayed as an indeterminate indicator when `0` (before the first
  /// post is processed) and as a determinate indicator thereafter.
  double _progress = 0;

  /// Error message from the last failed sync, or `null` if the last sync
  /// succeeded (or no sync has been attempted).
  String? _lastError;

  /// Creates a [SyncService].
  ///
  /// Inject [db] and [feed] in tests to mock dependencies.
  SyncService({
    DatabaseHelper? db,
    FeedService? feed,
  })  : _db = db ?? DatabaseHelper.instance,
        _feed = feed ?? FeedService();

  // ─── Public state ─────────────────────────────────────────────────────────

  /// Current lifecycle state.  Widgets that need to distinguish between
  /// error and completed states should check [status] rather than [isSyncing].
  SyncStatus get status => _status;

  /// Human-readable status string suitable for display in the UI.
  String get statusMessage => _statusMessage;

  /// Fractional sync progress `[0, 1]`.  `0` before the first post has been
  /// processed; `1` on completion.
  double get progress => _progress;

  /// The error message from the last failed sync, or `null` otherwise.
  String? get lastError => _lastError;

  /// Convenience getter: `true` while a sync is actively running.
  bool get isSyncing => _status == SyncStatus.syncing;

  // ─── Public actions ───────────────────────────────────────────────────────

  /// Starts a sync for all enabled [BlogSource]s.
  ///
  /// A no-op if a sync is already in progress.  If no sources are configured
  /// or all are disabled, transitions directly to [SyncStatus.done].
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

  /// Starts a sync for the single [BlogSource] identified by [sourceId].
  ///
  /// A no-op if a sync is already in progress or if [sourceId] does not
  /// match any known source.
  Future<void> syncSource(String sourceId) async {
    if (_status == SyncStatus.syncing) return;
    final sources = await _db.getBlogSources();
    final source = sources.where((s) => s.id == sourceId).firstOrNull;
    if (source == null) return;
    await _syncSources([source]);
  }

  // ─── Internal sync pipeline ───────────────────────────────────────────────

  /// Core sync loop: iterates over [sources] and performs a full
  /// posts-then-comments sync for each one.
  ///
  /// Progress is calculated as:
  ///   `(sourceIndex / totalSources) + (postIndex / postsInSource) × (1 / totalSources)`
  /// so that the progress bar advances smoothly as comments are fetched for
  /// each post within each source.
  Future<void> _syncSources(List<BlogSource> sources) async {
    _setStatus(SyncStatus.syncing, 'Starting sync…');
    _lastError = null;
    _progress = 0;

    try {
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        _setStatus(
            SyncStatus.syncing, 'Syncing "${source.name}" — fetching posts…');

        // Use the most recent local `updated_at` as the incremental sync
        // boundary; null means this is a first-time full fetch.
        final since = await _db.getLatestPostUpdatedAt(source.siteUrl);

        // Collect all posts into a list first so we know the total count for
        // progress reporting.
        final posts = await _feed.fetchPosts(source, since: since).toList();
        await _db.upsertPosts(posts);

        // Fetch and store comments for each new/updated post.
        for (var j = 0; j < posts.length; j++) {
          final post = posts[j];
          // Update progress as a fraction of all work across all sources.
          _progress = (i / sources.length) +
              (j / posts.length) * (1 / sources.length);
          _setStatus(
            SyncStatus.syncing,
            'Syncing "${source.name}" — '
            'comments for "${post.title}" (${j + 1}/${posts.length})…',
          );

          final comments = await _feed
              .fetchCommentsForPost(source, post.id)
              .toList();
          await _db.upsertComments(comments);
          // Recompute the denormalised comment count after writing new comments.
          await _db.updatePostCommentCount(post.id);
        }

        // Record the successful sync time so subsequent syncs can be
        // incremental.
        await _db.updateLastSyncAt(source.id);
      }

      _progress = 1;
      _setStatus(SyncStatus.done, 'Sync complete.');
    } catch (e) {
      _lastError = e.toString();
      _setStatus(SyncStatus.error, 'Sync failed: $_lastError');
    }
  }

  /// Updates [_status] and [_statusMessage] then notifies all listeners.
  ///
  /// Batching the two state changes into one method ensures that widgets
  /// always see a consistent (status, message) pair and do not receive a
  /// partial update.
  void _setStatus(SyncStatus status, String message) {
    _status = status;
    _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    // Release the HTTP client's connection pool when the service is removed
    // from the Provider tree (typically only on app shutdown).
    _feed.dispose();
    super.dispose();
  }
}
