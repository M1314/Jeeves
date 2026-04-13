import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../widgets/comment_thread.dart';
import 'package:intl/intl.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? highlightQuery;
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
  final _db = DatabaseHelper.instance;
  Post? _post;
  List<Comment> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final post = await _db.getPost(widget.postId);
    final comments = post != null
        ? await _db.getCommentsForPost(widget.postId)
        : <Comment>[];
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

    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post not found')),
        body: const Center(child: Text('This post could not be found.')),
      );
    }

    final post = _post!;
    final dateStr =
        DateFormat.yMMMMd().add_jm().format(post.publishedAt.toLocal());
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
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in browser',
            onPressed: () {
              // URL is stored; caller can launch it with url_launcher
              // For now we show a snack bar with the URL.
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
          // Title
          Text(post.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // Meta
          Text(
            '${post.author}  ·  $dateStr',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          // Labels
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
          // Body
          Text(bodyText, style: theme.textTheme.bodyLarge),
          const Divider(height: 32),
          // Comments heading
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
          // Comment thread
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
