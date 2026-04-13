import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'repositories/comment_repository.dart';
import 'providers/home_provider.dart';
import 'providers/search_provider.dart';
import 'screens/home_screen.dart';
import 'screens/search_results_screen.dart';
import 'screens/comment_detail_screen.dart';
import 'screens/writer_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const JeevesApp());
}

class JeevesApp extends StatelessWidget {
  const JeevesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = CommentRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider(repository)),
        ChangeNotifierProvider(create: (_) => SearchProvider(repository)),
      ],
      child: MaterialApp.router(
        title: 'Jeeves',
        theme: RetroTheme.theme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) {
        final query = state.uri.queryParameters['q'] ?? '';
        return SearchResultsScreen(query: query);
      },
    ),
    GoRoute(
      path: '/comment/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return CommentDetailScreen(commentId: id);
      },
    ),
    GoRoute(
      path: '/writer/:name',
      builder: (context, state) {
        final name = state.pathParameters['name']!;
        return WriterScreen(writerName: name);
      },
    ),
  ],
);
