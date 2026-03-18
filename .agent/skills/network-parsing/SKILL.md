# Networking & Parsing

---

## 1. dio — HTTP Client

### Theory
`dio` is the go-to HTTP client for Flutter. Key features over the built-in `http` package:
- **Interceptors** — middleware for every request/response. Use for logging, retry logic, and adding headers globally.
- **BaseOptions** — set default timeout, base URL, headers once. All requests inherit them.
- **Error handling** — `DioException` wraps network errors with a type (timeout, connection refused, bad response etc.).
- Always set `connectTimeout` and `receiveTimeout` — RSS feeds from random sites can hang indefinitely without them.

### Code Examples

```dart
// core/services/dio_provider.dart
Dio createDio() {
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'FeedFlow RSS Reader/1.0',
      'Accept': 'application/rss+xml, application/atom+xml, text/xml, */*',
    },
  ));

  // Logging interceptor (debug only)
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(responseBody: false));
  }

  // Retry interceptor — retry once on timeout/5xx
  dio.interceptors.add(RetryInterceptor(dio: dio, retries: 1));

  return dio;
}

// Fetch a feed URL
Future<String?> fetchFeedContent(String url) async {
  try {
    final response = await dio.get<String>(url);
    if (response.statusCode == 200) return response.data;
    return null;
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      debugPrint('Timeout fetching $url');
    } else if (e.type == DioExceptionType.badResponse) {
      debugPrint('HTTP ${e.response?.statusCode} for $url');
    }
    return null;
  }
}
```

---

## 2. RSS 2.0 & Atom 1.0 Structure

### Theory
Both formats are XML. You need to understand their structure to handle edge cases the parser might miss.

**RSS 2.0** structure:
```xml
<rss version="2.0">
  <channel>
    <title>Feed Name</title>
    <link>https://example.com</link>
    <description>About this feed</description>
    <item>
      <title>Article Title</title>
      <link>https://example.com/article</link>
      <description>Summary here</description>
      <pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>
      <guid>https://example.com/article</guid>
      <enclosure url="https://img.jpg" type="image/jpeg"/>  <!-- thumbnail -->
    </item>
  </channel>
</rss>
```

**Atom 1.0** structure:
```xml
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Feed Name</title>
  <link href="https://example.com"/>
  <entry>
    <title>Article Title</title>
    <link href="https://example.com/article"/>
    <summary>Summary here</summary>
    <published>2024-01-01T00:00:00Z</published>
    <id>https://example.com/article</id>  <!-- guid equivalent -->
    <media:thumbnail url="https://img.jpg"/>
  </entry>
</feed>
```

Key differences to handle:
- RSS uses `<item>`, Atom uses `<entry>`
- RSS date is RFC 822 (`Mon, 01 Jan 2024`), Atom is ISO 8601 (`2024-01-01T00:00:00Z`)
- RSS `<guid>` vs Atom `<id>` — both used for deduplication
- Thumbnails come from `<enclosure>`, `<media:thumbnail>`, or `<media:content>` — need to check all three

---

## 3. webfeed — Parsing RSS & Atom

### Theory
`webfeed` parses both RSS and Atom. It auto-detects the format. You get back a `RssFeed` or `AtomFeed` object. Always check for nulls — feed fields are often missing or malformed in the wild.

### Code Examples

```dart
// rss_parser_service.dart
import 'package:webfeed/webfeed.dart';

class RssParserService {
  final Dio _dio;
  RssParserService(this._dio);

  Future<ParsedFeed?> parseFeed(String url) async {
    final content = await fetchFeedContent(url);
    if (content == null) return null;

    try {
      // Try RSS first
      if (content.contains('<rss') || content.contains('<channel>')) {
        final feed = RssFeed.parse(content);
        return ParsedFeed.fromRss(feed, url);
      }
      // Then try Atom
      if (content.contains('<feed')) {
        final feed = AtomFeed.parse(content);
        return ParsedFeed.fromAtom(feed, url);
      }
      return null;
    } catch (e) {
      debugPrint('Parse error for $url: $e');
      return null;
    }
  }

  List<Article> articlesFromRss(RssFeed feed, int feedSourceId) {
    return (feed.items ?? []).map((item) {
      return Article()
        ..feedSourceId = feedSourceId
        ..guid = item.guid ?? item.link ?? ''
        ..title = item.title ?? 'Untitled'
        ..summary = _stripHtml(item.description ?? '')
        ..url = item.link ?? ''
        ..thumbnailUrl = _extractThumbnail(item)
        ..publishedAt = item.pubDate ?? DateTime.now()
        ..fetchedAt = DateTime.now();
    }).toList();
  }

  List<Article> articlesFromAtom(AtomFeed feed, int feedSourceId) {
    return (feed.items ?? []).map((entry) {
      return Article()
        ..feedSourceId = feedSourceId
        ..guid = entry.id ?? entry.links?.first.href ?? ''
        ..title = entry.title?.value ?? 'Untitled'
        ..summary = _stripHtml(entry.summary?.value ?? '')
        ..url = entry.links?.firstWhere(
              (l) => l.rel == 'alternate',
              orElse: () => entry.links!.first,
            ).href ?? ''
        ..thumbnailUrl = _extractAtomThumbnail(entry)
        ..publishedAt = entry.published ?? DateTime.now()
        ..fetchedAt = DateTime.now();
    }).toList();
  }

  // Extract thumbnail from RSS item — check multiple locations
  String? _extractThumbnail(RssItem item) {
    return item.enclosure?.url
      ?? item.media?.thumbnails?.firstOrNull?.url
      ?? item.media?.contents?.firstOrNull?.url;
  }

  // Strip HTML tags from summary
  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
```

---

## 4. Feed URL Validation

### Theory
When a user adds a custom feed or the RSS detector finds a URL, you need to verify it actually returns valid RSS/Atom before saving it. A simple `GET` request + parse attempt is sufficient.

### Code Examples

```dart
Future<FeedMetadata?> validateAndPreview(String url) async {
  try {
    final response = await dio.get<String>(url,
      options: Options(
        headers: {'Accept': 'application/rss+xml, application/atom+xml, text/xml'},
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    if (response.data == null) return null;
    final content = response.data!;

    if (content.contains('<rss') || content.contains('<channel>')) {
      final feed = RssFeed.parse(content);
      return FeedMetadata(
        name: feed.title ?? url,
        description: feed.description ?? '',
        articleCount: feed.items?.length ?? 0,
      );
    }

    if (content.contains('<feed')) {
      final feed = AtomFeed.parse(content);
      return FeedMetadata(
        name: feed.title?.value ?? url,
        description: feed.subtitle?.value ?? '',
        articleCount: feed.items?.length ?? 0,
      );
    }

    return null; // not a valid feed
  } catch (_) {
    return null;
  }
}
```

---

## 5. JavaScript Injection — RSS Detection

### Theory
`flutter_inappwebview` lets you inject JS into any loaded page and receive results back via a `JavaScriptHandler`. The RSS detector:
1. Injects JS on every `onLoadStop` event
2. JS scans `<head>` for RSS/Atom `<link>` tags
3. JS posts results back to Flutter via `window.flutter_inappwebview.callHandler`
4. Flutter validates each found URL and shows them in the bottom sheet

### Code Examples

```dart
// discovery_screen.dart
InAppWebView(
  initialUrlRequest: URLRequest(url: WebUri('https://duckduckgo.com')),
  onWebViewCreated: (controller) {
    // Register handler BEFORE page loads
    controller.addJavaScriptHandler(
      handlerName: 'rssDetected',
      callback: (args) {
        final raw = args.first as String;
        final links = (jsonDecode(raw) as List)
          .map((l) => DetectedFeed(
            title: l['title'] as String? ?? '',
            url: l['href'] as String,
          ))
          .toList();
        ref.read(detectionProvider.notifier).onFeedsDetected(links);
      },
    );
  },
  onLoadStop: (controller, url) async {
    // Inject RSS scanner on every page load
    await controller.evaluateJavascript(source: _rssDetectorScript);
  },
)

// The injected JavaScript
const _rssDetectorScript = '''
(function() {
  const selectors = [
    'link[type="application/rss+xml"]',
    'link[type="application/atom+xml"]',
    'link[type="application/rss"]',
  ];
  const found = [];
  selectors.forEach(sel => {
    document.querySelectorAll(sel).forEach(el => {
      found.push({ title: el.title || el.href, href: el.href });
    });
  });
  if (found.length > 0) {
    window.flutter_inappwebview.callHandler('rssDetected', JSON.stringify(found));
  }
})();
''';
```

---

## 6. Feed URL Probing

### Theory
Many sites have RSS feeds but don't advertise them via `<link>` tags. Probing common paths catches these. We try each common suffix relative to the page's origin and do a `HEAD` request first (cheaper) then `GET` only if HEAD returns 200.

### Code Examples

```dart
// feed_url_prober.dart
const _commonPaths = [
  '/feed', '/rss', '/feed.xml', '/atom.xml',
  '/feeds/posts/default', '/blog/feed', '/rss.xml',
  '/index.xml', '/feed/atom',
];

Future<List<String>> probeForFeeds(String pageUrl) async {
  final uri = Uri.parse(pageUrl);
  final base = '${uri.scheme}://${uri.host}';
  final found = <String>[];

  await Future.wait(_commonPaths.map((path) async {
    final candidate = '$base$path';
    try {
      final head = await dio.head(candidate,
        options: Options(
          receiveTimeout: const Duration(seconds: 4),
          followRedirects: true,
        ),
      );
      final contentType = head.headers.value('content-type') ?? '';
      if (contentType.contains('xml') || contentType.contains('rss')) {
        found.add(candidate);
      }
    } catch (_) {
      // Not a valid path — silently skip
    }
  }));

  return found;
}
```

---

## 7. OPML Parsing

### Theory
OPML is a simple XML format for feed lists. The structure is:
```xml
<opml version="2.0">
  <head><title>My Feeds</title></head>
  <body>
    <outline text="Tech" title="Tech">
      <outline type="rss" text="HN" xmlUrl="https://news.ycombinator.com/rss" htmlUrl="https://news.ycombinator.com"/>
    </outline>
  </body>
</opml>
```

`xmlUrl` is what you want. `htmlUrl` is the website. `type` is usually "rss" or "atom".

### Code Examples

```dart
// opml_service.dart
import 'package:xml/xml.dart';

class OpmlService {

  List<FeedImport> parseOpml(String opmlContent) {
    final doc = XmlDocument.parse(opmlContent);
    final outlines = doc.findAllElements('outline')
      .where((el) => el.getAttribute('xmlUrl') != null);

    return outlines.map((el) => FeedImport(
      name: el.getAttribute('text') ?? el.getAttribute('title') ?? '',
      rssUrl: el.getAttribute('xmlUrl')!,
      siteUrl: el.getAttribute('htmlUrl') ?? '',
    )).toList();
  }

  String generateOpml(List<FeedSource> feeds) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('opml', attributes: {'version': '2.0'}, nest: () {
      builder.element('head', nest: () {
        builder.element('title', nest: 'FeedFlow Export');
      });
      builder.element('body', nest: () {
        for (final feed in feeds) {
          builder.element('outline', attributes: {
            'type': 'rss',
            'text': feed.name,
            'title': feed.name,
            'xmlUrl': feed.rssUrl,
            'htmlUrl': feed.siteUrl,
          });
        }
      });
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }
}
```

---

## Resources

| Topic | Link |
|---|---|
| dio package | https://pub.dev/packages/dio |
| webfeed package | https://pub.dev/packages/webfeed |
| RSS 2.0 spec | https://www.rssboard.org/rss-specification |
| Atom 1.0 spec (RFC 4287) | https://www.ietf.org/rfc/rfc4287.txt |
| flutter_inappwebview docs | https://inappwebview.dev/docs |
| xml (dart) package | https://pub.dev/packages/xml |
| OPML spec | http://opml.org/spec2.opml |