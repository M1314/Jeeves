import 'package:flutter/material.dart';
import '../models/comment.dart';
import 'package:intl/intl.dart';

/// Renders a list of [Comment]s as a recursive thread.
class CommentThread extends StatelessWidget {
  final List<Comment> comments;
  final String? highlightQuery;
  final int depth;

  const CommentThread({
    super.key,
    required this.comments,
    this.highlightQuery,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Build a tree from the flat list
    final roots = _buildTree(comments);
    return _CommentThreadInternal(
      nodes: roots,
      depth: depth,
      highlightQuery: highlightQuery,
    );
  }

  static List<_CommentNode> _buildTree(List<Comment> comments) {
    final map = <String, _CommentNode>{};
    for (final c in comments) {
      map[c.id] = _CommentNode(comment: c);
    }
    final roots = <_CommentNode>[];
    for (final c in comments) {
      final node = map[c.id]!;
      if (c.parentId != null && map.containsKey(c.parentId)) {
        map[c.parentId]!.children.add(node);
      } else {
        roots.add(node);
      }
    }
    return roots;
  }
}

class _CommentNode {
  final Comment comment;
  final List<_CommentNode> children = [];
  _CommentNode({required this.comment});
}

class _CommentThreadInternal extends StatelessWidget {
  final List<_CommentNode> nodes;
  final int depth;
  final String? highlightQuery;

  const _CommentThreadInternal({
    required this.nodes,
    required this.depth,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes
          .map((node) => _CommentItem(
                node: node,
                depth: depth,
                highlightQuery: highlightQuery,
              ))
          .toList(),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final _CommentNode node;
  final int depth;
  final String? highlightQuery;

  const _CommentItem({
    required this.node,
    required this.depth,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = node.comment;
    final indentWidth = depth * 16.0;
    final dateStr = DateFormat.yMMMd().add_jm().format(c.publishedAt.toLocal());

    final bodyText = c.plainBody;
    final highlighted = highlightQuery != null && highlightQuery!.isNotEmpty
        ? _buildHighlightedText(context, bodyText, highlightQuery!)
        : Text(bodyText, style: theme.textTheme.bodyMedium);

    return Padding(
      padding: EdgeInsets.only(left: indentWidth, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: depth > 0
                    ? BorderSide(
                        color: theme.colorScheme.outlineVariant, width: 2)
                    : BorderSide.none,
              ),
            ),
            padding: depth > 0
                ? const EdgeInsets.only(left: 12)
                : EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${c.author} · $dateStr',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                highlighted,
              ],
            ),
          ),
          if (node.children.isNotEmpty)
            _CommentThreadInternal(
              nodes: node.children,
              depth: depth + 1,
              highlightQuery: highlightQuery,
            ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    String query,
  ) {
    final theme = Theme.of(context);
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor: theme.colorScheme.tertiaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: spans,
      ),
    );
  }
}
