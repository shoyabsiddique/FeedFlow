# Supabase

---

## 1. What Supabase Is (in FeedFlow's context)

### Theory
Supabase is an open-source Firebase alternative built on PostgreSQL. For FeedFlow, it serves one purpose: hosting the curated feed library so you can add/edit/deprecate feeds without shipping an app update.

The app uses Supabase entirely as a **read-only public data source**. The only write operations are:
- Inserting a row into `feed_suggestions` (anonymous, no auth)
- Incrementing `enable_count` via an Edge Function (prevents direct integer manipulation)

There is no user authentication, no user table, and no private data in Supabase.

### Setup

```dart
// main.dart — initialise Supabase before runApp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_REF.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );
  runApp(const ProviderScope(child: FeedFlowApp()));
}

// Access the client anywhere
final supabase = Supabase.instance.client;
```

---

## 2. PostgreSQL Schema

### Theory
You manage the library entirely from the Supabase dashboard. The schema has two tables. Understanding the SQL lets you add new feeds, tweak descriptions, or deprecate old ones directly from the dashboard.

### Code Examples

```sql
-- feeds table — the public library
CREATE TABLE feeds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  rss_url TEXT NOT NULL UNIQUE,
  site_url TEXT,
  logo_url TEXT,
  category TEXT NOT NULL CHECK (
    category IN ('tech', 'ai', 'finance', 'science', 'design', 'startups', 'politics')
  ),
  is_active BOOLEAN DEFAULT true,
  enable_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- feed_suggestions table — user submissions
CREATE TABLE feed_suggestions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  suggested_url TEXT NOT NULL,
  suggested_name TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed some initial feeds
INSERT INTO feeds (name, description, rss_url, site_url, logo_url, category) VALUES
  ('Hacker News', 'Top stories from the HN community', 'https://news.ycombinator.com/rss', 'https://news.ycombinator.com', 'https://news.ycombinator.com/favicon.ico', 'tech'),
  ('TechCrunch', 'Technology news and analysis', 'https://techcrunch.com/feed/', 'https://techcrunch.com', 'https://techcrunch.com/favicon.ico', 'tech'),
  ('The Batch (deeplearning.ai)', 'Weekly AI/ML newsletter', 'https://www.deeplearning.ai/the-batch/feed/', 'https://www.deeplearning.ai/the-batch', '', 'ai'),
  ('Benedict Evans', 'Tech strategy and analysis', 'https://www.ben-evans.com/benedictevans?format=rss', 'https://www.ben-evans.com', '', 'startups');
```

---

## 3. Row Level Security (RLS)

### Theory
RLS policies control what the anonymous (unauthenticated) client can do. Since the anon key is embedded in the app, you must ensure:
- `feeds` can only be **read** — never written to from the client
- `feed_suggestions` can only be **inserted** — users can't read others' suggestions
- No direct modification of `enable_count` — use an Edge Function

### Code Examples

```sql
-- Enable RLS on both tables
ALTER TABLE feeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_suggestions ENABLE ROW LEVEL SECURITY;

-- feeds: public read, no writes
CREATE POLICY "feeds_public_read"
  ON feeds FOR SELECT
  TO anon
  USING (is_active = true);  -- only return active feeds

-- feed_suggestions: insert only, no reads
CREATE POLICY "suggestions_insert_only"
  ON feed_suggestions FOR INSERT
  TO anon
  WITH CHECK (true);

-- Verify policies (run in SQL editor)
SELECT tablename, policyname, cmd, roles
FROM pg_policies
WHERE tablename IN ('feeds', 'feed_suggestions');
```

---

## 4. Supabase Flutter SDK — Querying

### Theory
The Flutter SDK wraps Supabase's REST API. You use a builder pattern to construct queries. Key methods:
- `.from('table')` — target a table
- `.select('col1, col2')` — pick columns (empty = all)
- `.eq('col', value)` — filter by equality
- `.order('col', ascending: false)` — sort results
- `.execute()` is NOT needed — `await` the query directly

### Code Examples

```dart
// supabase_library_service.dart
class SupabaseLibraryService {
  final SupabaseClient _client;
  SupabaseLibraryService(this._client);

  // Fetch all active feeds
  Future<List<SupabaseFeed>> fetchAllFeeds() async {
    final data = await _client
      .from('feeds')
      .select()
      .order('enable_count', ascending: false);

    return (data as List)
      .map((row) => SupabaseFeed.fromJson(row))
      .toList();
  }

  // Fetch feeds by category
  Future<List<SupabaseFeed>> fetchByCategory(String category) async {
    final data = await _client
      .from('feeds')
      .select()
      .eq('category', category)
      .order('enable_count', ascending: false);

    return (data as List)
      .map((row) => SupabaseFeed.fromJson(row))
      .toList();
  }

  // Submit a feed suggestion
  Future<void> suggestFeed(String url, String? name) async {
    await _client.from('feed_suggestions').insert({
      'suggested_url': url,
      'suggested_name': name,
    });
  }
}

// Model
class SupabaseFeed {
  final String id;
  final String name;
  final String description;
  final String rssUrl;
  final String siteUrl;
  final String logoUrl;
  final String category;
  final int enableCount;

  SupabaseFeed.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      description = json['description'] ?? '',
      rssUrl = json['rss_url'],
      siteUrl = json['site_url'] ?? '',
      logoUrl = json['logo_url'] ?? '',
      category = json['category'],
      enableCount = json['enable_count'] ?? 0;
}
```

---

## 5. Edge Function — enable_count Increment

### Theory
Edge Functions are Deno (TypeScript) functions that run server-side. The increment function receives a feed UUID and safely increments its counter using a PostgreSQL RPC call. This prevents the client from directly manipulating the integer.

### Code Examples

```typescript
// supabase/functions/increment-enable-count/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { feedId } = await req.json()

  if (!feedId) {
    return new Response(JSON.stringify({ error: 'feedId required' }), { status: 400 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')! // service role — bypasses RLS
  )

  const { error } = await supabase.rpc('increment_feed_count', { feed_id: feedId })

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})
```

```sql
-- PostgreSQL function called by the Edge Function
CREATE OR REPLACE FUNCTION increment_feed_count(feed_id UUID)
RETURNS void AS $$
  UPDATE feeds SET enable_count = enable_count + 1 WHERE id = feed_id;
$$ LANGUAGE sql SECURITY DEFINER;
```

```dart
// Calling the Edge Function from Flutter when user enables a feed
Future<void> onFeedEnabled(String supabaseId) async {
  try {
    await _client.functions.invoke(
      'increment-enable-count',
      body: {'feedId': supabaseId},
    );
  } catch (e) {
    // Non-critical — don't block the UI if this fails
    debugPrint('enable_count increment failed: $e');
  }
}
```

---

## 6. Offline Fallback

### Theory
The app caches the Supabase library in Isar on first fetch. If Supabase is unreachable (no internet, service down), the cached version is served silently.

### Code Examples

```dart
Future<List<SupabaseFeed>> getFeedLibrary() async {
  try {
    // Try remote first
    final remote = await supabaseLibraryService.fetchAllFeeds();
    // Cache to Isar
    await isar.writeTxn(() async {
      await isar.cachedLibraryFeeds.clear();
      await isar.cachedLibraryFeeds.putAll(
        remote.map((f) => CachedLibraryFeed.fromSupabase(f)).toList()
      );
    });
    return remote;
  } catch (e) {
    // Supabase unreachable — serve from cache
    debugPrint('Supabase unavailable, using cache: $e');
    final cached = await isar.cachedLibraryFeeds.where().findAll();
    return cached.map((c) => c.toSupabaseFeed()).toList();
  }
}
```

---

## Resources

| Topic | Link |
|---|---|
| Supabase Flutter quickstart | https://supabase.com/docs/guides/getting-started/quickstarts/flutter |
| supabase_flutter package | https://pub.dev/packages/supabase_flutter |
| Row Level Security guide | https://supabase.com/docs/guides/database/postgres/row-level-security |
| Edge Functions guide | https://supabase.com/docs/guides/functions |
| PostgreSQL RPC functions | https://supabase.com/docs/guides/database/functions |
| Supabase dashboard | https://supabase.com/dashboard |