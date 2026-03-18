# Flutter & Dart

---

## 1. Dart Language Fundamentals

### Theory
Dart is a strongly typed, object-oriented language. Everything in Dart is an object. Key concepts you must know for FeedFlow:

- **Null safety** — variables are non-nullable by default. Use `?` for nullable types.
- **async/await** — Dart is single-threaded but uses an event loop. `Future` is a promise. `async/await` makes async code readable.
- **Streams** — a sequence of async events. Isar uses streams to watch for DB changes in real time.
- **Isolates** — Dart's version of threads. Background sync runs in a separate isolate via workmanager.

### Code Examples

```dart
// Null safety
String name = "FeedFlow";      // non-nullable
String? title = null;          // nullable — can be null

// Future + async/await
Future<List<Article>> fetchArticles() async {
  final response = await dio.get('https://example.com/feed');
  return parseRss(response.data);
}

// Stream — watch Isar collection for changes
Stream<List<Article>> watchArticles() {
  return isar.articles.where().watch(fireImmediately: true);
}

// Isolate-safe code (workmanager runs in separate isolate)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // This runs in a background isolate
    await BackgroundSyncService().sync();
    return Future.value(true);
  });
}
```

---

## 2. Flutter Widget Tree

### Theory
Flutter UI is built entirely from widgets. Two types matter most:

- **StatelessWidget** — immutable, rebuilt when parent changes. Use for purely display components like `ArticleCard`.
- **StatefulWidget** — has mutable state via `State<T>`. Mostly replaced by Riverpod in this project, but still needed for things like animation controllers.
- **Widget lifecycle** — `initState()`, `build()`, `dispose()`. Always dispose controllers and subscriptions in `dispose()`.

### Code Examples

```dart
// StatelessWidget — ArticleCard
class ArticleCard extends StatelessWidget {
  final Article article;
  const ArticleCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: FaviconImage(url: article.feedLogoUrl),
        title: Text(article.title),
        subtitle: Text(article.summary),
        trailing: Text(timeAgo(article.publishedAt)),
      ),
    );
  }
}

// ConsumerWidget — Riverpod-aware widget (replaces StatelessWidget)
class HomeScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(homeFeedProvider);
    return articles.when(
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => ArticleCard(article: list[i]),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
```

---

## 3. Navigation — GoRouter

### Theory
GoRouter is the recommended navigation package for Flutter. It supports:
- **Named routes** — navigate by name, not by widget reference
- **Deep linking** — maps URLs to screens (critical for notification taps opening a specific article)
- **Nested navigation** — bottom nav with independent stacks per tab

### Code Examples

```dart
// app_router.dart
final router = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainScaffold(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/discovery', builder: (_, __) => const DiscoveryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/bookmarks', builder: (_, __) => const BookmarksScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        ]),
      ],
    ),
    // Deep link route for notification taps
    GoRoute(
      path: '/article/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ReaderScreen(articleId: id);
      },
    ),
  ],
);

// Navigate to article from notification
context.push('/article/42');
```

---

## 4. Riverpod — State Management

### Theory
Riverpod is a compile-safe state management library. Core concepts:

- **Provider** — exposes a value (sync, no state)
- **FutureProvider** — exposes an async value (fetches once)
- **StreamProvider** — exposes a stream (real-time Isar watches)
- **NotifierProvider** — exposes a class with methods that mutate state
- **AsyncNotifierProvider** — same but async
- **ref.watch** — rebuild widget when value changes
- **ref.read** — read once without rebuilding (use in callbacks)

### Code Examples

```dart
// Simple provider
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// FutureProvider — fetch library once
final libraryProvider = FutureProvider<List<SupabaseFeed>>((ref) async {
  final client = ref.read(supabaseProvider);
  return SupabaseLibraryService(client).fetchFeeds();
});

// StreamProvider — watch Isar articles in real time
final homeFeedProvider = StreamProvider<List<Article>>((ref) {
  final repo = ref.read(articleRepositoryProvider);
  return repo.watchHomeFeed();
});

// NotifierProvider — manage feed toggle state
@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  Future<List<FeedSource>> build() async {
    return ref.read(feedRepositoryProvider).getAllFeeds();
  }

  Future<void> toggleFeed(int feedId, bool enabled) async {
    await ref.read(feedRepositoryProvider).setEnabled(feedId, enabled);
    ref.invalidateSelf(); // trigger rebuild
  }
}
```

---

## 5. Isar — Local Database

### Theory
Isar is a high-performance embedded NoSQL database for Flutter. Key concepts:

- **Collections** — annotated Dart classes that map to Isar tables
- **Indexes** — speed up queries; use `@Index` on fields you filter/sort by
- **Full-text index** — `@Index(type: IndexType.value)` on String fields for search
- **Watchers** — reactive streams that emit when collection data changes
- **Transactions** — batch writes atomically; critical for syncing multiple articles

### Code Examples

```dart
// Collection definition
@collection
class Article {
  Id id = Isar.autoIncrement;

  @Index()
  late int feedSourceId;

  @Index(type: IndexType.value)  // full-text
  late String title;

  @Index(type: IndexType.value)  // full-text
  late String summary;

  late String guid;
  late String url;
  late DateTime publishedAt;
  bool isRead = false;
  bool isBookmarked = false;
}

// Repository — query articles for home feed
Future<List<Article>> getHomeFeed({
  String? category,
  int cap = 10,
}) async {
  return isar.articles
    .where()
    .sortByPublishedAtDesc()
    .filter()
    .isReadEqualTo(false)
    .findAll();
}

// Full-text search
Future<List<Article>> search(String query) async {
  return isar.articles
    .where()
    .titleContains(query, caseSensitive: false)
    .or()
    .summaryContains(query, caseSensitive: false)
    .sortByPublishedAtDesc()
    .findAll();
}

// Batch insert with transaction
Future<void> saveArticles(List<Article> articles) async {
  await isar.writeTxn(() async {
    await isar.articles.putAll(articles);
  });
}

// Watch for real-time updates
Stream<List<Article>> watchHomeFeed() {
  return isar.articles
    .where()
    .sortByPublishedAtDesc()
    .watch(fireImmediately: true);
}
```

---

## Resources

| Topic | Link |
|---|---|
| Dart language tour | https://dart.dev/language |
| Dart async & isolates | https://dart.dev/language/concurrency |
| Flutter widget catalog | https://docs.flutter.dev/ui/widgets |
| Riverpod docs | https://riverpod.dev/docs/introduction/getting_started |
| GoRouter docs | https://pub.dev/documentation/go_router/latest |
| Isar docs | https://isar.dev/tutorials/quickstart.html |
| Flutter cookbook | https://docs.flutter.dev/cookbook |