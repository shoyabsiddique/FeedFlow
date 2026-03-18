import 'package:isar/isar.dart';
import '../article.dart';

class ArticleRepository {
  final Isar _isar;
  ArticleRepository(this._isar);

  Future<List<Article>> getHomeFeed({
    String? category, // Filtering to be added in query
    List<String> tags = const [], // Filtering to be added in query
    int globalCap = 10,
    int globalTimeCap = 0, // hours, 0 = no cap
  }) async {
    if (globalTimeCap > 0) {
      final cutoff = DateTime.now().subtract(Duration(hours: globalTimeCap));
      return _isar.articles
          .filter()
          .publishedAtGreaterThan(cutoff)
          .sortByPublishedAtDesc()
          .findAll();
    }

    return _isar.articles.where().sortByPublishedAtDesc().findAll();
  }

  Future<void> saveArticles(List<Article> articles) async {
    await _isar.writeTxn(() async {
      await _isar.articles.putAll(articles);
    });
  }

  Future<Set<String>> getGuidsForFeed(int feedId) async {
    final list = await _isar.articles.filter().feedSourceIdEqualTo(feedId).guidProperty().findAll();
    return list.toSet();
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

  Stream<List<Article>> watchHomeFeed({
    int globalCap = 10,
    int globalTimeCap = 0,
  }) {
    if (globalTimeCap > 0) {
      final cutoff = DateTime.now().subtract(Duration(hours: globalTimeCap));
      return _isar.articles
          .filter()
          .publishedAtGreaterThan(cutoff)
          .sortByPublishedAtDesc()
          .watch(fireImmediately: true);
    }
    
    // Limits inside Streams are tricky natively with Isar watch, typically we limit the display in UI or pre-filter.
    return _isar.articles.where().sortByPublishedAtDesc().watch(fireImmediately: true);
  }

  Stream<List<Article>> watchBookmarks() {
    return _isar.articles
        .filter()
        .isBookmarkedEqualTo(true)
        .sortByPublishedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<List<Article>> search(String queryStr) async {
    return _isar.articles
        .where()
        .filter()
        .titleContains(queryStr, caseSensitive: false)
        .or()
        .summaryContains(queryStr, caseSensitive: false)
        .sortByPublishedAtDesc()
        .findAll();
  }
}
