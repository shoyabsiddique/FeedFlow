import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'isar_provider.dart';
import '../db/repositories/feed_repository.dart';
import '../db/repositories/article_repository.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
FeedRepository feedRepository(FeedRepositoryRef ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return FeedRepository(isar);
}

@Riverpod(keepAlive: true)
ArticleRepository articleRepository(ArticleRepositoryRef ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return ArticleRepository(isar);
}
