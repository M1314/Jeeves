import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../widgets/search_filter_bar.dart';
import 'post_detail_screen.dart';
import 'package:intl/intl.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  final _db = DatabaseHelper.instance;

  SearchResults? _results;
  bool _loading = false;
  String? _error;

  // Filter state
  String? _authorFilter;
  String? _labelFilter;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _searchPosts = true;
  bool _searchComments = true;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _db.search(
        query: query,
        searchPosts: _searchPosts,
        searchComments: _searchComments,
        authorFilter: _authorFilter,
        labelFilter: _labelFilter,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onFiltersChanged({
    String? author,
    String? label,
    DateTime? from,
    DateTime? to,
    bool searchPosts = true,
    bool searchComments = true,
  }) {
    _authorFilter = author;
    _labelFilter = label;
    _fromDate = from;
    _toDate = to;
    _searchPosts = searchPosts;
    _searchComments = searchComments;
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeeves Search'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _queryController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search posts and comments…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _queryController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryController.clear();
                          _search();
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SearchFilterBar(onFiltersChanged: _onFiltersChanged),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text('Error: $_error',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    if (_results == null) {
      return const Center(
        child: Text('Enter a search term above.'),
      );
    }
    if (_results!.isEmpty) {
      return const Center(child: Text('No results found.'));
    }

    final query = _queryController.text.trim();
    final items = <Widget>[];

    if (_results!.posts.isNotEmpty) {
      items.add(const _SectionHeader(title: 'Posts'));
      for (final r in _results!.posts) {
        items.add(_PostResult(post: r.post, query: query));
      }
    }

    if (_results!.comments.isNotEmpty) {
      items.add(const _SectionHeader(title: 'Comments'));
      for (final r in _results!.comments) {
        items.add(_CommentResult(result: r, query: query));
      }
    }

    return ListView(children: items);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _PostResult extends StatelessWidget {
  final Post post;
  final String query;
  const _PostResult({required this.post, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        DateFormat.yMMMd().format(post.publishedAt.toLocal());

    return ListTile(
      leading: const Icon(Icons.article_outlined),
      title: _HighlightText(text: post.title, query: query, bold: true),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${post.author} · $dateStr',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          _HighlightText(
            text: post.excerpt,
            query: query,
            maxLines: 2,
          ),
        ],
      ),
      isThreeLine: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PostDetailScreen(postId: post.id, highlightQuery: query),
        ),
      ),
    );
  }
}

class _CommentResult extends StatelessWidget {
  final CommentSearchResult result;
  final String query;
  const _CommentResult({required this.result, required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = result.comment;
    final dateStr =
        DateFormat.yMMMd().format(c.publishedAt.toLocal());

    return ListTile(
      leading: const Icon(Icons.comment_outlined),
      title: Text(
        result.postTitle,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${c.author} · $dateStr',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          _HighlightText(text: c.plainBody, query: query, maxLines: 2),
        ],
      ),
      isThreeLine: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            postId: c.postId,
            highlightQuery: query,
            scrollToCommentId: c.id,
          ),
        ),
      ),
    );
  }
}

/// Inline text with keyword highlights.
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final bool bold;
  final int? maxLines;

  const _HighlightText({
    required this.text,
    required this.query,
    this.bold = false,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = (bold
            ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
            : theme.textTheme.bodyMedium) ??
        const TextStyle();

    if (query.isEmpty) {
      return Text(text,
          style: baseStyle,
          maxLines: maxLines,
          overflow:
              maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
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
      text: TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}
