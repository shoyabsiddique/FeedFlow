import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../core/db/article.dart';
import '../../core/providers/isar_provider.dart';
import '../../core/providers/repository_providers.dart';

// Simple provider to fetch a single article
final articleProvider = FutureProvider.family<Article?, int>((ref, id) async {
  final isar = await ref.watch(isarProvider.future);
  final article = await isar.articles.get(id);

  // Mark as read when fetched for reading
  if (article != null && !article.isRead) {
    ref.read(articleRepositoryProvider).markRead(id);
  }

  return article;
});

String _readingTime(String? text) {
  if (text == null || text.isEmpty) return '';
  final wordCount = text.trim().split(RegExp(r'\s+')).length;
  final minutes = (wordCount / 225).ceil();
  return '$minutes min read';
}

class ReaderScreen extends ConsumerWidget {
  final int articleId;
  const ReaderScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncArticle = ref.watch(articleProvider(articleId));

    return asyncArticle.when(
      data: (article) {
        if (article == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Article not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: Icon(
                  article.isBookmarked
                      ? Icons.bookmark
                      : Icons.bookmark_outline,
                ),
                onPressed: () async {
                  // Await DB write before invalidating so the icon reflects the new state
                  await ref
                      .read(articleRepositoryProvider)
                      .toggleBookmark(article.id);
                  ref.invalidate(articleProvider(articleId));
                },
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                onPressed: () async {
                  final uri = Uri.tryParse(article.url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
          body:
              article.body != null && article.body!.isNotEmpty
                  // Mock readable mode vs webview
                  ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              timeago.format(article.publishedAt),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '·',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _readingTime(article.body ?? article.summary),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          article.body ?? article.summary,
                          style: const TextStyle(fontSize: 18, height: 1.6),
                        ),
                      ],
                    ),
                  )
                  // Fallback to InAppWebView if no nice parsed body (or just displaying the site)
                  : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(article.url)),
                  ),
        );
      },
      loading:
          () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, __) => Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('Error: $e')),
          ),
    );
  }
}
