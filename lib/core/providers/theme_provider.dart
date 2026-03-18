import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../db/app_settings.dart';
import 'isar_provider.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<ThemeMode> themeMode(ThemeModeRef ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.appSettings.where().watch(fireImmediately: true).map((list) {
    final theme = list.firstOrNull?.theme ?? 'system';
    switch (theme) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  });
}

Future<void> saveTheme(Isar isar, String theme) async {
  final existing = await isar.appSettings.where().findFirst() ?? AppSettings();
  await isar.writeTxn(() async {
    existing.theme = theme;
    await isar.appSettings.put(existing);
  });
}
