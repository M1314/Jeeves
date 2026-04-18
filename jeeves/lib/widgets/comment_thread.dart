/// Recursive comment thread widget.
///
/// [CommentThread] accepts a flat list of [Comment]s and builds a threaded
/// tree by matching [Comment.parentId] values to sibling [Comment.id]s.
/// Top-level comments (where [Comment.parentId] is `null` or references an
/// unknown comment) become root nodes; all other comments are nested beneath
/// their parent.
///
/// The tree is rendered by [_CommentThreadInternal] and [_CommentItem]
/// recursively.  Each reply level is indented by 16 dp and decorated with a
/// 2 dp vertical border in the theme's `outlineVariant` colour so thread
/// depth is visually clear.
///
/// An optional [highlightQuery] is forwarded to every [_CommentItem] so that
/// matching terms are highlighted with a background colour when the thread is
/// opened from a search result.
import 'package:flutter/material.dart';
import '../models/comment.dart';
import 'package:intl/intl.dart';

/// Public entry point widget.  Accepts a flat [comments] list and renders it
/// as a nested thread tree, optionally highlighting [highlightQuery] terms in
/// every comment body.
class CommentThread extends StatelessWidget {
  /// Flat list of comments to render.  Order within this list does not matter
  /// because the tree structure is determined by [Comment.parentId] matching.
  final List<Comment> comments;

  /// Optional search query.  All occurrences of this string in comment bodies
  /// are highlighted with a background colour.
  final String? highlightQuery;

  /// Starting depth level; defaults to 0 for the root call.  Used internally
  /// by recursive [_CommentThreadInternal] calls to increment indent levels.
  final int depth;

  const CommentThread({
    super.key,
    required this.comments,
    this.highlightQuery,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Convert the flat list into a tree of _CommentNodes.
    final roots = _buildTree(comments);
    return _CommentThreadInternal(
      nodes: roots,
      depth: depth,
      highlightQuery: highlightQuery,
    );
  }

  /// Converts a flat [List<Comment>] into a forest (list of root trees).
  ///
  /// Algorithm:
  /// 1. Create a [_CommentNode] for every comment and index them by ID.
  /// 2. For each comment, append its node to its parent's [children] list if
  ///    the parent exists in the index, otherwise treat it as a root node.
  ///
  /// This runs in O(n) time.  Comments whose [parentId] refers to a comment
  /// not in the list (e.g. a deleted or un-synced parent) are promoted to
  /// roots to avoid silent data loss.
  static List<_CommentNode> _buildTree(List<Comment> comments) {
    // Build an id → node index for O(1) parent lookup.
    final map = <String, _CommentNode>{};
    for (final c in comments) {
      map[c.id] = _CommentNode(comment: c);
    }
    final roots = <_CommentNode>[];
    for (final c in comments) {
      final node = map[c.id]!;
      if (c.parentId != null && map.containsKey(c.parentId)) {
        // Attach to the parent node's children list.
        map[c.parentId]!.children.add(node);
      } else {
        // No known parent → root comment.
        roots.add(node);
      }
    }
    return roots;
  }
}

/// Internal mutable tree node used during tree construction.
///
/// [children] is populated in [CommentThread._buildTree] and is read-only
/// after construction.
class _CommentNode {
  /// The comment this node represents.
  final Comment comment;

  /// Direct child replies, in the order they appear in the original flat list.
  final List<_CommentNode> children = [];

  _CommentNode({required this.comment});
}

/// Renders a list of [_CommentNode]s as a vertical column of [_CommentItem]s.
///
/// This widget is called recursively: each [_CommentItem] that has children
/// instantiates another [_CommentThreadInternal] with `depth + 1`.
class _CommentThreadInternal extends StatelessWidget {
  /// The nodes to render at this depth level.
  final List<_CommentNode> nodes;

  /// Current indentation depth (0 = root, 1 = first reply, etc.).
  final int depth;

  /// Forwarded highlight query.
  final String? highlightQuery;

  const _CommentThreadInternal({
    required this.nodes,
    required this.depth,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    // Return an empty widget for leaf nodes with no children.
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

/// Renders a single comment and recursively renders its children.
///
/// Visual structure:
/// - Horizontal indent of `depth × 16 dp` applied as padding.
/// - A 2 dp vertical left border (for depth > 0) to visually connect
///   replies to their parent thread.
/// - Author name and formatted publication date on one row.
/// - Comment body text with optional keyword highlights.
class _CommentItem extends StatelessWidget {
  /// The tree node containing the comment and its children.
  final _CommentNode node;

  /// Current indentation depth.
  final int depth;

  /// Optional highlight query.
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
    // Each nesting level adds 16 dp of left padding.
    final indentWidth = depth * 16.0;
    final dateStr = DateFormat.yMMMd().add_jm().format(c.publishedAt.toLocal());

    final bodyText = c.plainBody;
    // Build highlighted or plain body text based on whether a query is active.
    final highlighted = highlightQuery != null && highlightQuery!.isNotEmpty
        ? _buildHighlightedText(context, bodyText, highlightQuery!)
        : Text(bodyText, style: theme.textTheme.bodyMedium);

    return Padding(
      // Indent replies relative to their parent.
      padding: EdgeInsets.only(left: indentWidth, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                // Show a vertical left border only for nested comments
                // (depth > 0) so root comments are flush with the margin.
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
                // ── Author and timestamp ────────────────────────────
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
                // ── Comment body (plain text, optional highlight) ───
                highlighted,
              ],
            ),
          ),
          // ── Recursive children ────────────────────────────────────
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

  /// Builds a [RichText] widget with all occurrences of [query] in [text]
  /// highlighted using the theme's `tertiaryContainer` background colour.
  ///
  /// The search is case-insensitive; the original casing is preserved.
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
        // Append any remaining text after the last match.
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      // Append text before this match unstyled.
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      // Append the matched substring with a highlight background.
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
