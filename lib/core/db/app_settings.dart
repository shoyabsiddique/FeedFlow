import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  int globalArticleCap = 10;
  int globalTimeCap = 0; // hours, 0 = all time
  int syncIntervalMinutes = 60;
  bool notificationsEnabled = true;

  String theme = 'system';
  String discoverySearchEngine = 'https://duckduckgo.com';

  String? lastCategoryFilter;
  String? lastTagFilter;
}
