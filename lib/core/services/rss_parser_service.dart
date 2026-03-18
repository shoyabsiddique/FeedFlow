import 'package:dio/dio.dart';
import 'package:webfeed_plus/webfeed_plus.dart';
import '../db/article.dart';

class RssParserService {
  final Dio _dio;

  RssParserService(this._dio);

  Future<List<Article>> parseFeed(String url, int feedSourceId) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final body = response.data.toString();

      try {
        final rssFeed = RssFeed.parse(body);
        return _mapRss(rssFeed, feedSourceId, url);
      } catch (e) {
        // Fallback to Atom
        final atomFeed = AtomFeed.parse(body);
        return _mapAtom(atomFeed, feedSourceId, url);
      }
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, String>> fetchFeedMetadata(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) throw Exception('Not found');

      final body = response.data.toString();

      try {
        final rssFeed = RssFeed.parse(body);
        return {
          'title': rssFeed.title ?? '',
          'description': rssFeed.description ?? '',
          'siteUrl': rssFeed.link ?? '',
          'logoUrl': rssFeed.image?.url ?? '',
        };
      } catch (e) {
        final atomFeed = AtomFeed.parse(body);
        return {
          'title': atomFeed.title ?? '',
          'description': atomFeed.subtitle ?? '',
          'siteUrl': atomFeed.links?.firstOrNull?.href ?? '',
          'logoUrl': atomFeed.logo ?? atomFeed.icon ?? '',
        };
      }
    } catch (e) {
      throw Exception('Invalid or unreachable feed');
    }
  }

  List<Article> _mapRss(RssFeed feed, int feedSourceId, String sourceUrl) {
    return feed.items?.map((item) {
          return Article()
            ..feedSourceId = feedSourceId
            ..guid = item.guid ?? item.link ?? '${sourceUrl}_${item.title}'
            ..title = item.title ?? 'No title'
            ..summary = item.description ?? ''
            ..url = item.link ?? sourceUrl
            ..publishedAt = item.pubDate ?? DateTime.now()
            ..fetchedAt = DateTime.now()
            ..thumbnailUrl =
                item.enclosure?.url ?? item.content?.images.firstOrNull;
        }).toList() ??
        [];
  }

  List<Article> _mapAtom(AtomFeed feed, int feedSourceId, String sourceUrl) {
    return feed.items?.map((item) {
          return Article()
            ..feedSourceId = feedSourceId
            ..guid =
                item.id ??
                item.links?.firstOrNull?.href ??
                '${sourceUrl}_${item.title}'
            ..title = item.title ?? 'No title'
            ..summary = item.summary ?? item.content ?? ''
            ..url = item.links?.firstOrNull?.href ?? sourceUrl
            ..publishedAt =
                DateTime.tryParse(item.published ?? '') ??
                item.updated ??
                DateTime.now()
            ..fetchedAt = DateTime.now()
            ..thumbnailUrl =
                null; // Atom parsing doesn't always have easy media enclosure
        }).toList() ??
        [];
  }
}
