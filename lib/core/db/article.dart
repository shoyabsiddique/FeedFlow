import 'package:isar/isar.dart';

part 'article.g.dart';

@collection
class Article {
  Id id = Isar.autoIncrement;

  @Index()
  late int feedSourceId;

  late String guid;

  @Index(type: IndexType.value)
  late String title;

  @Index(type: IndexType.value)
  late String summary;

  String? body;

  late String url;
  String? thumbnailUrl;

  late DateTime publishedAt;
  late DateTime fetchedAt;

  bool isRead = false;
  bool isBookmarked = false;
}
