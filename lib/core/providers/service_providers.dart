import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'repository_providers.dart';
import '../services/supabase_library_service.dart';
import '../services/rss_parser_service.dart';
import '../services/notification_service.dart';
import '../services/background_sync_service.dart';

part 'service_providers.g.dart';

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  return Supabase.instance.client;
}

@Riverpod(keepAlive: true)
SupabaseLibraryService supabaseLibraryService(SupabaseLibraryServiceRef ref) {
  return SupabaseLibraryService(ref.watch(supabaseClientProvider));
}

@Riverpod(keepAlive: true)
Dio dio(DioRef ref) {
  final dio = Dio();
  dio.options.connectTimeout = const Duration(seconds: 10);
  dio.options.receiveTimeout = const Duration(seconds: 10);
  return dio;
}

@Riverpod(keepAlive: true)
RssParserService rssParserService(RssParserServiceRef ref) {
  return RssParserService(ref.watch(dioProvider));
}

@Riverpod(keepAlive: true)
NotificationService notificationService(NotificationServiceRef ref) {
  final service = NotificationService();
  service.init();
  return service;
}

@Riverpod(keepAlive: true)
BackgroundSyncService backgroundSyncService(BackgroundSyncServiceRef ref) {
  return BackgroundSyncService(
    feedRepo: ref.watch(feedRepositoryProvider),
    articleRepo: ref.watch(articleRepositoryProvider),
    parser: ref.watch(rssParserServiceProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
}
