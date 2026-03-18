import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/db/article.dart';
import '../../core/providers/repository_providers.dart';
import '../../shared/widgets/article_card.dart';

part 'search_screen.g.dart';

@riverpod
class SearchNotifier extends _$SearchNotifier {
  @override
  List<Article> build() => [];

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = [];
      return;
    }
    final repo = ref.read(articleRepositoryProvider);
    state = await repo.search(query);
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search articles...',
            border: InputBorder.none,
          ),
          onChanged: (val) {
             // Basic debounce can be added here
             ref.read(searchNotifierProvider.notifier).search(val);
          },
        ),
      ),
      body: results.isEmpty && _controller.text.isNotEmpty
          ? const Center(child: Text('No articles found.'))
          : ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ArticleCard(
                  article: results[index],
                  sourceName: 'Search Result',
                );
              },
            ),
    );
  }
}
