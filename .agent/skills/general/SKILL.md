# General (Git, JSON, XML, Error Handling)

---

## 1. Git — Branching & Workflow

### Theory
For a solo project like FeedFlow, keep git simple but disciplined. Recommended workflow:
- `main` — always stable, reflects what's on your device
- `feature/xxx` — one branch per feature (e.g. `feature/rss-discovery`)
- Commit often with meaningful messages
- Merge back to main when the feature is working end-to-end

Use `.gitignore` to keep secrets and generated files out of the repo.

### Code Examples

```bash
# Initial setup
git init
git remote add origin https://github.com/yourname/feedflow.git

# Feature branch workflow
git checkout -b feature/rss-discovery
# ... make changes ...
git add .
git commit -m "feat: inject JS RSS detector into in-app browser"
git checkout main
git merge feature/rss-discovery
git push origin main

# Undo last commit (keep changes)
git reset --soft HEAD~1

# See what changed
git diff
git status
```

```gitignore
# .gitignore for FeedFlow

# Flutter/Dart
.dart_tool/
.packages
build/
*.iml
*.g.dart          # generated Isar/Riverpod files (can be committed if preferred)
*.freezed.dart

# Environment secrets — NEVER commit these
.env
lib/env.dart      # if you store Supabase keys here

# iOS
ios/Pods/
ios/.symlinks/
ios/Flutter/Flutter.framework
ios/Flutter/Flutter.podspec

# Android
android/.gradle/
android/captures/
android/local.properties

# macOS/IDE
.DS_Store
.vscode/settings.json
*.swp
```

```dart
// lib/env.dart — store Supabase keys (add to .gitignore)
// Never hardcode secrets in committed files
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}

// Pass at build time:
// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
```

---

## 2. JSON Serialisation

### Theory
Dart is strongly typed — you can't just access `response['key']` safely without handling nulls and type mismatches. Two approaches:

- **Manual** — write `fromJson` and `toJson` methods. Simple, no build step.
- **json_serializable** — generates boilerplate automatically via `build_runner`. Use for complex models.

For FeedFlow, manual serialisation is fine for the small number of Supabase models. Isar handles its own persistence — you don't need JSON for local storage.

### Code Examples

```dart
// Manual fromJson — used for Supabase response parsing
class SupabaseFeed {
  final String id;
  final String name;
  final String description;
  final String rssUrl;
  final String siteUrl;
  final String logoUrl;
  final String category;
  final int enableCount;

  SupabaseFeed({
    required this.id,
    required this.name,
    required this.description,
    required this.rssUrl,
    required this.siteUrl,
    required this.logoUrl,
    required this.category,
    required this.enableCount,
  });

  factory SupabaseFeed.fromJson(Map<String, dynamic> json) {
    return SupabaseFeed(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      rssUrl: json['rss_url'] as String,
      siteUrl: json['site_url'] as String? ?? '',
      logoUrl: json['logo_url'] as String? ?? '',
      category: json['category'] as String,
      enableCount: json['enable_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'rss_url': rssUrl,
    'site_url': siteUrl,
    'logo_url': logoUrl,
    'category': category,
    'enable_count': enableCount,
  };
}

// Parsing a list from Supabase response
final data = await supabase.from('feeds').select();
final feeds = (data as List<dynamic>)
  .map((row) => SupabaseFeed.fromJson(row as Map<String, dynamic>))
  .toList();

// Safely accessing nested JSON (use null-aware operators)
final thumbnail = json['media']?['thumbnail']?['url'] as String?;
```

---

## 3. XML Parsing with dart:xml

### Theory
`dart:xml` provides a DOM-style API for parsing XML. Use it for OPML import/export. Key methods:
- `XmlDocument.parse(string)` — parse a full XML string
- `doc.findAllElements('tag')` — find all elements with a tag name (recursive)
- `el.getAttribute('name')` — get an attribute value (returns null if missing)
- `el.innerText` — get the text content of an element

### Code Examples

```dart
import 'package:xml/xml.dart';

// Parse OPML
List<FeedImport> parseOpml(String content) {
  final doc = XmlDocument.parse(content);

  // Handle both flat and nested OPML (some have category groups)
  final allOutlines = doc.findAllElements('outline');
  final feedOutlines = allOutlines.where(
    (el) => el.getAttribute('xmlUrl') != null
  );

  return feedOutlines.map((el) {
    return FeedImport(
      name: el.getAttribute('text') ?? el.getAttribute('title') ?? 'Unknown',
      rssUrl: el.getAttribute('xmlUrl')!,
      siteUrl: el.getAttribute('htmlUrl') ?? '',
      category: _inferCategory(el),
    );
  }).toList();
}

// Infer category from OPML parent outline title
String _inferCategory(XmlElement el) {
  final parent = el.parentElement;
  if (parent?.localName == 'outline') {
    final parentTitle = parent?.getAttribute('text') ?? '';
    if (parentTitle.toLowerCase().contains('tech')) return 'tech';
    if (parentTitle.toLowerCase().contains('ai')) return 'ai';
  }
  return 'tech'; // default
}

// Generate OPML export
String generateOpml(List<FeedSource> feeds) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('opml', attributes: {'version': '2.0'}, nest: () {
    builder.element('head', nest: () {
      builder.element('title', nest: 'FeedFlow Export');
      builder.element('dateCreated', nest: DateTime.now().toIso8601String());
    });
    builder.element('body', nest: () {
      for (final feed in feeds) {
        builder.element('outline', attributes: {
          'type': 'rss',
          'text': feed.name,
          'title': feed.name,
          'xmlUrl': feed.rssUrl,
          'htmlUrl': feed.siteUrl,
          'category': feed.category,
        });
      }
    });
  });
  return builder.buildDocument().toXmlString(pretty: true);
}
```

---

## 4. Error Handling & Graceful Degradation

### Theory
A good RSS reader must not crash or freeze when individual feeds fail. Principles:
- **Fail per-feed, not globally** — one bad feed URL should not stop others from syncing
- **Never block the UI on network** — always show cached data while syncing
- **Surface errors gently** — a small banner or badge, not a full error screen
- **Log silently in production** — use `debugPrint` in dev; consider Sentry or similar for production

### Code Examples

```dart
// Independent per-feed error handling
Future<void> syncAllFeeds(List<FeedSource> feeds) async {
  final results = await Future.wait(
    feeds.map((feed) => _syncOneFeed(feed)),
    eagerError: false, // don't cancel others if one fails
  );

  final failed = feeds.where((f) => results[feeds.indexOf(f)] == false).toList();
  if (failed.isNotEmpty) {
    debugPrint('Sync failed for: ${failed.map((f) => f.name).join(', ')}');
  }
}

Future<bool> _syncOneFeed(FeedSource feed) async {
  try {
    final parsed = await _parser.parseFeed(feed.rssUrl);
    if (parsed == null) return false;
    await _articleRepo.saveArticles(parsed.articles);
    return true;
  } on DioException catch (e) {
    debugPrint('Network error for ${feed.name}: ${e.type}');
    return false;
  } catch (e) {
    debugPrint('Unexpected error for ${feed.name}: $e');
    return false;
  }
}

// Async error display in UI — show snackbar, not crash
void onSyncError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Some feeds failed to sync'),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => ref.read(syncNotifierProvider.notifier).syncNow(),
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}

// Null-safe chaining — handle missing fields gracefully
String extractTitle(RssItem item) {
  return item.title?.trim().isNotEmpty == true
    ? item.title!.trim()
    : item.link ?? 'Untitled';
}

DateTime extractDate(RssItem item) {
  return item.pubDate ?? DateTime.now();
}

// Feed URL normalisation — handle common user mistakes
String normaliseUrl(String input) {
  var url = input.trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  return url;
}
```

---

## 5. Utilities You'll Write

### Time formatting

```dart
// date_formatter.dart
String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(date);
}

String estimatedReadTime(String text) {
  final words = text.split(RegExp(r'\s+')).length;
  final minutes = (words / 200).ceil(); // avg reading speed
  return '$minutes min read';
}
```

### HTML stripping

```dart
// Strip HTML tags from RSS summaries
String stripHtml(String html) {
  // Remove tags
  var text = html.replaceAll(RegExp(r'<[^>]*>'), '');
  // Decode common HTML entities
  text = text
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&nbsp;', ' ');
  // Collapse whitespace
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
```

### Category enum

```dart
// constants.dart
enum FeedCategory {
  tech('Tech & Dev', 'tech'),
  ai('AI / ML', 'ai'),
  finance('Finance', 'finance'),
  science('Science', 'science'),
  design('Design', 'design'),
  startups('Startups', 'startups'),
  politics('Politics', 'politics');

  final String label;
  final String key;
  const FeedCategory(this.label, this.key);

  static FeedCategory fromKey(String key) =>
    FeedCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => FeedCategory.tech,
    );
}
```

---

## Resources

| Topic | Link |
|---|---|
| Dart null safety | https://dart.dev/null-safety |
| dart:convert JSON | https://api.dart.dev/stable/dart-convert/dart-convert-library.html |
| xml package | https://pub.dev/packages/xml |
| Error handling in Dart | https://dart.dev/language/error-handling |
| Git cheatsheet | https://education.github.com/git-cheat-sheet-education.pdf |
| intl package (date formatting) | https://pub.dev/packages/intl |