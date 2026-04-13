/// Analytics dashboard for the Jeeves application.
///
/// Displays pre-computed aggregate statistics derived from the locally-stored
/// posts and comments:
///
/// - **Posts per month** — bar chart of publication frequency over time.
/// - **Comments per month** — bar chart of community engagement over time.
/// - **Top commenters** — ranked list of the most active commenters.
/// - **Most discussed posts** — ranked list of posts by comment count.
/// - **Label frequency** — chip cloud of the most-used tags/labels.
///
/// All data is loaded in a single parallel [Future.wait] call on [initState]
/// and cached in the screen's state.  A manual refresh is available via the
/// AppBar action and via pull-to-refresh on the [RefreshIndicator].
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/post.dart';
import '../widgets/activity_chart.dart';
import 'post_detail_screen.dart';

/// Stateful analytics dashboard that loads and displays aggregate metrics.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// Singleton data-access layer.
  final _db = DatabaseHelper.instance;

  /// Monthly post counts for the activity bar chart.
  List<ActivityPoint> _postActivity = [];

  /// Monthly comment counts for the activity bar chart.
  List<ActivityPoint> _commentActivity = [];

  /// Top commenters ranked by total comment count.
  List<RankedItem> _topCommenters = [];

  /// Most-commented posts, ranked by [Post.commentCount].
  List<Post> _topPosts = [];

  /// Most frequently used labels across all posts.
  List<RankedItem> _labelFreq = [];

  /// `true` while the initial or refresh data load is in progress.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches all analytics data from the database in parallel and updates
  /// the widget's state.
  ///
  /// Using [Future.wait] allows the five queries to run concurrently on
  /// sqflite's background isolate, reducing total wall-clock time compared
  /// to sequential awaits.
  Future<void> _load() async {
    final results = await Future.wait([
      _db.getPostActivityByMonth(),
      _db.getCommentActivityByMonth(),
      _db.getTopCommenters(limit: 10),
      _db.getMostCommentedPosts(limit: 10),
      _db.getLabelFrequency(limit: 20),
    ]);

    // Guard: the user may have navigated away before the queries completed.
    if (!mounted) return;
    setState(() {
      _postActivity = results[0] as List<ActivityPoint>;
      _commentActivity = results[1] as List<ActivityPoint>;
      _topCommenters = results[2] as List<RankedItem>;
      _topPosts = results[3] as List<Post>;
      _labelFreq = results[4] as List<RankedItem>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          // Manual refresh button in addition to pull-to-refresh.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _loading = true);
                await _load();
              },
              child: ListView(
                children: [
                  // ── Activity charts ──────────────────────────────────
                  // Both charts share the same height and axis style via
                  // ActivityChart; the colour distinguishes posts (indigo)
                  // from comments (teal).
                  ActivityChart(
                    data: _postActivity,
                    title: 'Posts per month',
                    barColor: Colors.indigo,
                  ),
                  ActivityChart(
                    data: _commentActivity,
                    title: 'Comments per month',
                    barColor: Colors.teal,
                  ),

                  const _SectionDivider(title: 'Top Commenters'),
                  // ── Top commenters ───────────────────────────────────
                  if (_topCommenters.isEmpty)
                    const _EmptyHint(message: 'No comment data yet.')
                  else
                    // Use asMap().entries to get a 1-based rank number for
                    // the CircleAvatar label.
                    ..._topCommenters.asMap().entries.map(
                          (e) => ListTile(
                            leading: CircleAvatar(
                              radius: 14,
                              child: Text('${e.key + 1}',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            title: Text(e.value.label),
                            trailing: _CountBadge(count: e.value.count),
                          ),
                        ),

                  const _SectionDivider(title: 'Most Discussed Posts'),
                  // ── Most discussed posts ─────────────────────────────
                  if (_topPosts.isEmpty)
                    const _EmptyHint(message: 'No post data yet.')
                  else
                    ..._topPosts.asMap().entries.map(
                          (e) => ListTile(
                            leading: CircleAvatar(
                              radius: 14,
                              child: Text('${e.key + 1}',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            title: Text(
                              e.value.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing:
                                _CountBadge(count: e.value.commentCount),
                            // Navigate to the post detail screen on tap.
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(
                                    postId: e.value.id),
                              ),
                            ),
                          ),
                        ),

                  const _SectionDivider(title: 'Label Frequency'),
                  // ── Label frequency ──────────────────────────────────
                  if (_labelFreq.isEmpty)
                    const _EmptyHint(message: 'No labels found.')
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        // Each chip shows the label name and its count,
                        // e.g. "peak oil  ×42".
                        children: _labelFreq
                            .map((item) => Chip(
                                  label: Text(
                                      '${item.label}  ×${item.count}'),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ─── Section divider ──────────────────────────────────────────────────────────

/// A labelled horizontal divider that separates analytics sections.
///
/// Renders the [title] in the theme's primary colour followed by a full-width
/// [Divider] line, matching the visual style used in Material 3 list headers.
class _SectionDivider extends StatelessWidget {
  /// The section heading text, e.g. `"Top Commenters"`.
  final String title;
  const _SectionDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ─── Empty-state hint ─────────────────────────────────────────────────────────

/// A muted hint text shown in place of a list when there is no data.
class _EmptyHint extends StatelessWidget {
  /// The message to display, e.g. `"No comment data yet."`.
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline)),
    );
  }
}

// ─── Count badge ──────────────────────────────────────────────────────────────

/// A small pill badge displaying a numeric [count] with the theme's secondary
/// container colour.  Used as a trailing widget in ranked list tiles.
class _CountBadge extends StatelessWidget {
  /// The numeric value to display inside the badge.
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSecondaryContainer)),
    );
  }
}
