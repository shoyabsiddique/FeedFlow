import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/discovery/discovery_screen.dart';
import '../features/bookmarks/bookmarks_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/library/category_details_screen.dart';

// Placeholder screens until we implement features
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: Text(title)));
}

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home', 
            builder: (_, __) => const HomeScreen(),
            routes: [
              GoRoute(
                path: 'search',
                builder: (_, __) => const SearchScreen(),
              ),
            ]
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/library',
            builder: (_, __) => const LibraryScreen(),
            routes: [
              GoRoute(
                path: 'category/:name',
                builder: (context, state) => CategoryDetailsScreen(
                  categoryName: state.pathParameters['name']!,
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/discovery', builder: (_, __) => const DiscoveryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/bookmarks', builder: (_, __) => const BookmarksScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/article/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ReaderScreen(articleId: id);
      },
    ),
  ],
);

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainScaffold({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Bookmarks'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
