import 'package:isar/isar.dart';
import '../feed_source.dart';
import '../article.dart';

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
        if (!enabled) {
          await _isar.articles.filter().feedSourceIdEqualTo(id).deleteAll();
        }
      }
    });
  }

  Future<void> disableBySupabaseId(String supabaseId) async {
    await _isar.writeTxn(() async {
      final feed = await _isar.feedSources.filter().supabaseIdEqualTo(supabaseId).findFirst();
      if (feed != null) {
        feed.isEnabled = false;
        await _isar.feedSources.put(feed);
        await _isar.articles.filter().feedSourceIdEqualTo(feed.id).deleteAll();
      }
    });
  }

  Stream<List<FeedSource>> watchAll() =>
      _isar.feedSources.where().watch(fireImmediately: true);
}
