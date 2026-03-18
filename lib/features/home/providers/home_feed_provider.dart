import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/db/article.dart';
import '../../../core/db/app_settings.dart';
import '../../../core/db/feed_source.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/isar_provider.dart';

part 'home_feed_provider.g.dart';

enum SortOrder {
  newest,      // Most recent first (default)
  oldest,      // Oldest first
  unreadFirst, // Unread articles before read
  bySource,    // Alphabetical by feed/source name
  titleAZ,     // Article title A→Z
}

@riverpod
class ActiveCategoryFilter extends _$ActiveCategoryFilter {
  @override
  String? build() {
    return null; // null means 'All'
  }

  void setFilter(String? category) {
    state = category;
  }
}

@riverpod
class ActiveTagFilter extends _$ActiveTagFilter {
  @override
  String? build() {
    return null; // null means 'All'
  }

  void setFilter(String? tag) {
    state = tag;
  }
}

@riverpod
class ActiveSortOrder extends _$ActiveSortOrder {
  @override
  SortOrder build() => SortOrder.newest;

  void setSort(SortOrder order) {
    state = order;
  }
}

@riverpod
Stream<List<Article>> homeFeed(HomeFeedRef ref) async* {
  final repo = ref.watch(articleRepositoryProvider);
  final isar = await ref.watch(isarProvider.future);
  
  final settings = await isar.appSettings.where().findFirst();
  final activeCategory = ref.watch(activeCategoryFilterProvider);
  final activeTag = ref.watch(activeTagFilterProvider);
  final sortOrder = ref.watch(activeSortOrderProvider);

  await for (final articles in repo.watchHomeFeed(
    globalCap: settings?.globalArticleCap ?? 10,
    globalTimeCap: settings?.globalTimeCap ?? 0,
  )) {
    List<Article> result = articles;

    // Filter by category/tag if needed
    if (activeCategory != null || activeTag != null) {
      final filtered = <Article>[];
      for (var article in articles) {
        final feed = await isar.feedSources.get(article.feedSourceId);
        if (feed == null) continue;
        if (activeCategory != null && feed.category != activeCategory) continue;
        if (activeTag != null && !feed.userTags.contains(activeTag)) continue;
        filtered.add(article);
      }
      result = filtered;
    }

    // Apply sort
    switch (sortOrder) {
      case SortOrder.newest:
        result.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      case SortOrder.oldest:
        result.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
      case SortOrder.unreadFirst:
        result.sort((a, b) {
          if (a.isRead == b.isRead) return b.publishedAt.compareTo(a.publishedAt);
          return a.isRead ? 1 : -1;
        });
      case SortOrder.bySource:
        // Build name map for this batch
        final nameMap = <int, String>{};
        for (final article in result) {
          if (!nameMap.containsKey(article.feedSourceId)) {
            final feed = await isar.feedSources.get(article.feedSourceId);
            nameMap[article.feedSourceId] = feed?.name ?? '';
          }
        }
        result.sort((a, b) {
          final cmp = nameMap[a.feedSourceId]!.compareTo(nameMap[b.feedSourceId]!);
          return cmp != 0 ? cmp : b.publishedAt.compareTo(a.publishedAt);
        });
      case SortOrder.titleAZ:
        result.sort((a, b) => a.title.compareTo(b.title));
    }

    yield result;
  }
}

/// Watches all local FeedSources and returns a map of id → name for display.
@riverpod
Stream<Map<int, String>> feedSourceNames(FeedSourceNamesRef ref) {
  final feedRepo = ref.watch(feedRepositoryProvider);
  return feedRepo.watchAll().map(
    (feeds) => {for (final f in feeds) f.id: f.name},
  );
}

/// Returns distinct categories from all local FeedSources the user has added.
@riverpod
Stream<List<String>> feedCategories(FeedCategoriesRef ref) {
  final feedRepo = ref.watch(feedRepositoryProvider);
  return feedRepo.watchAll().map((feeds) {
    final cats = feeds.map((f) => f.category).where((c) => c.isNotEmpty).toSet().toList();
    cats.sort();
    return cats;
  });
}
