import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../providers/service_providers.dart';

part 'rss_detector_service.g.dart';

class DetectedFeed {
  final String url;
  final String title;

  DetectedFeed(this.url, this.title);
}

class RssDetectorService {
  final Dio _dio;

  RssDetectorService(this._dio);

  static const String detectionScript = '''
    (function() {
      const links = document.querySelectorAll('link[type="application/rss+xml"], link[type="application/atom+xml"]');
      const feeds = Array.from(links).map(link => ({
        url: link.href,
        title: link.title || document.title
      }));
      window.flutter_inappwebview.callHandler('rssDetected', JSON.stringify(feeds));
    })();
  ''';

  /// Validate if a detected URL actually returns a valid RSS/Atom feed
  Future<bool> validateFeedUrl(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode != 200) return false;

      final body = response.data.toString().toLowerCase();
      return body.contains('<rss') ||
          body.contains('<feed') ||
          body.contains('<rdf:rdf');
    } catch (_) {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
RssDetectorService rssDetectorService(RssDetectorServiceRef ref) {
  return RssDetectorService(ref.watch(dioProvider));
}
