import 'package:supabase_flutter/supabase_flutter.dart';

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

class SupabaseLibraryService {
  final SupabaseClient _client;
  SupabaseLibraryService(this._client);

  Future<List<SupabaseFeed>> fetchAllFeeds() async {
    final data = await _client
        .from('feeds')
        .select()
        .order('enable_count', ascending: false);

    return (data as List).map((row) => SupabaseFeed.fromJson(row)).toList();
  }

  Future<List<SupabaseFeed>> fetchByCategory(String category) async {
    final data = await _client
        .from('feeds')
        .select()
        .eq('category', category)
        .order('enable_count', ascending: false);

    return (data as List).map((row) => SupabaseFeed.fromJson(row)).toList();
  }

  Future<List<SupabaseFeed>> getRandomFeeds({int limit = 10}) async {
    final data = await _client
        .from('feeds')
        .select()
        .limit(50); // Fetch up to 50 feeds

    final allFeeds =
        (data as List).map((row) => SupabaseFeed.fromJson(row)).toList();
    allFeeds.shuffle();
    return allFeeds.take(limit).toList();
  }

  Future<void> suggestFeed(String url, String? name) async {
    await _client.from('feed_suggestions').insert({
      'suggested_url': url,
      'suggested_name': name,
    });
  }

  Future<void> incrementEnableCount(String feedId) async {
    try {
      await _client.functions.invoke(
        'increment-enable-count',
        body: {'feedId': feedId},
      );
    } catch (e) {
      // Non-critical, fire-and-forget
    }
  }

  Future<String?> checkIfFeedExists(String url) async {
    final response =
        await _client
            .from('feeds')
            .select('category')
            .eq('rss_url', url)
            .maybeSingle();

    if (response != null) {
      return response['category'] as String?;
    }
    return null;
  }

  Future<SupabaseFeed> addFeedToLibrary({
    required String url,
    required String name,
    required String description,
    required String siteUrl,
    required String logoUrl,
    required String category,
  }) async {
    final response =
        await _client
            .from('feeds')
            .insert({
              'rss_url': url,
              'name': name,
              'description': description,
              'site_url': siteUrl,
              'logo_url': logoUrl,
              'category': category,
            })
            .select()
            .single();

    return SupabaseFeed.fromJson(response);
  }
}
