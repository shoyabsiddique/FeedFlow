import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/service_providers.dart';
import 'providers/library_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryNotifierProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search categories',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged:
                  (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
        ),
      ),
      body: libraryState.when(
        data: (feeds) {
          // Group feeds by category
          final Map<String, List<FeedWithStatus>> grouped = {};
          for (final item in feeds) {
            grouped.putIfAbsent(item.feed.category, () => []).add(item);
          }

          final sortedCategories = grouped.keys.toList()..sort();

          // Filter categories by search
          final filteredCategories =
              sortedCategories.where((cat) {
                return cat.toLowerCase().contains(_searchQuery);
              }).toList();

          if (filteredCategories.isEmpty) {
            return const Center(child: Text('No categories found.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 1.1,
            ),
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final category = filteredCategories[index];
              final categoryFeeds = grouped[category]!;

              return InkWell(
                onTap: () {
                  context.go('/library/category/$category');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.folder_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        category,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${categoryFeeds.length} sources',
                        style: TextStyle(
                          color:
                              Theme.of(
                                context,
                              ).textTheme.bodySmall?.color?.withOpacity(0.7) ??
                              Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error loading library: $e')),
      ),
      floatingActionButton: libraryState.maybeWhen(
        data: (feeds) {
          final Set<String> categories =
              feeds.map((f) => f.feed.category).toSet();
          final List<String> sortedCategories = categories.toList()..sort();
          return FloatingActionButton.extended(
            onPressed: () => _showAddCustomDialog(context, sortedCategories),
            icon: const Icon(Icons.add),
            label: const Text('Add Custom'),
          );
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _showAddCustomDialog(
    BuildContext context,
    List<String> categories,
  ) async {
    String selectedCategory = categories.isNotEmpty ? categories.first : 'News';
    final urlController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Custom Feed'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items:
                          categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setDialogState(() => selectedCategory = val);
                      },
                    )
                  else
                    TextField(
                      onChanged: (val) => selectedCategory = val,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'RSS Feed Link',
                      hintText: 'https://...',
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            final url = urlController.text.trim();
                            if (url.isEmpty || selectedCategory.isEmpty) return;

                            setDialogState(() => isLoading = true);

                            try {
                              final libraryService = ref.read(
                                supabaseLibraryServiceProvider,
                              );
                              // 1. Check if feed exists
                              final existingCategory = await libraryService
                                  .checkIfFeedExists(url);

                              if (existingCategory != null) {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Feed already exists in category: $existingCategory',
                                      ),
                                    ),
                                  );
                                }
                                setDialogState(() => isLoading = false);
                                return;
                              }

                              // 2. Validate and fetch feed
                              final parserService = ref.read(
                                rssParserServiceProvider,
                              );
                              final metadata = await parserService
                                  .fetchFeedMetadata(url);

                              // 3. Add to Supabase
                              await libraryService.addFeedToLibrary(
                                url: url,
                                name: metadata['title'] ?? 'Unknown',
                                description: metadata['description'] ?? '',
                                siteUrl: metadata['siteUrl'] ?? url,
                                logoUrl: metadata['logoUrl'] ?? '',
                                category: selectedCategory,
                              );

                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text('Feed added successfully!'),
                                  ),
                                );
                                // Refresh library
                                ref.invalidate(libraryNotifierProvider);
                                Navigator.pop(dialogContext);
                              }
                            } catch (e) {
                              log(e.toString());
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              log('finally');
                              if (dialogContext.mounted)
                                setDialogState(() => isLoading = false);
                            }
                          },
                  child: const Text('Add Feed'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
