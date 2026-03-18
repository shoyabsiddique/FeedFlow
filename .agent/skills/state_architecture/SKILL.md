# State & Data Architecture

---

## 1. Repository Pattern

### Theory
The repository pattern puts a clean interface between your business logic and your data source (Isar). Benefits:
- Providers and services never write Isar queries directly — they call repository methods
- If you ever swap Isar for another DB, only the repository changes
- Repositories are easy to mock in tests

Every Isar collection gets its own repository class. Repositories are stateless — they just wrap queries.

### Code Examples

```dart
// core/db/repositories/article_repository.dart
class ArticleRepository {
  final Isar _isar;
  ArticleRepository(this._isar);

  // Fetch home feed — applies flood control caps
  Future<List<Article>> getHomeFeed({
    String? category,
    List<String> tags = const [],
    int globalCap = 10,
    int globalTimeCap = 0, // hours, 0 = no cap
  }) async {
    var query = _isar.articles.where().sortByPublishedAtDesc();

    // Apply time cap
    if (globalTimeCap > 0) {
      final cutoff = DateTime.now().subtract(Duration(hours: globalTimeCap));
      return query
        .filter()
        .publishedAtGreaterThan(cutoff)
        .findAll();
    }

    return query.findAll();
  }

  Future<void> saveArticles(List<Article> articles) async {
    await _isar.writeTxn(() async {
      await _isar.articles.putAll(articles);
    });
  }

  Future<void> markRead(int id) async {
    await _isar.writeTxn(() async {
      final article = await _isar.articles.get(id);
      if (article != null) {
        article.isRead = true;
        await _isar.articles.put(article);
      }
    });
  }

  Future<void> toggleBookmark(int id) async {
    await _isar.writeTxn(() async {
      final article = await _isar.articles.get(id);
      if (article != null) {
        article.isBookmarked = !article.isBookmarked;
        await _isar.articles.put(article);
      }
    });
  }

  Stream<List<Article>> watchBookmarks() {
    return _isar.articles
      .filter()
      .isBookmarkedEqualTo(true)
      .watch(fireImmediately: true);
  }

  Future<List<Article>> search(String query) async {
    return _isar.articles
      .where()
      .filter()
      .titleContains(query, caseSensitive: false)
      .or()
      .summaryContains(query, caseSensitive: false)
      .sortByPublishedAtDesc()
      .findAll();
  }
}

// core/db/repositories/feed_repository.dart
class FeedRepository {
  final Isar _isar;
  FeedRepository(this._isar);

  Future<List<FeedSource>> getAllFeeds() =>
    _isar.feedSources.where().findAll();

  Future<List<FeedSource>> getEnabledFeeds() =>
    _isar.feedSources.filter().isEnabledEqualTo(true).findAll();

  Future<void> saveFeed(FeedSource feed) async {
    await _isar.writeTxn(() => _isar.feedSources.put(feed));
  }

  Future<void> setEnabled(int id, bool enabled) async {
    await _isar.writeTxn(() async {
      final feed = await _isar.feedSources.get(id);
      if (feed != null) {
        feed.isEnabled = enabled;
        await _isar.feedSources.put(feed);
      }
    });
  }

  Stream<List<FeedSource>> watchAll() =>
    _isar.feedSources.where().watch(fireImmediately: true);
}
```

---

## 2. Service Layer

### Theory
Services are stateless classes that contain business logic. They sit above repositories (which own data access) and below providers (which own reactive state). Services:
- Orchestrate multiple repositories or external calls
- Don't hold state themselves
- Are injected via Riverpod providers

### Code Examples

```dart
// core/services/background_sync_service.dart
class BackgroundSyncService {
  final FeedRepository _feedRepo;
  final ArticleRepository _articleRepo;
  final RssParserService _parser;
  final NotificationService _notifications;

  BackgroundSyncService({
    required FeedRepository feedRepo,
    required ArticleRepository articleRepo,
    required RssParserService parser,
    required NotificationService notifications,
  })  : _feedRepo = feedRepo,
        _articleRepo = articleRepo,
        _parser = parser,
        _notifications = notifications;

  Future<void> syncAllFeeds() async {
    final feeds = await _feedRepo.getEnabledFeeds();

    // Fetch each feed independently — one failure doesn't stop others
    await Future.wait(
      feeds.map((feed) => _syncFeed(feed)),
      eagerError: false,
    );
  }

  Future<void> _syncFeed(FeedSource feed) async {
    try {
      final parsed = await _parser.parseFeed(feed.rssUrl);
      if (parsed == null) return;

      final newArticles = await _filterNew(parsed.articles, feed.id);
      if (newArticles.isEmpty) return;

      await _articleRepo.saveArticles(newArticles);

      // Notify for top new article only (avoid notification spam)
      await _notifications.showNewArticle(newArticles.first);

      // Update last synced timestamp
      feed.lastSyncedAt = DateTime.now();
      await _feedRepo.saveFeed(feed);
    } catch (e) {
      debugPrint('Sync failed for ${feed.name}: $e');
    }
  }

  Future<List<Article>> _filterNew(List<Article> incoming, int feedId) async {
    final existing = await _articleRepo.getGuidsForFeed(feedId);
    return incoming.where((a) => !existing.contains(a.guid)).toList();
  }
}
```

---

## 3. Riverpod Provider Setup

### Theory
All repositories and services are exposed via Riverpod providers. This gives you:
- Dependency injection throughout the app
- Testable code (swap providers in tests)
- Reactive state that auto-updates UI

Key pattern: providers depend on other providers via `ref.watch` (reactive) or `ref.read` (one-time).

### Code Examples

```dart
// core/providers/isar_provider.dart
@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  return await Isar.open([
    FeedSourceSchema,
    ArticleSchema,
    UserTagSchema,
    AppSettingsSchema,
  ]);
}

// core/providers/repository_providers.dart
@Riverpod(keepAlive: true)
FeedRepository feedRepository(FeedRepositoryRef ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return FeedRepository(isar);
}

@Riverpod(keepAlive: true)
ArticleRepository articleRepository(ArticleRepositoryRef ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return ArticleRepository(isar);
}

// core/providers/service_providers.dart
@Riverpod(keepAlive: true)
BackgroundSyncService syncService(SyncServiceRef ref) {
  return BackgroundSyncService(
    feedRepo: ref.read(feedRepositoryProvider),
    articleRepo: ref.read(articleRepositoryProvider),
    parser: ref.read(rssParserServiceProvider),
    notifications: ref.read(notificationServiceProvider),
  );
}

// features/home/providers/home_feed_provider.dart
@riverpod
Stream<List<Article>> homeFeed(HomeFeedRef ref) {
  final repo = ref.watch(articleRepositoryProvider);
  final settings = ref.watch(settingsProvider).valueOrNull;

  return repo.watchHomeFeed(
    globalCap: settings?.globalArticleCap ?? 10,
    globalTimeCap: settings?.globalTimeCap ?? 0,
  );
}

// features/search/providers/search_provider.dart
@riverpod
class SearchNotifier extends _$SearchNotifier {
  @override
  List<Article> build() => [];

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = [];
      return;
    }
    final repo = ref.read(articleRepositoryProvider);
    state = await repo.search(query);
  }
}
```

---

## 4. Offline-First Design

### Theory
Offline-first means: always read from local Isar first, then sync from network in background. The UI never blocks on a network call. This gives the app instant load times and resilience to poor connectivity.

Pattern:
1. UI subscribes to an Isar stream (reactive, always shows local data)
2. On app launch or pull-to-refresh, a sync is triggered in background
3. Sync writes new articles to Isar
4. The stream automatically emits the updated data — UI updates with no extra code

### Code Examples

```dart
// The UI watches the stream — updates automatically when Isar changes
@riverpod
Stream<List<Article>> homeFeed(HomeFeedRef ref) {
  return ref.watch(articleRepositoryProvider).watchHomeFeed();
}

// Sync is triggered separately — does NOT block the stream
@riverpod
class SyncNotifier extends _$SyncNotifier {
  @override
  bool build() => false; // isSyncing

  Future<void> syncNow() async {
    state = true;
    try {
      await ref.read(syncServiceProvider).syncAllFeeds();
    } finally {
      state = false;
    }
  }
}

// HomeScreen — watches both independently
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(homeFeedProvider);
    final isSyncing = ref.watch(syncNotifierProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(syncNotifierProvider.notifier).syncNow(),
      child: articles.when(
        data: (list) => ArticleList(articles: list, isSyncing: isSyncing),
        loading: () => const ArticleListSkeleton(),
        error: (e, _) => ErrorState(message: e.toString()),
      ),
    );
  }
}
```

---

## 5. Optimistic UI Updates

### Theory
When a user toggles a feed on/off, you want the UI to respond instantly — not wait for Isar write to complete. Optimistic updates flip the UI state immediately and then write to the DB. If the write fails, revert.

### Code Examples

```dart
@riverpod
class LibraryNotifier extends _$LibraryNotifier {
  @override
  Future<List<FeedWithStatus>> build() async {
    // Load library feeds from Supabase cache + enabled state from Isar
    final supabaseFeeds = await ref.read(supabaseLibraryServiceProvider).getFeedLibrary();
    final enabledIds = (await ref.read(feedRepositoryProvider).getEnabledFeeds())
      .map((f) => f.supabaseId)
      .toSet();

    return supabaseFeeds.map((f) => FeedWithStatus(
      feed: f,
      isEnabled: enabledIds.contains(f.id),
    )).toList();
  }

  Future<void> toggleFeed(SupabaseFeed feed, bool enable) async {
    // Optimistic update — flip UI immediately
    state = state.whenData((list) => list.map((item) {
      if (item.feed.id == feed.id) return item.copyWith(isEnabled: enable);
      return item;
    }).toList());

    try {
      final repo = ref.read(feedRepositoryProvider);
      if (enable) {
        final source = FeedSource.fromSupabase(feed);
        await repo.saveFeed(source..isEnabled = true);
        // Fire-and-forget enable_count increment
        ref.read(supabaseLibraryServiceProvider).incrementEnableCount(feed.id);
      } else {
        await repo.disableBySupabaseId(feed.id);
      }
    } catch (e) {
      // Revert on failure
      state = state.whenData((list) => list.map((item) {
        if (item.feed.id == feed.id) return item.copyWith(isEnabled: !enable);
        return item;
      }).toList());
      debugPrint('Toggle failed: $e');
    }
  }
}
```

---

## Resources

| Topic | Link |
|---|---|
| Riverpod architecture guide | https://riverpod.dev/docs/concepts/about_code_generation |
| Offline-first Flutter | https://docs.flutter.dev/data-and-backend/networking |
| Isar transactions | https://isar.dev/crud.html#transactions |
| Repository pattern (general) | https://martinfowler.com/eaaCatalog/repository.html |
| Testing with Riverpod | https://riverpod.dev/docs/essentials/testing |