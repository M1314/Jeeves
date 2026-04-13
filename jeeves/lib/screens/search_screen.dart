/// Full-text search screen for Jeeves.
///
/// Provides a search bar and a collapsible [SearchFilterBar] that allows the
/// user to restrict results by content type (posts, comments), author,
/// label/tag, and date range.  Results are split into two ranked sections —
/// Posts and Comments — using BM25 relevance ordering from SQLite FTS5.
///
/// Tapping a post result opens [PostDetailScreen] scrolled to the top.
/// Tapping a comment result opens [PostDetailScreen] with the matching
/// comment's ID so the thread can be highlighted.
///
/// Search is triggered either by pressing the keyboard's search action key
/// or by submitting the text field.  The query and filter state are held
/// entirely in [_SearchScreenState]; there is no shared state store for
/// searches.
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../widgets/search_filter_bar.dart';
import 'post_detail_screen.dart';
import 'package:intl/intl.dart';

/// Screen widget for keyword search across stored posts and comments.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// Controller for the search text field.
  final _queryController = TextEditingController();

  /// Singleton database access layer.
  final _db = DatabaseHelper.instance;

  /// Most recent search result set, or `null` if no search has been run.
  SearchResults? _results;

  /// `true` while an async search query is in flight.
  bool _loading = false;

  /// Error message from the most recent failed search, or `null` otherwise.
  String? _error;

  // ── Active filter values ──────────────────────────────────────────────────

  /// Current author substring filter (empty string treated as "no filter").
  String? _authorFilter;

  /// Current label substring filter.
  String? _labelFilter;

  /// Inclusive start of the date range filter, or `null` for no lower bound.
  DateTime? _fromDate;

  /// Inclusive end of the date range filter (end-of-day, 23:59:59), or `null`.
  DateTime? _toDate;

  /// Whether posts should be included in the search results.
  bool _searchPosts = true;

  /// Whether comments should be included in the search results.
  bool _searchComments = true;

  @override
  void dispose() {
    // Release the controller to avoid a memory leak when the widget is removed
    // from the tree (e.g. on app exit or tab change if the widget is rebuilt).
    _queryController.dispose();
    super.dispose();
  }

  /// Executes a database search with the current query and filter values.
  ///
  /// Clears results if the query is empty.  Updates [_loading] around the
  /// async database call so the UI shows a spinner while work is in progress.
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

  /// Receives updated filter values from [SearchFilterBar] and re-runs the
  /// search with the new constraints.
  ///
  /// Called whenever the user changes any filter control in the filter panel.
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
    // Re-run the search so results update immediately when filters change.
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jeeves Search'),
        // Embed the search field in the AppBar's bottom area so it stays
        // visible above the scrollable results list.
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
                // Show a clear button only when there is text in the field.
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
              // Rebuild to show/hide the clear button as text is typed.
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Collapsible filter panel above the results list.
          SearchFilterBar(onFiltersChanged: _onFiltersChanged),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// Builds the appropriate body widget for the current search state:
  /// spinner, error message, empty-state hint, "no results" message, or the
  /// ranked results list.
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
      // No search has been run yet — show an instructional placeholder.
      return const Center(
        child: Text('Enter a search term above.'),
      );
    }
    if (_results!.isEmpty) {
      return const Center(child: Text('No results found.'));
    }

    final query = _queryController.text.trim();
    // Build a flat list of section headers and result tiles.
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

// ─── Section header ───────────────────────────────────────────────────────────

/// A small coloured heading that separates Posts from Comments in the list.
class _SectionHeader extends StatelessWidget {
  /// Label text, e.g. `"Posts"` or `"Comments"`.
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

// ─── Post result tile ─────────────────────────────────────────────────────────

/// A list tile representing a single post search result.
///
/// Displays the post title, author, publication date, and a 200-character
/// plain-text excerpt, with all occurrences of [query] highlighted via
/// [_HighlightText].  Tapping navigates to [PostDetailScreen].
class _PostResult extends StatelessWidget {
  /// The matched post.
  final Post post;

  /// The search query used for inline highlighting.
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
          // Author and date metadata line.
          Text('${post.author} · $dateStr',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          // Plain-text excerpt with keyword highlights.
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

// ─── Comment result tile ──────────────────────────────────────────────────────

/// A list tile representing a single comment search result.
///
/// Shows the parent post title as the primary label (so the user knows which
/// post the comment belongs to), with the comment author, date, and a snippet
/// of the comment body below.  Tapping opens [PostDetailScreen] with the
/// [Comment.id] so the matching comment is visually highlighted in the thread.
class _CommentResult extends StatelessWidget {
  /// The matched comment plus its parent post metadata.
  final CommentSearchResult result;

  /// The search query used for inline highlighting.
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
      // Show the parent post title so the user can see context at a glance.
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
            // Pass the comment ID so PostDetailScreen can scroll/highlight it.
            scrollToCommentId: c.id,
          ),
        ),
      ),
    );
  }
}

// ─── Inline keyword highlight ─────────────────────────────────────────────────

/// Renders [text] as a [RichText] with all occurrences of [query] highlighted
/// using the theme's `tertiaryContainer` background colour.
///
/// The comparison is case-insensitive; the original casing of the text is
/// preserved in the output.  If [query] is empty the text is rendered
/// unstyled using a plain [Text] widget.
///
/// The [bold] flag renders the entire text in [FontWeight.bold] (used for
/// post titles in result tiles).  [maxLines] clips the text with an ellipsis
/// when the rendered output exceeds the specified number of lines.
class _HighlightText extends StatelessWidget {
  /// The full text to render.
  final String text;

  /// The search query whose occurrences should be highlighted.
  final String query;

  /// When `true`, the base text style uses [FontWeight.bold].
  final bool bold;

  /// Optional line limit; `null` means unlimited.
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

    // If there is no query, avoid the overhead of building TextSpans.
    if (query.isEmpty) {
      return Text(text,
          style: baseStyle,
          maxLines: maxLines,
          overflow:
              maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip);
    }

    // Build a list of TextSpans, alternating between un-highlighted and
    // highlighted segments by scanning for [query] in a case-insensitive
    // manner while preserving the original text casing.
    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        // No more occurrences; append the remaining text unstyled.
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      // Append any text before this occurrence unstyled.
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      // Append the matched occurrence with a highlight background.
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
