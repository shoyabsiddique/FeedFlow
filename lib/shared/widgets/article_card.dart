import 'package:flutter/material.dart';
import '../../core/db/article.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class ArticleCard extends StatelessWidget {
  final Article article;
  final String sourceName;
  final String? sourceLogoUrl;

  const ArticleCard({
    super.key, 
    required this.article,
    required this.sourceName,
    this.sourceLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/article/${article.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      if (sourceLogoUrl != null && sourceLogoUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: CircleAvatar(
                            radius: 10,
                            backgroundImage: NetworkImage(sourceLogoUrl!),
                            onBackgroundImageError: (_, __) => const Icon(Icons.rss_feed, size: 10),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.rss_feed, size: 16),
                        ),
                      Expanded(
                        child: Text(
                          sourceName,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeago.format(article.publishedAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.summary.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim(), // Strip HTML
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (article.thumbnailUrl != null)
              Container(
                margin: const EdgeInsets.only(left: 16),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(article.thumbnailUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
