import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/post.dart';
import '../widgets/activity_chart.dart';
import 'post_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _db = DatabaseHelper.instance;

  List<ActivityPoint> _postActivity = [];
  List<ActivityPoint> _commentActivity = [];
  List<RankedItem> _topCommenters = [];
  List<Post> _topPosts = [];
  List<RankedItem> _labelFreq = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _db.getPostActivityByMonth(),
      _db.getCommentActivityByMonth(),
      _db.getTopCommenters(limit: 10),
      _db.getMostCommentedPosts(limit: 10),
      _db.getLabelFrequency(limit: 20),
    ]);

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

class _SectionDivider extends StatelessWidget {
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

class _EmptyHint extends StatelessWidget {
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

class _CountBadge extends StatelessWidget {
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
