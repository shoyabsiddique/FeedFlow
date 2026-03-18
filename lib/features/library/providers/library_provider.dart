import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/supabase_library_service.dart';
import '../../../core/db/feed_source.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/providers/repository_providers.dart';

part 'library_provider.g.dart';

class FeedWithStatus {
  final SupabaseFeed feed;
  final bool isEnabled;

  FeedWithStatus({required this.feed, required this.isEnabled});

  FeedWithStatus copyWith({SupabaseFeed? feed, bool? isEnabled}) {
    return FeedWithStatus(
      feed: feed ?? this.feed,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

@riverpod
class LibraryNotifier extends _$LibraryNotifier {
  @override
  Future<List<FeedWithStatus>> build() async {
    final supabaseFeeds = await ref.read(supabaseLibraryServiceProvider).fetchAllFeeds();
    final enabledIds = (await ref.read(feedRepositoryProvider).getEnabledFeeds())
        .map((f) => f.supabaseId)
        .whereType<String>()
        .toSet();

    return supabaseFeeds
        .map((f) => FeedWithStatus(
              feed: f,
              isEnabled: enabledIds.contains(f.id),
            ))
        .toList();
  }

  Future<void> toggleFeed(SupabaseFeed feed, bool enable) async {
    // Optimistic UI update
    state = state.whenData((list) => list.map((item) {
          if (item.feed.id == feed.id) return item.copyWith(isEnabled: enable);
          return item;
        }).toList());

    try {
      final repo = ref.read(feedRepositoryProvider);
      
      if (enable) {
        final source = FeedSource()
          ..rssUrl = feed.rssUrl
          ..name = feed.name
          ..description = feed.description
          ..siteUrl = feed.siteUrl
          ..logoUrl = feed.logoUrl
          ..category = feed.category
          ..isEnabled = true
          ..isFromLibrary = true
          ..supabaseId = feed.id;

        await repo.saveFeed(source);
        ref.read(supabaseLibraryServiceProvider).incrementEnableCount(feed.id); // Fire and forget
      } else {
        await repo.disableBySupabaseId(feed.id);
      }
    } catch (e) {
      // Revert upon failure
      state = state.whenData((list) => list.map((item) {
            if (item.feed.id == feed.id) return item.copyWith(isEnabled: !enable);
            return item;
          }).toList());
      debugPrint('Toggle failed: $e');
    }
  }
}
