import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/service_providers.dart';
import '../../shared/widgets/article_card.dart';
import '../../shared/widgets/category_chip.dart';
import 'providers/home_feed_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSyncing = false;

  Future<void> _syncAll() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await ref.read(backgroundSyncServiceProvider).syncAllFeeds();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Feed sync complete!')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showSortSheet() {
    final current = ref.read(activeSortOrderProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Sort by', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
          for (final option in [
            (SortOrder.newest, Icons.arrow_downward, 'Newest First'),
            (SortOrder.oldest, Icons.arrow_upward, 'Oldest First'),
            (SortOrder.unreadFirst, Icons.mark_email_unread_outlined, 'Unread First'),
            (SortOrder.bySource, Icons.rss_feed, 'By Source'),
            (SortOrder.titleAZ, Icons.sort_by_alpha, 'Title A→Z'),
          ])
            ListTile(
              leading: Icon(option.$2),
              title: Text(option.$3),
              trailing: current == option.$1 ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                ref.read(activeSortOrderProvider.notifier).setSort(option.$1);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final articleStream = ref.watch(homeFeedProvider);
    final activeCategory = ref.watch(activeCategoryFilterProvider);
    final feedNames = ref.watch(feedSourceNamesProvider).valueOrNull ?? {};
    final categories = ref.watch(feedCategoriesProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FeedFlow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync feeds',
              onPressed: _syncAll,
            ),
          IconButton(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onPressed: _showSortSheet,
            ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: categories.length + 1, // +1 for 'All'
              itemBuilder: (context, index) {
                final cat = index == 0 ? null : categories[index - 1];
                final label = cat ?? 'All';
                return CategoryChip(
                  label: label,
                  isSelected: activeCategory == cat,
                  onTap: () {
                    ref
                        .read(activeCategoryFilterProvider.notifier)
                        .setFilter(cat);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Article List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _syncAll,
              child: articleStream.when(
                data: (articles) {
                  if (articles.isEmpty) {
                    return ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No articles found.\nAdd some feeds from the Library!',
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    itemCount: articles.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return ArticleCard(
                        article: article,
                        sourceName:
                            feedNames[article.feedSourceId] ?? 'Unknown',
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
