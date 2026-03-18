import 'package:flutter/foundation.dart';
import '../db/repositories/feed_repository.dart';
import '../db/repositories/article_repository.dart';
import 'rss_parser_service.dart';
import 'notification_service.dart';
import '../db/article.dart';
import '../db/feed_source.dart';

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

    await Future.wait(
      feeds.map((feed) => _syncFeed(feed)),
      eagerError: false,
    );
  }

  Future<void> _syncFeed(FeedSource feed) async {
    try {
      final articles = await _parser.parseFeed(feed.rssUrl, feed.id);
      if (articles.isEmpty) return;

      final newArticles = await _filterNew(articles, feed.id);
      if (newArticles.isEmpty) return;

      await _articleRepo.saveArticles(newArticles);

      // Notify for top new article only (avoid spam)
      await _notifications.showNewArticle(newArticles.first, feed.name);

      feed.lastSyncedAt = DateTime.now();
      await _feedRepo.saveFeed(feed);
    } catch (e) {
      debugPrint('Sync failed for ${feed.name}: $e');
    }
  }

  Future<List<Article>> _filterNew(List<Article> incoming, int feedId) async {
    final existingGuids = await _articleRepo.getGuidsForFeed(feedId);
    return incoming.where((a) => !existingGuids.contains(a.guid)).toList();
  }
}
