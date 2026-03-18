import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/db/article.dart';
import '../../core/db/feed_source.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/providers/service_providers.dart';
import '../../core/services/supabase_library_service.dart';

class TrendingArticle {
  final Article article;
  final SupabaseFeed feed;

  TrendingArticle({required this.article, required this.feed});
}

final trendingArticlesProvider = FutureProvider.autoDispose<List<TrendingArticle>>((ref) async {
  final supabaseService = ref.watch(supabaseLibraryServiceProvider);
  final rssParserService = ref.watch(rssParserServiceProvider);

  // 1. Fetch random global feeds
  final feeds = await supabaseService.getRandomFeeds(limit: 5);
  final List<TrendingArticle> allArticles = [];

  // 2. Concurrently fetch and parse RSS feeds
  await Future.wait(
    feeds.map((feed) async {
      try {
        final articles = await rssParserService.parseFeed(feed.rssUrl, -1);
        final topArticles = articles.take(3).toList(); // get top 3 from each
        for (final article in topArticles) {
          allArticles.add(TrendingArticle(article: article, feed: feed));
        }
      } catch (e) {
        // Skip failed feeds
      }
    }),
  );

  // 3. Sort by date descending
  allArticles.sort((a, b) => b.article.publishedAt.compareTo(a.article.publishedAt));

  return allArticles;
});

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingState = ref.watch(trendingArticlesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(trendingArticlesProvider),
          ),
        ],
      ),
      body: trendingState.when(
        data: (articles) {
          if (articles.isEmpty) {
            return const Center(child: Text('No trending articles found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final item = articles[index];
              return _buildArticleCard(context, ref, item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading feeds: $e')),
      ),
    );
  }

  Widget _buildArticleCard(BuildContext context, WidgetRef ref, TrendingArticle item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.article.thumbnailUrl != null && item.article.thumbnailUrl!.isNotEmpty)
            InkWell(
              onTap: () async {
                final uri = Uri.parse(item.article.url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.inAppWebView);
                }
              },
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  item.article.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallbackImage(context),
                ),
              ),
            )
          else
            _buildFallbackImage(context),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      backgroundImage: item.feed.logoUrl.isNotEmpty ? NetworkImage(item.feed.logoUrl) : null,
                      child: item.feed.logoUrl.isEmpty ? const Icon(Icons.rss_feed, size: 14) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.feed.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTimeAgo(item.article.publishedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(item.article.url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.inAppWebView);
                    }
                  },
                  child: Text(
                    item.article.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _subscribeToFeed(context, ref, item.feed),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Subscribe'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        child: Center(
          child: Icon(
            Icons.article_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Future<void> _subscribeToFeed(BuildContext context, WidgetRef ref, SupabaseFeed feed) async {
    final repo = ref.read(feedRepositoryProvider);
    
    // Check if feed already exists locally
    final allFeeds = await repo.getAllFeeds();
    final exists = allFeeds.any((f) => f.rssUrl == feed.rssUrl);
    
    if (exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already subscribed to this feed!')),
        );
      }
      return;
    }

    final isarFeed = FeedSource()
      ..rssUrl = feed.rssUrl
      ..name = feed.name
      ..description = feed.description
      ..siteUrl = feed.siteUrl
      ..logoUrl = feed.logoUrl
      ..category = feed.category
      ..isEnabled = true;
      
    await repo.saveFeed(isarFeed);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Subscribed to ${feed.name}')),
      );
    }
  }
}
