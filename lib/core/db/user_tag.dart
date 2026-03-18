import 'package:isar/isar.dart';

part 'user_tag.g.dart';

@collection
class UserTag {
  Id id = Isar.autoIncrement;

  late String label;
  late String color;
  
  late DateTime createdAt;
}
