import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/feed_source.dart';
import '../db/article.dart';
import '../db/user_tag.dart';
import '../db/app_settings.dart';

part 'isar_provider.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(IsarRef ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return await Isar.open(
    [
      FeedSourceSchema,
      ArticleSchema,
      UserTagSchema,
      AppSettingsSchema,
    ],
    directory: dir.path,
  );
}
