import 'package:isar/isar.dart';

part 'feed_source.g.dart';

@collection
class FeedSource {
  Id id = Isar.autoIncrement;

  late String rssUrl;
  late String name;
  late String description;
  late String siteUrl;
  late String logoUrl;
  late String category;
  
  List<String> userTags = [];
  
  bool isEnabled = true;
  bool isFromLibrary = false;
  String? supabaseId;

  int articleCap = 10;
  int timeCap = 0; // 0 = global setting

  DateTime? lastSyncedAt;
}
