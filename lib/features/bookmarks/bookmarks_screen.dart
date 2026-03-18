import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/article.dart';
import '../../core/providers/repository_providers.dart';
import '../../shared/widgets/article_card.dart';

final bookmarksProvider = StreamProvider<List<Article>>((ref) {
  return ref.watch(articleRepositoryProvider).watchBookmarks();
});

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(bookmarksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: stream.when(
        data: (articles) {
          if (articles.isEmpty) {
            return const Center(child: Text('No bookmarked articles yet.'));
          }
          return ListView.separated(
            itemCount: articles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return ArticleCard(
                article: articles[index],
                sourceName: 'Saved Source', // Simplified for now
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error loading bookmarks: $e')),
      ),
    );
  }
}
