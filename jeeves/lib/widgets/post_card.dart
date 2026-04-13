/// Reusable card widget for displaying a post summary.
///
/// [PostCard] is a Material 3 [Card] showing:
/// - Post title (bold, up to 2 lines).
/// - Author name and publication date on a secondary line.
/// - A 200-character plain-text excerpt of the post body.
/// - Up to 5 label chips (if the post has labels).
/// - A comment count row at the bottom.
///
/// This widget is intended for use in browse/list screens.  For the full
/// post content including threaded comments, see [PostDetailScreen].
import 'package:flutter/material.dart';
import '../models/post.dart';
import 'package:intl/intl.dart';

/// A tappable card summarising a single [Post].
///
/// [onTap] is called when the card is tapped; typically used to navigate to
/// [PostDetailScreen].  If `null`, the card is still rendered but is not
/// interactive.
class PostCard extends StatelessWidget {
  /// The post whose metadata and excerpt are displayed.
  final Post post;

  /// Optional tap callback; navigates to the post detail screen when wired up.
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Format the publication date in the device's local timezone.
    final dateStr =
        DateFormat.yMMMd().format(post.publishedAt.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        // Match the card's corner radius for a seamless ink splash.
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Post title ──────────────────────────────────────────
              Text(
                post.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // ── Author and date ─────────────────────────────────────
              Text(
                '${post.author} · $dateStr',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 8),

              // ── Plain-text excerpt ──────────────────────────────────
              Text(
                post.excerpt,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // ── Label chips ─────────────────────────────────────────
              // Show at most 5 chips to avoid overflowing narrow cards.
              if (post.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: post.labels
                      .take(5)
                      .map((label) => Chip(
                            label: Text(label,
                                style: theme.textTheme.labelSmall),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 4),

              // ── Comment count ───────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.comment_outlined, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount} comments',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
