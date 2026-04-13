import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/search_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_app_bar.dart';
import '../widgets/comment_card.dart';
import '../widgets/retro_search_bar.dart';
import '../widgets/retro_loading_indicator.dart';
import '../widgets/retro_error_widget.dart';
import '../widgets/pagination_controls.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().search(widget.query);
    });
  }

  @override
  void didUpdateWidget(SearchResultsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SearchProvider>().search(widget.query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RetroAppBar(title: 'SEARCH'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: RetroSearchBar(
              initialValue: widget.query,
              onSearch: (q) =>
                  context.go('/search?q=${Uri.encodeComponent(q)}'),
            ),
          ),
          Consumer<SearchProvider>(
            builder: (context, provider, _) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    provider.loading
                        ? 'SEARCHING...'
                        : '${provider.results.length} RESULTS FOR "${provider.query}"',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 8,
                      color: RetroColors.electricBlue,
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Consumer<SearchProvider>(
              builder: (context, provider, _) {
                if (provider.loading) {
                  return const RetroLoadingIndicator();
                }
                if (provider.error != null) {
                  return RetroErrorWidget(
                    message: provider.error!,
                    onRetry: () => provider.search(widget.query),
                  );
                }
                if (provider.results.isEmpty && provider.query.isNotEmpty) {
                  return Center(
                    child: Text(
                      'NO RESULTS FOUND',
                      style: GoogleFonts.vt323(
                        fontSize: 32,
                        color: RetroColors.hotPink,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      CommentCard(comment: provider.results[i]),
                );
              },
            ),
          ),
          Consumer<SearchProvider>(
            builder: (context, provider, _) {
              return PaginationControls(
                currentPage: provider.page,
                totalPages: provider.totalPages,
                onPageSelected: provider.loadPage,
              );
            },
          ),
        ],
      ),
    );
  }
}
