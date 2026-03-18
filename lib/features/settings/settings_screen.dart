import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/db/app_settings.dart';
import '../../core/providers/isar_provider.dart';
import '../../core/providers/theme_provider.dart';

final settingsProvider = StreamProvider<AppSettings?>((ref) async* {
  final isar = await ref.watch(isarProvider.future);
  yield* isar.appSettings.where().watch(fireImmediately: true).map((list) => list.firstOrNull);
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: settingsAsync.when(
        data: (settings) {
          final s = settings ?? AppSettings();
          
          return ListView(
            children: [
              // --- Theme ---
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'light', icon: Icon(Icons.light_mode), label: Text('Light')),
                    ButtonSegment(value: 'system', icon: Icon(Icons.brightness_auto), label: Text('System')),
                    ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode), label: Text('Dark')),
                  ],
                  selected: {s.theme},
                  onSelectionChanged: (selection) async {
                    final isar = await ref.read(isarProvider.future);
                    await saveTheme(isar, selection.first);
                  },
                ),
              ),
              const Divider(),
              // --- Sync ---
              SwitchListTile(
                title: const Text('Background Sync'),
                subtitle: const Text('Periodically fetch new articles'),
                value: s.syncIntervalMinutes > 0,
                onChanged: (val) async {
                  final isar = await ref.read(isarProvider.future);
                  await isar.writeTxn(() async {
                    s.syncIntervalMinutes = val ? (24 * 60) : 0;
                    await isar.appSettings.put(s);
                  });
                  
                  if (val) {
                    Workmanager().registerPeriodicTask(
                      'feedflow_sync',
                      'sync_articles',
                      frequency: const Duration(hours: 24),
                      constraints: Constraints(
                        networkType: NetworkType.connected,
                      ),
                    );
                  } else {
                    Workmanager().cancelAll();
                  }
                },
              ),
              ListTile(
                title: const Text('Global Feed Limit'),
                subtitle: Text('Max ${s.globalArticleCap} articles per feed'),
                trailing: DropdownButton<int>(
                  value: s.globalArticleCap,
                  items: [10, 20, 50, 100].map((v) => DropdownMenuItem(value: v, child: Text(v.toString()))).toList(),
                  onChanged: (val) async {
                    if (val == null) return;
                    final isar = await ref.read(isarProvider.future);
                    await isar.writeTxn(() async {
                      s.globalArticleCap = val;
                      await isar.appSettings.put(s);
                    });
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Import OPML'),
                onTap: () {
                  // Future: open file picker and import
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Export OPML'),
                onTap: () {
                  // Future: generate OPML and trigger share dialog
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
