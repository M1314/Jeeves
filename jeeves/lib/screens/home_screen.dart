import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/home_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_app_bar.dart';
import '../widgets/retro_search_bar.dart';
import '../widgets/comment_card.dart';
import '../widgets/hit_counter.dart';
import '../widgets/marquee_text.dart';
import '../widgets/retro_loading_indicator.dart';
import '../widgets/retro_error_widget.dart';
import '../widgets/pixel_divider.dart';
import '../widgets/pagination_controls.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadRecentComments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RetroAppBar(
        title: 'JEEVES',
        marqueeText:
            '★ WELCOME TO JEEVES - THE RETRO COMMENT BROWSER FOR ECOSOPHIA.NET ★ EST. 2024 ★',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: RetroColors.darkSurface2,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: MarqueeText(
                text:
                    '  ✦ ECOSOPHIA.NET COMMENT BROWSER ✦ FIND YOUR FAVORITE COMMENTERS ✦ BROWSE THE DISCOURSE ✦  ',
                style: GoogleFonts.pressStart2p(
                  fontSize: 8,
                  color: RetroColors.hotPink,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'JEEVES',
                style: GoogleFonts.vt323(
                  fontSize: 80,
                  color: RetroColors.neonGreen,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(
                      color: RetroColors.neonGreen.withAlpha(128),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Text(
                'YOUR RETRO COMMENT BUTLER',
                style: GoogleFonts.pressStart2p(
                  fontSize: 9,
                  color: RetroColors.electricBlue,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            RetroSearchBar(
              onSearch: (q) =>
                  context.go('/search?q=${Uri.encodeComponent(q)}'),
            ),
            const SizedBox(height: 16),
            const PixelDivider(),
            const SizedBox(height: 8),
            Text(
              'RECENT COMMENTS',
              style: GoogleFonts.vt323(
                fontSize: 32,
                color: RetroColors.electricBlue,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Consumer<HomeProvider>(
              builder: (context, provider, _) {
                if (provider.loading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: RetroLoadingIndicator(),
                  );
                }
                if (provider.error != null) {
                  return RetroErrorWidget(
                    message: provider.error!,
                    onRetry: () => provider.loadRecentComments(
                        page: provider.currentPage),
                  );
                }
                if (provider.recentComments.isEmpty) {
                  return Center(
                    child: Text(
                      'NO COMMENTS FOUND',
                      style: GoogleFonts.vt323(
                        fontSize: 28,
                        color: RetroColors.hotPink,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    ...provider.recentComments.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CommentCard(comment: c),
                      ),
                    ),
                    PaginationControls(
                      currentPage: provider.currentPage,
                      totalPages: provider.totalPages,
                      onPageSelected: (p) =>
                          provider.loadRecentComments(page: p),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const PixelDivider(),
            const SizedBox(height: 16),
            const Center(child: HitCounter()),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
