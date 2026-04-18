/// Detail view for a single blog post with its threaded comments.
///
/// [PostDetailScreen] loads the [Post] and its [Comment]s from the local
/// database, then presents:
/// - The post title, author, publication date, and label chips.
/// - The full post body (HTML tags stripped to plain text).
/// - A threaded comment tree via [CommentThread], with optional keyword
///   highlights when navigated from a search result.
///
/// The [highlightQuery] parameter is forwarded to [CommentThread] so that
/// individual words matching the search term are highlighted in comment bodies.
///
/// The [scrollToCommentId] parameter is reserved for future use (e.g.
/// programmatically scrolling the list to a specific comment node); it is
/// passed here from [SearchScreen] when the user taps a comment result.
///
/// An action button displays the post URL via a [SnackBar] as a placeholder
/// until a `url_launcher` integration is added.
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../widgets/comment_thread.dart';
import 'package:intl/intl.dart';

/// Screen that displays the full content of a post and its comment thread.
class PostDetailScreen extends StatefulWidget {
  /// The [Post.id] of the post to display.
  final String postId;

  /// Optional search query whose terms are highlighted in the comment thread.
  final String? highlightQuery;

  /// Optional [Comment.id] indicating which comment should be visually
  /// emphasised (reserved for a future scroll-to implementation).
  final String? scrollToCommentId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.highlightQuery,
    this.scrollToCommentId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  /// Singleton data-access layer.
  final _db = DatabaseHelper.instance;

  /// The post loaded from the database, or `null` if not yet loaded.
  Post? _post;

  /// All comments for this post, ordered chronologically.
  List<Comment> _comments = [];

  /// `true` while the database fetch is in progress.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the post and its comments from the local database.
  ///
  /// Guards against calling [setState] after the widget has been unmounted
  /// (e.g. if the user navigates back before the query completes).
  Future<void> _load() async {
    final post = await _db.getPost(widget.postId);
    final comments = post != null
        ? await _db.getCommentsForPost(widget.postId)
        : <Comment>[];
    // Guard: the user may have already navigated away.
    if (!mounted) return;
    setState(() {
      _post = post;
      _comments = comments;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show a minimal loading scaffold while the database query is in progress.
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // The post was not found in the local database (e.g. deleted after sync).
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post not found')),
        body: const Center(child: Text('This post could not be found.')),
      );
    }

    final post = _post!;
    // Format the publication timestamp in the device's local timezone.
    final dateStr =
        DateFormat.yMMMMd().add_jm().format(post.publishedAt.toLocal());
    // Strip HTML tags from the post body for plain-text rendering.
    // A proper HTML renderer (e.g. flutter_html) could be substituted here.
    final bodyText = post.body
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          post.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Placeholder for url_launcher integration: show the post URL in a
          // SnackBar until the url_launcher package is added.
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(post.url)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Post title ─────────────────────────────────────────────────
          Text(post.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // ── Author and publication date ────────────────────────────────
          Text(
            '${post.author}  ·  $dateStr',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),

          // ── Label chips ────────────────────────────────────────────────
          if (post.labels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: post.labels
                  .map((l) => Chip(
                        label:
                            Text(l, style: theme.textTheme.labelSmall),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          const Divider(height: 32),

          // ── Post body (plain text) ─────────────────────────────────────
          Text(bodyText, style: theme.textTheme.bodyLarge),
          const Divider(height: 32),

          // ── Comments heading ───────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.comment_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_comments.length} Comments',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Comment thread ─────────────────────────────────────────────
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No comments yet.'),
            )
          else
            CommentThread(
              comments: _comments,
              highlightQuery: widget.highlightQuery,
            ),
        ],
      ),
    );
  }
}
