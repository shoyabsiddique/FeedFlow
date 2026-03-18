import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/library_provider.dart';

class CategoryDetailsScreen extends ConsumerStatefulWidget {
  final String categoryName;
  const CategoryDetailsScreen({super.key, required this.categoryName});

  @override
  ConsumerState<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends ConsumerState<CategoryDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryNotifierProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: libraryState.when(
        data: (feeds) {
          final categoryFeeds = feeds
              .where((f) => f.feed.category == widget.categoryName)
              .toList();

          if (categoryFeeds.isEmpty) {
            return const Center(child: Text('No feeds found in this category.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: categoryFeeds.length,
            itemBuilder: (context, index) {
              final feedStatus = categoryFeeds[index];
              final feed = feedStatus.feed;

              return Card(
                elevation: 0.5,
                margin: const EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                ),
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Logo
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: feed.logoUrl.isNotEmpty
                            ? Image.network(
                                feed.logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.rss_feed, color: Colors.grey),
                              )
                            : const Icon(Icons.rss_feed, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      // Text Config
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feed.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              feed.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8) ?? Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${feed.enableCount} subscribers',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6) ?? Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Toggle
                      Switch.adaptive(
                        value: feedStatus.isEnabled,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (val) {
                          ref
                              .read(libraryNotifierProvider.notifier)
                              .toggleFeed(feed, val);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Future: Open Suggest a Feed dialog
        },
        icon: const Icon(Icons.add),
        label: const Text('Suggest Feed'),
      ),
    );
  }
}
