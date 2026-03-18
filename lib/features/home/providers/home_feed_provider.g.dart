// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$homeFeedHash() => r'597b27f905435e72c0cbb319a2242ece43ea54d5';

/// See also [homeFeed].
@ProviderFor(homeFeed)
final homeFeedProvider = AutoDisposeStreamProvider<List<Article>>.internal(
  homeFeed,
  name: r'homeFeedProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$homeFeedHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HomeFeedRef = AutoDisposeStreamProviderRef<List<Article>>;
String _$feedSourceNamesHash() => r'6fab127856d7f7d8c534e9669b54c9c038cc5fd4';

/// Watches all local FeedSources and returns a map of id → name for display.
///
/// Copied from [feedSourceNames].
@ProviderFor(feedSourceNames)
final feedSourceNamesProvider =
    AutoDisposeStreamProvider<Map<int, String>>.internal(
  feedSourceNames,
  name: r'feedSourceNamesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$feedSourceNamesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FeedSourceNamesRef = AutoDisposeStreamProviderRef<Map<int, String>>;
String _$feedCategoriesHash() => r'f9f8c6c16ed2a1d1367b1de464e4381147224d32';

/// Returns distinct categories from all local FeedSources the user has added.
///
/// Copied from [feedCategories].
@ProviderFor(feedCategories)
final feedCategoriesProvider = AutoDisposeStreamProvider<List<String>>.internal(
  feedCategories,
  name: r'feedCategoriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$feedCategoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FeedCategoriesRef = AutoDisposeStreamProviderRef<List<String>>;
String _$activeCategoryFilterHash() =>
    r'2613676de6f9ec9677a24edd16f1f241c8586874';

/// See also [ActiveCategoryFilter].
@ProviderFor(ActiveCategoryFilter)
final activeCategoryFilterProvider =
    AutoDisposeNotifierProvider<ActiveCategoryFilter, String?>.internal(
  ActiveCategoryFilter.new,
  name: r'activeCategoryFilterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeCategoryFilterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveCategoryFilter = AutoDisposeNotifier<String?>;
String _$activeTagFilterHash() => r'53edbb569a7b73495706e7a1a8f022ac773cf9cf';

/// See also [ActiveTagFilter].
@ProviderFor(ActiveTagFilter)
final activeTagFilterProvider =
    AutoDisposeNotifierProvider<ActiveTagFilter, String?>.internal(
  ActiveTagFilter.new,
  name: r'activeTagFilterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeTagFilterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveTagFilter = AutoDisposeNotifier<String?>;
String _$activeSortOrderHash() => r'05528ce35598ce2c6b98eb264d986ee117ff1049';

/// See also [ActiveSortOrder].
@ProviderFor(ActiveSortOrder)
final activeSortOrderProvider =
    AutoDisposeNotifierProvider<ActiveSortOrder, SortOrder>.internal(
  ActiveSortOrder.new,
  name: r'activeSortOrderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeSortOrderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ActiveSortOrder = AutoDisposeNotifier<SortOrder>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
